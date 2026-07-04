"""西瓜敲击声特征提取（Python 端，训练用）。

必须与 Dart 端 lib/core/feature_extractor.dart 保持相同参数（见 feature_spec.json），
否则训练特征与端上推理特征不一致会严重掉点。

产出一个固定长度(33维)的特征向量，供轻量分类器(逻辑回归/随机森林/MLP)使用。
"""
from __future__ import annotations

import json
import os
from dataclasses import dataclass

import numpy as np
import librosa

_SPEC_PATH = os.path.join(os.path.dirname(__file__), "feature_spec.json")

with open(_SPEC_PATH, "r", encoding="utf-8") as f:
    SPEC = json.load(f)

SR = SPEC["sample_rate"]
N_FFT = SPEC["n_fft"]
HOP = SPEC["hop_length"]
WIN = SPEC["win_length"]
N_MELS = SPEC["n_mels"]
FMIN = SPEC["fmin"]
FMAX = SPEC["fmax"]
N_MFCC = SPEC["n_mfcc"]
TAP_WIN = SPEC["tap_window_seconds"]
PRE_ONSET = SPEC["pre_onset_seconds"]
FEATURE_ORDER = SPEC["feature_order"]
LABELS = SPEC["labels"]


@dataclass
class Tap:
    """单次敲击的截取波形（已重采样到 SR、单声道、float32）。"""
    y: np.ndarray
    sr: int = SR


def load_audio(path: str) -> np.ndarray:
    """读入任意音频，转单声道并重采样到目标采样率。"""
    y, _ = librosa.load(path, sr=SR, mono=True)
    return y.astype(np.float32)


def detect_taps(y: np.ndarray, sr: int = SR) -> list[np.ndarray]:
    """从一段录音里检测敲击事件，返回每次敲击对应的定长窗口波形。

    使用 onset 检测；每个 onset 向前留 pre_onset，截取 tap_window 秒。
    若检测不到，则退化为对整段做一次截取。
    """
    win_len = int(TAP_WIN * sr)
    pre_len = int(PRE_ONSET * sr)

    onsets = librosa.onset.onset_detect(
        y=y, sr=sr, units="samples", hop_length=HOP, backtrack=True
    )
    taps: list[np.ndarray] = []
    for on in onsets:
        start = max(0, int(on) - pre_len)
        seg = y[start:start + win_len]
        if len(seg) < win_len:
            seg = np.pad(seg, (0, win_len - len(seg)))
        # 过滤能量过低的伪 onset
        if float(np.sqrt(np.mean(seg ** 2))) > 1e-4:
            taps.append(seg.astype(np.float32))

    if not taps:
        seg = y[:win_len] if len(y) >= win_len else np.pad(y, (0, win_len - len(y)))
        taps.append(seg.astype(np.float32))
    return taps


def _decay_time(y: np.ndarray, sr: int) -> float:
    """振幅包络从峰值衰减到 10% 所需时间（秒）。成熟瓜通常衰减更慢。"""
    env = np.abs(librosa.util.normalize(y))
    peak_idx = int(np.argmax(env))
    peak = env[peak_idx]
    if peak <= 0:
        return 0.0
    thresh = 0.1 * peak
    tail = env[peak_idx:]
    below = np.where(tail < thresh)[0]
    if len(below) == 0:
        return len(tail) / sr
    return float(below[0]) / sr


def extract_features(tap: np.ndarray, sr: int = SR) -> np.ndarray:
    """从单次敲击窗口提取 33 维特征向量，顺序与 feature_order 一致。"""
    y = tap.astype(np.float32)

    # 梅尔谱参数与 Dart 端严格对齐：HTK mel + norm=None + power=2 + power_to_db(ref=1, top_db=80) + DCT-II ortho
    melspec = librosa.feature.melspectrogram(
        y=y, sr=sr, n_fft=N_FFT, hop_length=HOP, win_length=WIN,
        n_mels=N_MELS, fmin=FMIN, fmax=FMAX, power=2.0,
        htk=True, norm=None, window="hann", center=True,
    )
    s_db = librosa.power_to_db(melspec, ref=1.0, top_db=80.0)
    mfcc = librosa.feature.mfcc(S=s_db, n_mfcc=N_MFCC, dct_type=2, norm="ortho")
    mfcc_mean = np.mean(mfcc, axis=1)
    mfcc_std = np.std(mfcc, axis=1)

    centroid = float(np.mean(librosa.feature.spectral_centroid(
        y=y, sr=sr, n_fft=N_FFT, hop_length=HOP)))
    bandwidth = float(np.mean(librosa.feature.spectral_bandwidth(
        y=y, sr=sr, n_fft=N_FFT, hop_length=HOP)))
    rolloff = float(np.mean(librosa.feature.spectral_rolloff(
        y=y, sr=sr, n_fft=N_FFT, hop_length=HOP)))
    # 整段过零率（与 Dart 端实现一致：符号变化数 / 样本数）
    signs = (y >= 0).astype(np.int8)
    zcr = float(np.sum(np.abs(np.diff(signs)))) / max(1, len(y))

    # 主共振频率：平均功率谱的峰值频率
    spec = np.abs(librosa.stft(y, n_fft=N_FFT, hop_length=HOP, win_length=WIN)) ** 2
    avg_spec = np.mean(spec, axis=1)
    freqs = np.linspace(0, sr / 2, len(avg_spec))
    dominant = float(freqs[int(np.argmax(avg_spec))])

    log_energy = float(np.log1p(np.sum(y ** 2)))
    decay = _decay_time(y, sr)

    vec = np.concatenate([
        mfcc_mean, mfcc_std,
        [centroid, bandwidth, rolloff, zcr, dominant, log_energy, decay],
    ]).astype(np.float32)

    assert len(vec) == len(FEATURE_ORDER), (
        f"特征维度 {len(vec)} 与规范 {len(FEATURE_ORDER)} 不一致")
    return vec


def extract_from_file(path: str) -> np.ndarray:
    """从一个音频文件提取特征：检测所有敲击，逐一提特征后取平均。"""
    y = load_audio(path)
    taps = detect_taps(y)
    feats = np.stack([extract_features(t) for t in taps], axis=0)
    return np.mean(feats, axis=0)
