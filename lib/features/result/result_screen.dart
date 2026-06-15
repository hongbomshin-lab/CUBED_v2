import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/explain.dart';
import '../../core/product_thumb.dart';
import '../../core/theme.dart';
import '../../data/models/product.dart';
import '../../domain/interpretation.dart';
import '../../providers/providers.dart';
import 'widgets/grade_hero.dart';
import 'widgets/social_section.dart';
import 'widgets/sweetener_chips.dart';

class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key, required this.product});
  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interp = ref.watch(interpretationProvider(product));
    return Scaffold(
      appBar: AppBar(title: const Text('분석 결과')),
      body: interp.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('해석 오류: $e')),
        data: (it) => _Body(it: it),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.it});
  final Interpretation it;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = it.product;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        _ProductHeader(it: it),
        const SizedBox(height: 16),
        GradeHero(it: it),

        // 함정 카드
        if (it.trapLines.isNotEmpty) ...[
          const SizedBox(height: 16),
          ...it.trapLines.map((t) => _TrapCard(line: t)),
        ],

        // 대체당 조합 맞춤 메시지 (킬러 피처)
        if (it.combo != null) ...[
          const SizedBox(height: 16),
          _ComboCard(combo: it.combo!),
        ],

        // 대체당 칩
        const SizedBox(height: 20),
        _SectionTitle('포함된 대체당', trailing: '${it.chips.length}종'),
        const SizedBox(height: 10),
        SweetenerChips(chips: it.chips),
        const SizedBox(height: 8),
        const _ChipLegend(),

        // 영양성분
        const SizedBox(height: 22),
        const _SectionTitle('영양성분', trailing: '1회분 기준'),
        const SizedBox(height: 10),
        _NutritionGrid(p: p),

        // 대안 추천 (킬러 피처)
        const SizedBox(height: 24),
        const _SectionTitle('대신 이건 어때요?'),
        const SizedBox(height: 4),
        const Text('같은 칸에서 혈당 부담이 더 낮은 제품',
            style: TextStyle(color: CubedColors.inkSoft, fontSize: 13)),
        const SizedBox(height: 12),
        _Alternatives(product: p),

        // 좋아요 + 코멘트
        const SizedBox(height: 28),
        const Divider(height: 1, color: CubedColors.line),
        const SizedBox(height: 20),
        SocialSection(productId: p.productId),

        // 검수 안내
        if (!p.verified) ...[
          const SizedBox(height: 24),
          _DraftNotice(notes: p.notes),
        ],
        const SizedBox(height: 12),
        Text(it.reason,
            style: const TextStyle(color: CubedColors.inkSoft, fontSize: 12, height: 1.5)),
      ],
    );
  }
}

