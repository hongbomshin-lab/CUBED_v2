// test/core/rulebook_test.dart
// 실측 오판정 케이스 회귀 테스트 (2026-08 신호등 점검).
import 'package:flutter_test/flutter_test.dart';
import 'package:cubed_app/core/rulebook.dart';

void main() {
  const giMap = {
    'maltodextrin': Grade.caution,
    'aspartame': Grade.low,
    'sodium-saccharin': Grade.low,
    'sucralose': Grade.low,
  };

  test('케이스 A: 딥앤쫀득초코 — 말토덱스트린이 등급을 주의로 끌어올린다', () {
    // 당0g·75kcal/70g·carb5·당알코올10 — 순탄수는 0이지만 말토덱스트린(주의) 포함.
    final g = glycemicGrade(
      isLiquid: false, servingSize: 70, kcal: 75, carb: 5, fiber: 0,
      sugarAlcohol: 10, rareSugarG: 0,
      slugs: const ['aspartame', 'maltodextrin', 'sodium-saccharin'],
      giMap: giMap,
    );
    expect(g, Grade.caution);
  });

  test('케이스 A: 아라비아검·MSG는 여전히 등급 계산에서 제외', () {
    expect(rulebookSweeteners(['gum-arabic', 'monosodium-glutamate', 'maltodextrin']),
        ['maltodextrin']);
  });

  test('케이스 B: 제로 초코파이 — 1회분 순탄수 7g은 밀도(6.4g/100g)가 낮아도 중간', () {
    // 110g·110kcal·carb7·당0g — 100g당 6.4g < 10 이지만 절대량 7g ≥ 5 → +1단계.
    final g = glycemicGrade(
      isLiquid: false, servingSize: 110, kcal: 110, carb: 7, fiber: 0,
      sugarAlcohol: 0, rareSugarG: 0,
      slugs: const ['sucralose'],
      giMap: giMap,
    );
    expect(g, Grade.mid);
    // "왜"의 근거인 탄수 함정도 당 0g 제품에 표시돼야 한다.
    final t = traps(
      isLiquid: false, servingSize: 110, kcal: 110, sugar: 0,
      sugarAlcohol: 0, carb: 7, fiber: 0, slugs: const ['sucralose'],
    );
    expect(t, containsAll(['칼로리 함정', '탄수 함정']));
  });

  test('1회분 순탄수 15g 이상은 밀도 무관 주의', () {
    final g = glycemicGrade(
      isLiquid: false, servingSize: 200, kcal: 80, carb: 16, fiber: 0,
      sugarAlcohol: 0, rareSugarG: 0, slugs: const [], giMap: giMap,
    );
    expect(g, Grade.caution); // 16g ≥ 15 → +2
  });

  test('열량 정합 클램프: 탄수 19g인데 12kcal(미기재 알룰로스) → 유효 3g → 낮음', () {
    // 실측: 롯데 Happiz 트로피칼 — 탄수 대부분이 rare_sugar_g 미기재 알룰로스.
    final g = glycemicGrade(
      isLiquid: true, servingSize: 350, kcal: 12, carb: 19, fiber: 0,
      sugarAlcohol: 0, rareSugarG: 0, slugs: const ['sucralose'], giMap: giMap,
    );
    expect(g, Grade.low);
    expect(effectiveNetCarb(19, 12), 3);
  });

  test('당알코올 미량 완화: 소르비톨액 0.8g 음료는 낮음, SA 미기재면 보수 유지', () {
    const gi2 = {'d-sorbitol-solution': Grade.mid, 'maltitol': Grade.caution};
    // 실측: 암바사 제로 — SA 0.8g 명시 → 미량 무시
    final trace = glycemicGrade(
      isLiquid: true, servingSize: 250, kcal: 0, carb: 0, fiber: 0,
      sugarAlcohol: 0.8, rareSugarG: 0,
      slugs: const ['d-sorbitol-solution'], giMap: gi2,
    );
    expect(trace, Grade.low);
    // SA 미기재(0) + 말티톨 → 양을 모르므로 주의 유지 (예: 폴라포 커피 제로슈거)
    final unknown = glycemicGrade(
      isLiquid: false, servingSize: 130, kcal: 90, carb: 13, fiber: 0,
      sugarAlcohol: 0, rareSugarG: 0, slugs: const ['maltitol'], giMap: gi2,
    );
    expect(unknown, Grade.caution);
  });

  test('말토덱스트린 미량 carrier: 순탄수 0 신뢰 데이터면 중간으로 완화', () {
    // 실측: 환타 제로 파인애플향 — carb 0·kcal 0, 말토덱스트린은 향료 carrier
    final g = glycemicGrade(
      isLiquid: true, servingSize: 350, kcal: 0, carb: 0, fiber: 0,
      sugarAlcohol: 0, rareSugarG: 0,
      slugs: const ['sucralose', 'maltodextrin'], giMap: giMap,
    );
    expect(g, Grade.mid); // 주의가 아니라 중간 — 경고는 유지하되 빨간불은 아님
  });

  test('진짜 제로(순탄수 0·위험 성분 없음)는 여전히 낮음', () {
    final g = glycemicGrade(
      isLiquid: true, servingSize: 355, kcal: 0, carb: 3, fiber: 0,
      sugarAlcohol: 3, rareSugarG: 0, slugs: const ['sucralose'], giMap: giMap,
    );
    expect(g, Grade.low);
  });
}
