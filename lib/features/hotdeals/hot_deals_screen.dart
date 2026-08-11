import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../data/deal_repository.dart';
import '../../data/models/brand_deal.dart';
import '../../providers/providers.dart';

/// 핫딜 탭 — 저당 브랜드(라라스윗·널담·마이노멀) 공식몰 특가 모음.
/// brand_deals 를 20개씩 페이지로 읽어(더보기) 부하를 줄인다.
class HotDealsScreen extends ConsumerStatefulWidget {
  const HotDealsScreen({super.key});

  @override
  ConsumerState<HotDealsScreen> createState() => _HotDealsScreenState();
}

class _HotDealsScreenState extends ConsumerState<HotDealsScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  String _query = '';
  String? _brandSlug;
  String? _category;
  DealSort _sort = DealSort.discount;

  final List<BrandDeal> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _error = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<List<BrandDeal>> _fetch(int offset) =>
      ref.read(dealRepositoryProvider).deals(
            query: _query,
            brandSlug: _brandSlug,
            category: _category,
            sort: _sort,
            offset: offset,
          );

  /// 필터/검색 변경 시 처음부터 다시 로드.
  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = false;
      _items.clear();
      _hasMore = true;
    });
    try {
      final rows = await _fetch(0);
      if (!mounted) return;
      setState(() {
        _items.addAll(rows);
        _loading = false;
        _hasMore = rows.length == DealRepository.pageSize;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  /// 더보기 — 다음 페이지를 이어붙임.
  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final rows = await _fetch(_items.length);
      if (!mounted) return;
      setState(() {
        _items.addAll(rows);
        _loadingMore = false;
        _hasMore = rows.length == DealRepository.pageSize;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted || v.trim() == _query) return;
      _query = v.trim();
      _reload();
    });
  }

  void _clearSearch() {
    FocusScope.of(context).unfocus();
    _searchCtrl.clear();
    if (_query.isNotEmpty) {
      _query = '';
      _reload();
    }
  }

  Future<void> _open(BrandDeal d) async {
    final uri = Uri.parse(d.productUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('링크를 열 수 없어요')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CubedColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 2),
              child: Text('오늘의 저당 특가 🔥',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5)),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('라라스윗·널담·마이노멀 공식몰 특가를 한눈에',
                  style: TextStyle(color: CubedColors.inkSoft, fontSize: 13)),
            ),

            // 검색바
            _SearchBar(
              controller: _searchCtrl,
              onChanged: _onSearch,
              onClear: _clearSearch,
            ),

            // 브랜드 필터 칩
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _Chip(
                    label: '전체',
                    selected: _brandSlug == null,
                    onTap: () {
                      _brandSlug = null;
                      _reload();
                    },
                  ),
                  for (final b in DealRepository.brands)
                    _Chip(
                      label: b.label,
                      selected: _brandSlug == b.slug,
                      onTap: () {
                        _brandSlug = b.slug;
                        _reload();
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // 카테고리 필터 칩
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _CatChip(
                    label: '전체',
                    selected: _category == null,
                    onTap: () {
                      _category = null;
                      _reload();
                    },
                  ),
                  for (final c in DealRepository.categories)
                    _CatChip(
                      label: c,
                      selected: _category == c,
                      onTap: () {
                        _category = c;
                        _reload();
                      },
                    ),
                ],
              ),
            ),

            // 개수 + 정렬
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 16, 8),
              child: Row(
                children: [
                  Text(
                    _loading ? '' : '${_items.length}${_hasMore ? '+' : ''}개',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: CubedColors.inkSoft),
                  ),
                  const Spacer(),
                  for (final s in DealSort.values) ...[
                    if (s != DealSort.values.first)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('·',
                            style: TextStyle(color: CubedColors.line)),
                      ),
                    _SortText(
                        label: s.label,
                        on: _sort == s,
                        onTap: () {
                          _sort = s;
                          _reload();
                        }),
                  ],
                ],
              ),
            ),

            // 목록 + 더보기
            Expanded(child: _buildBody()),

            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('가격·재고는 수집 시점 기준이며 실제와 다를 수 있어요. 구매는 브랜드몰에서 진행돼요.',
                  style: TextStyle(fontSize: 11, color: CubedColors.inkSoft)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error) {
      return const _Empty(
          icon: Icons.error_outline_rounded, text: '특가를 불러오지 못했어요');
    }
    if (_items.isEmpty) {
      return const _Empty(
          icon: Icons.search_off_rounded, text: '표시할 특가가 없어요');
    }
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.60,
            ),
            delegate: SliverChildBuilderDelegate(
              (_, i) =>
                  _DealCard(deal: _items[i], onTap: () => _open(_items[i])),
              childCount: _items.length,
            ),
          ),
        ),
        if (_hasMore)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: _loadingMore
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: SizedBox(
                            width: 22,
                            height: 22,
                            child:
                                CircularProgressIndicator(strokeWidth: 2)),
                      ),
                    )
                  : OutlinedButton(
                      onPressed: _loadMore,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: CubedColors.ink,
                        side: const BorderSide(color: CubedColors.line),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: const Text('더보기',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
            ),
          ),
      ],
    );
  }
}

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
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
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
                hintText: '상품명 검색 (예: 쿠키)',
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

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: CubedColors.inkSoft),
            const SizedBox(height: 12),
            Text(text,
                style:
                    const TextStyle(color: CubedColors.inkSoft, fontSize: 14)),
          ],
        ),
      );
}

