import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import 'point_card.dart' show won;
import 'point_models.dart';
import 'points_controller.dart';

/// 포인트 적립·사용 내역 — 원장을 그대로 보여준다.
/// 포인트는 돈이라 사용자가 '언제 왜 얼마'를 대조할 수 있어야 한다.
class PointsHistoryScreen extends ConsumerWidget {
  const PointsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(pointLedgerProvider);
    final balance = ref.watch(pointBalanceProvider);

    return Scaffold(
      backgroundColor: CubedColors.bg,
      appBar: AppBar(title: const Text('포인트 내역')),
      body: Column(
        children: [
          // 현재 잔액
          Container(
            width: double.infinity,
            color: CubedColors.surface,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('사용 가능',
                    style:
                        TextStyle(fontSize: 12, color: CubedColors.inkSoft)),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(won(balance),
                        style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            height: 1)),
                    const SizedBox(width: 3),
                    const Text('P',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: CubedColors.brand)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? const Center(
                    child: Text('아직 내역이 없어요',
                        style: TextStyle(color: CubedColors.inkSoft)),
                  )
                : ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: CubedColors.line),
                    itemBuilder: (_, i) => _EntryTile(entry: entries[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});
  final PointEntry entry;

  @override
  Widget build(BuildContext context) {
    final earn = entry.isEarn;
    final color = earn ? CubedColors.brand : CubedColors.inkSoft;

    return Container(
      color: CubedColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              earn ? Icons.add_rounded : Icons.shopping_bag_rounded,
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.subject ?? entry.reason.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('${entry.reason.label} · ${_when(entry.at)}',
                    style: const TextStyle(
                        fontSize: 12, color: CubedColors.inkSoft)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${earn ? '+' : '−'}${won(entry.delta.abs())}P',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }

  static String _when(DateTime at) {
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 1) return '방금';
    if (d.inHours < 1) return '${d.inMinutes}분 전';
    if (d.inDays < 1) return '${d.inHours}시간 전';
    if (d.inDays < 7) return '${d.inDays}일 전';
    return '${at.month}월 ${at.day}일';
  }
}
