import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/product_price.dart';

class PriceRepository {
  PriceRepository(this._db);
  final SupabaseClient _db;

  static const _priceCols =
      'id,product_id,catalog_product_key,catalog_name,brand,'
      'channel,store,price,unit_count,promo_type,offer_kind,'
      'minimum_order_amount,offer_key,offer_title,offer_note,link_url,fetched_at';

  Future<List<ProductPrice>> forProduct({
    String? productId,
    String? catalogProductKey,
  }) async {
    var query =
        _db.from('product_prices').select(_priceCols).eq('is_active', true);
    if (catalogProductKey != null) {
      query = query.eq('catalog_product_key', catalogProductKey);
    } else if (productId != null) {
      query = query.eq('product_id', productId);
    } else {
      return const [];
    }
    final rows = await query;
    final prices = rows.map((row) => ProductPrice.fromMap(row)).toList();
    prices.sort((a, b) => a.unitPrice.compareTo(b.unitPrice));
    return prices;
  }
}
