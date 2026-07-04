# 瓜熟 (GuaShu) — 西瓜成熟度声学检测 App

用手机麦克风录制"敲击西瓜"的声音，通过信号处理 + 机器学习判断西瓜成熟度（未熟 / 适中·好吃 / 过熟）。跨平台（Android / iOS），端上推理，离线可用。

## 快速开始（Android）

```powershell
cd "C:\Users\AD Wang\watermelon"
flutter pub get
flutter run          # 连真机或开模拟器
```

> 声学检测建议用**真机**测试（模拟器没有真实麦克风/敲击声）。

## 目录结构

```
lib/
  main.dart                 应用入口，启动时加载分类器
  core/
    feature_spec.dart       特征规范常量（与 training/feature_spec.json 对齐）
    wav.dart                WAV 读写
    dsp.dart                FFT / 梅尔滤波器组 / DCT
    feature_extractor.dart  33 维特征提取
    tap_detector.dart       敲击(onset)检测
    audio_recorder.dart     录音封装
    detection_service.dart  录音->检测->特征->分类 编排
    classifier.dart         分类器接口
    heuristic_classifier.dart  冷启动经验规则分类器
    model_classifier.dart   ML 逻辑回归分类器(读 model.json)
    classifier_factory.dart 有模型走 ML，否则回退启发式
    sample_repository.dart  采集样本本地存储 + 导出 zip
    models.dart             数据模型
  screens/                  UI：主页/检测/采集/历史/关于
  widgets/                  置信度条、频谱图
assets/models/              model.json / *.tflite（训练产出，可选）
training/                   Python 训练管线（见 training/README.md）
docs/DESIGN.md              架构设计 / 路线图 / 上架合规清单
```

## 两种判定模式

- **启发式模式**（默认，冷启动）：基于共振频率/频谱质心/衰减时间等经验规则，无需数据即可用。
- **机器学习模式**：用采集数据训练出 `assets/models/model.json` 后，App 自动升级。
  1. App"贡献数据"页采集"敲击声+真实结果"→"我的采集数据"导出 zip。
  2. 解压到 `training/data/`，跑 `python train.py --deploy`。
  3. `flutter run` 重新构建，即进入 ML 模式。

## 未来上架

代码跨平台，Android 现在即可打包上架 Google Play。iOS 打包/上架 App Store 需在 macOS + Xcode 上进行（见 `docs/DESIGN.md` 合规清单）。

## 免责

声学判瓜受品种、噪声、手法、机型影响，结果仅供参考，不保证准确。
