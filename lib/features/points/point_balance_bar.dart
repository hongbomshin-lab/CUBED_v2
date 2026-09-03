import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../missions/missions_screen.dart';
import 'point_card.dart' show won;
import 'points_controller.dart';

/// 특가 목록 위의 포인트 잔액 바.
///
/// 상품 바로 위에 둬야 '이만큼 깎인다'가 읽힌다.
/// 잔액이 부족할 때 '어디서 더 모으지'로 이어지도록 미션으로 보낸다.
class PointBalanceBar extends ConsumerWidget {
  const PointBalanceBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(pointBalanceProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: CubedColors.ink,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MissionsScreen()),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              const Icon(Icons.savings_rounded,
                  size: 16, color: CubedColors.lime),
              const SizedBox(width: 8),
              Text('내 포인트',
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
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: CubedColors.lime,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('모으기',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: CubedColors.ink)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
