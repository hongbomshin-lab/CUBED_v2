import 'sweetener.dart';

/// 제품 (products 테이블) + 조인된 감미료 목록
class Product {
  final String productId;
  final String name;
  final String? brand;
  final String? category;
  final double servingSize;
  final String unit; // 'ml' | 'g'
  final double kcal;
  final double carb;
  final double sugar;
  final double protein;
  final double fat;
  final double? sodiumMg;
  final double fiber;
  final double sugarAlcohol;
  final double rareSugarG;
  final String? ingredientsRaw;
  final String? sweetenerSummary;
  final int sweetenerCount;
  final String? barcode;
  final String? imageFile;
  final String? sourceType;
  final bool verified;
  final String? notes;
  final List<ProductSweetener> sweeteners;

  const Product({
    required this.productId,
    required this.name,
    this.brand,
    this.category,
    required this.servingSize,
    required this.unit,
    required this.kcal,
    required this.carb,
    required this.sugar,
    required this.protein,
    required this.fat,
    this.sodiumMg,
    required this.fiber,
    required this.sugarAlcohol,
    required this.rareSugarG,
    this.ingredientsRaw,
    this.sweetenerSummary,
    required this.sweetenerCount,
    this.barcode,
    this.imageFile,
    this.sourceType,
    required this.verified,
    this.notes,
    this.sweeteners = const [],
  });

  List<String> get slugs => sweeteners.map((e) => e.slug).toList();

  /// 한 단위 표현: "1캔(355ml)" / "1개(50g)"
  String get unitDesc {
    final n = servingSize == servingSize.roundToDouble()
        ? servingSize.toInt().toString()
        : servingSize.toString();
    return '1회분($n$unit)';
  }

  static double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;

  factory Product.fromMap(Map<String, dynamic> m) {
    final rawSweeteners = (m['product_sweeteners'] as List?) ?? const [];
    final list = rawSweeteners
        .map((e) => ProductSweetener.fromMap(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return Product(
      productId: m['product_id'] as String,
      name: m['name'] as String? ?? '',
      brand: m['brand'] as String?,
      category: m['category'] as String?,
      servingSize: _d(m['serving_size']),
      unit: (m['unit'] as String?) ?? 'g',
      kcal: _d(m['kcal']),
      carb: _d(m['carb']),
      sugar: _d(m['sugar']),
      protein: _d(m['protein']),
      fat: _d(m['fat']),
      sodiumMg: (m['sodium_mg'] as num?)?.toDouble(),
      fiber: _d(m['fiber']),
      sugarAlcohol: _d(m['sugar_alcohol']),
      rareSugarG: _d(m['rare_sugar_g']),
      ingredientsRaw: m['ingredients_raw'] as String?,
      sweetenerSummary: m['sweetener_summary'] as String?,
      sweetenerCount: (m['sweetener_count'] as num?)?.toInt() ?? 0,
      barcode: m['barcode'] as String?,
      imageFile: m['image_file'] as String?,
      sourceType: m['source_type'] as String?,
      verified: (m['verified'] as bool?) ?? false,
      notes: m['notes'] as String?,
      sweeteners: list,
    );
  }
}

class ComboRule {
  final String comboKey;
  final String headline;
  final String message;
  final String tone; // info | warn | fun
  final int priority;
  const ComboRule({
    required this.comboKey,
    required this.headline,
    required this.message,
    required this.tone,
    required this.priority,
  });

  List<String> get keySlugs => comboKey.split('+');

  factory ComboRule.fromMap(Map<String, dynamic> m) => ComboRule(
        comboKey: m['combo_key'] as String,
        headline: m['headline'] as String,
        message: m['message'] as String,
        tone: (m['tone'] as String?) ?? 'info',
        priority: (m['priority'] as num?)?.toInt() ?? 0,
      );
}
