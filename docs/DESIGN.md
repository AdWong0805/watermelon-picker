# 西瓜成熟度检测 App — 架构设计文档

> 代号：**瓜熟蒂落 (GuaShu)** · 跨平台 (Android / iOS) · 端上推理

## 1. 产品目标

用手机麦克风采集"敲击西瓜"的声音，结合信号处理与机器学习，无损判断西瓜的**成熟度 / 是否好吃**。

- 现阶段：不上架，做出可运行的安卓 MVP，验证核心链路。
- 未来：代码跨平台，随时可打包 iOS 并上架 Google Play / App Store。

## 2. 技术可行性（文献依据）

用敲击声判断西瓜成熟度是学术界已充分验证的方向，手机麦克风即可实现：

| 研究 | 方法 | 报告准确率 |
|------|------|--------|
| Zeng et al., ETH Zurich (2013)，安卓众包 App | ZCR + 短时能量 STE + SVM | ~89% |
| IJCNN (2010) | MFCC + 多层感知机 MLP | ~77% |
| ECAPA-TDNN (2024)，手机录音 | 梅尔谱 + 深度网络 | ~89.5% |
| htw saar，CNN | 声学共振 + 卷积网络 | ~96% |
| Springer (2025)，多模态 | 图像 VGG16 + MFCC+随机森林 | 音频 98% / 图像 85% |
| 土耳其 (2025) | 频谱 120 特征 + KNN/随机森林 | ~96% |
| TCSAE (2010，中文) | 频带幅值向量 BMV + PNN | 高 |

**核心原理**：西瓜成熟时内部糖度/密度/组织结构变化 → 敲击的共振频率（"声纹"）随之改变。成熟瓜通常声音更低沉（共振频率更低）、衰减更慢。

**常用特征**：MFCC、梅尔频谱、频带幅值向量(BMV)、过零率(ZCR)+短时能量(STE)、共振峰频率、衰减时间。

**常用模型**：SVM / 随机森林 / KNN（轻量，可端上跑）；CNN（吃梅尔频谱图，精度高）。

### 关键现实约束（务必牢记）
1. 论文准确率多在**实验室 / 单一品种 / 自采数据集**下取得，换品种、换手机、换环境噪声后**泛化会明显下降**。
2. **没有公开的大规模西瓜敲击声数据集**。想做准，必须"边用边众包收集数据 + 持续迭代模型"。→ 数据采集能力从架构第一天就内建。
3. 因此 App 的定位应是**辅助参考**，而非绝对权威判断；UI 上要给出置信度并做免责说明（也利于合规过审）。

## 3. 技术选型

| 维度 | 选择 | 理由 |
|------|------|------|
| 跨平台框架 | **Flutter (Dart)** | 单代码库覆盖双端；音频/TFLite 生态成熟；UI 性能好 |
| 推理位置 | **纯端上 (TFLite)** | 离线可用、隐私好、零服务器成本，适合 MVP |
| 音频录制 | `record` | 跨平台录制 PCM/WAV |
| 信号处理 | `fftea`（Dart FFT）自研特征提取 | 端上算 FFT→频谱→梅尔谱/共振频率 |
| 端上模型 | `tflite_flutter` | 加载训练好的 .tflite |
| 冷启动 | **启发式分类器**（基于共振频率阈值） | 无模型时 App 也能给结果，逐步用众包数据替换为 ML 模型 |
| 本地存储 | `sqflite` + 文件系统 | 采集样本(WAV+标签+元数据) |
| 训练管线 | Python + librosa + scikit-learn / Keras | 离线训练，导出 TFLite |

## 4. 系统架构

```
┌───────────────────────────── Flutter App ─────────────────────────────┐
│                                                                        │
│  UI 层 (screens/)                                                       │
│   ├─ 检测页：录音→检测→结果(成熟度+置信度)                                  │
│   ├─ 采集页：录敲击声+切瓜后真实标签→本地库(众包)                            │
│   └─ 历史/设置/关于(含免责声明、隐私政策入口)                                │
│                                                                        │
│  领域层 (core/)                                                          │
│   ├─ AudioRecorder      录音、写 PCM/WAV                                 │
│   ├─ TapDetector        从音频流里检测"敲击"事件(onset 检测)               │
│   ├─ FeatureExtractor   FFT→功率谱→梅尔谱/MFCC/共振频率/ZCR/STE/衰减       │
│   ├─ RipenessClassifier (抽象接口)                                       │
│   │    ├─ HeuristicClassifier   规则/阈值(冷启动，无需模型)                 │
│   │    └─ TfliteClassifier      加载 assets/models/*.tflite               │
│   └─ SampleRepository   采集样本的本地持久化 + 导出(zip/csv)                │
│                                                                        │
│  资源 (assets/)                                                         │
│   └─ models/  ripeness_model.tflite + labels.txt (训练管线产出，可选)      │
└────────────────────────────────────────────────────────────────────────┘
                                   │
                        (导出采集数据 / 手动)
                                   ▼
┌──────────────────────── Python 训练管线 (training/) ────────────────────┐
│  1. 采集: App 导出的 WAV + label.csv                                      │
│  2. feature_extraction.py  librosa 提梅尔谱/MFCC                          │
│  3. train.py               训练 RandomForest / 小型 CNN，交叉验证          │
│  4. export_tflite.py       导出 ripeness_model.tflite + labels.txt        │
│  5. 拷回 app 的 assets/models/ → 下次构建即用 ML 模型                       │
└──────────────────────────────────────────────────────────────────────────┘
```

