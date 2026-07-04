import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 简单的功率谱可视化（对数幅度）。
class SpectrumChart extends StatelessWidget {
  final List<double> powerSpectrum;
  final Color color;

  const SpectrumChart({
    super.key,
    required this.powerSpectrum,
    this.color = const Color(0xFF2E7D32),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      width: double.infinity,
      child: CustomPaint(painter: _SpectrumPainter(powerSpectrum, color)),
    );
  }
}

class _SpectrumPainter extends CustomPainter {
  final List<double> spectrum;
  final Color color;

  _SpectrumPainter(this.spectrum, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (spectrum.isEmpty) return;
    // 只画前半段（更有信息量的低中频）
    final n = (spectrum.length * 0.6).round().clamp(1, spectrum.length);
    final logs = List<double>.generate(n, (i) => math.log(1 + spectrum[i]));
    final maxV = logs.reduce(math.max);
    if (maxV <= 0) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final barW = size.width / n;
    for (int i = 0; i < n; i++) {
      final h = (logs[i] / maxV) * size.height;
      canvas.drawRect(
        Rect.fromLTWH(i * barW, size.height - h, barW * 0.9, h),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpectrumPainter old) =>
      old.spectrum != spectrum;
}
