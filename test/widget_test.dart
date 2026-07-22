// ZERO DOT 룰북 엔진 단위 테스트 (rulebook.ts 검증 케이스 포팅)
import 'package:flutter_test/flutter_test.dart';
import 'package:cubed_app/core/rulebook.dart';

void main() {
  group('netCarb', () {
    test('탄수 − 식이섬유 − 당알코올 − 희소당', () {
      expect(netCarb(20, 1, 15, 0), 4);
    });
    test('음수 방지 → 0', () {
      expect(netCarb(5, 0, 0, 8), 0);
    });
  });

  group('glycemicGrade', () {
    final gi = {'allulose': Grade.low, 'maltitol': Grade.caution, 'sucralose': Grade.low};

    test('알룰로스만 든 제로 음료 → 낮음', () {
      final g = glycemicGrade(
        isLiquid: true, servingSize: 500, carb: 5, fiber: 0, sugarAlcohol: 0,
        rareSugarG: 5, slugs: ['allulose'], giMap: gi,
      );
      expect(g, Grade.low);
    });

    test('말티톨 든 저당 과자 → 주의', () {
      final g = glycemicGrade(
        isLiquid: false, servingSize: 30, carb: 20, fiber: 1, sugarAlcohol: 15,
        rareSugarG: 0, slugs: ['maltitol'], giMap: gi,
      );
      expect(g, Grade.caution);
    });
  });

  group('traps', () {
    test('말티톨 든 무설탕 과자(당0g) → 당알코올 함정 포함', () {
      final t = traps(
        isLiquid: false, servingSize: 30, kcal: 120, sugar: 0,
        sugarAlcohol: 15, carb: 20, fiber: 1, rareSugarG: 0, slugs: ['maltitol'],
      );
      expect(t, contains('당알코올 함정'));
    });

    test('에리스리톨만 든 제로 음료(당0g) → 당알코올 함정 아님', () {
      final t = traps(
        isLiquid: true, servingSize: 355, kcal: 0, sugar: 0,
        sugarAlcohol: 3, carb: 3, fiber: 0, rareSugarG: 0, slugs: ['erythritol'],
      );
      expect(t, isNot(contains('당알코올 함정')));
    });

    test('말티톨 미세량(당알코올 1g < 2g) → 당알코올 함정 아님', () {
      final t = traps(
        isLiquid: false, servingSize: 30, kcal: 50, sugar: 0,
        sugarAlcohol: 1, carb: 5, fiber: 0, rareSugarG: 0, slugs: ['maltitol'],
      );
      expect(t, isNot(contains('당알코올 함정')));
    });
  });

  group('rulebookSweeteners', () {
    test("class='기타'(말토덱스트린)는 제외", () {
      expect(rulebookSweeteners(['sucralose', 'maltodextrin']), ['sucralose']);
    });
  });
}
