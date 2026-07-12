import 'package:flutter/material.dart';

import '../../../core/rulebook.dart';
import '../../../core/theme.dart';
import '../../../data/models/product.dart';
import '../../../domain/interpretation.dart';
import 'sweetener_sheet.dart';

/// 대체당 칩 — 혈당 위험 내림차순 정렬, 탭하면 성분 바텀시트.
/// 분류색·범례 없이 '혈당 올림' 마커 하나로 단순화.
class SweetenerChips extends StatelessWidget {
  const SweetenerChips({super.key, required this.chips, required this.notes});
  final List<SweetenerChip> chips;
  final Map<String, ComboRule> notes; // slug -> 단일 성분 규칙

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) {
      return const Text('표시된 대체당이 없어요.',
          style: TextStyle(color: CubedColors.inkSoft, fontSize: 13));
    }
    int rank(SweetenerChip c) =>
        switch (c.glycemic) { Grade.caution => 2, Grade.mid => 1, Grade.low => 0 };
    final sorted = [...chips]..sort((a, b) => rank(b).compareTo(rank(a)));
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: sorted
          .map((c) => _Chip(c: c, onTap: () => showSweetenerSheet(context, c, notes[c.slug])))
          .toList(),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.c, required this.onTap});
  final SweetenerChip c;
  final VoidCallback onTap;

  bool get _raises => c.isRisky || c.glycemic != Grade.low;

  @override
  Widget build(BuildContext context) {
    final color = _raises ? CubedColors.grade(c.glycemic) : CubedColors.inkSoft;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _raises ? color.withValues(alpha: 0.07) : CubedColors.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: _raises ? color.withValues(alpha: 0.35) : CubedColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            if (c.amountG != null) ...[
              const SizedBox(width: 4),
              Text('${_n(c.amountG!)}g',
                  style: const TextStyle(color: CubedColors.inkSoft, fontSize: 12)),
            ],
            if (_raises) ...[
              const SizedBox(width: 5),
              const Text('🩸', style: TextStyle(fontSize: 11)),
            ],
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 14, color: CubedColors.inkSoft),
          ],
        ),
      ),
    );
  }

  static String _n(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}
