import 'package:flutter_test/flutter_test.dart';

import 'package:guashu/core/feature_spec.dart';
import 'package:guashu/core/heuristic_classifier.dart';
import 'package:guashu/core/models.dart';

void main() {
  test('特征规范维度自洽', () {
    expect(FeatureSpec.featureCount, 33);
    expect(FeatureSpec.labels.length, 3);
    expect(FeatureSpec.labelsZh.length, 3);
  });

  test('启发式分类器：低频长衰减判为更成熟', () {
    final clf = HeuristicClassifier();
    TapFeatures mk(double freq, double centroid, double decay) => TapFeatures(
          vector: List.filled(FeatureSpec.featureCount, 0),
          dominantFreq: freq,
          spectralCentroid: centroid,
          decayTime: decay,
          logEnergy: 1,
          powerSpectrum: const [],
        );

    final unripe = clf.classify([mk(360, 2400, 0.03)]);
    final ripe = clf.classify([mk(180, 1200, 0.14)]);

    expect(unripe.label, Ripeness.unripe);
    expect(ripe.label, Ripeness.ripe);
    // 概率和约等于 1
    final sum = ripe.scores.values.reduce((a, b) => a + b);
    expect((sum - 1).abs() < 1e-6, true);
  });
}