/// 딜 카드 — 상품사진 + 브랜드 + 이름 + 할인 히어로.
class _DealCard extends StatelessWidget {
  const _DealCard({required this.deal, required this.onTap});
  final BrandDeal deal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (tag, cleanName) = deal.tagAndName;
    return Material(
      color: CubedColors.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 사진 (남는 높이 채움) + 뱃지 — 이미지가 유연하게 줄어 오버플로우 방지
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (deal.imageUrl != null)
                    CachedNetworkImage(
                      imageUrl: deal.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: CubedColors.line),
                      errorWidget: (_, __, ___) => Container(
                        color: CubedColors.bg,
                        child: const Icon(Icons.image_not_supported_rounded,
                            color: CubedColors.inkSoft),
                      ),
                    )
                  else
                    Container(
                      color: CubedColors.bg,
                      child: const Icon(Icons.local_mall_rounded,
                          color: CubedColors.inkSoft, size: 36),
                    ),
                  if (deal.isSoldout)
                    Container(
                      color: Colors.black.withValues(alpha: 0.45),
                      alignment: Alignment.center,
                      child: const Text('품절',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800)),
                    ),
                ],
              ),
            ),

            // 텍스트 영역 (자연 높이 — 남는 공간은 위 이미지가 흡수)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(deal.brandName,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: CubedColors.inkSoft)),
                    if (tag != null) ...[
                      const SizedBox(width: 4),
                      Flexible(child: _TagChip(text: tag)),
                    ],
                  ]),
                  const SizedBox(height: 3),
                  Text(cleanName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          height: 1.25,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  // 할인 히어로: 원가 있으면 할인율%, 없으면 '특가' 뱃지 (허위 원가 조작 없음)
                  if (deal.hasDiscount) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('${deal.discountRate.round()}%',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: CubedColors.caution)),
                        const SizedBox(width: 5),
                        Text('${_won(deal.salePrice)}원',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    Text('${_won(deal.listPrice!)}원',
                        style: const TextStyle(
                            fontSize: 12,
                            color: CubedColors.inkSoft,
                            decoration: TextDecoration.lineThrough)),
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: CubedColors.brand,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('특가',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white)),
                        ),
                        const SizedBox(width: 5),
                        Text('${_won(deal.salePrice)}원',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    const SizedBox(height: 15),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _won(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: CubedColors.brand.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: CubedColors.brand)),
      );
}

class _Chip extends StatelessWidget {
  const _Chip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: selected ? CubedColors.brand : CubedColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: selected ? CubedColors.brand : CubedColors.line),
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : CubedColors.inkSoft)),
          ),
        ),
      );
}

class _CatChip extends StatelessWidget {
  const _CatChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 7),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: selected
                  ? CubedColors.brand.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                  color: selected ? CubedColors.brand : CubedColors.line),
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color:
                        selected ? CubedColors.brand : CubedColors.inkSoft)),
          ),
        ),
      );
}

class _SortText extends StatelessWidget {
  const _SortText(
      {required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Text(label,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                color: on ? CubedColors.brand : CubedColors.inkSoft)),
      );
}
