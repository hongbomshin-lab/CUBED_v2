import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/deal_repository.dart';
import '../../providers/providers.dart';
import 'point_card.dart' show won;
import 'point_models.dart';
import 'points_controller.dart';
import 'redeem_sheet.dart';

/// 포인트 상점 — 핫딜 탭의 '포인트 상점' 모드 본문.
///
/// 가짜 상품을 만들지 않고 실제 판매중인 핫딜(brand_deals)을 그대로 쓴다.
/// 가짜인 것은 포인트 잔액과 결제 승인뿐이다.
class PointsShop extends ConsumerWidget {
  const PointsShop({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(pointBalanceProvider);
    // 기본 정렬(할인율순)을 그대로 쓴다 — 상점도 '싸게 사는 곳'이라 기준이 같다.
    final async = ref.watch(dealsProvider(const DealQuery()));

    return Column(
      children: [
        _BalanceBar(balance: balance),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(
              child: Text('상품을 불러오지 못했어요',
                  style: TextStyle(color: CubedColors.inkSoft)),
            ),
            data: (deals) {
              // 품절 상품은 교환 대상에서 뺀다.
              final items = deals
                  .where((d) => !d.isSoldout)
                  .map(ShopItem.new)
                  .toList();
              if (items.isEmpty) {
                return const Center(
                  child: Text('교환할 수 있는 상품이 없어요',
                      style: TextStyle(color: CubedColors.inkSoft)),
                );
              }
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.62,
                ),
                itemCount: items.length,
                itemBuilder: (_, i) => _ShopCard(
                  item: items[i],
                  balance: balance,
                  onTap: () => showRedeemSheet(context, items[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BalanceBar extends StatelessWidget {
  const _BalanceBar({required this.balance});
  final int balance;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: CubedColors.ink,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        const Icon(Icons.savings_rounded, size: 16, color: CubedColors.lime),
        const SizedBox(width: 8),
        Text('사용 가능',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.7))),
        const Spacer(),
        Text('${won(balance)}P',
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: Colors.white)),
      ]),
    );
  }
}

class _ShopCard extends StatelessWidget {
  const _ShopCard({
    required this.item,
    required this.balance,
    required this.onTap,
  });
  final ShopItem item;
  final int balance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final usable = item.maxUsablePoints(balance);
    final pay = item.price - usable * PointPolicy.wonPerPoint;

    return Material(
      color: CubedColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(14)),
                child: SizedBox(
                  width: double.infinity,
                  child: item.imageUrl == null
                      ? Container(
                          color: CubedColors.bg,
                          child: const Icon(Icons.image_not_supported_rounded,
                              color: CubedColors.line))
                      : CachedNetworkImage(
                          imageUrl: item.imageUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              Container(color: CubedColors.bg),
                        ),
                ),
            ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.brandName,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: CubedColors.inkSoft)),
                  const SizedBox(height: 3),
                  Text(item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.25)),
                  const SizedBox(height: 8),
                  // 포인트로 깎이는 만큼을 강조 — 상점의 존재 이유다.
                  if (usable > 0)
                    Text('−${won(usable)}P',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: CubedColors.brand)),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('${won(pay)}원',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w900)),
                      if (usable > 0) ...[
                        const SizedBox(width: 5),
                        Text('${won(item.price)}원',
                            style: const TextStyle(
                              fontSize: 11,
                              color: CubedColors.inkSoft,
                              decoration: TextDecoration.lineThrough,
                            )),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
