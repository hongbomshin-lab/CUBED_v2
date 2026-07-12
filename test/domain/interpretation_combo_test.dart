// test/domain/interpretation_combo_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cubed_app/core/rulebook.dart';
import 'package:cubed_app/data/models/product.dart';
import 'package:cubed_app/data/models/sweetener.dart';
import 'package:cubed_app/data/product_repository.dart';
import 'package:cubed_app/domain/interpretation.dart';

Sweetener sw(String slug, String name, String klass, Grade gi) => Sweetener(
      slug: slug, standardName: name, klass: klass, glycemicImpact: gi,
      cariogenicImpact: '중립', kcalPerG: 0,
    );

Product product({
  double sugar = 0, double carb = 0, double fiber = 0, double sa = 0,
  double kcal = 0, double serving = 100, String? category,
  List<ProductSweetener> sweeteners = const [],
}) => Product(
      productId: 'p1', name: '테스트', category: category,
      servingSize: serving, unit: 'g', kcal: kcal, carb: carb, sugar: sugar,
      protein: 0, fat: 0, fiber: fiber, sugarAlcohol: sa, rareSugarG: 0,
      sweetenerCount: sweeteners.length, verified: true, sweeteners: sweeteners,
    );

ReferenceData refData(List<ComboRule> rules) => ReferenceData(
      sweeteners: {
        'maltitol': sw('maltitol', '말티톨', '당알코올', Grade.caution),
        'erythritol': sw('erythritol', '에리스리톨', '당알코올', Grade.low),
        'sucralose': sw('sucralose', '수크랄로스', '인공', Grade.low),
        'maltodextrin': sw('maltodextrin', '말토덱스트린', '기타', Grade.caution),
      },
      categoryLiquid: {'음료': true, '과자': false},
      comboRules: rules,
    );

const zeroDuo = ComboRule(
    comboKey: 'erythritol+sucralose', headline: '제로의 정석',
    message: '에리스리톨 + 수크랄로스 조합.', tone: 'info', priority: 100);
const maltitolNote = ComboRule(
    comboKey: 'maltitol', headline: '말티톨 주의보',
    message: '말티톨은 무설탕 표기여도 혈당을 올릴 수 있어요.', tone: 'warn', priority: 90);

void main() {
  test('다중 조합 규칙만 recipeCombo로 매칭', () {
    final p = product(carb: 3, sa: 3, serving: 355, category: '음료', sweeteners: const [
      ProductSweetener(slug: 'erythritol', sortOrder: 0),
      ProductSweetener(slug: 'sucralose', sortOrder: 1),
    ]);
    final it = Interpretation.of(p, refData(const [zeroDuo, maltitolNote]));
    expect(it.recipeCombo?.headline, '제로의 정석');
    expect(it.slugNotes, isEmpty);
  });

  test('단일 규칙은 slugNotes로만 매칭 (recipeCombo 아님)', () {
    final p = product(carb: 20, fiber: 1, sa: 15, kcal: 120, serving: 30,
        category: '과자', sweeteners: const [ProductSweetener(slug: 'maltitol', sortOrder: 0)]);
    final it = Interpretation.of(p, refData(const [zeroDuo, maltitolNote]));
    expect(it.recipeCombo, isNull);
    expect(it.slugNotes['maltitol']?.headline, '말티톨 주의보');
  });

  test('trapLines에 룰북 코드가 실린다', () {
    final p = product(carb: 20, fiber: 1, sa: 15, kcal: 120, serving: 30,
        category: '과자', sweeteners: const [ProductSweetener(slug: 'maltitol', sortOrder: 0)]);
    final it = Interpretation.of(p, refData(const []));
    expect(it.trapLines.map((l) => l.code), contains('당알코올 함정'));
  });
}
