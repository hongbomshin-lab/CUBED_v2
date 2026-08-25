import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
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
      progress[m.code] ?? const MissionProgress(periodKey: '');
}

/// 미션 화면 상태.
///
/// **판정과 적립은 전부 서버(fire_event)가 한다.** 이 클래스는
/// 이벤트를 서버에 알리고 결과를 다시 읽어 화면에 반영할 뿐이다 —
/// 진행도·연속·보상 금액 중 어느 것도 앱이 계산하지 않는다.
/// 로그인하지 않았으면 아무것도 하지 않는다(포인트는 계정에 귀속된다).
class MissionsController extends StateNotifier<MissionState> {
  MissionsController(this._ref) : super(const MissionState()) {
    _load();
  }

  final Ref _ref;
  late final MissionRepository _repo =
      MissionRepository(_ref.read(pointsRepositoryProvider));

  Future<void> _load() async {
    final missions = await _repo.load();
    state = state.copyWith(missions: missions, loading: false);
    await refresh();
  }

  /// 서버에서 진행도·연속을 다시 읽어 화면에 반영한다.
  /// 로그인하지 않았으면 빈 상태로 둔다.
  Future<void> refresh() async {
    if (_ref.read(currentUserProvider) == null) {
      state = state.copyWith(
          progress: const {}, streak: const StreakState(), loading: false);
      return;
    }
    try {
      final repo = _ref.read(pointsRepositoryProvider);
      final rows = await repo.progress();
      final st = await repo.streak();
      state = state.copyWith(
        progress: {
          for (final e in rows.entries)
            e.key: MissionProgress(
              periodKey: '',
              count: e.value.count,
              completedAt: e.value.done ? DateTime.now() : null,
            ),
        },
        streak: StreakState(
          current: st.current,
          best: st.best,
          lastDate:
              st.lastDate == null ? null : PeriodKey.day(st.lastDate!),
          startDate: null,
        ),
        loading: false,
      );
    } catch (e) {
      // 조회 실패는 화면만 비게 두고 넘어간다 — 적립은 서버가 이미 마쳤다.
      state = state.copyWith(loading: false);
    }
  }

  /// 출석. 하루 한 번만 인정된다(서버가 판정한다).
  /// 이번에 적립된 포인트 합계를 돌려준다 — 0 이면 이미 출석했거나 상한에 걸린 것.
  Future<int> checkIn() => fire(MissionTrigger.checkin);

  /// 사용자 행동을 서버에 알린다.
  ///
  /// 어떤 미션이 걸리는지, 목표·보상이 얼마인지는 서버의 missions 표가 정한다.
  /// checkin 을 뺀 트리거는 [refId] 가 필수다 — 서버가 '본인이 만든 실제 행'인지
  /// 확인하기 때문에, 근거 없이 부르면 아무 일도 일어나지 않는다.
  Future<int> fire(
    MissionTrigger trigger, [
    Map<String, String> data = const {},
    String? refId,
  ]) async {
    if (_ref.read(currentUserProvider) == null) return 0;
    var earned = 0;
    try {
      final awards = await _ref
          .read(pointsRepositoryProvider)
          .fire(trigger.code, data: data, refId: refId);
      earned = awards.fold(0, (sum, a) => sum + a.reward);
    } catch (e) {
      // 조용히 삼키면 서버 오류를 못 본다 — 실제로 fire_event 가 42702 로
      // 항상 실패하는데도 '이미 출석했어요'로만 보였다.
      debugPrint('fire_event 실패: $e');
      rethrow;
    }
    // 서버가 진행·적립을 마쳤으니 화면과 잔액을 다시 읽는다.
    await refresh();
    _ref.invalidate(serverBalanceProvider);
    _ref.invalidate(serverLedgerProvider);
    _ref.invalidate(dailyRoomProvider);
    return earned;
  }

}

final missionsProvider =
    StateNotifierProvider<MissionsController, MissionState>(
        (ref) => MissionsController(ref));
