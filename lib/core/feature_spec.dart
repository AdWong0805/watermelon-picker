/// 特征规范常量，必须与 training/feature_spec.json 保持一致。
/// 任何一处改动都要同步另一处，否则训练/推理特征不匹配会严重掉点。
class FeatureSpec {
  static const int version = 1;
  static const int sampleRate = 22050;
  static const double tapWindowSeconds = 0.35;
  static const double preOnsetSeconds = 0.01;
  static const int nFft = 1024;
  static const int hopLength = 512;
  static const int winLength = 1024;
  static const int nMels = 40;
  static const double fMin = 50.0;
  static const double fMax = 11025.0;
  static const int nMfcc = 13;

  /// 33 维特征顺序，与 Python 端严格一致。
  static const List<String> featureOrder = [
    'mfcc_mean_0', 'mfcc_mean_1', 'mfcc_mean_2', 'mfcc_mean_3', 'mfcc_mean_4',
    'mfcc_mean_5', 'mfcc_mean_6', 'mfcc_mean_7', 'mfcc_mean_8', 'mfcc_mean_9',
    'mfcc_mean_10', 'mfcc_mean_11', 'mfcc_mean_12',
    'mfcc_std_0', 'mfcc_std_1', 'mfcc_std_2', 'mfcc_std_3', 'mfcc_std_4',
    'mfcc_std_5', 'mfcc_std_6', 'mfcc_std_7', 'mfcc_std_8', 'mfcc_std_9',
    'mfcc_std_10', 'mfcc_std_11', 'mfcc_std_12',
    'spectral_centroid', 'spectral_bandwidth', 'spectral_rolloff',
    'zero_crossing_rate', 'dominant_freq', 'log_energy', 'decay_time',
  ];

  static int get featureCount => featureOrder.length;

  static const List<String> labels = ['unripe', 'ripe', 'overripe'];
  static const List<String> labelsZh = ['未熟', '适中·好吃', '过熟'];
}
