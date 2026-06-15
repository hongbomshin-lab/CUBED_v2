import 'package:flutter/material.dart';

import '../../../core/rulebook.dart';
import '../../../core/theme.dart';
import '../../../domain/interpretation.dart';

/// 대체당 칩 목록 — class별 색, 함량, 혈당 위험 마커
class SweetenerChips extends StatelessWidget {
  const SweetenerChips({super.key, required this.chips});
  final List<SweetenerChip> chips;

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) {
      return const Text('표시된 대체당이 없어요.',
          style: TextStyle(color: CubedColors.inkSoft, fontSize: 13));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips.map((c) => _Chip(c)).toList(),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.c);
  final SweetenerChip c;
  @override
  Widget build(BuildContext context) {
    final color = CubedColors.klass(c.klass);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 7),
          Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          if (c.amountG != null) ...[
            const SizedBox(width: 4),
            Text('${_n(c.amountG!)}g', style: const TextStyle(color: CubedColors.inkSoft, fontSize: 12)),
          ],
          if (c.isRisky) ...[
            const SizedBox(width: 5),
            const Text('🩸', style: TextStyle(fontSize: 11)),
          ],
          if (c.glycemic == Grade.caution && !c.isRisky) ...[
            const SizedBox(width: 5),
            const Icon(Icons.warning_amber_rounded, size: 13, color: CubedColors.caution),
          ],
        ],
      ),
    );
  }

  static String _n(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}
