import 'package:flutter/material.dart';

/// 미션을 발동시키는 사용자 행동.
///
/// **이 목록만 코드에 있다.** 어떤 미션이 걸려 있고 얼마를 주는지는 데이터다 —
/// 앱은 "무슨 일이 일어났다"만 알리고, 조건·목표·보상은 미션 정의가 정한다.
enum MissionTrigger {
  checkin('checkin'),
  productLog('product_log'),
  storeReview('store_review'),
  storeFavorite('store_favorite'),
  menuBoardReport('menu_board_report'),
  storeReport('store_report'),
  productComment('product_comment');

  const MissionTrigger(this.code);
  final String code;

  static MissionTrigger? fromCode(String? c) {
    for (final t in values) {
      if (t.code == c) return t;
    }
    return null;
  }
}

/// 진행도를 언제 초기화할지.
enum MissionPeriod {
  once('once'), // 평생 1회
  daily('daily'), // 매일 0시
  weekly('weekly'), // 매주
  streak('streak'); // 끊기면 초기화 (연속)

  const MissionPeriod(this.code);
  final String code;

  static MissionPeriod fromCode(String? c) {
    for (final p in values) {
      if (p.code == c) return p;
    }
    return MissionPeriod.once;
  }
}

/// 미션 한 줄. 앱이 만들지 않고 읽어 온다(지금은 에셋, 나중엔 DB).
class Mission {
  final String code;
  final String title;
  final String description;
  final String icon;
  final MissionTrigger trigger;

  /// 이벤트에 딸려온 값과 대조할 조건. 비어 있으면 무조건 통과.
  /// 예) {'grade': 'low'} → 저당 등급 기록만 인정.
  final Map<String, String> condition;

  final MissionPeriod period;
  final int target;
  final int reward;
  final int sort;
  final bool active;

  const Mission({
    required this.code,
    required this.title,
    required this.description,
    required this.icon,
    required this.trigger,
    required this.condition,
    required this.period,
    required this.target,
    required this.reward,
    required this.sort,
    required this.active,
  });

  /// 이 이벤트가 미션 조건을 만족하는지.
  bool accepts(MissionTrigger t, Map<String, String> data) {
    if (t != trigger) return false;
    for (final e in condition.entries) {
      if (data[e.key] != e.value) return false;
    }
    return true;
  }

  factory Mission.fromMap(Map<String, dynamic> m) => Mission(
        code: m['code'] as String,
        title: m['title'] as String,
        description: (m['description'] as String?) ?? '',
        icon: (m['icon'] as String?) ?? 'flag',
        trigger:
            MissionTrigger.fromCode(m['trigger'] as String?) ??
                MissionTrigger.checkin,
        condition: ((m['condition'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k.toString(), v.toString())),
        period: MissionPeriod.fromCode(m['period'] as String?),
        // 정의(데이터)가 잘못 들어와도 앱이 손해 보지 않도록 여기서 막는다.
        // target 0 이면 이벤트마다 즉시 달성되고, reward 음수면 잔액이 깎인다.
        target: _atLeast(1, (m['target'] as num?)?.toInt()),
        reward: _atLeast(0, (m['reward'] as num?)?.toInt()),
        sort: (m['sort'] as num?)?.toInt() ?? 0,
        active: (m['active'] as bool?) ?? true,
      );

  /// 아이콘 이름 → 위젯. 정의가 데이터라 이름으로 들어온다.
  IconData get iconData => switch (icon) {
        'event_available' => Icons.event_available_rounded,
        'local_fire_department' => Icons.local_fire_department_rounded,
        'workspace_premium' => Icons.workspace_premium_rounded,
        'restaurant' => Icons.restaurant_rounded,
        'rate_review' => Icons.rate_review_rounded,
        'favorite' => Icons.favorite_rounded,
        'photo_camera' => Icons.photo_camera_rounded,
        _ => Icons.flag_rounded,
      };
}

int _atLeast(int floor, int? v) => (v == null || v < floor) ? floor : v;

/// 미션 진행 상황 (사용자 × 미션 × 기간).
class MissionProgress {
  /// 어느 기간의 진행인지. daily='2026-08-23', weekly='2026-W34',
  /// once='', streak=연속이 시작된 날짜.
  /// **같은 키에 이미 달성 기록이 있으면 두 번 주지 않는다** — 중복 적립 방어.
  final String periodKey;
  final int count;
  final DateTime? completedAt;

  const MissionProgress({
    required this.periodKey,
    this.count = 0,
    this.completedAt,
  });

  bool get done => completedAt != null;

  MissionProgress copyWith({int? count, DateTime? completedAt}) =>
      MissionProgress(
        periodKey: periodKey,
        count: count ?? this.count,
        completedAt: completedAt ?? this.completedAt,
      );
}

/// 연속 기록 상태. 진행 횟수로는 표현이 안 돼(어제 했는지를 봐야 한다) 따로 둔다.
class StreakState {
  final int current;
  final int best;

  /// 마지막으로 인정된 날 (yyyy-MM-dd).
  final String? lastDate;

  /// 지금 연속이 시작된 날 — streak 미션의 기간키로 쓴다.
  /// 연속이 끊겨 새로 시작하면 키가 바뀌어 다시 받을 수 있다.
  final String? startDate;

  const StreakState({
    this.current = 0,
    this.best = 0,
    this.lastDate,
    this.startDate,
  });
}

/// 날짜 키 헬퍼.
class PeriodKey {
  PeriodKey._();

  static String day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// ISO 주차 (2026-W34). 주간 미션의 기간키.
  static String week(DateTime d) {
    final thursday = d.add(Duration(days: 4 - (d.weekday == 7 ? 7 : d.weekday)));
    final firstDay = DateTime(thursday.year, 1, 1);
    final week = ((thursday.difference(firstDay).inDays) / 7).floor() + 1;
    return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
  }
}
