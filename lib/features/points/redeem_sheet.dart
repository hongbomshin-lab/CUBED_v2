import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import 'point_card.dart' show won;
import 'point_models.dart';
import 'points_controller.dart';

/// 상품 구매 시트 — 포인트로 얼마를 깎고 얼마를 결제할지 정한다.
///
/// ⚠️ 결제는 아직 **모양만** 있다. 실제 승인은 일어나지 않는다.
/// 실물 상품이라 앱스토어 인앱결제 의무 대상이 아니고, 외부 PG(포트원·토스 등)를
/// 붙이면 되는데 사업자·정산 계좌·환불 정책이 선행돼야 한다.
Future<void> showRedeemSheet(BuildContext context, ShopItem item) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: CubedColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _RedeemSheet(item: item),
  );
}

class _RedeemSheet extends ConsumerStatefulWidget {
  const _RedeemSheet({required this.item});
  final ShopItem item;

  @override
  ConsumerState<_RedeemSheet> createState() => _RedeemSheetState();
}

class _RedeemSheetState extends ConsumerState<_RedeemSheet> {
  ShopItem get item => widget.item;

  @override
  Widget build(BuildContext context) {
    final balance = ref.watch(pointBalanceProvider);

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
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: CubedColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // 상품
            Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: item.imageUrl == null
                      ? Container(color: CubedColors.bg)
                      : CachedNetworkImage(
                          imageUrl: item.imageUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              Container(color: CubedColors.bg),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.brandName,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: CubedColors.inkSoft)),
                    const SizedBox(height: 3),
                    Text(item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('${won(item.price)}원',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ]),

            const SizedBox(height: 20),

            // 포인트 사용은 아직 붙이지 않는다 — 아래 주석 참고.
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: CubedColors.bg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                const Icon(Icons.savings_rounded,
                    size: 18, color: CubedColors.inkSoft),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    balance > 0
                        ? '보유 ${won(balance)}P — 포인트 사용처는 준비 중이에요'
                        : '저당 제품을 기록하면 포인트가 쌓여요',
                    style: const TextStyle(
                        fontSize: 12.5, color: CubedColors.inkSoft),
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 8),
            // 특가와 합치면서, 브랜드몰로 바로 가는 원래 동선도 남긴다.
            SizedBox(
              width: double.infinity,
              height: 44,
              child: TextButton.icon(
                onPressed: () => _openMall(context),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: Text('${item.brandName} 공식몰에서 보기',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                style: TextButton.styleFrom(
                    foregroundColor: CubedColors.inkSoft),
              ),
            ),
            const Text(
              '결제 기능은 준비 중이에요. 지금은 포인트 차감만 됩니다.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: CubedColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMall(BuildContext context) async {
    final url = item.deal.productUrl;
    if (url.isEmpty) return;
    try {
      final ok = await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('링크를 열 수 없어요')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('링크를 열 수 없어요')));
      }
    }
  }


}


