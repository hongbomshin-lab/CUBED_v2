import 'package:flutter_test/flutter_test.dart';
import 'package:cubed_app/data/models/food_log.dart';
import 'package:cubed_app/features/diary/log_image_url.dart';

FoodLog _log({String? productId, String? imagePath}) => FoodLog(
      id: 'x',
      eatenOn: DateTime(2026, 7, 11),
      productId: productId,
      name: '테스트',
      imagePath: imagePath,
    );

void main() {
  test('DB 제품 → product-images 공개 URL ({product_id}.png 규칙)', () {
    final r = logImageUrl(_log(productId: 'P1'));
    expect(r, isNotNull);
    expect(r!.needsAuth, isFalse);
    expect(r.url, endsWith('/storage/v1/object/public/product-images/P1.png'));
  });

  test('촬영 제품 → submission-images authenticated URL', () {
    final r = logImageUrl(_log(imagePath: 'folder-1'));
    expect(r, isNotNull);
    expect(r!.needsAuth, isTrue);
    expect(
        r.url,
        endsWith(
            '/storage/v1/object/authenticated/submission-images/folder-1/full.jpg'));
  });

  test('둘 다 없으면 null (placeholder)', () {
    expect(logImageUrl(_log()), isNull);
  });
}
