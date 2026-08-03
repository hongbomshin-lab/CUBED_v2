import 'package:cubed_app/data/models/product_price.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fetchedAt = DateTime.parse('2026-07-31T03:00:00Z');

  test('묶음 총액을 개당가로 반올림한다', () {
    final price = ProductPrice(
      id: 'price-1',
      productId: 'product-1',
      catalogProductKey: 'product:product-1',
      catalogName: '저당 초콜릿 초코바',
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
        catalogProductKey: 'product:product-1',
        catalogName: '저당 초콜릿 초코바',
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

  test('행사명과 구매 조건을 DB 응답에서 읽는다', () {
    final price = ProductPrice.fromMap({
      'id': 'price-2',
      'product_id': 'product-1',
      'catalog_product_key': 'lalasweet:popcorn:corn-soup',
      'catalog_name': '라라스윗 저당 콘스프맛 팝콘',
      'channel': 'brand_mall',
      'store': '라라스윗 공식몰',
      'price': 2970,
      'unit_count': 3,
      'promo_type': 'sale',
      'offer_key': 'lalasweet-250-addon',
      'offer_title': '제과 베스트 990원딜',
      'offer_note': '제과 2세트 구매 후 추가 옵션 선택 시',
      'offer_kind': 'conditional_addon',
      'minimum_order_amount': 34000,
      'fetched_at': '2026-08-02T01:00:00Z',
    });

    expect(price.unitPrice, 990);
    expect(price.offerTitle, '제과 베스트 990원딜');
    expect(price.offerNote, contains('추가 옵션'));
    expect(price.isConditional, true);
    expect(price.minimumOrderAmount, 34000);
  });
}
