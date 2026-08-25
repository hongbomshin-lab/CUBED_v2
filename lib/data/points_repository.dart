import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/points/point_models.dart';

/// 포인트·미션 서버 접근.
///
/// 적립 금액은 서버가 정한다 — 앱은 '무슨 일이 일어났다'만 알린다.
/// 그래서 이 클래스에는 금액을 계산하는 코드가 없다.
class PointsRepository {
  PointsRepository(this._db);
  final SupabaseClient _db;

  /// 현재 잔액. 원장의 합이라 서버에서 구한다.
  Future<int> balance() async {
    final v = await _db.rpc('my_point_balance');
    return (v as num?)?.toInt() ?? 0;
  }

  /// 오늘 더 적립할 수 있는 여유분 (일일 상한 − 오늘 적립분).
  Future<int> dailyRoom() async {
    final v = await _db.rpc('daily_earn_room');
    return (v as num?)?.toInt() ?? 0;
  }

  /// 적립·사용 내역 (최신순).
  Future<List<PointEntry>> ledger({int limit = 100}) async {
    final rows = await _db
        .from('point_ledger')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(_toEntry).toList();
  }

  /// 먹은 기록으로 적립 요청. 금액은 넘기지 않는다 — 서버가 정한다.
  /// 실제 적립된 포인트를 돌려준다(상한에 걸리면 잘린 값, 중복이면 0).
  Future<int> earnForLog(String logId) async {
    final v = await _db.rpc('earn_sugar_saved', params: {'p_log_id': logId});
    return (v as num?)?.toInt() ?? 0;
  }

  /// 사용자 행동 알림. 걸리는 미션이 있으면 서버가 진행·적립하고
  /// 이번에 달성된 미션 목록을 돌려준다.
  Future<List<MissionAward>> fire(
    String trigger, {
    Map<String, String> data = const {},
    String? refId,
  }) async {
    final rows = await _db.rpc('fire_event', params: {
      'p_trigger': trigger,
      'p_data': data,
      if (refId != null) 'p_ref_id': refId,
    });
    return ((rows as List?) ?? const [])
        .map((r) => MissionAward(
              // 반환 컬럼은 out_ 접두어를 쓴다 — 함수 안에서 테이블 컬럼명과
              // 겹치면 PL/pgSQL 이 42702(ambiguous)로 실패하기 때문이다.
              code: r['out_mission_code'] as String,
              title: r['out_title'] as String,
              reward: (r['out_reward'] as num).toInt(),
            ))
        .toList();
  }

  /// 포인트 사용. 잔액이 모자라면 서버가 예외를 던진다.
  Future<int> spend({
    required int amount,
    required String subject,
    String? refId,
  }) async {
    final v = await _db.rpc('spend_points', params: {
      'p_amount': amount,
      'p_subject': subject,
      if (refId != null) 'p_ref_id': refId,
    });
    return (v as num?)?.toInt() ?? 0;
  }

  /// 미션 정의 (서버가 원본). 비활성·기간 지난 미션은 빼고 받는다.
  Future<List<Map<String, dynamic>>> missions() async {
    final now = DateTime.now().toIso8601String();
    final rows = await _db
        .from('missions')
        .select()
        .eq('is_active', true)
        .or('starts_at.is.null,starts_at.lte.$now')
        .or('ends_at.is.null,ends_at.gte.$now')
        .order('sort_order');
    return rows.cast<Map<String, dynamic>>();
  }

  /// 미션 진행 상황 (mission_code → count/완료여부).
  Future<Map<String, ({int count, bool done})>> progress() async {
    final rows = await _db
        .from('mission_progress')
        .select('mission_code, count, completed_at');
    return {
      for (final r in rows)
        r['mission_code'] as String: (
          count: (r['count'] as num?)?.toInt() ?? 0,
          done: r['completed_at'] != null,
        ),
    };
  }

  /// 출석 연속 상태.
  Future<({int current, int best, DateTime? lastDate})> streak() async {
    final row = await _db
        .from('user_streaks')
        .select()
        .eq('kind', 'checkin')
        .maybeSingle();
    if (row == null) return (current: 0, best: 0, lastDate: null);
    final last = row['last_date'] as String?;
    return (
      current: (row['current'] as num?)?.toInt() ?? 0,
      best: (row['best'] as num?)?.toInt() ?? 0,
      lastDate: last == null ? null : DateTime.parse(last),
    );
  }

  static PointEntry _toEntry(Map<String, dynamic> m) => PointEntry(
        id: m['id'] as String,
        at: DateTime.parse(m['created_at'] as String).toLocal(),
        delta: (m['delta'] as num).toInt(),
        reason: switch (m['reason'] as String?) {
          'sugar_saved' => PointReason.sugarSaved,
          'mission' => PointReason.mission,
          'redeem' => PointReason.redeem,
          _ => PointReason.sugarSaved,
        },
        subject: m['subject'] as String?,
      );
}

/// 이번에 달성된 미션 (서버가 알려준다).
class MissionAward {
  final String code;
  final String title;
  final int reward;
  const MissionAward({
    required this.code,
    required this.title,
    required this.reward,
  });
}
