import 'package:flutter_test/flutter_test.dart';
import 'package:cubed_app/features/ocr/ocr_service.dart';

void main() {
  test('parsed map 편집 → Product 반영(순수)', () {
    final m = <String, dynamic>{
      'name': '테스트 음료', 'category': '과일음료', 'unit': 'ml',
      'serving_size': 500, 'carb': 6, 'rare_sugar_g': 3.3,
      'sweeteners': [{'slug': 'allulose', 'amount_g': 3.3}], 'unknown_sweeteners': <String>[],
    };
    final r = OcrResult.fromParsed(m);
    expect(r.product.rareSugarG, 3.3);
    expect(r.product.carb, 6);
    expect(r.product.sweeteners.single.slug, 'allulose');
  });
}
