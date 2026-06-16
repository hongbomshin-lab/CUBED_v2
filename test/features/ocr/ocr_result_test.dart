import 'package:flutter_test/flutter_test.dart';
import 'package:cubed_app/features/ocr/ocr_service.dart';

void main() {
  test('fromParsed: 파싱맵 → Product + 미지감미료', () {
    final m = <String, dynamic>{
      'name': '제로 콜라',
      'brand': '테스트',
      'category': '탄산음료',
      'serving_size': 355,
      'unit': 'ml',
      'kcal': 0, 'carb': 0, 'sugar': 0, 'protein': 0, 'fat': 0,
      'ingredients_raw': '정제수, 합성착향료, 수크랄로스, 아세설팜칼륨',
      'sweeteners': [
        {'slug': 'sucralose', 'amount_g': null},
        {'slug': 'acesulfame-potassium', 'amount_g': null},
      ],
      'unknown_sweeteners': ['신종감미료X'],
      'notes': null,
    };

    final r = OcrResult.fromParsed(m, barcode: '8801234567890');

    expect(r.product.name, '제로 콜라');
    expect(r.product.category, '탄산음료');
    expect(r.product.unit, 'ml');
    expect(r.product.barcode, '8801234567890');
    expect(r.product.verified, false);
    expect(r.product.sourceType, 'OCR제보');
    expect(r.product.sweeteners.length, 2);
    expect(r.product.sweeteners.first.slug, 'sucralose');
    expect(r.product.sweetenerCount, 2);
    expect(r.unknownSweeteners, ['신종감미료X']);
  });

  test('fromParsed: 누락 필드는 기본값', () {
    final r = OcrResult.fromParsed({'category': '과자/스낵', 'unit': 'g', 'sweeteners': []});
    expect(r.product.name, '촬영한 제품');
    expect(r.product.kcal, 0);
    expect(r.product.sweeteners, isEmpty);
  });
}
