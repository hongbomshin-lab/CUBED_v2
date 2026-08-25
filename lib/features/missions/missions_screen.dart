import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../auth/login_screen.dart';
import '../points/point_card.dart' show won;
import 'mission_models.dart';
import '../../providers/providers.dart';
import 'missions_controller.dart';

/// 미션 화면 — 출석 도장판 + 미션 목록.
/// 목록은 미션 정의(데이터)를 그대로 그린다. 미션이 늘어도 이 화면은 안 바뀐다.
class MissionsScreen extends ConsumerWidget {
  const MissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(missionsProvider);

    return Scaffold(
      backgroundColor: CubedColors.bg,
      appBar: AppBar(title: const Text('미션')),
      body: st.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 28),
              children: [
                const AttendanceCard(),
                const SizedBox(height: 8),
                _Group(
                  label: '오늘의 미션',
                  missions: st.missions
                      .where((m) => m.period == MissionPeriod.daily)
                      .toList(),
                ),
                _Group(
                  label: '연속 도전',
                  missions: st.missions
                      .where((m) => m.period == MissionPeriod.streak)
                      .toList(),
                ),
                _Group(
                  label: '주간 미션',
                  missions: st.missions
                      .where((m) => m.period == MissionPeriod.weekly)
                      .toList(),
                ),
                _Group(
                  label: '도전 과제',
                  missions: st.missions
                      .where((m) => m.period == MissionPeriod.once)
                      .toList(),
                ),
              ],
            ),
    );
  }
}

class _Group extends ConsumerWidget {
  const _Group({required this.label, required this.missions});
  final String label;
  final List<Mission> missions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (missions.isEmpty) return const SizedBox.shrink();
    final st = ref.watch(missionsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(label,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        ),
        for (final m in missions)
          _MissionTile(
            mission: m,
            progress: st.progressOf(m),
            streak: st.streak,
          ),
      ],
    );
  }
}

class _MissionTile extends StatelessWidget {
  const _MissionTile({
    required this.mission,
    required this.progress,
    required this.streak,
  });
  final Mission mission;
  final MissionProgress progress;
  final StreakState streak;

  @override
  Widget build(BuildContext context) {
    // 연속 미션은 현재 연속 일수가 곧 진행도다.
    final count = mission.period == MissionPeriod.streak
        ? streak.current
        : progress.count;
    final done = progress.done;
    final ratio = (count / mission.target).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: CubedColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: (done ? CubedColors.brand : CubedColors.inkSoft)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              done ? Icons.check_rounded : mission.iconData,
              size: 20,
              color: done ? CubedColors.brand : CubedColors.inkSoft,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mission.title,
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w800)),
                if (mission.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(mission.description,
                      style: const TextStyle(
                          fontSize: 12, color: CubedColors.inkSoft)),
                ],
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 6,
                        backgroundColor: CubedColors.line,
                        valueColor: AlwaysStoppedAnimation(
                            done ? CubedColors.brand : CubedColors.brand),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('$count/${mission.target}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: CubedColors.inkSoft)),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            done ? '완료' : '+${won(mission.reward)}P',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: done ? CubedColors.inkSoft : CubedColors.brand,
            ),
          ),
        ],
      ),
    );
  }
}

/// 출석 도장판 — 7칸 + 연속 일수 + 출석 버튼.
class AttendanceCard extends ConsumerWidget {
  const AttendanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(missionsProvider);
    final streak = st.streak;
    final checked = st.checkedInToday;

    // 도장판은 이번 연속의 마지막 7일을 보여준다.
    final filled = streak.current % 7 == 0 && streak.current > 0
        ? 7
        : streak.current % 7;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: CubedColors.ink,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.local_fire_department_rounded,
                size: 18, color: CubedColors.lime),
            const SizedBox(width: 6),
            Text('연속 ${streak.current}일',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
            const Spacer(),
            if (streak.best > 0)
              Text('최고 ${streak.best}일',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.5))),
          ]),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var i = 0; i < 7; i++) ...[
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: i < filled
                            ? CubedColors.lime
                            : Colors.white.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: i < filled
                          ? const Icon(Icons.check_rounded,
                              size: 16, color: CubedColors.ink)
                          : Text('${i + 1}',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white
                                      .withValues(alpha: 0.35))),
                    ),
                  ),
                ),
                if (i < 6) const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor:
                    checked ? Colors.white.withValues(alpha: 0.12) : CubedColors.lime,
                foregroundColor: checked ? Colors.white70 : CubedColors.ink,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13)),
              ),
              onPressed: checked ? null : () => _onCheckIn(context, ref),
              child: Text(
                checked ? '오늘 출석 완료' : '출석체크하고 포인트 받기',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onCheckIn(BuildContext context, WidgetRef ref) async {
    // 로그인해야 계정에 쌓인다. 비로그인이면 로그인 화면으로 보낸다.
    if (ref.read(currentUserProvider) == null) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }
    final earned = await ref.read(missionsProvider.notifier).checkIn();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(earned > 0 ? '출석 완료 · +${won(earned)}P' : '오늘은 이미 출석했어요'),
      duration: const Duration(seconds: 2),
    ));
  }
}
