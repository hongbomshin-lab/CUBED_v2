/// 당류 개인 판정 — WHO 유리당 권고 × SugarProfile.
/// rulebook.dart와 동일 철학: 런타임 계산만, DB 저장 없음.
///
/// 산식:
///   하루 열량   = clamp(체중×30, 1400, 2400) kcal (체중 없으면 2000)
///   하루 한도 g = 하루 열량 × goal 비율 ÷ 4
///   한 끼 한도 g = round(하루 한도 ÷ 식사 횟수)     (없으면 3끼)
///   유효당류 g  = 당류 + 0.5 × 위험 당알코올(risky slug 있을 때만)
library;

import '../data/models/sweetener.dart';
import 'rulebook.dart' show riskySugarAlcohol;
import 'sugar_profile.dart';

enum SugarLevel { ok, watch, avoid, unknown }

class SugarVerdict {
  final SugarLevel level;
  final double ratio; // 유효당류 ÷ 한 끼 한도 (unknown이면 0)
  final int mealLimitG;
  final double effectiveSugarG;
  const SugarVerdict({
    required this.level,
    required this.ratio,
    required this.mealLimitG,
    required this.effectiveSugarG,
  });
}

/// goal → 열량 대비 유리당 비율 (혈당 5% / 체중 7.5% / 건강 10%)
double goalRatio(SugarGoal g) => switch (g) {
      SugarGoal.bloodSugar => 0.05,
      SugarGoal.weight => 0.075,
      SugarGoal.general => 0.10,
    };

/// 한 끼 당류 한도(g, 정수 반올림 — 소수점은 가짜 정밀도).
/// 열량 클램프(1400~2400)는 "체중 클수록 한도 커지는" 역설 차단용.
int mealSugarLimitG(SugarProfile p) {
  final kcal =
      p.weightKg == null ? 2000.0 : (p.weightKg! * 30).clamp(1400.0, 2400.0);
  final dailyG = kcal * goalRatio(p.goal) / 4;
  return (dailyG / (p.mealsPerDay ?? 3)).round();
}

/// 판정에 넣을 당알코올 g.
/// 감미료별 개별 g이 있으면 risky 성분 합계만, 없으면 총량(계수는 judgeSugar가 적용).
double judgedSugarAlcoholG(
    double totalSugarAlcoholG, List<ProductSweetener> sweeteners) {
  final riskyAmounts = sweeteners
      .where((s) => riskySugarAlcohol.contains(s.slug) && s.amountG != null)
      .toList();
  if (riskyAmounts.isEmpty) return totalSugarAlcoholG;
  return riskyAmounts.fold(0.0, (a, s) => a + s.amountG!);
}

/// 당류 개인 판정 (순수 함수).
/// [sugarG] null = 당류 미확인(OCR 미표기) → 무조건 ⚪ unknown.
/// 양 배수(portion) 반영은 호출부 책임 — 배수를 곱한 g을 넘긴다.
SugarVerdict judgeSugar({
  required double? sugarG,
  required double sugarAlcoholG,
  required List<String> sweetenerSlugs,
  required SugarProfile profile,
}) {
  final limit = mealSugarLimitG(profile);
  if (sugarG == null) {
    return SugarVerdict(
        level: SugarLevel.unknown, ratio: 0, mealLimitG: limit, effectiveSugarG: 0);
  }
  // 혈당 올리는 당알코올만 ×0.5 환산 (에리스리톨·알룰로스 등 혈당영향 0은 제외)
  final risky = sweetenerSlugs.any(riskySugarAlcohol.contains);
  final effective = sugarG + (risky ? 0.5 * sugarAlcoholG : 0);
  final ratio = effective / limit;
  final level = ratio <= 0.5
      ? SugarLevel.ok
      : ratio <= 1.0
          ? SugarLevel.watch
          : SugarLevel.avoid;
  return SugarVerdict(
      level: level, ratio: ratio, mealLimitG: limit, effectiveSugarG: effective);
}