## 5. 检测流程（端上）

1. 用户点"开始"，对着西瓜用指关节敲 3~5 下。
2. `AudioRecorder` 录制原始 PCM。
3. `TapDetector` 在录音里检测敲击起始点，截取每次敲击后约 200~400ms 的窗口。
4. `FeatureExtractor` 对每个敲击窗口：
   - 加窗 → FFT → 功率谱
   - 计算：主共振频率、频谱质心、频带能量分布、梅尔谱/MFCC、衰减时间、ZCR、STE
5. `RipenessClassifier` 对多次敲击的特征做聚合投票，输出：
   - 类别（未熟 / 适中好吃 / 过熟）+ 置信度
6. UI 展示结果 + 置信度条 + 免责说明；可一键"帮我们改进"进入采集页贡献数据。

## 6. 冷启动策略（关键）

因为暂时没有训练数据，App 上线即能用靠**启发式分类器**：
- 依据文献：成熟瓜主共振频率偏低、频谱质心偏低、低频能量占比高、衰减更慢。
- 设一组可调阈值把西瓜分到"未熟 / 适中 / 过熟"，并给出经验置信度。
- 明确标注"经验规则模式，非机器学习"。
- 随着众包数据积累（目标先攒到每类 ≥ 数百段敲击），用训练管线产出 TFLite 模型，App 自动切换为 ML 模式。

## 7. 数据采集与众包（合规前提下）

- **完全 opt-in**，默认关闭上传；MVP 阶段仅本地存储，可手动导出 zip 给自己训练。
- 每条样本：WAV + 标签(切开后真实：甜度/成熟度/是否好吃) + 元数据(机型、采样率、时间戳、可选品种/产地)。
- 不采集任何个人身份信息；未来若做云端上传，需先补隐私政策 + 用户同意弹窗。

## 8. 未来上架合规准备清单（现在就预留）

### 通用
- [ ] 应用图标、启动图、应用名（多语言）
- [ ] 隐私政策页面（App 内可访问 + 线上可访问 URL）
- [ ] 明确的**免责声明**：结果仅供参考，不保证准确（避免"医疗/绝对承诺"式表述）
- [ ] 版本号与构建号规范 (semver)

### Android / Google Play
- [ ] `RECORD_AUDIO` 权限 + 运行时申请 + 用途说明
- [ ] Data safety 表单（声明是否收集音频、是否上传）
- [ ] 目标 API level 满足 Play 最新要求
- [ ] 签名密钥 (upload keystore) 妥善保管；配置 `key.properties`（不入库）
- [ ] AAB 打包 (`flutter build appbundle`)

### iOS / App Store
- [ ] `NSMicrophoneUsageDescription` 麦克风用途文案（Info.plist）
- [ ] App Privacy "Nutrition Label"（声明数据收集）
- [ ] Bundle ID、开发者账号($99/年)、证书与描述文件
- [ ] 需在 macOS + Xcode 上打包（Windows 无法完成这一步，将来在 Mac 上做）

## 9. 里程碑路线图

- **M0 脚手架**：Flutter 项目可编译运行空壳（本次）
- **M1 MVP**：录音→敲击检测→特征→启发式分类→结果 UI（安卓可跑）
- **M2 数据采集**：本地采集+标注+导出，攒数据集
- **M3 训练管线**：Python 训练出第一个 TFLite 模型，App 切 ML 模式
- **M4 打磨**：多次敲击聚合、噪声鲁棒性、UI/UX、i18n
- **M5 上架准备**：隐私政策、图标、签名、合规表单；iOS 在 Mac 上打包提交

## 10. 参考文献

1. Zeng W. et al. *Classifying watermelon ripeness by analysing acoustic signals using mobile devices.* Personal and Ubiquitous Computing, 2013.
2. *Non-destructive classification of watermelon ripeness using MFCC and MLP.* IJCNN, 2010.
3. *Non-destructive Ripeness Judgement of Watermelon Based on Mel Spectrogram and ECAPA-TDNN.* ICNC-FSKD, 2024.
4. Albert-Weiss et al. *Acoustic Ripeness Classification for Watermelon Fruits using CNN.* htw saar.
5. *Classification of Watermelons Based on Ripeness Using Multimodal Data.* Springer, 2025.
6. Chen X., Yuan P., Deng X. *Watermelon ripeness detection by wavelet multiresolution decomposition.* Postharvest Biology and Technology, 2017.
7. 基于 BMV 特征的西瓜成熟度无损检测方法. 农业工程学报(TCSAE), 2010.
8. 专利 CN117238313A：基于梅尔谱和深度学习的西瓜成熟度无损检测方法及系统.
