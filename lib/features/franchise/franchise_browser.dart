import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/franchise_repository.dart';
import '../../data/models/franchise_drink.dart';
import '../../providers/providers.dart';
import 'franchise_detail_sheet.dart';
import 'franchise_ui.dart';

/// 프랜차이즈 메뉴 당류정보 브라우저 — 검색 + 브랜드 필터 + 정렬 + 목록.
/// 저당맵 탭의 '메뉴 당류' 모드 본문으로 쓰인다.
class FranchiseBrowser extends ConsumerStatefulWidget {
  const FranchiseBrowser({super.key});

  @override
  ConsumerState<FranchiseBrowser> createState() => _FranchiseBrowserState();
}

class _FranchiseBrowserState extends ConsumerState<FranchiseBrowser> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  String _query = '';
  final Set<String> _brands = {};
  FranchiseSort _sort = FranchiseSort.sugarAsc;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _query = q.trim());
    });
  }

  void _clearSearch() {
    FocusScope.of(context).unfocus();
    _searchCtrl.clear();
    setState(() => _query = '');
  }

  void _toggleBrand(String? brand) {
    setState(() {
      if (brand == null) {
        _brands.clear();
      } else if (_brands.contains(brand)) {
        _brands.remove(brand);
      } else {
        _brands.add(brand);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(franchiseSearchProvider(
      FranchiseQuery(query: _query, brands: _brands, sort: _sort),
    ));

    return Column(
      children: [
        _SearchBar(
          controller: _searchCtrl,
          onChanged: _onSearchChanged,
          onClear: _clearSearch,
        ),
        _BrandFilterBar(selected: _brands, onTap: _toggleBrand),
        _SortBar(
          sort: _sort,
          onChanged: (s) => setState(() => _sort = s),
          count: async.valueOrNull?.length,
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(
              child: Text('메뉴를 불러오지 못했어요',
                  style: TextStyle(color: CubedColors.inkSoft)),
            ),
            data: (drinks) {
              if (drinks.isEmpty) {
                return const Center(
                  child: Text('검색 결과가 없어요',
                      style: TextStyle(color: CubedColors.inkSoft)),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 24),
                itemCount: drinks.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _DrinkCard(
                  drink: drinks[i],
                  onTap: () => showFranchiseDetailSheet(context, drinks[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 상단 검색바 (저당맵 검색바와 동일 톤).
class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: CubedColors.bg,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: CubedColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: CubedColors.line),
        ),
        child: Row(children: [
          const Icon(Icons.search_rounded, size: 20, color: CubedColors.inkSoft),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: '메뉴 이름 검색 (예: 아메)',
                hintStyle: TextStyle(color: CubedColors.inkSoft, fontSize: 14),
              ),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, __) => value.text.isEmpty
                ? const SizedBox.shrink()
                : GestureDetector(
                    onTap: onClear,
                    child: const Icon(Icons.close_rounded,
                        size: 18, color: CubedColors.inkSoft),
                  ),
          ),
        ]),
      ),
    );
  }
}

/// 브랜드 필터 칩 (전체 + 6개 브랜드).
class _BrandFilterBar extends StatelessWidget {
  const _BrandFilterBar({required this.selected, required this.onTap});
  final Set<String> selected;
  final void Function(String?) onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: CubedColors.bg,
      padding: const EdgeInsets.only(bottom: 6),
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _Chip(
            label: '전체',
            selected: selected.isEmpty,
            onTap: () => onTap(null),
          ),
          for (final b in FranchiseRepository.brands)
            _Chip(
              label: b,
              selected: selected.contains(b),
              onTap: () => onTap(b),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? CubedColors.brand : CubedColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: selected ? CubedColors.brand : CubedColors.line),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : CubedColors.inkSoft,
            ),
          ),
        ),
      ),
    );
  }
}

/// 정렬 선택 + 결과 수.
class _SortBar extends StatelessWidget {
  const _SortBar({
    required this.sort,
    required this.onChanged,
    required this.count,
  });
  final FranchiseSort sort;
  final ValueChanged<FranchiseSort> onChanged;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: CubedColors.bg,
      padding: const EdgeInsets.fromLTRB(14, 2, 12, 8),
      child: Row(
        children: [
          if (count != null)
            Text('$count개',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: CubedColors.inkSoft)),
          const Spacer(),
          for (final s in FranchiseSort.values) ...[
            GestureDetector(
              onTap: () => onChanged(s),
              child: Text(
                s.label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: s == sort ? FontWeight.w800 : FontWeight.w600,
                  color: s == sort ? CubedColors.brand : CubedColors.inkSoft,
                ),
              ),
            ),
            if (s != FranchiseSort.values.last)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('·',
                    style: TextStyle(color: CubedColors.line, fontSize: 12)),
              ),
          ],
        ],
      ),
    );
  }
}

/// 목록 카드 — 메뉴명(강조) + 브랜드 + 당류(크게, 색상) + 칼로리(보조).
class _DrinkCard extends StatelessWidget {
  const _DrinkCard({required this.drink, required this.onTap});
  final FranchiseDrink drink;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = sugarColor(drink.sugarG);
    return Material(
      color: CubedColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      drink.nameClean,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800, height: 1.2),
                    ),
                    const SizedBox(height: 4),
                    Row(children: [
                      Text(drink.brand,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: CubedColors.inkSoft)),
                      if (drink.size != null) ...[
                        const Text('  ·  ',
                            style: TextStyle(
                                fontSize: 12, color: CubedColors.line)),
                        Text(drink.size!,
                            style: const TextStyle(
                                fontSize: 12, color: CubedColors.inkSoft)),
                      ],
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // 당류 강조(주인공) + 칼로리 보조
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        fmtNum(drink.sugarG),
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: color,
                            height: 1),
                      ),
                      Text('g 당',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: color)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    drink.calories == null
                        ? '칼로리 -'
                        : '${fmtNum(drink.calories)} kcal',
                    style: const TextStyle(
                        fontSize: 12, color: CubedColors.inkSoft),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
