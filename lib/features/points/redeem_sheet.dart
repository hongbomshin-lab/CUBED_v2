import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  /// 이번 주문에 쓸 포인트. 기본은 쓸 수 있는 만큼 다 쓴다.
  int? _use;

  ShopItem get item => widget.item;

  @override
  Widget build(BuildContext context) {
    final balance = ref.watch(pointBalanceProvider);
    final maxUse = item.maxUsablePoints(balance);
    final use = (_use ?? maxUse).clamp(0, maxUse);
    final pay = item.price - use * PointPolicy.wonPerPoint;

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
            const Divider(color: CubedColors.line),
            const SizedBox(height: 12),

            // 포인트 사용
            Row(children: [
              const Text('포인트 사용',
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              const Spacer(),
              Text('보유 ${won(balance)}P',
                  style: const TextStyle(
                      fontSize: 12, color: CubedColors.inkSoft)),
            ]),
            const SizedBox(height: 6),
            if (maxUse == 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text('사용할 수 있는 포인트가 없어요',
                    style:
                        TextStyle(fontSize: 13, color: CubedColors.inkSoft)),
              )
            else ...[
              Row(children: [
                Expanded(
                  child: Slider(
                    value: use.toDouble(),
                    max: maxUse.toDouble(),
                    divisions: maxUse < 20 ? maxUse : 20,
                    activeColor: CubedColors.brand,
                    onChanged: (v) => setState(() => _use = v.round()),
                  ),
                ),
                SizedBox(
                  width: 76,
                  child: Text('−${won(use)}P',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: CubedColors.brand)),
                ),
              ]),
              // 전액 포인트 결제는 막아 둔다 — 적립 로직이 확정되기 전 안전장치.
              Text(
                '주문 금액의 ${(PointPolicy.maxUseRatio * 100).round()}%까지 쓸 수 있어요',
                style:
                    const TextStyle(fontSize: 11, color: CubedColors.inkSoft),
              ),
            ],

            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CubedColors.bg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(children: [
                _Line(label: '상품 금액', value: '${won(item.price)}원'),
                const SizedBox(height: 8),
                _Line(
                  label: '포인트 사용',
                  value: '−${won(use * PointPolicy.wonPerPoint)}원',
                  highlight: true,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1, color: CubedColors.line),
                ),
                Row(children: [
                  const Text('결제 금액',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Text('${won(pay)}원',
                      style: const TextStyle(
                          fontSize: 19, fontWeight: FontWeight.w900)),
                ]),
              ]),
            ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: CubedColors.brand,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => _onPay(use, pay),
                child: Text('${won(pay)}원 결제하기',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 10),
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

  Future<void> _onPay(int use, int pay) async {
    final method = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: CubedColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _PayMethodSheet(),
    );
    if (method == null || !mounted) return;

    if (use > 0) {
      ref
          .read(pointLedgerProvider.notifier)
          .spend(amount: use, productName: item.name);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(use > 0
            ? '$method 결제 준비 완료 · 포인트 ${won(use)}P 사용'
            : '$method 결제 준비 완료'),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
    this.highlight = false,
  });
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Row(children: [
        Text(label,
            style: const TextStyle(fontSize: 13, color: CubedColors.inkSoft)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: highlight ? CubedColors.brand : CubedColors.ink)),
      ]);
}

/// 결제수단 선택 — 실물 상품이라 외부 PG 를 쓸 수 있다(인앱결제 의무 아님).
class _PayMethodSheet extends StatelessWidget {
  const _PayMethodSheet();

  @override
  Widget build(BuildContext context) {
    const methods = [
      ('카카오페이', Icons.chat_bubble_rounded, Color(0xFFFEE500)),
      ('토스페이', Icons.bolt_rounded, Color(0xFF3182F6)),
      ('신용·체크카드', Icons.credit_card_rounded, CubedColors.inkSoft),
    ];
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: CubedColors.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),
          const Text('결제수단 선택',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          for (final (label, icon, color) in methods)
            ListTile(
              leading: Icon(icon, color: color),
              title: Text(label,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: CubedColors.inkSoft),
              onTap: () => Navigator.of(context).pop(label),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
