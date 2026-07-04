import 'package:flutter/material.dart';

import '../core/models.dart';

/// 三类成熟度的置信度条。
class ConfidenceBars extends StatelessWidget {
  final Map<Ripeness, double> scores;
  final Ripeness highlight;

  const ConfidenceBars({
    super.key,
    required this.scores,
    required this.highlight,
  });

  Color _colorFor(Ripeness r, BuildContext ctx) {
    switch (r) {
      case Ripeness.unripe:
        return const Color(0xFF8BC34A);
      case Ripeness.ripe:
        return const Color(0xFF2E7D32);
      case Ripeness.overripe:
        return const Color(0xFFC62828);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: Ripeness.values.map((r) {
        final v = (scores[r] ?? 0).clamp(0.0, 1.0);
        final isTop = r == highlight;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: 76,
                child: Text(
                  r.labelZh,
                  style: TextStyle(
                    fontWeight: isTop ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: v,
                    minHeight: 14,
                    backgroundColor: Colors.black12,
                    valueColor:
                        AlwaysStoppedAnimation(_colorFor(r, context)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 44,
                child: Text(
                  '${(v * 100).toStringAsFixed(0)}%',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontWeight: isTop ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
