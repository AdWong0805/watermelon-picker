import 'dart:math' as math;

import 'models.dart';

/// 成熟度分类器抽象接口。
/// 实现：HeuristicClassifier（冷启动规则）、ModelClassifier（训练出的 ML 模型）。
abstract class RipenessClassifier {
  /// 'heuristic' | 'ml'
  String get mode;

  /// 对多次敲击的特征做聚合，输出单一预测。
  Prediction classify(List<TapFeatures> taps);
}

/// 数值工具：softmax（带防溢出）。
List<double> softmax(List<double> logits) {
  final maxL = logits.reduce((a, b) => a > b ? a : b);
  final exps = logits.map((l) {
    final d = l - maxL;
    return d < -60 ? 0.0 : math.exp(d);
  }).toList();
  final sum = exps.fold<double>(0, (a, b) => a + b);
  if (sum <= 0) return List.filled(logits.length, 1.0 / logits.length);
  return exps.map((e) => e / sum).toList();
}
