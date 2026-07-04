import 'dart:math' as math;
import 'dart:typed_data';

import 'feature_spec.dart';

/// 从一段录音中检测敲击事件，返回每次敲击对应的定长窗口。
class TapDetector {
  static const int _sr = FeatureSpec.sampleRate;
  static const int _hop = 256;
  static const int _win = 512;

  /// 返回敲击窗口列表；每个窗口长度 = tapWindowSeconds * sr。
  static List<Float64List> detect(Float64List y) {
    final winLen = (FeatureSpec.tapWindowSeconds * _sr).round();
    final preLen = (FeatureSpec.preOnsetSeconds * _sr).round();
    final minGap = (0.12 * _sr / _hop).round(); // 相邻敲击最小间隔（帧）

    if (y.length < _win) {
      return [_slice(y, 0, winLen)];
    }

    // 短时能量包络
    final numFrames = 1 + (y.length - _win) ~/ _hop;
    final energy = Float64List(numFrames);
    double maxE = 0;
    for (int f = 0; f < numFrames; f++) {
      final s = f * _hop;
      double e = 0;
      for (int i = 0; i < _win; i++) {
        final v = y[s + i];
        e += v * v;
      }
      energy[f] = e;
      if (e > maxE) maxE = e;
    }
    if (maxE <= 0) return [_slice(y, 0, winLen)];

    // 能量一阶差分上的峰值 = onset
    final threshold = 0.18 * maxE;
    final onsets = <int>[];
    int lastPeak = -minGap * 2;
    for (int f = 1; f < numFrames - 1; f++) {
      final rising = energy[f] > energy[f - 1];
      final localMax = energy[f] >= energy[f + 1];
      if (energy[f] >= threshold && rising && localMax) {
        if (f - lastPeak >= minGap) {
          onsets.add(f);
          lastPeak = f;
        } else if (onsets.isNotEmpty && energy[f] > energy[onsets.last]) {
          onsets[onsets.length - 1] = f; // 同一次敲击取更强的峰
          lastPeak = f;
        }
      }
    }

    if (onsets.isEmpty) {
      // 退化：取全局能量最大处
      int best = 0;
      for (int f = 0; f < numFrames; f++) {
        if (energy[f] > energy[best]) best = f;
      }
      onsets.add(best);
    }

    final taps = <Float64List>[];
    for (final f in onsets) {
      final onsetSample = f * _hop;
      final start = math.max(0, onsetSample - preLen);
      taps.add(_slice(y, start, winLen));
    }
    return taps;
  }

  static Float64List _slice(Float64List y, int start, int len) {
    final out = Float64List(len);
    for (int i = 0; i < len; i++) {
      final idx = start + i;
      out[i] = idx < y.length ? y[idx] : 0.0;
    }
    return out;
  }
}
