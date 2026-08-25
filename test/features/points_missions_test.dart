import 'package:flutter_test/flutter_test.dart';

import 'package:cubed_app/core/sugar_baselines.dart';
import 'package:cubed_app/features/missions/mission_models.dart';
import 'package:cubed_app/features/points/point_models.dart';

/// 포인트·미션 코너 케이스.
///
/// 돈이 걸린 로직이라 '정상 경로'보다 경계와 악용 경로를 먼저 본다.
void main() {
  // ── 적립 금액: sugarPointsFor 가 유일한 출처 ──────────────────
  group('적립 금액 (아낀 설탕)', () {
    test('기준값보다 당류가 적으면 그 차이만큼', () {
      // 탄산음료 기준 27g, 제로콜라 0g → 27P
      expect(
        sugarPointsFor(category: '탄산음료', name: '제로콜라', sugar: 0),
        27,
      );
    });

    test('당류가 기준값과 같으면 0 — 아낀 게 없다', () {
      expect(sugarPointsFor(category: '탄산음료', name: '콜라', sugar: 27), 0);
    });

    test('당류가 기준값보다 많으면 음수가 아니라 0', () {
      expect(sugarPointsFor(category: '탄산음료', name: '콜라', sugar: 40), 0);
    });

    test('모르는 카테고리는 0 — 기준이 없으면 적립하지 않는다', () {
      expect(sugarPointsFor(category: '해장국', name: '뼈해장국', sugar: 0), 0);
    });

    test('카테고리가 null 이면 0', () {
      expect(sugarPointsFor(category: null, name: '무엇이든', sugar: 0), 0);
    });

    test('키워드 규칙이 카테고리 기본값보다 우선', () {
      // 커피 기본값 22(라떼), 아메리카노 키워드는 10
      final ame = sugarPointsFor(category: '커피', name: '아이스 아메리카노', sugar: 0);
      final latte = sugarPointsFor(category: '커피', name: '바닐라라떼', sugar: 0);
      expect(ame, 10);
      expect(latte, 22);
      expect(ame < latte, isTrue);
    });

    test('키워드는 대소문자를 가리지 않는다', () {
      expect(
        sugarPointsFor(category: '커피', name: 'ICED 아메리카노', sugar: 0),
        sugarPointsFor(category: '커피', name: '아메리카노', sugar: 0),
      );
    });

    test('소수점 당류는 반올림된다', () {
      // 27 - 0.4 = 26.6 → 27
      expect(sugarPointsFor(category: '탄산음료', name: '제로콜라', sugar: 0.4), 27);
      // 27 - 0.6 = 26.4 → 26
      expect(sugarPointsFor(category: '탄산음료', name: '제로콜라', sugar: 0.6), 26);
    });

    test('음수 당류(데이터 오류)로 기준값보다 큰 적립이 나오면 안 된다', () {
      final p = sugarPointsFor(category: '탄산음료', name: '이상한값', sugar: -100);
      // 현재 구현은 방어하지 않는다 — 127P 가 나온다.
      expect(p <= 27, isTrue,
          reason: '음수 당류는 0으로 취급해야 기준값을 넘는 적립이 안 생긴다');
    });
  });

  // ── 포인트 사용 규칙 ─────────────────────────────────────────
  group('포인트 사용 (PointPolicy)', () {
    test('주문 금액의 절반까지만 쓸 수 있다', () {
      expect(PointPolicy.usableFor(10000, 999999), 5000);
    });

    test('잔액이 적으면 잔액까지만', () {
      expect(PointPolicy.usableFor(10000, 300), 300);
    });

    test('잔액 0 이면 0', () {
      expect(PointPolicy.usableFor(10000, 0), 0);
    });

    test('상품가 0 이면 0 — 나눗셈/음수 결제액이 생기면 안 된다', () {
      expect(PointPolicy.usableFor(0, 5000), 0);
    });

    test('홀수 금액은 내림 — 결제액이 음수가 되지 않게', () {
      expect(PointPolicy.usableFor(999, 999999), 499);
    });

    test('잔액이 음수여도 사용 가능액은 음수가 아니다', () {
      expect(PointPolicy.usableFor(10000, -50) >= 0, isTrue,
          reason: '음수 잔액이 그대로 새어 나오면 결제액이 상품가보다 커진다');
    });

    test('사용액을 빼도 결제액은 항상 0 이상', () {
      for (final price in [0, 1, 999, 10000, 85000]) {
        final use = PointPolicy.usableFor(price, 999999);
        expect(price - use * PointPolicy.wonPerPoint >= 0, isTrue,
            reason: '상품가 $price 에서 결제액이 음수가 됐다');
      }
    });
  });

  // ── 미션 조건 매칭 ───────────────────────────────────────────
  group('미션 조건 (Mission.accepts)', () {
    Mission m({
      MissionTrigger trigger = MissionTrigger.productLog,
      Map<String, String> condition = const {},
    }) =>
        Mission(
          code: 'c',
          title: 't',
          description: '',
          icon: 'flag',
          trigger: trigger,
          condition: condition,
          period: MissionPeriod.daily,
          target: 1,
          reward: 10,
          sort: 0,
          active: true,
        );

    test('트리거가 다르면 안 걸린다', () {
      expect(m().accepts(MissionTrigger.checkin, const {}), isFalse);
    });

    test('조건이 비어 있으면 무조건 통과', () {
      expect(m().accepts(MissionTrigger.productLog, const {}), isTrue);
    });

    test('조건이 맞아야 통과', () {
      final low = m(condition: {'grade': 'low'});
      expect(low.accepts(MissionTrigger.productLog, {'grade': 'low'}), isTrue);
      expect(low.accepts(MissionTrigger.productLog, {'grade': 'mid'}), isFalse);
    });

    test('조건 키가 이벤트에 없으면 통과하지 않는다', () {
      final low = m(condition: {'grade': 'low'});
      expect(low.accepts(MissionTrigger.productLog, const {}), isFalse);
    });

    test('조건이 여러 개면 전부 맞아야 한다 (AND)', () {
      final both = m(condition: {'grade': 'low', 'brand': '널담'});
      expect(
          both.accepts(MissionTrigger.productLog,
              {'grade': 'low', 'brand': '널담'}),
          isTrue);
      expect(
          both.accepts(MissionTrigger.productLog,
              {'grade': 'low', 'brand': '라라스윗'}),
          isFalse);
    });

    test('이벤트에 여분의 값이 있어도 조건만 맞으면 통과', () {
      final low = m(condition: {'grade': 'low'});
      expect(
          low.accepts(MissionTrigger.productLog,
              {'grade': 'low', 'brand': '널담', 'x': 'y'}),
          isTrue);
    });
  });

  // ── 미션 정의 파싱 (데이터가 잘못 들어와도 죽지 않아야) ──────────
  group('미션 정의 파싱 (Mission.fromMap)', () {
    test('모르는 trigger 는 checkin 으로 떨어진다', () {
      final m = Mission.fromMap({'code': 'a', 'title': 't', 'trigger': '없는거'});
      expect(m.trigger, MissionTrigger.checkin);
    });

    test('모르는 period 는 once — 매일 반복 적립보다 안전한 쪽', () {
      final m = Mission.fromMap({'code': 'a', 'title': 't', 'period': '없는거'});
      expect(m.period, MissionPeriod.once);
    });

    test('target·reward 가 없으면 기본값 (1, 0)', () {
      final m = Mission.fromMap({'code': 'a', 'title': 't'});
      expect(m.target, 1);
      expect(m.reward, 0);
    });

    test('condition 이 없으면 빈 조건', () {
      final m = Mission.fromMap({'code': 'a', 'title': 't'});
      expect(m.condition, isEmpty);
    });

    test('condition 값이 숫자여도 문자열로 정규화된다', () {
      final m = Mission.fromMap({
        'code': 'a',
        'title': 't',
        'condition': {'count': 3},
      });
      expect(m.condition['count'], '3');
    });

    test('target 0 은 즉시 달성이 되어버린다 — 정의 실수 방어 필요', () {
      final m = Mission.fromMap(
          {'code': 'a', 'title': 't', 'target': 0, 'reward': 100});
      expect(m.target >= 1, isTrue,
          reason: 'target 0 이면 이벤트 한 번에 무한히 달성 처리된다');
    });

    test('reward 가 음수면 포인트가 깎인다 — 정의 실수 방어 필요', () {
      final m = Mission.fromMap(
          {'code': 'a', 'title': 't', 'reward': -100});
      expect(m.reward >= 0, isTrue, reason: '미션 달성으로 잔액이 줄면 안 된다');
    });
  });

  // ── 기간키: 중복 적립 방어의 핵심 ─────────────────────────────
  group('기간키 (PeriodKey)', () {
    test('같은 날은 같은 키', () {
      expect(PeriodKey.day(DateTime(2026, 8, 25, 0, 0)),
          PeriodKey.day(DateTime(2026, 8, 25, 23, 59)));
    });

    test('날짜가 바뀌면 키가 바뀐다 (자정 경계)', () {
      expect(PeriodKey.day(DateTime(2026, 8, 25, 23, 59)),
          isNot(PeriodKey.day(DateTime(2026, 8, 26, 0, 0))));
    });

    test('한 자리 월·일은 0 으로 채운다 (문자열 비교가 어긋나지 않게)', () {
      expect(PeriodKey.day(DateTime(2026, 1, 5)), '2026-01-05');
    });

    test('같은 주(월~일)는 같은 주차 키', () {
      // 2026-08-24(월) ~ 2026-08-30(일)
      final mon = PeriodKey.week(DateTime(2026, 8, 24));
      final sun = PeriodKey.week(DateTime(2026, 8, 30));
      expect(mon, sun);
    });

    test('일요일과 다음 월요일은 다른 주차', () {
      final sun = PeriodKey.week(DateTime(2026, 8, 30));
      final mon = PeriodKey.week(DateTime(2026, 8, 31));
      expect(sun, isNot(mon));
    });

    test('연말연시 주차가 해를 넘겨도 깨지지 않는다', () {
      // 2026-12-28(월)~2027-01-03(일) 은 같은 ISO 주
      final a = PeriodKey.week(DateTime(2026, 12, 28));
      final b = PeriodKey.week(DateTime(2027, 1, 3));
      expect(a, b, reason: 'ISO 주차는 목요일이 속한 해를 따른다');
    });

    test('주차는 2자리로 채워진다', () {
      expect(PeriodKey.week(DateTime(2026, 1, 8)), matches(r'^\d{4}-W\d{2}$'));
    });
  });

  // ── 원장 항목 ───────────────────────────────────────────────
  group('원장 (PointEntry)', () {
    PointEntry e(int delta) => PointEntry(
          id: 'x',
          at: DateTime(2026, 8, 25),
          delta: delta,
          reason: PointReason.sugarSaved,
        );

    test('양수는 적립, 음수는 사용', () {
      expect(e(10).isEarn, isTrue);
      expect(e(-10).isEarn, isFalse);
    });

    test('0 은 적립이 아니다 — 목록에 +0P 가 뜨면 안 된다', () {
      expect(e(0).isEarn, isFalse);
    });
  });

  // ── 상점 표시 ───────────────────────────────────────────────
  group('상점 (ShopItem)', () {
    test('잔액이 상품가의 절반을 넘어도 절반까지만 깎인다', () {
      // 가격 1000, 잔액 5000 → 500
      expect(PointPolicy.usableFor(1000, 5000), 500);
    });

    test('1P 는 1원 — 표시와 차감 단위가 어긋나면 안 된다', () {
      expect(PointPolicy.wonPerPoint, 1);
    });
  });
}
