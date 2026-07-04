# 训练管线（Python）

把 App 采集/导出的"敲击声 + 真实标签"训练成一个轻量分类器，导出给 App 端使用。

## 环境

```bash
cd training
python -m venv .venv
# Windows PowerShell:
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

## 数据组织（二选一）

**方式 A：labels.csv**
```
training/data/
  labels.csv        # 列: filepath,label
  clip_0001.wav
  clip_0002.wav
```
`label` 取值：`unripe` / `ripe` / `overripe`（见 feature_spec.json）。

**方式 B：按标签分目录**
```
training/data/
  unripe/*.wav
  ripe/*.wav
  overripe/*.wav
```

> 数据来源：用 App 的"采集"页，敲西瓜录音 → 切开后填真实标签 → 导出 zip，解压到 `data/`。

## 训练 & 导出

```bash
python train.py --deploy              # 逻辑回归(默认)，训练后直接部署到 App assets
python train.py --model rf            # 随机森林，仅用于评估准确率对比
```

产出：
- `artifacts/model.json` —— **纯 Dart 可直接评估**（StandardScaler + 多类 softmax）。`--deploy` 会拷到 `../assets/models/model.json`，App 下次构建即从"启发式模式"升级为"ML 模式"。
- `artifacts/metrics.txt` —— 交叉验证准确率。

## 特征对齐（重要）

训练特征(Python/librosa)与端上推理特征(Dart)必须一致，否则严重掉点。
用 `dump_features.py` 对同一段录音导出 Python 特征，与 App 开发者页导出的 Dart 特征逐项比对：

```bash
python dump_features.py data/ripe/clip_0001.wav
```

差异大时，需按 `feature_spec.json` 校准 Dart 端 `feature_extractor.dart`。

## 进阶：CNN + TFLite（数据量大以后）

数据充足后可切换到"梅尔谱 + CNN → TFLite"路线以提精度：
1. `pip install tensorflow`
2. 见 `export_tflite.py`（占位/示例）。
3. 产出 `ripeness_model.tflite` + `labels.txt` 放入 `../assets/models/`，App 端改用 `TfliteClassifier`。
