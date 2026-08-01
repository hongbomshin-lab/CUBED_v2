class ProductPrice {
  const ProductPrice({
    required this.id,
    required this.productId,
    required this.channel,
    required this.store,
    required this.price,
    required this.unitCount,
    required this.promoType,
    this.offerKey,
    this.offerTitle,
    this.offerNote,
    this.linkUrl,
    required this.fetchedAt,
  });

  final String id;
  final String productId;
  final String channel;
  final String store;
  final int price;
  final int unitCount;
  final String promoType;
  final String? offerKey;
  final String? offerTitle;
  final String? offerNote;
  final String? linkUrl;
  final DateTime fetchedAt;

  int get unitPrice => (price / unitCount).round();
  bool get isRegular => promoType == 'regular';

  String get channelLabel => switch (channel) {
        'convenience' => '편의점',
        'online' => '온라인',
        'brand_mall' => '공식몰',
        _ => channel,
      };

  String get promoLabel => switch (promoType) {
        'sale' => '할인',
        'one_plus_one' => '1+1',
        'two_plus_one' => '2+1',
        'bundle' => '묶음',
        _ => '정가',
      };

  factory ProductPrice.fromMap(Map<String, dynamic> map) => ProductPrice(
        id: map['id'] as String,
        productId: map['product_id'] as String,
        channel: map['channel'] as String,
        store: map['store'] as String,
        price: (map['price'] as num).toInt(),
        unitCount: (map['unit_count'] as num?)?.toInt() ?? 1,
        promoType: map['promo_type'] as String? ?? 'regular',
        offerKey: map['offer_key'] as String?,
        offerTitle: map['offer_title'] as String?,
        offerNote: map['offer_note'] as String?,
        linkUrl: map['link_url'] as String?,
        fetchedAt: DateTime.parse(map['fetched_at'] as String),
      );
}

class HotDealItem {
  const HotDealItem({
    required this.offer,
    required this.productId,
    required this.name,
    this.brand,
    this.imageFile,
    this.regularUnitPrice,
  });

  final ProductPrice offer;
  final String productId;
  final String name;
  final String? brand;
  final String? imageFile;
  final int? regularUnitPrice;

  int? get discountRate {
    final regular = regularUnitPrice;
    if (regular == null || regular <= offer.unitPrice) return null;
    return ((regular - offer.unitPrice) / regular * 100).round();
  }
}
