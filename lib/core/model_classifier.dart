import 'dart:convert';

import 'classifier.dart';
import 'feature_spec.dart';
import 'models.dart';

/// 机器学习分类器：加载训练管线导出的 model.json（StandardScaler + 多类逻辑回归）。
/// 纯 Dart 评估，无需 tflite 运行时。
class ModelClassifier implements RipenessClassifier {
  final List<double> _mean;
  final List<double> _scale;
  final List<List<double>> _coef; // [numClasses][numFeatures]
  final List<double> _intercept; // [numClasses]
  final List<String> _labels;

  ModelClassifier._(this._mean, this._scale, this._coef, this._intercept, this._labels);

  @override
  String get mode => 'ml';

  /// 从 model.json 文本构建；格式不符会抛异常，由工厂捕获后回退。
  factory ModelClassifier.fromJson(String jsonStr) {
    final m = json.decode(jsonStr) as Map<String, dynamic>;
    if (m['type'] != 'logreg') {
      throw const FormatException('不支持的模型类型');
    }
    List<double> dl(dynamic x) =>
        (x as List).map((e) => (e as num).toDouble()).toList();
    final coef = (m['coef'] as List).map((row) => dl(row)).toList();
    final model = ModelClassifier._(
      dl(m['scaler_mean']),
      dl(m['scaler_scale']),
      coef,
      dl(m['intercept']),
      (m['labels'] as List).map((e) => e.toString()).toList(),
    );
    if (model._mean.length != FeatureSpec.featureCount) {
      throw const FormatException('特征维度与规范不一致');
    }
    return model;
  }

  List<double> _predictOne(List<double> vec) {
    final n = _mean.length;
    final x = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final s = _scale[i] == 0 ? 1.0 : _scale[i];
      x[i] = (vec[i] - _mean[i]) / s;
    }
    final logits = List<double>.filled(_coef.length, 0);
    for (int c = 0; c < _coef.length; c++) {
      double z = _intercept[c];
      final w = _coef[c];
      for (int i = 0; i < n; i++) {
        z += w[i] * x[i];
      }
      logits[c] = z;
    }
    return softmax(logits);
  }

  @override
  Prediction classify(List<TapFeatures> taps) {
    if (taps.isEmpty) {
      return const Prediction(
        label: Ripeness.ripe,
        confidence: 0,
        scores: {Ripeness.unripe: 0.34, Ripeness.ripe: 0.33, Ripeness.overripe: 0.33},
        mode: 'ml',
        tapCount: 0,
      );
    }
    // 逐 tap 预测概率后取平均
    final numClasses = _coef.length;
    final avg = List<double>.filled(numClasses, 0);
    for (final t in taps) {
      final p = _predictOne(t.vector);
      for (int c = 0; c < numClasses; c++) {
        avg[c] += p[c];
      }
    }
    for (int c = 0; c < numClasses; c++) {
      avg[c] /= taps.length;
    }

    final scores = <Ripeness, double>{};
    for (int c = 0; c < numClasses; c++) {
      final r = Ripeness.fromLabel(_labels[c]) ?? Ripeness.fromIndex(c);
      scores[r] = avg[c];
    }
    int best = 0;
    for (int c = 1; c < numClasses; c++) {
      if (avg[c] > avg[best]) best = c;
    }
    return Prediction(
      label: Ripeness.fromLabel(_labels[best]) ?? Ripeness.fromIndex(best),
      confidence: avg[best],
      scores: scores,
      mode: 'ml',
      tapCount: taps.length,
    );
  }
}
