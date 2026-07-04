import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fftea/fftea.dart';

import 'feature_spec.dart';

/// 底层信号处理：加窗、STFT、梅尔滤波器组、DCT。
/// 参数对齐 librosa（center=True + reflect padding, periodic hann, HTK mel, DCT-II ortho）。
class Dsp {
  final FFT _fft = FFT(FeatureSpec.nFft);
  late final Float64List _hann = _periodicHann(FeatureSpec.winLength);
  late final List<Float64List> _melFb = _buildMelFilterbank();

  static Float64List _periodicHann(int n) {
    final w = Float64List(n);
    for (int i = 0; i < n; i++) {
      w[i] = 0.5 - 0.5 * math.cos(2 * math.pi * i / n);
    }
    return w;
  }

  static double _hzToMel(double hz) => 2595.0 * _log10(1 + hz / 700.0);
  static double _melToHz(double mel) => 700.0 * (math.pow(10, mel / 2595.0) - 1);
  static double _log10(double x) => math.log(x) / math.ln10;

  /// HTK 三角梅尔滤波器组，norm=None（峰值=1）。
  static List<Float64List> _buildMelFilterbank() {
    const nFft = FeatureSpec.nFft;
    const nMels = FeatureSpec.nMels;
    final sr = FeatureSpec.sampleRate.toDouble();
    final nBins = nFft ~/ 2 + 1;

    final melMin = _hzToMel(FeatureSpec.fMin);
    final melMax = _hzToMel(FeatureSpec.fMax);
    final melPoints = List<double>.generate(
        nMels + 2, (i) => melMin + (melMax - melMin) * i / (nMels + 1));
    final hzPoints = melPoints.map(_melToHz).toList();

    final binFreqs = List<double>.generate(nBins, (i) => i * sr / nFft);

    final fb = List.generate(nMels, (_) => Float64List(nBins));
    for (int m = 1; m <= nMels; m++) {
      final left = hzPoints[m - 1];
      final center = hzPoints[m];
      final right = hzPoints[m + 1];
      for (int b = 0; b < nBins; b++) {
        final f = binFreqs[b];
        double v = 0;
        if (f >= left && f <= center && center > left) {
          v = (f - left) / (center - left);
        } else if (f > center && f <= right && right > center) {
          v = (right - f) / (right - center);
        }
        fb[m - 1][b] = v;
      }
    }
    return fb;
  }

  /// 对一帧（长度 winLength）加窗并做 FFT，返回功率谱与幅度谱（长度 nFft/2+1）。
  ({Float64List power, Float64List magnitude}) frameSpectrum(Float64List frame) {
    final nBins = FeatureSpec.nFft ~/ 2 + 1;
    final windowed = Float64List(FeatureSpec.nFft);
    final len = math.min(frame.length, FeatureSpec.winLength);
    for (int i = 0; i < len; i++) {
      windowed[i] = frame[i] * _hann[i];
    }
    final spec = _fft.realFft(windowed);
    final power = Float64List(nBins);
    final magnitude = Float64List(nBins);
    for (int b = 0; b < nBins; b++) {
      final re = spec[b].x;
      final im = spec[b].y;
      final p = re * re + im * im;
      power[b] = p;
      magnitude[b] = math.sqrt(p);
    }
    return (power: power, magnitude: magnitude);
  }

  /// 功率谱 -> 梅尔能量（power melspectrogram，norm=None）。
  Float64List melEnergies(Float64List power) {
    final out = Float64List(FeatureSpec.nMels);
    for (int m = 0; m < FeatureSpec.nMels; m++) {
      double s = 0;
      final fb = _melFb[m];
      for (int b = 0; b < power.length; b++) {
        s += fb[b] * power[b];
      }
      out[m] = s;
    }
    return out;
  }

  /// power_to_db：10*log10(max(x,1e-10))，ref=1.0；顶部 80dB 截断在调用处统一做。
  static double powerToDb(double x) => 10.0 * _log10(math.max(x, 1e-10));

  /// DCT-II 正交归一，取前 nMfcc 个系数。输入长度 N=nMels。
  static Float64List dctOrtho(Float64List x, int nCoeffs) {
    final n = x.length;
    final out = Float64List(nCoeffs);
    final s0 = math.sqrt(1.0 / n);
    final sk = math.sqrt(2.0 / n);
    for (int k = 0; k < nCoeffs; k++) {
      double sum = 0;
      for (int i = 0; i < n; i++) {
        sum += x[i] * math.cos(math.pi * k * (2 * i + 1) / (2 * n));
      }
      out[k] = (k == 0 ? s0 : sk) * sum;
    }
    return out;
  }
}