class _ProductHeader extends StatelessWidget {
  const _ProductHeader({required this.it});
  final Interpretation it;
  @override
  Widget build(BuildContext context) {
    final p = it.product;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProductThumb(imageFile: p.imageFile, size: 72),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (p.brand != null)
                Text(p.brand!, style: const TextStyle(color: CubedColors.inkSoft, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(p.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, height: 1.25)),
              const SizedBox(height: 6),
              if (p.category != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: CubedColors.brand.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(p.category!,
                      style: const TextStyle(color: CubedColors.brand, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrapCard extends StatelessWidget {
  const _TrapCard({required this.line});
  final TrapLine line;
  @override
  Widget build(BuildContext context) {
    final isTrap = line.tier == TrapTier.trap;
    final c = isTrap ? CubedColors.caution : CubedColors.inkSoft;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isTrap ? c.withValues(alpha: 0.07) : CubedColors.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isTrap ? c.withValues(alpha: 0.25) : CubedColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(line.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(line.text,
                style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: isTrap ? FontWeight.w700 : FontWeight.w500,
                    color: isTrap ? CubedColors.ink : CubedColors.inkSoft)),
          ),
        ],
      ),
    );
  }
}

class _ComboCard extends StatelessWidget {
  const _ComboCard({required this.combo});
  final ComboRule combo;
  @override
  Widget build(BuildContext context) {
    final (c, icon) = switch (combo.tone) {
      'warn' => (CubedColors.caution, Icons.science_rounded),
      'fun' => (CubedColors.brand, Icons.auto_awesome_rounded),
      _ => (CubedColors.artificial, Icons.lightbulb_rounded),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: c, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(combo.headline, style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 15))),
          ]),
          const SizedBox(height: 8),
          Text(combo.message, style: const TextStyle(fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }
}

class _NutritionGrid extends StatelessWidget {
  const _NutritionGrid({required this.p});
  final Product p;
  @override
  Widget build(BuildContext context) {
    String n(double? v, String u) =>
        v == null ? '–' : (v == v.roundToDouble() ? '${v.toInt()}$u' : '$v$u');
    final items = <(String, String)>[
      ('열량', n(p.kcal, 'kcal')),
      ('탄수화물', n(p.carb, 'g')),
      ('당류', n(p.sugar, 'g')),
      ('단백질', n(p.protein, 'g')),
      ('지방', n(p.fat, 'g')),
      ('나트륨', n(p.sodiumMg, 'mg')),
      if (p.fiber > 0) ('식이섬유', n(p.fiber, 'g')),
      if (p.sugarAlcohol > 0) ('당알코올', n(p.sugarAlcohol, 'g')),
      if (p.rareSugarG > 0) ('알룰로스', n(p.rareSugarG, 'g')),
    ];
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: CubedColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CubedColors.line),
      ),
      child: Wrap(
        children: items.map((e) {
          return SizedBox(
            width: (MediaQuery.of(context).size.width - 40 - 12) / 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Column(
                children: [
                  Text(e.$2, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 3),
                  Text(e.$1, style: const TextStyle(color: CubedColors.inkSoft, fontSize: 11)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _Alternatives extends ConsumerWidget {
  const _Alternatives({required this.product});
  final Product product;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alts = ref.watch(alternativesProvider(product));
    return alts.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (list) {
        if (list.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CubedColors.low.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(children: [
              Text('👍', style: TextStyle(fontSize: 18)),
              SizedBox(width: 10),
              Expanded(child: Text('이 칸에서 이미 좋은 선택이에요.', style: TextStyle(fontWeight: FontWeight.w600))),
            ]),
          );
        }
        return Column(
          children: list.map((alt) {
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ResultScreen(product: alt.product)),
                ),
                leading: CircleAvatar(
                  backgroundColor: CubedColors.grade(alt.grade).withValues(alpha: 0.15),
                  child: Text(gradeText[alt.grade]!.emoji),
                ),
                title: Text(alt.product.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                subtitle: Text('순탄수 ${_n(alt.netCarb)}g · ${gradeText[alt.grade]!.badge}',
                    style: const TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  static String _n(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.trailing});
  final String title;
  final String? trailing;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        if (trailing != null)
          Text(trailing!, style: const TextStyle(color: CubedColors.inkSoft, fontSize: 13)),
      ],
    );
  }
}

class _ChipLegend extends StatelessWidget {
  const _ChipLegend();
  @override
  Widget build(BuildContext context) {
    Widget dot(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(t, style: const TextStyle(fontSize: 11, color: CubedColors.inkSoft)),
        ]);
    return Wrap(spacing: 14, runSpacing: 6, children: [
      dot(CubedColors.natural, '천연'),
      dot(CubedColors.artificial, '인공'),
      dot(CubedColors.sugarAlcohol, '당알코올'),
      dot(CubedColors.etc, '기타'),
      const Text('🩸 혈당 올림', style: TextStyle(fontSize: 11, color: CubedColors.inkSoft)),
    ]);
  }
}

class _DraftNotice extends StatelessWidget {
  const _DraftNotice({this.notes});
  final String? notes;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CubedColors.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CubedColors.line),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info_outline_rounded, size: 16, color: CubedColors.inkSoft),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '검수 전 자동 추출 데이터예요. 실제 라벨과 다를 수 있어요.${notes != null && notes!.isNotEmpty ? '\n· $notes' : ''}',
            style: const TextStyle(color: CubedColors.inkSoft, fontSize: 12, height: 1.5),
          ),
        ),
      ]),
    );
  }
}
