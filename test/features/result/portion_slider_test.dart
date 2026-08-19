import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cubed_app/features/result/widgets/portion_slider.dart';

void main() {
  test('1배: 그대로', () {
    expect(portionSummary(factor: 1, netCarb: 4, kcal: 120), '순탄수 4g · 120kcal');
  });
  test('1.5배: 소수 1자리 반올림', () {
    expect(portionSummary(factor: 1.5, netCarb: 4.1, kcal: 120), '순탄수 6.2g · 180kcal');
  });
  test('0.5배', () {
    expect(portionSummary(factor: 0.5, netCarb: 4, kcal: 121), '순탄수 2g · 61kcal');
  });
  test('소수 2자리 순탄수 × 1.5배: 이중 반올림 없이 정확', () {
    expect(portionSummary(factor: 1.5, netCarb: 4.16, kcal: 100), '순탄수 6.2g · 150kcal');
  });
  test('소수 2자리 순탄수 × 3배: 경계값 100', () {
    expect(portionSummary(factor: 3, netCarb: 33.33, kcal: 50), '순탄수 100g · 150kcal');
  });
  testWidgets('긴 unitDesc도 오버플로 없이 렌더링', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: PortionSlider(
                productId: 'p1',
                netCarb: 4,
                kcal: 120,
                unitDesc: '1회분(123.456789012345678ml)'),
          ),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(find.text('이만큼 먹으면?'), findsOneWidget);
  });
}
