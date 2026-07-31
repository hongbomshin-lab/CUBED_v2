import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/product_price.dart';

class PriceRepository {
  PriceRepository(this._db);
  final SupabaseClient _db;

  static const _priceCols =
      'id,product_id,channel,store,price,unit_count,promo_type,link_url,fetched_at';

  Future<List<ProductPrice>> forProduct(String productId) async {
    final rows = await _db
        .from('product_prices')
        .select(_priceCols)
        .eq('product_id', productId)
        .eq('is_active', true);
    final prices = rows.map((row) => ProductPrice.fromMap(row)).toList();
    prices.sort((a, b) => a.unitPrice.compareTo(b.unitPrice));
    return prices;
  }

  Future<List<HotDealItem>> hotDeals() async {
    final results = await Future.wait([
      _db
          .from('product_prices')
          .select('$_priceCols,products(product_id,name,brand,image_file)')
          .eq('is_active', true)
          .neq('promo_type', 'regular'),
      _db
          .from('product_prices')
          .select('product_id,price,unit_count')
          .eq('is_active', true)
          .eq('promo_type', 'regular'),
    ]);

    final regularByProduct = <String, int>{};
    for (final row in results[1]) {
      final productId = row['product_id'] as String;
      final unitPrice =
          ((row['price'] as num) / (row['unit_count'] as num)).round();
      final current = regularByProduct[productId];
      if (current == null || unitPrice < current) {
        regularByProduct[productId] = unitPrice;
      }
    }

    final deals = <HotDealItem>[];
    for (final row in results[0]) {
      final product = row['products'];
      if (product is! Map) continue;
      final productMap = Map<String, dynamic>.from(product);
      final offer = ProductPrice.fromMap(row);
      deals.add(HotDealItem(
        offer: offer,
        productId: productMap['product_id'] as String,
        name: productMap['name'] as String? ?? '',
        brand: productMap['brand'] as String?,
        imageFile: productMap['image_file'] as String?,
        regularUnitPrice: regularByProduct[offer.productId],
      ));
    }
    deals.sort((a, b) => a.offer.unitPrice.compareTo(b.offer.unitPrice));
    return deals;
  }
}
