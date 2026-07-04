"""训练西瓜成熟度分类器，并导出可供 App 端使用的模型。

数据组织方式（两种任选）：
  A) data/labels.csv  含列: filepath,label     (filepath 相对 data/ 或绝对路径)
  B) data/<label>/*.wav  按标签建子目录 (unripe/ ripe/ overripe/)

用法：
  python train.py                     # 自动发现 data/ 下数据
  python train.py --data ./data       # 指定数据目录
  python train.py --model logreg      # logreg(默认,可纯Dart评估) | rf(随机森林,仅报告)

导出：
  artifacts/model.json     -> StandardScaler + 多类逻辑回归权重 (纯 Dart 可直接评估)
  artifacts/metrics.txt    -> 交叉验证报告
并可用 --deploy 直接拷贝到 App 的 assets/models/model.json
"""
from __future__ import annotations

import argparse
import csv
import json
import os
import shutil

import numpy as np
from sklearn.linear_model import LogisticRegression
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import cross_val_score, StratifiedKFold
from sklearn.preprocessing import StandardScaler

from features import extract_from_file, FEATURE_ORDER, LABELS, SPEC

HERE = os.path.dirname(__file__)
DEFAULT_DATA = os.path.join(HERE, "data")
ARTIFACTS = os.path.join(HERE, "artifacts")
APP_ASSETS = os.path.abspath(os.path.join(HERE, "..", "assets", "models"))


def discover_samples(data_dir: str) -> list[tuple[str, str]]:
    """返回 [(filepath, label), ...]。优先用 labels.csv，否则按子目录名当标签。"""
    samples: list[tuple[str, str]] = []
    csv_path = os.path.join(data_dir, "labels.csv")
    if os.path.exists(csv_path):
        with open(csv_path, newline="", encoding="utf-8") as f:
            for row in csv.DictReader(f):
                fp = row["filepath"]
                if not os.path.isabs(fp):
                    fp = os.path.join(data_dir, fp)
                samples.append((fp, row["label"].strip()))
        return samples

    for label in LABELS:
        sub = os.path.join(data_dir, label)
        if not os.path.isdir(sub):
            continue
        for name in os.listdir(sub):
            if name.lower().endswith((".wav", ".m4a", ".mp3", ".flac", ".ogg")):
                samples.append((os.path.join(sub, name), label))
    return samples


def build_dataset(samples: list[tuple[str, str]]):
    X, y = [], []
    for fp, label in samples:
        if label not in LABELS:
            print(f"  跳过未知标签 {label}: {fp}")
            continue
        try:
            X.append(extract_from_file(fp))
            y.append(LABELS.index(label))
        except Exception as e:  # noqa: BLE001
            print(f"  提取失败 {fp}: {e}")
    return np.array(X, dtype=np.float32), np.array(y, dtype=np.int64)


def export_logreg(scaler: StandardScaler, clf: LogisticRegression, path: str):
    """导出为纯 Dart 可评估的 JSON：标准化参数 + softmax 权重。"""
    coef = clf.coef_
    intercept = clf.intercept_
    # 二分类时 sklearn 只给一行权重，补成两类 softmax 形式
    if coef.shape[0] == 1:
        coef = np.vstack([-coef[0], coef[0]])
        intercept = np.array([-intercept[0], intercept[0]])
    model = {
        "type": "logreg",
        "feature_order": FEATURE_ORDER,
        "labels": LABELS,
        "labels_zh": SPEC["labels_zh"],
        "scaler_mean": scaler.mean_.tolist(),
        "scaler_scale": scaler.scale_.tolist(),
        "coef": coef.tolist(),
        "intercept": intercept.tolist(),
        "spec_version": SPEC["version"],
    }
    with open(path, "w", encoding="utf-8") as f:
        json.dump(model, f, ensure_ascii=False, indent=2)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default=DEFAULT_DATA)
    ap.add_argument("--model", choices=["logreg", "rf"], default="logreg")
    ap.add_argument("--deploy", action="store_true",
                    help="训练后把 model.json 拷贝到 App 的 assets/models/")
    args = ap.parse_args()

    os.makedirs(ARTIFACTS, exist_ok=True)

    samples = discover_samples(args.data)
    if not samples:
        print(f"未在 {args.data} 找到任何样本。")
        print("请先用 App 的采集页录制带标签的敲击声并导出，或按 data/<label>/*.wav 组织。")
        return
    print(f"发现 {len(samples)} 条样本，开始提取特征……")
    X, y = build_dataset(samples)
    print(f"数据集: X={X.shape}, 各类数量={np.bincount(y, minlength=len(LABELS))}")

    if len(np.unique(y)) < 2:
        print("至少需要两个类别的数据才能训练。")
        return

    scaler = StandardScaler().fit(X)
    Xs = scaler.transform(X)

    n_splits = min(5, np.min(np.bincount(y)))
    report_lines = [f"样本数={len(y)}  各类={np.bincount(y, minlength=len(LABELS)).tolist()}"]

    if args.model == "rf":
        clf = RandomForestClassifier(n_estimators=300, random_state=42)
    else:
        clf = LogisticRegression(max_iter=2000, multi_class="auto")

    if n_splits >= 2:
        cv = StratifiedKFold(n_splits=n_splits, shuffle=True, random_state=42)
        scores = cross_val_score(clf, Xs, y, cv=cv)
        line = f"{args.model} {n_splits}折交叉验证准确率: {scores.mean():.3f} ± {scores.std():.3f}"
        print(line)
        report_lines.append(line)
    else:
        report_lines.append("样本过少，跳过交叉验证。")

    clf.fit(Xs, y)

    with open(os.path.join(ARTIFACTS, "metrics.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(report_lines) + "\n")

    if args.model == "logreg":
        out = os.path.join(ARTIFACTS, "model.json")
        export_logreg(scaler, clf, out)
        print(f"已导出 {out}")
        if args.deploy:
            os.makedirs(APP_ASSETS, exist_ok=True)
            dst = os.path.join(APP_ASSETS, "model.json")
            shutil.copy(out, dst)
            print(f"已部署到 App: {dst}")
    else:
        print("随机森林仅用于评估参考；部署请用 --model logreg（可纯 Dart 评估）。")


if __name__ == "__main__":
    main()
