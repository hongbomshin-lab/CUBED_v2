import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models/franchise_drink.dart';
import 'franchise_ui.dart';

/// 프랜차이즈 음료 상세 바텀시트.
Future<void> showFranchiseDetailSheet(
    BuildContext context, FranchiseDrink drink) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: CubedColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _FranchiseDetailSheet(drink: drink),
  );
}

class _FranchiseDetailSheet extends StatelessWidget {
  const _FranchiseDetailSheet({required this.drink});
  final FranchiseDrink drink;

  @override
  Widget build(BuildContext context) {
    final color = sugarColor(drink.sugarG);
    final cubes = drink.sugarCubes ??
        (drink.sugarG == null ? null : drink.sugarG! / 3.3);

    final sizeLine = [
      if (drink.size != null) drink.size!,
      if (drink.volumeMl != null) '${drink.volumeMl}ml',
    ].join('  ·  ');

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 8,
          bottom: 20 + MediaQuery.of(context).viewPadding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: CubedColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // 브랜드 + 메뉴명
            Text(drink.brand,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: CubedColors.inkSoft)),
            const SizedBox(height: 4),
            Text(drink.nameClean,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            if (sizeLine.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(sizeLine,
                  style: const TextStyle(
                      fontSize: 13, color: CubedColors.inkSoft)),
            ],
            const SizedBox(height: 20),

            // 당류 대표 표시(주인공) + 각설탕 환산
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: 0.25)),
              ),
              child: Column(
                children: [
                  const Text('당류',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: CubedColors.inkSoft)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(fmtNum(drink.sugarG),
                          style: TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w900,
                              color: color,
                              height: 1)),
                      Text(' g',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: color)),
                    ],
                  ),
                  if (cubes != null) ...[
                    const SizedBox(height: 8),
                    _CubeRow(cubes: cubes, color: color),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 칼로리 + 제로옵션
            Row(children: [
              Expanded(
                child: _StatBox(
                  label: '칼로리',
                  value: drink.calories == null
                      ? '-'
                      : '${fmtNum(drink.calories)} kcal',
                ),
              ),
              if (drink.hasZeroOption) ...[
                const SizedBox(width: 10),
                const Expanded(
                  child: _StatBox(label: '제로 옵션', value: '있음'),
                ),
              ],
            ]),

            if (drink.altSweetener != null) ...[
              const SizedBox(height: 12),
              _InfoLine(
                icon: Icons.eco_rounded,
                label: '대체 감미료',
                value: drink.altSweetener!,
              ),
            ],

            const SizedBox(height: 20),
            // 나머지 영양성분 (기본 접힘)
            _NutritionExpand(drink: drink),
          ],
        ),
      ),
    );
  }
}

class _CubeRow extends StatelessWidget {
  const _CubeRow({required this.cubes, required this.color});
  final double cubes;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final full = cubes.floor().clamp(0, 12);
    return Column(
      children: [
        Wrap(
          spacing: 3,
          runSpacing: 3,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < full; i++)
              Icon(Icons.crop_square_rounded, size: 16, color: color),
          ],
        ),
        const SizedBox(height: 4),
        Text('각설탕 약 ${cubes.toStringAsFixed(1)}개',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: CubedColors.bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: CubedColors.inkSoft)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 18, color: CubedColors.brand),
      const SizedBox(width: 8),
      Text('$label  ',
          style: const TextStyle(fontSize: 13, color: CubedColors.inkSoft)),
      Expanded(
        child: Text(value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      ),
    ]);
  }
}

/// 나머지 영양성분 — 기본 접힘.
class _NutritionExpand extends StatelessWidget {
  const _NutritionExpand({required this.drink});
  final FranchiseDrink drink;

  @override
  Widget build(BuildContext context) {
    final rows = <({String label, String value})>[
      (label: '탄수화물', value: fmtNum(drink.carbsG, unit: ' g')),
      (label: '단백질', value: fmtNum(drink.proteinG, unit: ' g')),
      (label: '지방', value: fmtNum(drink.fatG, unit: ' g')),
      (label: '나트륨', value: fmtNum(drink.sodiumMg, unit: ' mg')),
      (label: '카페인', value: fmtNum(drink.caffeineMg, unit: ' mg')),
    ];
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          backgroundColor: CubedColors.bg,
          collapsedBackgroundColor: CubedColors.bg,
          title: const Text('영양성분 전체',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          children: [
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(r.label,
                        style: const TextStyle(
                            fontSize: 13, color: CubedColors.inkSoft)),
                    Text(r.value,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
