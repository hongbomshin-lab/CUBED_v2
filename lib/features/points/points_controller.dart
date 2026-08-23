import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'point_models.dart';

/// 포인트 잔액 + 원장.
///
/// ⚠️ 지금은 메모리 위의 **가짜 데이터**다. 앱을 끄면 초기화된다.
/// 실제로는 서버 원장(append-only)에서 읽고, 적립·차감은
/// security definer RPC 로만 일어나야 한다 — 포인트는 돈이라
/// 클라이언트가 잔액을 쓸 수 있으면 안 된다.
class PointsController extends StateNotifier<List<PointEntry>> {
  PointsController() : super(_seed());

  /// 화면을 비어 보이지 않게 하려는 예시 적립 내역.
  static List<PointEntry> _seed() {
    final now = DateTime.now();
    PointEntry e(int daysAgo, int delta, PointReason r, String? subject) =>
        PointEntry(
          id: 'seed-$daysAgo-${r.name}',
          at: now.subtract(Duration(days: daysAgo, hours: daysAgo * 3)),
          delta: delta,
          reason: r,
          subject: subject,
        );
    return [
      e(0, 30, PointReason.lowSugarLog, '라라스윗 초코 아이스크림'),
      e(1, 30, PointReason.lowSugarLog, '널담 고단백 통밀스콘'),
      e(1, 10, PointReason.midSugarLog, '제로콜라'),
      e(2, 30, PointReason.mission, '3일 연속 출석'),
      e(3, 30, PointReason.lowSugarLog, '마이노멀 저당 케찹'),
      e(4, 30, PointReason.lowSugarLog, '널담 저당 쫀득빵'),
      e(6, 10, PointReason.midSugarLog, '아메리카노'),
    ];
  }

  int get balance => state.fold(0, (sum, e) => sum + e.delta);

  /// 최근 7일 적립분 (사용분 제외).
  int get earnedThisWeek {
    final from = DateTime.now().subtract(const Duration(days: 7));
    return state
        .where((e) => e.isEarn && e.at.isAfter(from))
        .fold(0, (sum, e) => sum + e.delta);
  }

  /// 먹은 기록 적립. 등급에 따라 금액이 정해진다.
  /// 적립이 0이면(주의 등급) 원장에 남기지 않는다.
  int earnForLog({required String? grade, required String productName}) {
    final amount = PointPolicy.earnFor(grade);
    if (amount <= 0) return 0;
    _add(
      delta: amount,
      reason: grade == 'low' ? PointReason.lowSugarLog : PointReason.midSugarLog,
      subject: productName,
    );
    return amount;
  }

  /// 미션 달성 적립. 금액은 미션 정의가 정한다(앱이 계산하지 않는다).
  void earnMission({required int amount, required String missionTitle}) {
    if (amount <= 0) return;
    _add(delta: amount, reason: PointReason.mission, subject: missionTitle);
  }

  /// 상품 구매에 포인트 사용. 잔액을 넘으면 아무것도 하지 않는다.
  bool spend({required int amount, required String productName}) {
    if (amount <= 0 || amount > balance) return false;
    _add(delta: -amount, reason: PointReason.redeem, subject: productName);
    return true;
  }

  void _add({
    required int delta,
    required PointReason reason,
    String? subject,
  }) {
    state = [
      PointEntry(
        id: 'e${DateTime.now().microsecondsSinceEpoch}',
        at: DateTime.now(),
        delta: delta,
        reason: reason,
        subject: subject,
      ),
      ...state,
    ];
  }
}

/// 원장 (최신순).
final pointLedgerProvider =
    StateNotifierProvider<PointsController, List<PointEntry>>(
        (ref) => PointsController());

/// 현재 잔액. 원장의 합이라 따로 저장하지 않는다.
final pointBalanceProvider = Provider<int>((ref) {
  final entries = ref.watch(pointLedgerProvider);
  return entries.fold(0, (sum, e) => sum + e.delta);
});

/// 최근 7일 적립분 (마이페이지 카드용).
final pointWeeklyEarnProvider = Provider<int>((ref) {
  final entries = ref.watch(pointLedgerProvider);
  final from = DateTime.now().subtract(const Duration(days: 7));
  return entries
      .where((e) => e.isEarn && e.at.isAfter(from))
      .fold(0, (sum, e) => sum + e.delta);
});
