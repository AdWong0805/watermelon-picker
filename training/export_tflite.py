"""进阶路线（可选）：梅尔谱 + 小型 CNN -> TFLite。

仅当数据量较大、想追求更高精度时使用。需要 `pip install tensorflow`。
默认的部署路线是 train.py 的逻辑回归(model.json，纯 Dart 评估)，无需 TensorFlow。

本文件给出一个可运行的骨架：加载 data/ 下音频 -> 计算对数梅尔谱(定长) -> 训练 CNN -> 导出 tflite。
"""
from __future__ import annotations

import os

import numpy as np

from features import load_audio, detect_taps, SR, N_FFT, HOP, N_MELS, FMIN, FMAX, LABELS
from train import discover_samples

HERE = os.path.dirname(__file__)
APP_ASSETS = os.path.abspath(os.path.join(HERE, "..", "assets", "models"))
N_FRAMES = 16  # 定长时间帧数（tap_window≈0.35s / hop）


def logmel(y: np.ndarray) -> np.ndarray:
    import librosa
    m = librosa.feature.melspectrogram(
        y=y, sr=SR, n_fft=N_FFT, hop_length=HOP, n_mels=N_MELS, fmin=FMIN, fmax=FMAX)
    m = librosa.power_to_db(m, ref=np.max)
    if m.shape[1] < N_FRAMES:
        m = np.pad(m, ((0, 0), (0, N_FRAMES - m.shape[1])))
    else:
        m = m[:, :N_FRAMES]
    return m.astype(np.float32)


def main():
    try:
        import tensorflow as tf
    except ImportError:
        print("未安装 tensorflow。请先 pip install tensorflow，或改用 train.py 的逻辑回归路线。")
        return

    samples = discover_samples(os.path.join(HERE, "data"))
    if not samples:
        print("data/ 下没有样本。")
        return

    X, y = [], []
    for fp, label in samples:
        if label not in LABELS:
            continue
        try:
            for tap in detect_taps(load_audio(fp)):
                X.append(logmel(tap))
                y.append(LABELS.index(label))
        except Exception as e:  # noqa: BLE001
            print(f"跳过 {fp}: {e}")

    X = np.array(X)[..., np.newaxis]
    y = np.array(y)
    print(f"数据: X={X.shape}")

    model = tf.keras.Sequential([
        tf.keras.layers.Input(shape=(N_MELS, N_FRAMES, 1)),
        tf.keras.layers.Conv2D(16, 3, activation="relu", padding="same"),
        tf.keras.layers.MaxPool2D(2),
        tf.keras.layers.Conv2D(32, 3, activation="relu", padding="same"),
        tf.keras.layers.GlobalAveragePooling2D(),
        tf.keras.layers.Dense(32, activation="relu"),
        tf.keras.layers.Dense(len(LABELS), activation="softmax"),
    ])
    model.compile(optimizer="adam", loss="sparse_categorical_crossentropy",
                  metrics=["accuracy"])
    model.fit(X, y, epochs=30, validation_split=0.2, batch_size=16)

    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    tflite = converter.convert()
    os.makedirs(APP_ASSETS, exist_ok=True)
    with open(os.path.join(APP_ASSETS, "ripeness_model.tflite"), "wb") as f:
        f.write(tflite)
    with open(os.path.join(APP_ASSETS, "labels.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(LABELS))
    print(f"已导出 tflite 到 {APP_ASSETS}")


if __name__ == "__main__":
    main()
