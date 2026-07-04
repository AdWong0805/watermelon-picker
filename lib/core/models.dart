import 'feature_spec.dart';

/// 西瓜成熟度类别。
enum Ripeness {
  unripe,
  ripe,
  overripe;

  int get index3 => Ripeness.values.indexOf(this);

  String get labelEn => FeatureSpec.labels[index3];
  String get labelZh => FeatureSpec.labelsZh[index3];

  static Ripeness fromIndex(int i) => Ripeness.values[i.clamp(0, 2)];

  static Ripeness? fromLabel(String label) {
    final i = FeatureSpec.labels.indexOf(label);
    return i >= 0 ? Ripeness.values[i] : null;
  }
}

/// 分类结果。
class Prediction {
  final Ripeness label;
  final double confidence; // 0~1
  final Map<Ripeness, double> scores; // 各类得分（和为 1）
  final String mode; // 'heuristic' | 'ml'
  final int tapCount; // 参与投票的敲击次数

  const Prediction({
    required this.label,
    required this.confidence,
    required this.scores,
    required this.mode,
    required this.tapCount,
  });
}

/// 单次敲击提取出的特征包（含 33 维向量 + 便于展示的关键量）。
class TapFeatures {
  final List<double> vector; // 33 维，顺序同 FeatureSpec.featureOrder
  final double dominantFreq;
  final double spectralCentroid;
  final double decayTime;
  final double logEnergy;
  final List<double> powerSpectrum; // 用于频谱可视化

  const TapFeatures({
    required this.vector,
    required this.dominantFreq,
    required this.spectralCentroid,
    required this.decayTime,
    required this.logEnergy,
    required this.powerSpectrum,
  });
}
