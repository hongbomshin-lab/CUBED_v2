import 'package:flutter/material.dart';

import '../../../core/rulebook.dart';
import '../../../core/theme.dart';
import '../../../data/models/product.dart';
import '../../../domain/interpretation.dart';

/// 칩 탭 → 성분 상세 바텀시트. 단일 성분 combo 규칙(slugNotes)이 본문,
/// 없으면 등급 기반 기본 문장. 치아 영향(cariogenic)도 함께 표시.
void showSweetenerSheet(BuildContext context, SweetenerChip c, ComboRule? note) {
  showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _SheetBody(c: c, note: note),
  );
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({required this.c, required this.note});
  final SweetenerChip c;
  final ComboRule? note;

  String get _fallback => switch (c.glycemic) {
        Grade.caution => '${c.name}은(는) 혈당을 올릴 수 있는 감미료예요. 양 조절이 필요해요.',
        Grade.mid => '${c.name}은(는) 혈당을 약간 올릴 수 있어요.',
        Grade.low => '${c.name}은(는) 혈당에 거의 영향이 없어요.',
      };

  @override
  Widget build(BuildContext context) {
    final gc = CubedColors.grade(c.glycemic);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(note?.headline ?? c.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: gc.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('혈당 ${c.glycemic.ko}',
                      style: TextStyle(color: gc, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('${c.klass} 감미료${c.amountG != null ? ' · ${_n(c.amountG!)}g 함유' : ''}',
                style: const TextStyle(color: CubedColors.inkSoft, fontSize: 13)),
            const SizedBox(height: 14),
            Text(note?.message ?? _fallback,
                style: const TextStyle(fontSize: 15, height: 1.55)),
            if (c.note != null && c.note!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(c.note!,
                  style: const TextStyle(color: CubedColors.inkSoft, fontSize: 13, height: 1.5)),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.emoji_emotions_outlined, size: 16, color: CubedColors.inkSoft),
                const SizedBox(width: 6),
                Text(
                  switch (c.cariogenic) {
                    '억제' => '치아: 충치균 억제에 도움',
                    '유발' => '치아: 충치 유발 가능',
                    _ => '치아: 중립',
                  },
                  style: const TextStyle(color: CubedColors.inkSoft, fontSize: 13),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _n(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}
