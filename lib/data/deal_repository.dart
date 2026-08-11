import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/brand_deal.dart';

/// 브랜드 특가 데이터 접근 (brand_deals). 앱은 읽기만.
class DealRepository {
  DealRepository(this._db);
  final SupabaseClient _db;

  /// 필터 칩용 브랜드 목록 (slug, 표시명).
  static const brands = [
    (slug: 'lalasweet', label: '라라스윗'),
    (slug: 'nuldam', label: '널담'),
    (slug: 'mynormal', label: '마이노멀'),
  ];

  /// 카테고리 필터 라벨 (crawler classifyCategory 와 일치).
  static const categories = [
    '아이스크림', '빵', '디저트', '과자', '음료', '단백바',
    '소스/드레싱', '감미료/시럽', '잼/스프레드',
  ];

  /// 활성 특가 조회. is_deal=true & 종료 안 된 것만.
  Future<List<BrandDeal>> deals({
    String? brandSlug,
    String? category,
    DealSort sort = DealSort.discount,
  }) async {
    var q = _db
        .from('brand_deals')
        .select('*, crawl_brands(display_name)')
        .eq('is_deal', true)
        .isFilter('ended_at', null);

    if (brandSlug != null) q = q.eq('brand_slug', brandSlug);
    if (category != null) q = q.eq('category', category);

    final rows = await switch (sort) {
      DealSort.discount => q.order('discount_rate', ascending: false),
      DealSort.latest => q.order('last_seen_at', ascending: false),
    }.limit(300);

    return rows.map((m) => BrandDeal.fromMap(m)).toList();
  }
}

/// 핫딜 조회 파라미터 — provider family 키(불변·값 동등성).
class DealQuery {
  final String? brandSlug;
  final String? category;
  final DealSort sort;
  const DealQuery({this.brandSlug, this.category, this.sort = DealSort.discount});

  @override
  bool operator ==(Object other) =>
      other is DealQuery &&
      other.brandSlug == brandSlug &&
      other.category == category &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(brandSlug, category, sort);
}
