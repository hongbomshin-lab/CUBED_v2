import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import 'points_controller.dart';
import 'points_history_screen.dart';

/// 천 단위 콤마.
String won(int v) => v.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

/// 마이페이지 상단 포인트 카드 — 잔액 + 이번 주 적립 + 내역 진입.
class PointCard extends ConsumerWidget {
  const PointCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(pointBalanceProvider);
    final weekly = ref.watch(pointWeeklyEarnProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Material(
        color: CubedColors.ink,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PointsHistoryScreen()),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.savings_rounded,
                            size: 16, color: CubedColors.lime),
                        const SizedBox(width: 6),
                        Text('내 포인트',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: 0.7))),
                      ]),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            won(balance),
                            style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                height: 1,
                                color: Colors.white),
                          ),
                          const SizedBox(width: 3),
                          const Text('P',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: CubedColors.lime)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        weekly > 0
                            ? '이번 주 +${won(weekly)}P 모았어요'
                            : '저당 제품을 기록하면 포인트가 쌓여요',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: Colors.white.withValues(alpha: 0.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
