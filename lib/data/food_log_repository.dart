import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/food_log.dart';

/// 먹은 기록 데이터 접근. 카카오 로그인(auth.uid()) 기반 소유권 (RLS own-rows).
class FoodLogRepository {
  FoodLogRepository(this._db);
  final SupabaseClient _db;

  String? get _uid => _db.auth.currentUser?.id;

  /// 하루치 기록 (오늘 토글 상태 판정용)
  Future<List<FoodLog>> logsForDay(DateTime day) async {
    final uid = _uid;
    if (uid == null) return const [];
    final rows = await _db
        .from('product_logs')
        .select()
        .eq('user_id', uid)
        .eq('eaten_on', FoodLog.dateKey(day))
        .order('created_at');
    return rows.map((m) => FoodLog.fromMap(m)).toList();
  }

  /// 한 달치 기록 (달력 마커 + 일별 리스트 공용)
  Future<List<FoodLog>> logsForMonth(DateTime month) async {
    final uid = _uid;
    if (uid == null) return const [];
    final first = DateTime(month.year, month.month, 1);
    final next = DateTime(month.year, month.month + 1, 1);
    final rows = await _db
        .from('product_logs')
        .select()
        .eq('user_id', uid)
        .gte('eaten_on', FoodLog.dateKey(first))
        .lt('eaten_on', FoodLog.dateKey(next))
        .order('eaten_on');
    return rows.map((m) => FoodLog.fromMap(m)).toList();
  }

  /// 오늘 이 제품의 기록 (없으면 null) — 결과 화면 버튼 상태
  Future<FoodLog?> todayLogFor({String? productId, required String name}) async {
    final today = await logsForDay(DateTime.now());
    for (final log in today) {
      if (log.matches(productId: productId, name: name)) return log;
    }
    return null;
  }

  /// 누적 포인트 (아낀 설탕 g 합계). 비로그인 0.
  Future<int> totalPoints() async {
    final uid = _uid;
    if (uid == null) return 0;
    // ponytail: 전 행 fetch 후 클라 합산 — 행이 수만 건 규모가 되면 RPC 집계로 교체
    final rows =
        await _db.from('product_logs').select('points').eq('user_id', uid);
    return rows.fold<int>(0, (sum, r) => sum + ((r['points'] as num?) ?? 0).toInt());
  }

  /// '오늘 이거 먹었어요' 토글 → 기록됐으면 true, 해제됐으면 false
  /// 오늘 기록 토글. 추가되면 새 기록의 id, 취소되면 null.
  /// (id 가 필요한 이유: 서버 적립 RPC 가 '어느 기록으로 적립할지'를 받는다)
  Future<String?> toggleToday({
    String? productId,
    required String name,
    String? brand,
    String? category,
    String? grade,
    String? imagePath,
    int points = 0,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('로그인이 필요해요');
    final existing = await todayLogFor(productId: productId, name: name);
    if (existing != null) {
      await _db.from('product_logs').delete().eq('id', existing.id);
      return null;
    }
    final row = await _db.from('product_logs').insert(FoodLog.insertMap(
          userId: uid,
          eatenOn: DateTime.now(),
          productId: productId,
          name: name,
          brand: brand,
          category: category,
          grade: grade,
          imagePath: imagePath,
          points: points,
        )).select('id').single();
    return row['id'] as String;
  }

  Future<void> removeLog(String id) async {
    await _db.from('product_logs').delete().eq('id', id);
  }
}
