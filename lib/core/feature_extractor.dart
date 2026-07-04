import 'dart:math' as math;
import 'dart:typed_data';

import 'dsp.dart';
import 'feature_spec.dart';
import 'models.dart';

/// 从单次敲击窗口提取 33 维特征向量（顺序同 FeatureSpec.featureOrder）。
class FeatureExtractor {
  final Dsp _dsp = Dsp();

  static const int _sr = FeatureSpec.sampleRate;
  static const int _nFft = FeatureSpec.nFft;
  static const int _hop = FeatureSpec.hopLength;
  static const int _nMels = FeatureSpec.nMels;
  static const int _nMfcc = FeatureSpec.nMfcc;

  /// numpy 'reflect' 填充。
  static Float64List _reflectPad(Float64List y, int pad) {
    final n = y.length;
    if (n <= 1) {
      final out = Float64List(n + 2 * pad);
      for (int i = 0; i < out.length; i++) {
        out[i] = n == 1 ? y[0] : 0;
      }
      return out;
    }
    final out = Float64List(n + 2 * pad);
    for (int i = 0; i < pad; i++) {
      out[pad - 1 - i] = y[(i + 1) % n]; // 左侧反射（不含边缘）
    }
    for (int i = 0; i < n; i++) {
      out[pad + i] = y[i];
    }
    for (int i = 0; i < pad; i++) {
      final idx = n - 2 - i;
      out[pad + n + i] = y[idx >= 0 ? idx : 0];
    }
    return out;
  }

  TapFeatures extract(Float64List tap) {
    final pad = _nFft ~/ 2;
    final padded = _reflectPad(tap, pad);
    final numFrames = 1 + (tap.length ~/ _hop);

    final freqs = List<double>.generate(
        _nFft ~/ 2 + 1, (i) => i * _sr / _nFft);

    // 逐帧累积
    final melDbFrames = <Float64List>[];
    final avgPower = Float64List(_nFft ~/ 2 + 1);
    double centroidSum = 0, bandwidthSum = 0, rolloffSum = 0;
    int validFrames = 0;
    double globalMaxDb = -double.infinity;

    for (int t = 0; t < numFrames; t++) {
      final start = t * _hop;
      if (start + _nFft > padded.length) break;
      final frame = Float64List.sublistView(padded, start, start + _nFft);
      final sp = _dsp.frameSpectrum(frame);
      final power = sp.power;
      final mag = sp.magnitude;

      for (int b = 0; b < power.length; b++) {
        avgPower[b] += power[b];
      }

      // 梅尔 db（先存原始 db，稍后统一 top_db 截断）
      final mel = _dsp.melEnergies(power);
      final melDb = Float64List(_nMels);
      for (int m = 0; m < _nMels; m++) {
        final db = Dsp.powerToDb(mel[m]);
        melDb[m] = db;
        if (db > globalMaxDb) globalMaxDb = db;
      }
      melDbFrames.add(melDb);

      // 频谱标量（用幅度谱）
      double magSum = 0, wSum = 0;
      for (int b = 0; b < mag.length; b++) {
        magSum += mag[b];
        wSum += freqs[b] * mag[b];
      }
      final centroid = magSum > 0 ? wSum / magSum : 0.0;
      double varSum = 0;
      for (int b = 0; b < mag.length; b++) {
        final d = freqs[b] - centroid;
        varSum += mag[b] * d * d;
      }
      final bandwidth = magSum > 0 ? math.sqrt(varSum / magSum) : 0.0;

      double cum = 0;
      double rolloff = freqs.last;
      final thresh = 0.85 * magSum;
      for (int b = 0; b < mag.length; b++) {
        cum += mag[b];
        if (cum >= thresh) {
          rolloff = freqs[b];
          break;
        }
      }

      centroidSum += centroid;
      bandwidthSum += bandwidth;
      rolloffSum += rolloff;
      validFrames++;
    }

    if (validFrames == 0) {
      return TapFeatures(
        vector: Float64List(FeatureSpec.featureCount).toList(),
        dominantFreq: 0,
        spectralCentroid: 0,
        decayTime: 0,
        logEnergy: 0,
        powerSpectrum: avgPower.toList(),
      );
    }

    // MFCC：top_db 截断到 (globalMaxDb - 80)，逐帧 DCT，再取均值/标准差
    final floor = globalMaxDb - 80.0;
    final mfccMean = Float64List(_nMfcc);
    final mfccSq = Float64List(_nMfcc);
    for (final melDb in melDbFrames) {
      final clipped = Float64List(_nMels);
      for (int m = 0; m < _nMels; m++) {
        clipped[m] = melDb[m] < floor ? floor : melDb[m];
      }
      final mfcc = Dsp.dctOrtho(clipped, _nMfcc);
      for (int k = 0; k < _nMfcc; k++) {
        mfccMean[k] += mfcc[k];
        mfccSq[k] += mfcc[k] * mfcc[k];
      }
    }
    final nf = melDbFrames.length;
    for (int k = 0; k < _nMfcc; k++) {
      mfccMean[k] /= nf;
    }
    final mfccStd = Float64List(_nMfcc);
    for (int k = 0; k < _nMfcc; k++) {
      final v = mfccSq[k] / nf - mfccMean[k] * mfccMean[k];
      mfccStd[k] = v > 0 ? math.sqrt(v) : 0.0;
    }

    // 平均功率谱 -> 主共振频率
    double maxP = -1;
    int maxIdx = 0;
    for (int b = 0; b < avgPower.length; b++) {
      avgPower[b] /= validFrames;
      if (avgPower[b] > maxP) {
        maxP = avgPower[b];
        maxIdx = b;
      }
    }
    final dominant = freqs[maxIdx];

    // ZCR（整段近似）
    int zc = 0;
    for (int i = 1; i < tap.length; i++) {
      if ((tap[i] >= 0) != (tap[i - 1] >= 0)) zc++;
    }
    final zcr = tap.length > 1 ? zc / tap.length : 0.0;

    // 对数能量
    double energy = 0;
    for (final v in tap) {
      energy += v * v;
    }
    final logEnergy = math.log(1 + energy);

    final decay = _decayTime(tap);

    // 拼装 33 维
    final vec = <double>[];
    vec.addAll(mfccMean);
    vec.addAll(mfccStd);
    vec.add(centroidSum / validFrames);
    vec.add(bandwidthSum / validFrames);
    vec.add(rolloffSum / validFrames);
    vec.add(zcr);
    vec.add(dominant);
    vec.add(logEnergy);
    vec.add(decay);

    return TapFeatures(
      vector: vec,
      dominantFreq: dominant,
      spectralCentroid: centroidSum / validFrames,
      decayTime: decay,
      logEnergy: logEnergy,
      powerSpectrum: avgPower.toList(),
    );
  }

  /// 振幅包络从峰值衰减到 10% 的时间（秒）。成熟瓜通常衰减更慢。
  static double _decayTime(Float64List y) {
    if (y.isEmpty) return 0;
    double maxAbs = 0;
    for (final v in y) {
      final a = v.abs();
      if (a > maxAbs) maxAbs = a;
    }
    if (maxAbs <= 0) return 0;
    int peakIdx = 0;
    double peak = 0;
    for (int i = 0; i < y.length; i++) {
      final a = y[i].abs() / maxAbs;
      if (a > peak) {
        peak = a;
        peakIdx = i;
      }
    }
    final thresh = 0.1 * peak;
    for (int i = peakIdx; i < y.length; i++) {
      if (y[i].abs() / maxAbs < thresh) {
        return (i - peakIdx) / _sr;
      }
    }
    return (y.length - peakIdx) / _sr;
  }
}
