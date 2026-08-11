import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../data/deal_repository.dart';
import '../../data/models/brand_deal.dart';
import '../../providers/providers.dart';

/// 핫딜 탭 — 저당 브랜드(라라스윗·널담) 공식몰 특가 모음.
/// brand_deals 테이블을 읽어 표시(백엔드 crawl-deals 가 6시간마다 갱신).
class HotDealsScreen extends ConsumerStatefulWidget {
  const HotDealsScreen({super.key});

  @override
  ConsumerState<HotDealsScreen> createState() => _HotDealsScreenState();
}

class _HotDealsScreenState extends ConsumerState<HotDealsScreen> {
  String? _brandSlug; // null = 전체
  String? _category; // null = 전체
  DealSort _sort = DealSort.discount;

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
    final async = ref.watch(dealsProvider(DealQuery(
      brandSlug: _brandSlug,
      category: _category,
      sort: _sort,
    )));
    final count = async.valueOrNull?.length;

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
              padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text('라라스윗·널담·마이노멀 공식몰 특가를 한눈에',
                  style: TextStyle(color: CubedColors.inkSoft, fontSize: 13)),
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
                    onTap: () => setState(() => _brandSlug = null),
                  ),
                  for (final b in DealRepository.brands)
                    _Chip(
                      label: b.label,
                      selected: _brandSlug == b.slug,
                      onTap: () => setState(() => _brandSlug = b.slug),
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
                    onTap: () => setState(() => _category = null),
                  ),
                  for (final c in DealRepository.categories)
                    _CatChip(
                      label: c,
                      selected: _category == c,
                      onTap: () => setState(() => _category = c),
                    ),
                ],
              ),
            ),

            // 개수 + 정렬
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 16, 8),
              child: Row(
                children: [
                  Text(count == null ? '' : '$count개 특가',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: CubedColors.inkSoft)),
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
                        onTap: () => setState(() => _sort = s)),
                  ],
                ],
              ),
            ),

            // 목록
            Expanded(
              child: async.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) => const _Empty(
                    icon: Icons.error_outline_rounded,
                    text: '특가를 불러오지 못했어요'),
                data: (deals) => deals.isEmpty
                    ? const _Empty(
                        icon: Icons.local_fire_department_outlined,
                        text: '표시할 특가가 없어요')
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.60,
                        ),
                        itemCount: deals.length,
                        itemBuilder: (_, i) => _DealCard(
                            deal: deals[i], onTap: () => _open(deals[i])),
                      ),
              ),
            ),

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
                  ] else
                    Text('${_won(deal.salePrice)}원',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w900)),
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
