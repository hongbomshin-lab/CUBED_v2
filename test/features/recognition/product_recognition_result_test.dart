import 'package:cubed_app/features/recognition/product_recognition_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('성공 응답에서 DB Product를 파싱한다', () {
    final result = ProductRecognitionResult.fromMap({
      'matched': true,
      'confidence': 0.94,
      'reason': '제품명과 맛 표기 일치',
      'product': {
        'product_id': 'p1',
        'name': '라라스윗 저당 초콜릿 초코바',
        'brand': '라라스윗',
        'serving_size': 90,
        'unit': 'ml',
        'verified': false,
        'product_sweeteners': <Map<String, dynamic>>[],
      },
    });

    expect(result.matched, true);
    expect(result.confidence, 0.94);
    expect(result.product?.productId, 'p1');
    expect(result.product?.brand, '라라스윗');
  });

  test('미인식 응답은 product null을 유지한다', () {
    final result = ProductRecognitionResult.fromMap({
      'matched': false,
      'confidence': 0.42,
      'reason': '후보와 일치하지 않음',
      'product': null,
    });

    expect(result.matched, false);
    expect(result.product, isNull);
  });
}
