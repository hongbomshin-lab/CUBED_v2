import 'package:cubed_app/data/models/product_price.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fetchedAt = DateTime.parse('2026-07-31T03:00:00Z');

  test('묶음 총액을 개당가로 반올림한다', () {
    final price = ProductPrice(
      id: 'price-1',
      productId: 'product-1',
      channel: 'brand_mall',
      store: '라라스윗 공식몰',
      price: 20900,
      unitCount: 8,
      promoType: 'bundle',
      fetchedAt: fetchedAt,
    );

    expect(price.unitPrice, 2613);
    expect(price.channelLabel, '공식몰');
    expect(price.promoLabel, '묶음');
  });

  test('정가 대비 개당 할인율을 계산한다', () {
    final deal = HotDealItem(
      offer: ProductPrice(
        id: 'price-1',
        productId: 'product-1',
        channel: 'brand_mall',
        store: '라라스윗 공식몰',
        price: 20900,
        unitCount: 8,
        promoType: 'bundle',
        fetchedAt: fetchedAt,
      ),
      productId: 'product-1',
      name: '저당 초콜릿 초코바',
      regularUnitPrice: 3300,
    );

    expect(deal.discountRate, 21);
  });
}
