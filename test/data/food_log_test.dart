import 'package:flutter_test/flutter_test.dart';
import 'package:cubed_app/data/models/food_log.dart';

void main() {
  test('fromMap: DB row → FoodLog', () {
    final log = FoodLog.fromMap({
      'id': 'uuid-1',
      'eaten_on': '2026-07-11',
      'product_id': '0TKKSWYBWCTQH',
      'name': '1500저당바더블초코',
      'brand': '서주',
      'category': '아이스크림/빙과',
      'grade': 'mid',
      'image_path': null,
    });
    expect(log.id, 'uuid-1');
    expect(log.eatenOn, DateTime(2026, 7, 11));
    expect(log.productId, '0TKKSWYBWCTQH');
    expect(log.name, '1500저당바더블초코');
    expect(log.brand, '서주');
    expect(log.category, '아이스크림/빙과');
    expect(log.grade, 'mid');
    expect(log.imagePath, isNull);
  });

  test('dateKey: 한 자리 월·일 zero-pad', () {
    expect(FoodLog.dateKey(DateTime(2026, 7, 3)), '2026-07-03');
    expect(FoodLog.dateKey(DateTime(2026, 11, 25)), '2026-11-25');
  });

  test('insertMap: eaten_on은 dateKey 포맷', () {
    final m = FoodLog.insertMap(
      userId: 'u1',
      eatenOn: DateTime(2026, 7, 11, 23, 59), // 시각은 무시
      productId: null,
      name: '촬영한 제품',
      grade: 'low',
      imagePath: 'folder-uuid',
    );
    expect(m['user_id'], 'u1');
    expect(m['eaten_on'], '2026-07-11');
    expect(m['product_id'], isNull);
    expect(m['name'], '촬영한 제품');
    expect(m['grade'], 'low');
    expect(m['image_path'], 'folder-uuid');
  });

  test('matches: DB 제품은 product_id로 판정', () {
    final log = FoodLog.fromMap({
      'id': 'a', 'eaten_on': '2026-07-11',
      'product_id': 'P1', 'name': '제로콜라',
    });
    expect(log.matches(productId: 'P1', name: '다른이름'), isTrue);
    expect(log.matches(productId: 'P2', name: '제로콜라'), isFalse);
    // 촬영 제품(productId null) 쿼리는 DB 제품 기록과 매칭 안 됨
    expect(log.matches(productId: null, name: '제로콜라'), isFalse);
  });

  test('matches: 촬영 제품은 소문자 이름으로 판정 (dedup index와 동일 규칙)', () {
    final log = FoodLog.fromMap({
      'id': 'b', 'eaten_on': '2026-07-11',
      'product_id': null, 'name': 'Zero Bar',
    });
    expect(log.matches(productId: null, name: 'zero bar'), isTrue);
    expect(log.matches(productId: null, name: '딴제품'), isFalse);
    expect(log.matches(productId: 'P1', name: 'Zero Bar'), isFalse);
  });
}
