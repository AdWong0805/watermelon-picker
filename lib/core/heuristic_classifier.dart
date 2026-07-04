import 'classifier.dart';
import 'models.dart';

/// 冷启动启发式分类器（无需训练数据）。
///
/// 依据文献经验：成熟瓜敲击声更低沉——主共振频率更低、频谱质心更低、衰减更慢。
/// 用这几个量合成一个 0~1 的"成熟指数"，再按到各类原型的距离给出置信度。
///
/// 注意：这是经验规则，非机器学习，仅供参考。攒到数据后由 ModelClassifier 取代。
class HeuristicClassifier implements RipenessClassifier {
  @override
  String get mode => 'heuristic';

  // 经验阈值（可后续按真实数据校准）
  static const double _freqHigh = 320.0; // 高于此偏未熟
  static const double _freqLow = 110.0; // 低于此偏过熟
  static const double _centroidHigh = 2200.0;
  static const double _centroidLow = 700.0;
  static const double _decayShort = 0.05;
  static const double _decayLong = 0.20;

  // 各类"成熟指数"原型
  static const double _protoUnripe = 0.18;
  static const double _protoRipe = 0.58;
  static const double _protoOverripe = 0.90;

  static double _clamp01(double x) => x < 0 ? 0 : (x > 1 ? 1 : x);

  @override
  Prediction classify(List<TapFeatures> taps) {
    if (taps.isEmpty) {
      return const Prediction(
        label: Ripeness.ripe,
        confidence: 0,
        scores: {Ripeness.unripe: 0.34, Ripeness.ripe: 0.33, Ripeness.overripe: 0.33},
        mode: 'heuristic',
        tapCount: 0,
      );
    }

    double freq = 0, centroid = 0, decay = 0;
    for (final t in taps) {
      freq += t.dominantFreq;
      centroid += t.spectralCentroid;
      decay += t.decayTime;
    }
    freq /= taps.length;
    centroid /= taps.length;
    decay /= taps.length;

    // 三个"越大越成熟"的分量
    final freqScore = _clamp01((_freqHigh - freq) / (_freqHigh - _freqLow));
    final centroidScore =
        _clamp01((_centroidHigh - centroid) / (_centroidHigh - _centroidLow));
    final decayScore = _clamp01((decay - _decayShort) / (_decayLong - _decayShort));

    // 频率权重更高（文献中相关性最强）
    final ripeIndex = _clamp01(0.5 * freqScore + 0.25 * centroidScore + 0.25 * decayScore);

    // 到各原型距离 -> softmax（温度控制陡峭度）
    const temp = 0.22;
    final logits = [
      -(ripeIndex - _protoUnripe).abs() / temp,
      -(ripeIndex - _protoRipe).abs() / temp,
      -(ripeIndex - _protoOverripe).abs() / temp,
    ];
    final probs = softmax(logits);

    final scores = {
      Ripeness.unripe: probs[0],
      Ripeness.ripe: probs[1],
      Ripeness.overripe: probs[2],
    };
    int best = 0;
    for (int i = 1; i < probs.length; i++) {
      if (probs[i] > probs[best]) best = i;
    }

    return Prediction(
      label: Ripeness.fromIndex(best),
      confidence: probs[best],
      scores: scores,
      mode: 'heuristic',
      tapCount: taps.length,
    );
  }
}
