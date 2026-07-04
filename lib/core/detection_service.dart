import 'dart:typed_data';

import 'classifier.dart';
import 'feature_extractor.dart';
import 'models.dart';
import 'tap_detector.dart';
import 'wav.dart';

/// 一次检测的完整结果。
class DetectionResult {
  final Prediction prediction;
  final List<TapFeatures> taps;
  final String wavPath;

  const DetectionResult({
    required this.prediction,
    required this.taps,
    required this.wavPath,
  });

  int get tapCount => taps.length;
}

/// 把 录音文件 -> 敲击检测 -> 特征提取 -> 分类 串起来。
class DetectionService {
  final FeatureExtractor _extractor = FeatureExtractor();
  final RipenessClassifier classifier;

  DetectionService(this.classifier);

  /// 分析一个 WAV 文件。计算较重，建议在调用处用 compute/isolate（此处同步实现，音频短足够快）。
  DetectionResult analyzeFile(String wavPath) {
    final wav = Wav.readFile(wavPath);
    final samples = _resampleIfNeeded(wav.samples, wav.sampleRate);
    final tapWindows = TapDetector.detect(samples);
    final feats = tapWindows.map(_extractor.extract).toList();
    final pred = classifier.classify(feats);
    return DetectionResult(prediction: pred, taps: feats, wavPath: wavPath);
  }

  /// 录音理论上已是目标采样率；若设备回退到其它采样率，做线性重采样兜底。
  static Float64List _resampleIfNeeded(Float64List y, int srcSr) {
    const target = 22050;
    if (srcSr == target || y.isEmpty) return y;
    final ratio = target / srcSr;
    final n = (y.length * ratio).floor();
    final out = Float64List(n);
    for (int i = 0; i < n; i++) {
      final srcPos = i / ratio;
      final i0 = srcPos.floor();
      final i1 = (i0 + 1).clamp(0, y.length - 1);
      final frac = srcPos - i0;
      out[i] = y[i0] * (1 - frac) + y[i1] * frac;
    }
    return out;
  }
}
