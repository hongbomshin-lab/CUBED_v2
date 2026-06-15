import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/rulebook.dart';
import 'models/product.dart';
import 'models/sweetener.dart';

/// 앱 시작 시 1회 로드하는 기준 데이터 (감미료·카테고리·조합규칙)
class ReferenceData {
  final Map<String, Sweetener> sweeteners; // slug -> Sweetener
  final Map<String, bool> categoryLiquid; // category -> is_liquid
  final List<ComboRule> comboRules;

  const ReferenceData({
    required this.sweeteners,
    required this.categoryLiquid,
    required this.comboRules,
  });

  /// 룰북용 giMap (slug -> Grade)
  Map<String, Grade> get giMap =>
      {for (final e in sweeteners.entries) e.key: e.value.glycemicImpact};

  bool isLiquid(String? category) => categoryLiquid[category] ?? false;
  String nameOf(String slug) => sweeteners[slug]?.standardName ?? slug;
}

class ProductRepository {
  ProductRepository(this._db);
  final SupabaseClient _db;

  static const _productCols =
      'product_id,name,brand,category,serving_size,unit,kcal,carb,sugar,protein,fat,'
      'sodium_mg,fiber,sugar_alcohol,rare_sugar_g,ingredients_raw,sweetener_summary,'
      'sweetener_count,barcode,image_file,source_type,verified,notes,'
      'product_sweeteners(slug,amount_g,sort_order)';

  /// 기준 데이터 일괄 로드
  Future<ReferenceData> loadReference() async {
    final sw = await _db.from('sweeteners').select();
    final cat = await _db.from('category_meta').select('category,is_liquid');
    final combo = await _db.from('combo_rules').select().eq('active', true);

    return ReferenceData(
      sweeteners: {
        for (final m in sw) (m['slug'] as String): Sweetener.fromMap(m),
      },
      categoryLiquid: {
        for (final m in cat) (m['category'] as String): (m['is_liquid'] as bool? ?? false),
      },
      comboRules: combo.map((m) => ComboRule.fromMap(m)).toList(),
    );
  }

  /// 바코드로 제품 1개 조회 (없으면 null)
  Future<Product?> findByBarcode(String barcode) async {
    final rows = await _db
        .from('products')
        .select(_productCols)
        .eq('barcode', barcode)
        .limit(1);
    if (rows.isEmpty) return null;
    return Product.fromMap(rows.first);
  }

  /// 이름 검색 (OCR 폴백/수동 검색)
  Future<List<Product>> searchByName(String q, {int limit = 20}) async {
    final rows = await _db
        .from('products')
        .select(_productCols)
        .ilike('name', '%$q%')
        .limit(limit);
    return rows.map((m) => Product.fromMap(m)).toList();
  }

  /// 카테고리별 목록 (둘러보기)
  Future<List<Product>> byCategory(String category, {int limit = 50}) async {
    final rows = await _db
        .from('products')
        .select(_productCols)
        .eq('category', category)
        .limit(limit);
    return rows.map((m) => Product.fromMap(m)).toList();
  }

  /// 같은 카테고리에서 '더 나은' 대안 후보 (킬러 피처용 원천 데이터)
  Future<List<Product>> alternativesIn(String category, String excludeId,
      {int limit = 30}) async {
    final rows = await _db
        .from('products')
        .select(_productCols)
        .eq('category', category)
        .neq('product_id', excludeId)
        .limit(limit);
    return rows.map((m) => Product.fromMap(m)).toList();
  }

  /// OCR 제보 (미등록 제품) — user_submissions insert
  Future<void> submitOcr({
    String? barcode,
    String? ocrText,
    Map<String, dynamic>? parsed,
    String? imagePath,
  }) async {
    await _db.from('user_submissions').insert({
      'barcode': barcode,
      'ocr_text': ocrText,
      'parsed': parsed,
      'image_path': imagePath,
      'status': 'pending',
    });
  }
}
