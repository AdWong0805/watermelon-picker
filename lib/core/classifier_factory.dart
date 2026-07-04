import 'package:flutter/services.dart' show rootBundle;

import 'classifier.dart';
import 'heuristic_classifier.dart';
import 'model_classifier.dart';

/// 决定用哪种分类器：assets/models/model.json 存在且有效 -> ML；否则 -> 启发式。
class ClassifierFactory {
  static Future<RipenessClassifier> load() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/models/model.json');
      return ModelClassifier.fromJson(jsonStr);
    } catch (_) {
      // 资源不存在或格式不符 -> 冷启动启发式
      return HeuristicClassifier();
    }
  }
}
