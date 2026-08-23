import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../points/points_controller.dart';
import 'mission_models.dart';
import 'mission_repository.dart';

/// 미션 진행 상태 전체.
class MissionState {
  final List<Mission> missions;

  /// 미션코드 → 현재 기간의 진행.
  final Map<String, MissionProgress> progress;
  final StreakState streak;
  final bool loading;

  const MissionState({
    this.missions = const [],
    this.progress = const {},
    this.streak = const StreakState(),
    this.loading = true,
  });

  MissionState copyWith({
    List<Mission>? missions,
    Map<String, MissionProgress>? progress,
    StreakState? streak,
    bool? loading,
  }) =>
      MissionState(
        missions: missions ?? this.missions,
        progress: progress ?? this.progress,
        streak: streak ?? this.streak,
        loading: loading ?? this.loading,
      );

  /// 오늘 출석했는지 — 출석 도장판·버튼 상태에 쓴다.
  bool get checkedInToday =>
      streak.lastDate == PeriodKey.day(DateTime.now());

  MissionProgress progressOf(Mission m) =>
      progress[m.code] ?? MissionProgress(periodKey: '');
}

/// 미션 엔진.
///
/// 앱은 [fire] 로 "무슨 일이 일어났다"만 알린다. 어떤 미션이 걸리는지,
/// 목표가 몇이고 보상이 얼마인지는 미션 정의(데이터)가 정한다 —
/// 그래서 미션을 추가해도 이 코드는 바뀌지 않는다.
///
/// ⚠️ 진행도는 지금 **메모리 위의 가짜**다. 앱을 끄면 초기화된다.
/// 실제로는 서버가 미션 정의를 읽어 진행도를 갱신하고 적립해야 한다 —
/// 포인트 금액이 앱에 있으면 조작할 수 있다.
class MissionsController extends StateNotifier<MissionState> {
  MissionsController(this._ref) : super(const MissionState()) {
    _load();
  }

  final Ref _ref;
  static const _repo = MissionRepository();

  Future<void> _load() async {
    final missions = await _repo.load();
    state = state.copyWith(missions: missions, loading: false);
  }

  /// 출석. 하루 한 번만 인정된다(같은 날 다시 눌러도 아무 일 없음).
  /// 적립된 포인트 총합을 돌려준다 — 0이면 이미 출석한 것.
  int checkIn() => fire(MissionTrigger.checkin);

  /// 사용자 행동 발생. 해당 트리거·조건에 걸리는 미션들의 진행을 올린다.
  /// 이번에 새로 달성된 미션들의 보상 합계를 돌려준다.
  int fire(MissionTrigger trigger, [Map<String, String> data = const {}]) {
    final now = DateTime.now();
    final today = PeriodKey.day(now);

    // 출석 성격의 트리거는 연속 상태를 먼저 갱신한다.
    var streak = state.streak;
    if (trigger == MissionTrigger.checkin) {
      if (streak.lastDate == today) return 0; // 오늘 이미 처리됨
      final yesterday =
          PeriodKey.day(now.subtract(const Duration(days: 1)));
      final continues = streak.lastDate == yesterday;
      final current = continues ? streak.current + 1 : 1;
      streak = StreakState(
        current: current,
        best: current > streak.best ? current : streak.best,
        lastDate: today,
        startDate: continues ? (streak.startDate ?? today) : today,
      );
    }

    final progress = Map<String, MissionProgress>.from(state.progress);
    var earned = 0;

    for (final m in state.missions) {
      if (!m.accepts(trigger, data)) continue;

      final key = _periodKey(m, now, streak);
      var p = progress[m.code];
      // 기간이 바뀌었으면 진행을 새로 시작한다 (매일·매주 초기화, 연속 재시작).
      if (p == null || p.periodKey != key) {
        p = MissionProgress(periodKey: key);
      }
      if (p.done) continue; // 이 기간엔 이미 받았다

      // 연속 미션은 '누적 횟수'가 아니라 현재 연속 일수가 곧 진행도다.
      final count =
          m.period == MissionPeriod.streak ? streak.current : p.count + 1;

      if (count >= m.target) {
        p = p.copyWith(count: count, completedAt: now);
        earned += m.reward;
        _ref.read(pointLedgerProvider.notifier).earnMission(
              amount: m.reward,
              missionTitle: m.title,
            );
      } else {
        p = p.copyWith(count: count);
      }
      progress[m.code] = p;
    }

    state = state.copyWith(progress: progress, streak: streak);
    return earned;
  }

  /// 미션의 진행을 어느 단위로 묶을지.
  /// streak 는 '연속이 시작된 날'을 키로 써서, 끊겼다 다시 이어지면
  /// 새 키가 되어 보상을 다시 받을 수 있다.
  String _periodKey(Mission m, DateTime now, StreakState streak) =>
      switch (m.period) {
        MissionPeriod.once => '',
        MissionPeriod.daily => PeriodKey.day(now),
        MissionPeriod.weekly => PeriodKey.week(now),
        MissionPeriod.streak => streak.startDate ?? PeriodKey.day(now),
      };
}

final missionsProvider =
    StateNotifierProvider<MissionsController, MissionState>(
        (ref) => MissionsController(ref));
