/// 카테고리별 "일반 제품 1회 섭취 당류" 기준값 (docs/sugar-baselines.md 근거).
/// 포인트 = 기준값 − 제품 당류 (1P = 아낀 설탕 1g, 음수는 0).
/// 기준은 일반 제품 1회 섭취 단위 고정값 — 제품 용량에 비례시키지 않는다
/// (1.5L 제로콜라를 기록해도 캔 1개 기준 포인트만 적립).
library;

class SugarBaseline {
  const SugarBaseline({
    required this.category,
    this.keywords,
    required this.baselineG,
    required this.basis,
  });

  final String category;

  /// 제품명 포함 키워드 (소문자 비교). null이면 카테고리 기본값.
  final List<String>? keywords;

  /// 일반 제품 1회 섭취 당류 g
  final int baselineG;

  /// 기준 단위 설명 (예: '250ml 캔 1개')
  final String basis;
}

/// 선언 순서 = 매칭 우선순위 (키워드 규칙이 기본값보다 먼저 와야 함).
const List<SugarBaseline> kSugarBaselines = [
  // 음료
  SugarBaseline(category: '탄산음료', baselineG: 27, basis: '일반 콜라 250ml 캔'),
  SugarBaseline(category: '에너지드링크', baselineG: 27, basis: '일반 에너지드링크 250ml 캔'),
  SugarBaseline(category: '스포츠/이온음료', baselineG: 30, basis: '일반 이온음료 500ml'),
  SugarBaseline(category: '과일음료', baselineG: 36, basis: '일반 주스 350ml'),
  SugarBaseline(category: '건강/기능성음료', baselineG: 10, basis: '일반 기능성음료 100ml 병'),
  SugarBaseline(
      category: '차/티음료',
      keywords: ['아이스티', '에이드', '블렌딩', '밀크티'],
      baselineG: 25,
      basis: '일반 아이스티 500ml'),
  SugarBaseline(
      category: '차/티음료',
      keywords: ['식혜', '수정과'],
      baselineG: 20,
      basis: '일반 식혜 238ml 캔'),
  SugarBaseline(
      category: '차/티음료',
      keywords: ['유자차', '꿀'],
      baselineG: 20,
      basis: '일반 유자차 음료'),
  // RTD 차는 이봉분포: 대부분 0~1g(대체당), 유자·꿀차만 20g+ → 기본값은 하한 완충
  SugarBaseline(category: '차/티음료', baselineG: 3, basis: '일반 차음료'),
  SugarBaseline(
      category: '커피',
      keywords: ['아메리카노'],
      baselineG: 10,
      basis: '일반 가당 아메리카노 275ml'),
  SugarBaseline(
      category: '커피', keywords: ['믹스'], baselineG: 6, basis: '일반 커피믹스 1봉'),
  SugarBaseline(category: '커피', baselineG: 22, basis: '일반 라떼 275ml'),
  SugarBaseline(
      category: '우유/요거트음료',
      keywords: ['우유', '쉐이크', '셰이크', '밀크'],
      baselineG: 26,
      basis: '일반 가공유 240ml'),
  SugarBaseline(category: '우유/요거트음료', baselineG: 12, basis: '일반 요거트드링크 1병'),
  SugarBaseline(category: '두유/식물성음료', baselineG: 8, basis: '일반 두유 190ml'),
  SugarBaseline(category: '단백질음료', baselineG: 5, basis: '일반 단백질음료 1병'),
  // 아이스크림 — 형태별로 일반 제품 당류가 다름
  SugarBaseline(
      category: '아이스크림/빙과',
      keywords: ['쉐이크', '셰이크'],
      baselineG: 26,
      basis: '일반 밀크쉐이크 1컵'),
  SugarBaseline(
      category: '아이스크림/빙과', keywords: ['콘'], baselineG: 22, basis: '일반 콘 1개'),
  SugarBaseline(
      category: '아이스크림/빙과',
      keywords: ['모나카', '샌드'],
      baselineG: 24,
      basis: '일반 모나카 1개'),
  SugarBaseline(
      category: '아이스크림/빙과',
      keywords: ['파인트', '파르페', '컵', '아이스크림'],
      baselineG: 20,
      basis: '일반 컵 아이스크림 1개'),
  SugarBaseline(
      category: '아이스크림/빙과',
      keywords: ['쭈쭈바', '쮸쮸바', '튜브', '아이스팝'],
      baselineG: 15,
      basis: '일반 튜브 빙과 1개'),
  SugarBaseline(category: '아이스크림/빙과', baselineG: 14, basis: '일반 아이스바 1개'),
  // 간식
  SugarBaseline(category: '젤리', baselineG: 40, basis: '일반 젤리 1봉'),
  SugarBaseline(
      category: '초콜릿/캔디/껌',
      keywords: ['캔디', '민트', '홀스', '호올스'],
      baselineG: 7,
      basis: '일반 캔디 1회'),
  SugarBaseline(
      category: '초콜릿/캔디/껌', keywords: ['껌'], baselineG: 2, basis: '일반 껌 1회'),
  SugarBaseline(category: '초콜릿/캔디/껌', baselineG: 20, basis: '일반 초콜릿 1개'),
  SugarBaseline(
      category: '과자/스낵',
      keywords: ['그래놀라', '오트', '오즈'],
      baselineG: 15,
      basis: '일반 그래놀라 50g'),
  SugarBaseline(
      category: '과자/스낵',
      keywords: ['팝콘'],
      baselineG: 23,
      basis: '일반 카라멜팝콘 1봉(75g)'),
  SugarBaseline(
      category: '과자/스낵', keywords: ['웨하스'], baselineG: 6, basis: '일반 웨하스 1회'),
  SugarBaseline(
      category: '과자/스낵', baselineG: 7, basis: '일반 쿠키 1회(2~3개)'),
  SugarBaseline(
      category: '빵/디저트',
      keywords: ['단팥', '호빵'],
      baselineG: 18,
      basis: '일반 단팥빵 1개'),
  SugarBaseline(
      category: '빵/디저트', keywords: ['도넛'], baselineG: 9, basis: '일반 도넛 1개'),
  SugarBaseline(
      category: '빵/디저트',
      keywords: ['티라미수', '케이크'],
      baselineG: 30,
      basis: '일반 티라미수 1컵'),
  SugarBaseline(
      category: '빵/디저트', keywords: ['소금빵'], baselineG: 3, basis: '일반 소금빵 1개'),
  SugarBaseline(
      category: '빵/디저트', keywords: ['초코파이'], baselineG: 13, basis: '일반 초코파이 1개'),
  SugarBaseline(category: '빵/디저트', baselineG: 15, basis: '일반 크림빵 1개'),
  // 식사
  SugarBaseline(
      category: '간편식/식사', keywords: ['비빔면'], baselineG: 12, basis: '일반 비빔면 1봉'),
  SugarBaseline(
      category: '간편식/식사', keywords: ['떡볶이'], baselineG: 16, basis: '일반 떡볶이 1인분'),
  SugarBaseline(
      category: '간편식/식사',
      keywords: ['비빔밥'],
      baselineG: 6,
      basis: '일반 비빔밥 1인분'),
  SugarBaseline(
      category: '간편식/식사',
      keywords: ['덮밥', '도시락'],
      baselineG: 12,
      basis: '일반 고기양념 도시락 1인분'),
  SugarBaseline(
      category: '간편식/식사', keywords: ['샌드'], baselineG: 7, basis: '일반 샌드위치 1개'),
  SugarBaseline(
      category: '간편식/식사', baselineG: 8, basis: '일반 샐러드 1팩(드레싱 포함)'),
  SugarBaseline(category: '단백질/에너지바', baselineG: 15, basis: '일반 에너지바 1개'),
  SugarBaseline(
      category: '소스/장류', keywords: ['초고추장'], baselineG: 8, basis: '일반 초고추장 20g'),
  SugarBaseline(
      category: '소스/장류', keywords: ['드레싱'], baselineG: 4, basis: '일반 드레싱 30g'),
  SugarBaseline(category: '소스/장류', baselineG: 5, basis: '일반 쌈장 20g'),
];

/// 카테고리+제품명으로 기준값 규칙 찾기. 모르는 카테고리는 null (포인트 없음).
SugarBaseline? sugarBaselineFor({String? category, required String name}) {
  if (category == null) return null;
  final lower = name.toLowerCase();
  SugarBaseline? fallback;
  for (final rule in kSugarBaselines) {
    if (rule.category != category) continue;
    if (rule.keywords == null) {
      fallback ??= rule;
      continue;
    }
    if (rule.keywords!.any(lower.contains)) return rule;
  }
  return fallback;
}

/// 적립 포인트 (아낀 설탕 g). 기준값이 없거나 당류가 더 많으면 0.
int sugarPointsFor({
  String? category,
  required String name,
  required double sugar,
}) {
  final rule = sugarBaselineFor(category: category, name: name);
  if (rule == null) return 0;
  final saved = rule.baselineG - sugar;
  if (saved <= 0) return 0;
  return saved.round();
}

/// 각설탕 환산 (1개 ≈ 3g) — UI 카피용.
int sugarCubesFor(int points) => (points / 3).round();
