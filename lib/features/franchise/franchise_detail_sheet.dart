import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models/franchise_drink.dart';
import 'franchise_ui.dart';

/// 프랜차이즈 음료 상세 바텀시트. 같은 메뉴의 온도/사이즈 변형을 탭으로 전환.
Future<void> showFranchiseDetailSheet(
    BuildContext context, FranchiseMenu menu) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: CubedColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _FranchiseDetailSheet(menu: menu),
  );
}

class _FranchiseDetailSheet extends StatefulWidget {
  const _FranchiseDetailSheet({required this.menu});
  final FranchiseMenu menu;

  @override
  State<_FranchiseDetailSheet> createState() => _FranchiseDetailSheetState();
}

class _FranchiseDetailSheetState extends State<_FranchiseDetailSheet> {
  late String? _temp;
  late String? _size;

  FranchiseMenu get menu => widget.menu;

  @override
  void initState() {
    super.initState();
    _temp = menu.representative.temperature;
    _size = menu.representative.size;
  }

  /// 현재 선택(온도·사이즈)에 맞는 변형. 없으면 대표.
  FranchiseDrink get _selected {
    final temps = menu.temperatures;
    final sizes = menu.sizes;
    for (final v in menu.variants) {
      final tempOk = temps.isEmpty || v.temperature == _temp;
      final sizeOk = sizes.isEmpty || v.size == _size;
      if (tempOk && sizeOk) return v;
    }
    return menu.representative;
  }

  @override
  Widget build(BuildContext context) {
    final d = _selected;
    final color = sugarColor(d.sugarG);
    final cubes = d.sugarCubes ?? (d.sugarG == null ? null : d.sugarG! / 3.3);
    final temps = menu.temperatures;
    final sizes = menu.sizes;

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
            Text(menu.brand,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: CubedColors.inkSoft)),
            const SizedBox(height: 4),
            Text(menu.displayName,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            if (d.volumeMl != null) ...[
              const SizedBox(height: 4),
              Text('${d.volumeMl}ml',
                  style: const TextStyle(
                      fontSize: 13, color: CubedColors.inkSoft)),
            ],
            const SizedBox(height: 16),

            // 온도 탭
            if (temps.length > 1)
              _Segment(
                options: [
                  for (final t in temps) (value: t, label: t == 'ICE' ? '아이스' : '핫'),
                ],
                selected: _temp,
                onChanged: (v) => setState(() => _temp = v),
              ),
            if (temps.length > 1 && sizes.length > 1)
              const SizedBox(height: 8),
            // 사이즈 탭
            if (sizes.length > 1)
              _Segment(
                options: [for (final s in sizes) (value: s, label: s)],
                selected: _size,
                onChanged: (v) => setState(() => _size = v),
              ),
            if (temps.length > 1 || sizes.length > 1)
              const SizedBox(height: 16),

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
                      Text(fmtNum(d.sugarG),
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
                  value: d.calories == null
                      ? '-'
                      : '${fmtNum(d.calories)} kcal',
                ),
              ),
              if (d.hasZeroOption) ...[
                const SizedBox(width: 10),
                const Expanded(
                  child: _StatBox(label: '제로 옵션', value: '있음'),
                ),
              ],
            ]),

            if (d.altSweetener != null) ...[
              const SizedBox(height: 12),
              _InfoLine(
                icon: Icons.eco_rounded,
                label: '대체 감미료',
                value: d.altSweetener!,
              ),
            ],

            const SizedBox(height: 20),
            // 나머지 영양성분 (기본 접힘)
            _NutritionExpand(drink: d),
          ],
        ),
      ),
    );
  }
}

/// 값 선택 세그먼트 (온도/사이즈 공용).
class _Segment extends StatelessWidget {
  const _Segment({
    required this.options,
    required this.selected,
    required this.onChanged,
  });
  final List<({String value, String label})> options;
  final String? selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: CubedColors.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          for (final o in options)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(o.value),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: o.value == selected
                        ? CubedColors.surface
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(17),
                    boxShadow: o.value == selected
                        ? [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 4)
                          ]
                        : null,
                  ),
                  child: Text(o.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: o.value == selected
                              ? CubedColors.ink
                              : CubedColors.inkSoft)),
                ),
              ),
            ),
        ],
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
        if (full > 0)
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
