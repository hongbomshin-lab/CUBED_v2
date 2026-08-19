import 'package:flutter_test/flutter_test.dart';
import 'package:cubed_app/core/sugar_judge.dart';
import 'package:cubed_app/core/sugar_profile.dart';
import 'package:cubed_app/data/models/sweetener.dart';

void main() {
  group('mealSugarLimitG', () {
    test('70kg·3끼 예시: 혈당 9 / 체중 13 / 건강 18', () {
      expect(mealSugarLimitG(const SugarProfile(goal: SugarGoal.bloodSugar, weightKg: 70)), 9);
      expect(mealSugarLimitG(const SugarProfile(goal: SugarGoal.weight, weightKg: 70)), 13);
      expect(mealSugarLimitG(const SugarProfile(goal: SugarGoal.general, weightKg: 70)), 18);
    });

    test('미입력(2000kcal·3끼) 기본값: 혈당 8 / 체중 13 / 건강 17', () {
      expect(mealSugarLimitG(const SugarProfile(goal: SugarGoal.bloodSugar)), 8);
      expect(mealSugarLimitG(const SugarProfile(goal: SugarGoal.weight)), 13);
      expect(mealSugarLimitG(const SugarProfile(goal: SugarGoal.general)), 17);
    });

    test('열량 클램프 하한 1400: 30kg → 900이 아니라 1400 기준', () {
      // 1400 × 0.05 ÷ 4 ÷ 3 = 5.83 → 6
      expect(mealSugarLimitG(const SugarProfile(goal: SugarGoal.bloodSugar, weightKg: 30)), 6);
    });

    test('열량 클램프 상한 2400: 100kg → 3000이 아니라 2400 기준', () {
      // 2400 × 0.05 ÷ 4 ÷ 3 = 10
      expect(mealSugarLimitG(const SugarProfile(goal: SugarGoal.bloodSugar, weightKg: 100)), 10);
    });

    test('식사 횟수 반영: 2000kcal·2끼 건강 = 25', () {
      expect(mealSugarLimitG(const SugarProfile(goal: SugarGoal.general, mealsPerDay: 2)), 25);
    });
  });

  group('judgeSugar', () {
    const weight = SugarProfile(goal: SugarGoal.weight); // 한 끼 한도 13g

    test('경계값 0.5: 6.5g/13g → ok, 6.6g → watch', () {
      expect(judgeSugar(sugarG: 6.5, sugarAlcoholG: 0, sweetenerSlugs: const [], profile: weight).level,
          SugarLevel.ok);
      expect(judgeSugar(sugarG: 6.6, sugarAlcoholG: 0, sweetenerSlugs: const [], profile: weight).level,
          SugarLevel.watch);
    });

    test('경계값 1.0: 13g → watch, 13.1g → avoid', () {
      expect(judgeSugar(sugarG: 13, sugarAlcoholG: 0, sweetenerSlugs: const [], profile: weight).level,
          SugarLevel.watch);
      expect(judgeSugar(sugarG: 13.1, sugarAlcoholG: 0, sweetenerSlugs: const [], profile: weight).level,
          SugarLevel.avoid);
    });

    test('당류 null(미확인) → 무조건 unknown', () {
      final v = judgeSugar(
          sugarG: null, sugarAlcoholG: 30, sweetenerSlugs: const ['maltitol'], profile: weight);
      expect(v.level, SugarLevel.unknown);
      expect(v.mealLimitG, 13);
    });

    test('risky 당알코올(말티톨) → ×0.5 환산', () {
      // 0g 당류 + 말티톨 30g → 유효당류 15g > 13g → avoid
      final v = judgeSugar(
          sugarG: 0, sugarAlcoholG: 30, sweetenerSlugs: const ['maltitol'], profile: weight);
      expect(v.effectiveSugarG, 15);
      expect(v.level, SugarLevel.avoid);
    });

    test('non-risky 당알코올(에리스리톨) → 미환산', () {
      final v = judgeSugar(
          sugarG: 0, sugarAlcoholG: 30, sweetenerSlugs: const ['erythritol'], profile: weight);
      expect(v.effectiveSugarG, 0);
      expect(v.level, SugarLevel.ok);
    });
  });

  group('judgedSugarAlcoholG', () {
    test('개별 g 없으면 총량 사용', () {
      expect(
        judgedSugarAlcoholG(20, const [ProductSweetener(slug: 'maltitol', sortOrder: 0)]),
        20,
      );
    });

    test('risky 개별 g이 있으면 risky 합계만 사용 (에리스리톨 g 무시)', () {
      expect(
        judgedSugarAlcoholG(20, const [
          ProductSweetener(slug: 'maltitol', amountG: 8, sortOrder: 0),
          ProductSweetener(slug: 'erythritol', amountG: 12, sortOrder: 1),
        ]),
        8,
      );
    });
  });
}
