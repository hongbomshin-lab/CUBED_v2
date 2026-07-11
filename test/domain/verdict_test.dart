// test/domain/verdict_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cubed_app/core/rulebook.dart';
import 'package:cubed_app/data/models/product.dart';
import 'package:cubed_app/data/models/sweetener.dart';
import 'package:cubed_app/data/product_repository.dart';
import 'package:cubed_app/domain/interpretation.dart';
import 'package:cubed_app/domain/verdict.dart';

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

const maltitolNote = ComboRule(
    comboKey: 'maltitol', headline: '말티톨 주의보',
    message: '말티톨은 무설탕 표기여도 혈당을 올릴 수 있어요.', tone: 'warn', priority: 90);
const maltodextrinNote = ComboRule(
    comboKey: 'maltodextrin', headline: '숨은 고GI 주의',
    message: '말토덱스트린은 혈당을 빨리 올릴 수 있어요.', tone: 'warn', priority: 85);

Interpretation interp(Product p, List<ComboRule> rules) =>
    Interpretation.of(p, refData(rules));

void main() {
  final maltitolSnack = product(carb: 20, fiber: 1, sa: 15, kcal: 120, serving: 30,
      category: '과자', sweeteners: const [ProductSweetener(slug: 'maltitol', sortOrder: 0)]);
  final zeroDrink = product(carb: 3, sa: 3, serving: 355, category: '음료',
      sweeteners: const [
        ProductSweetener(slug: 'erythritol', sortOrder: 0),
        ProductSweetener(slug: 'sucralose', sortOrder: 1),
      ]);

  test('무설탕인데 함정 → zeroBusted, 혈당 올라요', () {
    final v = Verdict.of(interp(maltitolSnack, const []));
    expect(v.kind, VerdictKind.zeroBusted);
    expect(v.realityText, '혈당 올라요');
  });

  test('당알코올 함정 불릿은 단일 규칙 카피로 대체(중복 제거)', () {
    final v = Verdict.of(interp(maltitolSnack, const [maltitolNote]));
    expect(v.whyBullets, contains(maltitolNote.message));
    expect(v.whyBullets.where((b) => b.contains('때문에 혈당이 오를 수')), isEmpty);
  });

  test('진짜 제로 → zeroTrue, 진짜예요', () {
    final v = Verdict.of(interp(zeroDrink, const []));
    expect(v.kind, VerdictKind.zeroTrue);
    expect(v.realityText, '진짜예요');
    expect(v.whyBullets, isNotEmpty); // 폴백: 등급 설명 문장
  });

  test('당류 있는 일반 제품 → generic, 스트립 없음', () {
    final p = product(sugar: 12, carb: 20, kcal: 150, serving: 50, category: '과자');
    final v = Verdict.of(interp(p, const []));
    expect(v.kind, VerdictKind.generic);
    expect(v.labelText, '');
  });

  test('함정에 안 잡힌 warn 단일 규칙은 불릿으로 승격, 최대 3개', () {
    final p = product(carb: 25, sa: 15, kcal: 200, serving: 30, category: '과자',
        sweeteners: const [
          ProductSweetener(slug: 'maltitol', sortOrder: 0),
          ProductSweetener(slug: 'maltodextrin', sortOrder: 1),
        ]);
    final v = Verdict.of(interp(p, const [maltitolNote, maltodextrinNote]));
    expect(v.whyBullets, contains(maltodextrinNote.message));
    expect(v.whyBullets.length, lessThanOrEqualTo(3));
  });
}
