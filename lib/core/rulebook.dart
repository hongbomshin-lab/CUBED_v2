/// ZERO DOT 룰북 엔진 (Dart) — rulebook.ts 1:1 포팅.
/// 영양값에서 해석값(순탄수·혈당영향 등급·0g 함정)을 계산한다.
/// 해석값은 DB에 저장하지 않고 이 함수로만 계산한다(절대 원칙).
///
/// ※ 등급 결합: 누적 상향(감미료기준 등급 + 순탄수 단계, 상한 '주의'). max 아님.
/// ※ 당알코올 함정: 혈당 올리는 당알코올(RISKY_SA)에만, 한 단위 당알코올 ≥ 2g일 때만.
/// ※ class='기타' 중 혈당영향 '낮음'(아라비아검 등)만 등급 계산에서 제외한다.
///   말토덱스트린은 고GI 탄수화물 — 개별 g이 라벨에 안 잡혀 순탄수로 못 잡는 실사례가
///   있어(케이스 A: 딥앤쫀득초코) 감미료 등급 경로로 반드시 반영한다.
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
const _tCarbServing = [5.0, 15.0]; // 1회분 절대 순탄수(g) → +1/+2 단계 (밀도와 max 결합)
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

/// 룰북 혈당등급 계산에서 제외할 class='기타' slug.
/// maltodextrin은 glycemic_impact '주의' — 등급에 반영해야 하므로 제외하지 않는다.
const _excludedClassEtc = {'gum-arabic', 'monosodium-glutamate'};

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

/// 순탄수 단계 = max(밀도 100당 기준, 1회분 절대 g 기준).
/// 밀도만 보면 1회분이 큰 저밀도 제품(예: 순탄수 7g인데 6.4g/100g)이 빠져나간다.
int _carbSteps(bool isLiquid, double p100, double ncServing) {
  final t = isLiquid ? _tCarbLiq : _tCarbSolid;
  final density = p100 >= t[1] ? 2 : (p100 >= t[0] ? 1 : 0);
  final serving = ncServing >= _tCarbServing[1]
      ? 2
      : (ncServing >= _tCarbServing[0] ? 1 : 0);
  return density > serving ? density : serving;
}

/// (B-1) 혈당영향 '낮음'인 class='기타'(아라비아검·MSG)만 룰북 입력에서 제외.
List<String> rulebookSweeteners(List<String> slugs) =>
    slugs.where((s) => !_excludedClassEtc.contains(s)).toList();

/// 등급 계산에서 제외되는 slug인지 — 표시층(top 감미료 선정)과 기준 공유용.
bool isRulebookExcluded(String slug) => _excludedClassEtc.contains(slug);

/// 열량 정합 상한: 라벨 kcal로 물리적으로 가능한 최대 흡수 탄수는 kcal/4 g.
/// 순탄수가 이를 넘으면 미기재 알룰로스/감미료가 탄수에 섞인 것 — 유효 순탄수를 클램프.
/// (예: 탄수 19g인데 12kcal → 유효 3g. kcal 미상(0)은 클램프하지 않음 — OCR null 보호)
double effectiveNetCarb(double nc, double kcal) =>
    kcal > 0 && nc > kcal / 4 ? _round1(kcal / 4) : nc;

/// 감미료 단계(0~2) — 양 감응:
/// · 혈당 올리는 당알코올: 한 단위 당알코올이 명시적으로 2g 미만(0<SA<2)이면 미량 → 0단계
///   (당알코올 함정의 _tSaMin과 동일 기준. SA 미기재(0)는 알 수 없으므로 보수 유지)
/// · 말토덱스트린: 전량이 탄수이므로 유효 순탄수가 함량 상한 — 신뢰 가능한 순탄수 < 2g이면
///   미량 carrier로 보고 +1(중간)로 완화. 순탄수 계산이 깨진 데이터(탄수<차감합)는 보수 유지.
int _sweetenerSteps(
  List<String> slugs,
  Map<String, Grade> giMap,
  double sugarAlcohol,
  double effNc,
  bool ncReliable,
) {
  var worst = 0;
  for (final s in rulebookSweeteners(slugs)) {
    var g = _rank[giMap[s] ?? Grade.low] ?? 0;
    if (g == 0) continue;
    if (riskySugarAlcohol.contains(s) &&
        sugarAlcohol > 0 &&
        sugarAlcohol < _tSaMin) {
      g = 0;
    }
    if (s == 'maltodextrin' && ncReliable && effNc < _tSaMin && g > 1) g = 1;
    if (g > worst) worst = g;
  }
  return worst;
}

/// 혈당영향 등급 = 감미료 단계 + 순탄수 단계 (누적, 상한 '주의').
/// 순탄수 단계는 열량 정합 클램프를 거친 유효 순탄수 기준.
Grade glycemicGrade({
  required bool isLiquid,
  required double servingSize,
  required double kcal,
  required double carb,
  required double fiber,
  required double sugarAlcohol,
  required double rareSugarG,
  required List<String> slugs,
  required Map<String, Grade> giMap,
}) {
  final ncReliable = carb - fiber - sugarAlcohol - rareSugarG >= 0;
  final nc = effectiveNetCarb(
      netCarb(carb, fiber, sugarAlcohol, rareSugarG), kcal);
  final p100 = servingSize > 0 ? _round1(nc * 100 / servingSize) : 0.0;
  final sw = _sweetenerSteps(slugs, giMap, sugarAlcohol, nc, ncReliable);
  final total = sw + _carbSteps(isLiquid, p100, nc);
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
  // 함정도 등급과 같은 유효 순탄수(열량 정합 클램프) 기준으로 판정한다.
  final nc = effectiveNetCarb(
      netCarb(carb, fiber, sugarAlcohol, rareSugarG), kcal);
  final p100 = servingSize > 0 ? nc * 100 / servingSize : 0.0;
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
  // ℹ️ 참고: 당류 높음(저당 초과)·탄수 있음.
  // 탄수 함정은 당 0g 제품에도 보여준다 — "왜 걸렸는지"의 핵심 근거(케이스 B).
  if (sugarHigh) out.add('당류 함정');
  if (!sugarHigh && _carbSteps(isLiquid, p100, nc) > 0) out.add('탄수 함정');
  return out.isEmpty ? ['없음'] : out;
}
