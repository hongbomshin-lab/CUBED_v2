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

  /// 한 페이지 크기 ("더보기" 단위).
  static const pageSize = 20;

  /// 활성 특가 조회. is_deal=true & 종료 안 된 것만. 페이지 단위(부하 절감).
  /// [query] 상품명 부분일치(대소문자 무시). 공백은 토큰 AND.
  /// [offset] 건너뛸 개수(페이지×pageSize).
  Future<List<BrandDeal>> deals({
    String query = '',
    String? brandSlug,
    String? category,
    DealSort sort = DealSort.discount,
    int offset = 0,
    int limit = pageSize,
  }) async {
    var q = _db
        .from('brand_deals')
        .select('*, crawl_brands(display_name)')
        .eq('is_deal', true)
        .isFilter('ended_at', null);

    if (brandSlug != null) q = q.eq('brand_slug', brandSlug);
    if (category != null) q = q.eq('category', category);

    // 각 토큰이 상품명에 포함(부분일치). 토큰 간 AND.
    for (final tok in query.trim().split(RegExp(r'\s+'))) {
      if (tok.isEmpty) continue;
      final esc = tok.replaceAll('%', r'\%').replaceAll('_', r'\_');
      q = q.ilike('name', '%$esc%');
    }

    final ordered = switch (sort) {
      DealSort.discount => q.order('discount_rate', ascending: false),
      DealSort.latest => q.order('last_seen_at', ascending: false),
    };
    final rows = await ordered.range(offset, offset + limit - 1);
    return rows.map((m) => BrandDeal.fromMap(m)).toList();
  }
}

/// 핫딜 조회 파라미터 — provider family 키(불변·값 동등성).
class DealQuery {
  final String query;
  final String? brandSlug;
  final String? category;
  final DealSort sort;
  const DealQuery({
    this.query = '',
    this.brandSlug,
    this.category,
    this.sort = DealSort.discount,
  });

  @override
  bool operator ==(Object other) =>
      other is DealQuery &&
      other.query == query &&
      other.brandSlug == brandSlug &&
      other.category == category &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(query, brandSlug, category, sort);
}
