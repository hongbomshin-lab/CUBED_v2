import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/price_format.dart';
import '../../core/product_thumb.dart';
import '../../core/theme.dart';
import '../../data/models/product_price.dart';
import '../../providers/providers.dart';

class HotDealsScreen extends ConsumerWidget {
  const HotDealsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deals = ref.watch(hotDealsProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('핫딜',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: CubedColors.brand,
                              )),
                  const SizedBox(height: 6),
                  const Text('총액보다 개당가로 비교했어요',
                      style:
                          TextStyle(color: CubedColors.inkSoft, fontSize: 15)),
                ],
              ),
            ),
            Expanded(
              child: deals.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => _ErrorState(
                  onRetry: () => ref.invalidate(hotDealsProvider),
                ),
                data: (items) => items.isEmpty
                    ? const _EmptyState()
                    : RefreshIndicator(
                        onRefresh: () async =>
                            ref.refresh(hotDealsProvider.future),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, index) =>
                              _DealCard(item: items[index]),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DealCard extends StatelessWidget {
  const _DealCard({required this.item});
  final HotDealItem item;

  @override
  Widget build(BuildContext context) {
    final offer = item.offer;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CubedColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: CubedColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProductThumb(imageFile: item.imageFile, size: 72, radius: 8),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: CubedColors.brand.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(offer.promoLabel,
                        style: const TextStyle(
                            color: CubedColors.brand,
                            fontSize: 10,
                            fontWeight: FontWeight.w800)),
                  ),
                  if (item.discountRate != null) ...[
                    const SizedBox(width: 6),
                    Text('${item.discountRate}% 할인',
                        style: const TextStyle(
                            color: CubedColors.caution,
                            fontSize: 11,
                            fontWeight: FontWeight.w800)),
                  ],
                ]),
                const SizedBox(height: 7),
                Text(item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800)),
                if (offer.offerTitle != null) ...[
                  const SizedBox(height: 3),
                  Text(offer.offerTitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: CubedColors.brand,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ],
                const SizedBox(height: 3),
                Text('${offer.store} · ${checkedDate(offer.fetchedAt)}',
                    style: const TextStyle(
                        color: CubedColors.inkSoft, fontSize: 11)),
                const SizedBox(height: 9),
                Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('개당 ${won(offer.unitPrice)}',
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w900)),
                        Text('${offer.unitCount}개 ${won(offer.price)}',
                            style: const TextStyle(
                                color: CubedColors.inkSoft, fontSize: 11)),
                        if (offer.offerNote != null) ...[
                          const SizedBox(height: 4),
                          Text(offer.offerNote!,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: CubedColors.inkSoft,
                                  fontSize: 10,
                                  height: 1.3)),
                        ],
                      ],
                    ),
                  ),
                  if (offer.linkUrl != null)
                    IconButton.filled(
                      tooltip: '구매 페이지 열기',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => launchUrl(Uri.parse(offer.linkUrl!),
                          mode: LaunchMode.externalApplication),
                      icon: const Icon(Icons.open_in_new_rounded, size: 17),
                    ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const Center(
        child: Text('지금 확인된 핫딜이 없어요',
            style: TextStyle(color: CubedColors.inkSoft)),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('핫딜을 불러오지 못했어요',
                style: TextStyle(color: CubedColors.inkSoft)),
            const SizedBox(height: 10),
            IconButton.filled(
              tooltip: '다시 불러오기',
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
      );
}
