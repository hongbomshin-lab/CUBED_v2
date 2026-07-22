/// ZERO DOT 룰북 엔진 (Dart) — rulebook.ts 1:1 포팅.
/// 영양값에서 해석값(순탄수·혈당영향 등급·0g 함정)을 계산한다.
/// 해석값은 DB에 저장하지 않고 이 함수로만 계산한다(절대 원칙).
///
/// ※ 등급 결합: 누적 상향(감미료기준 등급 + 순탄수 단계, 상한 '주의'). max 아님.
/// ※ 당알코올 함정: 혈당 올리는 당알코올(RISKY_SA)에만, 한 단위 당알코올 ≥ 2g일 때만.
/// ※ class='기타'(말토덱스트린 등)는 감미료 아님 → rulebookSweeteners()로 걸러 넘긴다.
/// ※ 액상/고형은 category_meta.is_liquid가 정답 — 본 엔진은 isLiquid 불리언을 인자로 받는다.
library;

enum Grade { low, mid, caution }

extension GradeLabel on Grade {
  /// DB/표시용 한글명 (rulebook.ts의 '낮음'|'중간'|'주의')
  String get ko => switch (this) {
        Grade.low => '낮음',
        Grade.mid => '중간',
        Grade.caution => '주의',
      };
}

const _rank = {Grade.low: 0, Grade.mid: 1, Grade.caution: 2};
const _inv = [Grade.low, Grade.mid, Grade.caution];

// ---- 임계 (rulebook.ts와 동일) ----
const _tCarbLiq = [2.5, 5.0]; // 액상 100ml당 순탄수 → +1/+2 단계
const _tCarbSolid = [10.0, 20.0]; // 고형 100g당 순탄수 → +1/+2 단계
const _tKcalLiq = 4.0; // 당0g인데 100ml당 kcal ≥ 4 → 칼로리 함정
const _tKcalSolid = 40.0; // 당0g인데 100g당 kcal ≥ 40 → 칼로리 함정
const _tSugarLowLiq = 2.5; // 액상 100ml당 당류 > 2.5 → 당류 함정
const _tSugarLowSolid = 5.0; // 고형 100g당 당류 > 5 → 당류 함정
const _tSaMin = 2.0; // 당알코올 함정은 한 단위 당알코올 ≥ 2g 일 때만

/// 혈당 올리는 당알코올만 (세분형 slug 포함)
const riskySugarAlcohol = {
  'maltitol', 'd-maltitol',
  'xylitol',
  'sorbitol', 'd-sorbitol-solution',
  'polyglycitol',
};

/// 룰북 혈당등급 계산에서 제외할 class='기타' slug
const _excludedClassEtc = {'maltodextrin', 'gum-arabic', 'monosodium-glutamate'};

double _round2(double v) => (v * 100).round() / 100;
double _round1(double v) => (v * 10).round() / 10;

/// 순탄수 = 탄수 − 식이섬유 − 당알코올 − 희소당. 음수 방지, 소수 2자리.
double netCarb(double carb, double fiber, double sugarAlcohol, [double rareSugarG = 0]) {
  final v = carb - fiber - sugarAlcohol - rareSugarG;
  return v <= 0 ? 0 : _round2(v);
}

/// 100당 순탄수(액상 100ml / 고형 100g 기준). 소수 1자리.
double per100NetCarb(
  double servingSize,
  double carb,
  double fiber,
  double sugarAlcohol, [
  double rareSugarG = 0,
]) {
  final nc = netCarb(carb, fiber, sugarAlcohol, rareSugarG);
  return servingSize > 0 ? _round1(nc * 100 / servingSize) : 0;
}

int _carbSteps(bool isLiquid, double p100) {
  final t = isLiquid ? _tCarbLiq : _tCarbSolid;
  if (p100 >= t[1]) return 2;
  if (p100 >= t[0]) return 1;
  return 0;
}

/// (B-1) class='기타'(말토덱스트린 등)는 룰북 입력에서 제외 — 이중계산 방지.
List<String> rulebookSweeteners(List<String> slugs) =>
    slugs.where((s) => !_excludedClassEtc.contains(s)).toList();

/// 감미료 slug 배열에서 glycemic_impact 최악 등급.
Grade sweetenerWorst(List<String> slugs, Map<String, Grade> giMap) {
  var worst = 0;
  for (final s in rulebookSweeteners(slugs)) {
    final g = _rank[giMap[s] ?? Grade.low] ?? 0;
    if (g > worst) worst = g;
  }
  return _inv[worst];
}

/// 혈당영향 등급 = 감미료기준 + 순탄수 단계 (누적, 상한 '주의').
Grade glycemicGrade({
  required bool isLiquid,
  required double servingSize,
  required double carb,
  required double fiber,
  required double sugarAlcohol,
  required double rareSugarG,
  required List<String> slugs,
  required Map<String, Grade> giMap,
}) {
  final p100 = per100NetCarb(servingSize, carb, fiber, sugarAlcohol, rareSugarG);
  var sw = 0;
  for (final s in rulebookSweeteners(slugs)) {
    final g = _rank[giMap[s] ?? Grade.low] ?? 0;
    if (g > sw) sw = g;
  }
  final total = sw + _carbSteps(isLiquid, p100);
  return _inv[total > 2 ? 2 : total];
}

/// 0g/저당 함정 코드. (0g 함정류는 당류 0g 제품에만 적용)
List<String> traps({
  required bool isLiquid,
  required double servingSize,
  required double kcal,
  required double sugar,
  required double sugarAlcohol,
  required double carb,
  required double fiber,
  double rareSugarG = 0,
  List<String> slugs = const [],
}) {
  final p100 = per100NetCarb(servingSize, carb, fiber, sugarAlcohol, rareSugarG);
  final per100kcal = servingSize > 0 ? kcal * 100 / servingSize : 0.0;
  final per100sugar = servingSize > 0 ? sugar * 100 / servingSize : 0.0;
  final zero = sugar <= 0.5;
  final sugarHigh = per100sugar > (isLiquid ? _tSugarLowLiq : _tSugarLowSolid);
  final out = <String>[];
  // 🚩 오해유발(0g 마케팅): 당알코올·칼로리
  if (zero && sugarAlcohol >= _tSaMin && slugs.any(riskySugarAlcohol.contains)) {
    out.add('당알코올 함정');
  }
  if (zero && per100kcal >= (isLiquid ? _tKcalLiq : _tKcalSolid)) {
    out.add('칼로리 함정');
  }
  // ℹ️ 참고: 당류 높음(저당 초과)·탄수 있음
  if (sugarHigh) out.add('당류 함정');
  if (!zero && !sugarHigh && _carbSteps(isLiquid, p100) > 0) out.add('탄수 함정');
  return out.isEmpty ? ['없음'] : out;
}
