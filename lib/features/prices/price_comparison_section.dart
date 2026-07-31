import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/price_format.dart';
import '../../core/theme.dart';
import '../../data/models/product_price.dart';
import '../../providers/providers.dart';

class PriceComparisonSection extends ConsumerWidget {
  const PriceComparisonSection({super.key, required this.productId});
  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (productId == 'ocr-temp') return const SizedBox.shrink();
    final prices = ref.watch(productPricesProvider(productId));
    return prices.when(
      loading: () => const _Loading(),
      error: (_, __) => _PriceError(
        onRetry: () => ref.invalidate(productPricesProvider(productId)),
      ),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return _PriceContent(items: items);
      },
    );
  }
}

class _PriceContent extends StatelessWidget {
  const _PriceContent({required this.items});
  final List<ProductPrice> items;

  @override
  Widget build(BuildContext context) {
    final regular = items.where((item) => item.isRegular).fold<ProductPrice?>(
          null,
          (best, item) =>
              best == null || item.unitPrice < best.unitPrice ? item : best,
        );
    final deals = items.where((item) => !item.isRegular).toList()
      ..sort((a, b) => a.unitPrice.compareTo(b.unitPrice));
    final best = deals.isNotEmpty ? deals.first : items.first;
    final summary = regular != null && best.unitPrice < regular.unitPrice
        ? '정가 ${won(regular.unitPrice)} → ${best.channelLabel} ${won(best.unitPrice)}'
        : '가장 낮은 개당가 ${won(best.unitPrice)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 22),
        const Text('가격 비교',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        const SizedBox(height: 5),
        Text(summary,
            style: const TextStyle(
                color: CubedColors.brand,
                fontSize: 15,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        for (final item in items) ...[
          _PriceRow(item: item, isBest: identical(item, best)),
          if (!identical(item, items.last)) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.item, required this.isBest});
  final ProductPrice item;
  final bool isBest;

  @override
  Widget build(BuildContext context) {
    final detail = item.unitCount > 1
        ? '총 ${won(item.price)} · ${item.unitCount}개 묶음'
        : item.promoLabel;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: isBest
            ? CubedColors.brand.withValues(alpha: 0.06)
            : CubedColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: isBest
                ? CubedColors.brand.withValues(alpha: 0.45)
                : CubedColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(item.store,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                  if (isBest) ...[
                    const SizedBox(width: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: CubedColors.brand,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('최저가',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800)),
                    ),
                  ],
                ]),
                const SizedBox(height: 4),
                Text('$detail · ${checkedDate(item.fetchedAt)}',
                    style: const TextStyle(
                        color: CubedColors.inkSoft, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(won(item.unitPrice),
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 16)),
              const Text('개당',
                  style: TextStyle(color: CubedColors.inkSoft, fontSize: 10)),
            ],
          ),
          if (item.linkUrl != null) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: '구매 페이지 열기',
              visualDensity: VisualDensity.compact,
              onPressed: () => launchUrl(Uri.parse(item.linkUrl!),
                  mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_new_rounded, size: 19),
            ),
          ],
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(top: 22),
        child: LinearProgressIndicator(minHeight: 2, color: CubedColors.brand),
      );
}

class _PriceError extends StatelessWidget {
  const _PriceError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Row(children: [
          const Expanded(
            child: Text('가격 정보를 불러오지 못했어요',
                style: TextStyle(color: CubedColors.inkSoft, fontSize: 12)),
          ),
          IconButton(
            tooltip: '가격 다시 불러오기',
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 19),
          ),
        ]),
      );
}
