import 'package:flutter_test/flutter_test.dart';

import 'package:cubed_app/core/sugar_baselines.dart';

void main() {
  group('sugarBaselineFor', () {
    test('카테고리 기본값 매칭', () {
      final r = sugarBaselineFor(category: '탄산음료', name: '코카콜라 제로');
      expect(r?.baselineG, 27);
    });

    test('키워드 규칙이 기본값보다 우선', () {
      expect(
          sugarBaselineFor(category: '아이스크림/빙과', name: '라라스윗 저당 바닐라 아이스크림 콘')
              ?.baselineG,
          22); // 콘 규칙
      expect(sugarBaselineFor(category: '아이스크림/빙과', name: '라라스윗 저당 멜론바')
              ?.baselineG,
          14); // 기본(바)
      expect(
          sugarBaselineFor(category: '커피', name: '제로 스위트 아메리카노')?.baselineG,
          10);
      expect(sugarBaselineFor(category: '커피', name: '저당 카라멜 라떼')?.baselineG, 22);
      expect(sugarBaselineFor(category: '차/티음료', name: '팔도 비락 식혜 제로')
              ?.baselineG,
          20);
    });

    test('셰이크/쉐이크 표기 변형 모두 매칭', () {
      expect(sugarBaselineFor(category: '아이스크림/빙과', name: '저당 설레임 밀크셰이크')
              ?.baselineG,
          26);
      expect(sugarBaselineFor(category: '아이스크림/빙과', name: '라라스윗 저당 밀크 쉐이크')
              ?.baselineG,
          26);
    });

    test('모르는 카테고리/null은 null', () {
      expect(sugarBaselineFor(category: '없는카테고리', name: 'x'), isNull);
      expect(sugarBaselineFor(category: null, name: 'x'), isNull);
    });

    test('모든 규칙: 키워드 규칙은 같은 카테고리 기본값보다 앞에 선언되어야 함', () {
      final seenDefault = <String>{};
      for (final r in kSugarBaselines) {
        if (r.keywords == null) {
          seenDefault.add(r.category);
        } else {
          expect(seenDefault.contains(r.category), isFalse,
              reason: '${r.category} 키워드 규칙이 기본값 뒤에 선언됨');
        }
      }
      // 모든 카테고리에 기본값 규칙 존재
      final categories = kSugarBaselines.map((r) => r.category).toSet();
      expect(seenDefault, categories);
    });
  });

  group('sugarPointsFor', () {
    test('포인트 = 기준값 - 당류 (반올림)', () {
      expect(
          sugarPointsFor(category: '탄산음료', name: '코카콜라 제로', sugar: 0), 27);
      expect(sugarPointsFor(category: '젤리', name: '맛있는 곤약젤리 망고', sugar: 0.9),
          39);
    });

    test('당류가 기준값 이상이면 0 (음수 없음)', () {
      expect(sugarPointsFor(category: '차/티음료', name: '가당 아이스티', sugar: 42), 0);
    });

    test('기준값 없으면 0', () {
      expect(sugarPointsFor(category: null, name: 'x', sugar: 0), 0);
    });
  });

  test('sugarCubesFor: 각설탕 3g 환산', () {
    expect(sugarCubesFor(27), 9);
    expect(sugarCubesFor(0), 0);
  });
}
