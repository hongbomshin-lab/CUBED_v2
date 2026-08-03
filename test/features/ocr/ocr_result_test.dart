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
      'kcal': 0,
      'carb': 0,
      'sugar': 0,
      'protein': 0,
      'fat': 0,
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
    final r = OcrResult.fromParsed(
        {'category': '과자/스낵', 'unit': 'g', 'sweeteners': []});
    expect(r.product.name, '촬영한 제품');
    expect(r.product.kcal, 0);
    expect(r.product.sweeteners, isEmpty);
  });

  test('fromParsed: image_path → imagePath', () {
    final r = OcrResult.fromParsed({
      'category': '과자/스낵',
      'unit': 'g',
      'sweeteners': [],
      'image_path': 'abc-123-folder',
    });
    expect(r.imagePath, 'abc-123-folder');
  });

  test('fromParsed: image_path 없으면 imagePath null', () {
    final r = OcrResult.fromParsed(
        {'category': '과자/스낵', 'unit': 'g', 'sweeteners': []});
    expect(r.imagePath, isNull);
  });

  test('fromParsed: 등록 제품 매칭 시 DB Product를 결과에 사용한다', () {
    final r = OcrResult.fromParsed({
      'name': 'OCR 제품명',
      'unit': 'g',
      'sweeteners': <Map<String, dynamic>>[],
      'matched_product': {
        'product_id': 'lala-1',
        'name': '라라스윗 저당 초콜릿 초코바',
        'brand': '라라스윗',
        'serving_size': 90,
        'unit': 'ml',
        'verified': true,
        'product_sweeteners': <Map<String, dynamic>>[],
      },
    });

    expect(r.product.productId, 'lala-1');
    expect(r.product.name, '라라스윗 저당 초콜릿 초코바');
    expect(r.product.verified, true);
  });

  test('fromParsed: 미등록 제품의 가격 카탈로그 매칭을 보존한다', () {
    final r = OcrResult.fromParsed({
      'name': '라라스윗 자두 제로바',
      'brand': '라라스윗',
      'unit': 'g',
      'sweeteners': <Map<String, dynamic>>[],
      'price_match': {
        'catalog_product_key': 'lalasweet:zero-bar:plum',
        'catalog_name': '라라스윗 자두 제로바',
        'confidence': 0.92,
      },
    });

    expect(r.product.productId, 'ocr-temp');
    expect(r.priceCatalogKey, 'lalasweet:zero-bar:plum');
    expect(r.priceCatalogName, '라라스윗 자두 제로바');
    expect(r.priceMatchConfidence, 0.92);
  });
}
