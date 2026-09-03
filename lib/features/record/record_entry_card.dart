import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../providers/providers.dart';
import 'record_screen.dart';

/// 홈(제품분석 탭)의 '오늘 저당 기록하기' 진입 카드.
///
/// **자기완결형 위젯** — 진입 위치와 무관하게 동작하도록 만들었다.
/// 나중에 하단 탭/FAB로 옮기고 싶으면 이 위젯만 이동하면 된다
/// (기록 로직은 RecordScreen 에 있고, 이 카드는 열기만 한다).
class RecordEntryCard extends ConsumerWidget {
  const RecordEntryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loggedToday = _hasLogToday(ref);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(CubedFx.radiusCard),
        boxShadow: CubedFx.shadowCard,
      ),
      child: Material(
        color: CubedColors.surface,
        borderRadius: BorderRadius.circular(CubedFx.radiusCard),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const RecordScreen()),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: CubedColors.brand.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.add_task_rounded,
                      color: CubedColors.brand, size: 23),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('오늘 저당 기록하기',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              letterSpacing: -0.2)),
                      const SizedBox(height: 3),
                      Text(
                        loggedToday
                            ? '잘하고 있어요 — 내일도 이어가요'
                            : '먹은 저당 제품을 남기고 포인트 받기',
                        style: const TextStyle(
                            color: CubedColors.inkSoft, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusPill(done: loggedToday),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 오늘 기록이 하나라도 있는지 — 이번 달 기록에서 오늘 날짜만 본다.
  /// (monthLogsProvider 는 달력에서도 쓰여 캐시된다)
  bool _hasLogToday(WidgetRef ref) {
    final now = DateTime.now();
    final logs = ref
        .watch(monthLogsProvider((year: now.year, month: now.month)))
        .valueOrNull;
    if (logs == null) return false;
    return logs.any((l) =>
        l.eatenOn.year == now.year &&
        l.eatenOn.month == now.month &&
        l.eatenOn.day == now.day);
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.done});
  final bool done;

  @override
  Widget build(BuildContext context) {
    if (done) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: CubedColors.brand.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.check_rounded, size: 14, color: CubedColors.brandDeep),
          SizedBox(width: 3),
          Text('완료',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: CubedColors.brandDeep)),
        ]),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: CubedColors.ink,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text('기록하기',
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
    );
  }
}
