/// 브랜드 특가 (brand_deals + crawl_brands 조인). 핫딜 탭이 읽는 모델.
class BrandDeal {
  final String id;
  final String brandSlug;
  final String brandName; // crawl_brands.display_name
  final String name;
  final String? summary;
  final int? listPrice; // 할인 전(없으면 단일가)
  final int salePrice;
  final double discountRate; // 0이면 할인 없음
  final String productUrl;
  final String? imageUrl;
  final String? category;
  final bool isSoldout;
  final List<String> dealSignals;

  const BrandDeal({
    required this.id,
    required this.brandSlug,
    required this.brandName,
    required this.name,
    this.summary,
    this.listPrice,
    required this.salePrice,
    required this.discountRate,
    required this.productUrl,
    this.imageUrl,
    this.category,
    this.isSoldout = false,
    this.dealSignals = const [],
  });

  bool get hasDiscount => listPrice != null && listPrice! > salePrice;

  /// 이름 앞 [태그] 분리 → (태그, 순수이름). 없으면 (null, 이름).
  (String?, String) get tagAndName {
    final m = RegExp(r'^\s*\[([^\]]+)\]\s*(.+)$').firstMatch(name);
    if (m != null) return (m.group(1)!.trim(), m.group(2)!.trim());
    return (null, name);
  }

  static int? _i(dynamic v) => v == null ? null : (v as num).toInt();

  factory BrandDeal.fromMap(Map<String, dynamic> m) {
    // crawl_brands 조인은 {brand: {display_name}} 또는 평면 컬럼으로 올 수 있어 모두 방어.
    String brandName = m['brand_slug'] as String? ?? '';
    final b = m['crawl_brands'];
    if (b is Map && b['display_name'] is String) {
      brandName = b['display_name'] as String;
    } else if (m['brand_name'] is String) {
      brandName = m['brand_name'] as String;
    }
    return BrandDeal(
      id: m['id'] as String,
      brandSlug: m['brand_slug'] as String,
      brandName: brandName,
      name: m['name'] as String,
      summary: (m['summary'] as String?)?.trim().isEmpty ?? true
          ? null
          : (m['summary'] as String).trim(),
      listPrice: _i(m['list_price']),
      salePrice: _i(m['sale_price']) ?? 0,
      discountRate: (m['discount_rate'] as num?)?.toDouble() ?? 0,
      productUrl: m['product_url'] as String,
      imageUrl: (m['image_url'] as String?)?.trim().isEmpty ?? true
          ? null
          : (m['image_url'] as String).trim(),
      category: (m['category'] as String?)?.trim().isEmpty ?? true
          ? null
          : (m['category'] as String).trim(),
      isSoldout: (m['is_soldout'] as bool?) ?? false,
      dealSignals: (m['deal_signals'] as List?)?.cast<String>() ?? const [],
    );
  }
}

/// 핫딜 정렬 기준.
enum DealSort {
  discount('할인율순'),
  latest('최신순');

  const DealSort(this.label);
  final String label;
}
