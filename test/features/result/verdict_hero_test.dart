// test/features/result/verdict_hero_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cubed_app/core/rulebook.dart';
import 'package:cubed_app/data/models/product.dart';
import 'package:cubed_app/data/models/sweetener.dart';
import 'package:cubed_app/data/product_repository.dart';
import 'package:cubed_app/domain/interpretation.dart';
import 'package:cubed_app/features/result/widgets/verdict_hero.dart';

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

ReferenceData refData() => ReferenceData(
      sweeteners: {
        'maltitol': sw('maltitol', '말티톨', '당알코올', Grade.caution),
        'erythritol': sw('erythritol', '에리스리톨', '당알코올', Grade.low),
      },
      categoryLiquid: {'음료': true, '과자': false},
      comboRules: const [],
    );

Widget host(Interpretation it) => ProviderScope(
    child: MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: VerdictHero(it: it)))));

void main() {
  testWidgets('반전 케이스: 라벨 vs 실제 스트립 표시', (tester) async {
    final p = product(carb: 20, fiber: 1, sa: 15, kcal: 120, serving: 30,
        category: '과자', sweeteners: const [ProductSweetener(slug: 'maltitol', sortOrder: 0)]);
    await tester.pumpWidget(host(Interpretation.of(p, refData())));
    expect(find.text('무설탕·제로'), findsOneWidget);
    expect(find.text('혈당 올라요'), findsOneWidget);
  });

  testWidgets('진짜 제로: 진짜예요 확인 스트립', (tester) async {
    final p = product(carb: 3, sa: 3, serving: 355, category: '음료',
        sweeteners: const [ProductSweetener(slug: 'erythritol', sortOrder: 0)]);
    await tester.pumpWidget(host(Interpretation.of(p, refData())));
    expect(find.text('진짜예요'), findsOneWidget);
  });

  testWidgets('일반 제품: 스트립 없이 등급 배지', (tester) async {
    final p = product(sugar: 12, carb: 20, kcal: 150, serving: 50, category: '과자');
    await tester.pumpWidget(host(Interpretation.of(p, refData())));
    expect(find.text('무설탕·제로'), findsNothing);
    expect(find.text('혈당 주의'), findsOneWidget);
  });

  testWidgets('함정 없는 일반 제품: 등급 설명이 한 번만 보인다', (tester) async {
    final p = product(sugar: 1, carb: 4, kcal: 20, serving: 100, category: '과자');
    await tester.pumpWidget(host(Interpretation.of(p, refData())));
    expect(find.text('혈당을 거의 올리지 않아요.'), findsOneWidget);
  });
}
