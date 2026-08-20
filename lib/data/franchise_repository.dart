import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/franchise_drink.dart';
import 'translation_repository.dart';

/// 프랜차이즈 검색 파라미터 — provider family 키(불변·값 동등성).
/// [brand] null이면 전체. 단일 브랜드 선택.
class FranchiseQuery {
  final String query;
  final String? brand;
  final FranchiseSort sort;
  const FranchiseQuery({
    this.query = '',
    this.brand,
    this.sort = FranchiseSort.sugarAsc,
  });

  @override
  bool operator ==(Object other) =>
      other is FranchiseQuery &&
      other.query == query &&
      other.brand == brand &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(query, brand, sort);
}

/// 프랜차이즈 음료 당류/영양 데이터 접근 (franchise_drinks).
class FranchiseRepository {
  FranchiseRepository(this._db);
  final SupabaseClient _db;

  /// 필터 칩에 노출할 브랜드 순서.
  static const brands = [
    '스타벅스',
    '메가커피',
    '컴포즈커피',
    '빽다방',
    '이디야',
    '투썸플레이스',
  ];

  /// 검색 + 브랜드 필터 + 정렬. 같은 메뉴(브랜드+기본명)는 하나로 묶어 반환.
  /// - [brand] 지정 시 해당 브랜드로 한정하고 그 안에서 [query] 재검색.
  /// - [query] name_clean·name 부분일치(대소문자 무시). 공백은 토큰 AND.
  ///   (브랜드는 [brand]로 이미 한정하므로 검색어 대상에서 제외)
  /// - 대표 변형: 가장 작은 용량(기본 사이즈) 기준. 정렬은 대표 기준.
  Future<List<FranchiseMenu>> search({
    String query = '',
    String? brand,
    FranchiseSort sort = FranchiseSort.sugarAsc,
  }) async {
    final tokens = query
        .trim()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();

    // 브랜드 미선택 시에만 검색어를 brand에도 매칭(브랜드명으로 검색 가능).
    final searchCols = brand == null
        ? ['name_clean', 'name', 'brand']
        : ['name_clean', 'name'];

    // PostgREST 기본 max-rows(1000) 때문에 range로 전체를 페이지 단위로 수집.
    const page = 1000;
    final drinks = <FranchiseDrink>[];
    for (var from = 0;; from += page) {
      var q = _db.from('franchise_drinks').select();
      if (brand != null) {
        q = q.eq('brand', brand);
      }
      // 각 토큰이 검색 대상 컬럼 중 하나에 포함(토큰 간 AND).
      for (final tok in tokens) {
        final esc = tok.replaceAll('%', r'\%').replaceAll('_', r'\_');
        q = q.or(searchCols.map((c) => '$c.ilike.%$esc%').join(','));
      }
      final rows = await q.range(from, from + page - 1);
      drinks.addAll(rows.map((m) => FranchiseDrink.fromMap(m)));
      if (rows.length < page) break;
    }

    return _sorted(_grouped(drinks), sort);
  }

  /// 표시 언어 기준 텍스트 필터.
  ///
  /// 외국어로 볼 때는 사용자가 화면에 보이는 말(Americano)로 검색하므로
  /// 서버의 한국어 컬럼 검색만으로는 걸리지 않는다. 번역명·원문 양쪽을 대상으로
  /// 클라이언트에서 토큰 AND 부분일치로 거른다(메뉴 약 1,000건 규모라 부담 없음).
  static List<FranchiseMenu> filterByText(
    List<FranchiseMenu> menus,
    String query,
    TranslationDict dict,
  ) {
    final tokens = query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return menus;

    return menus.where((m) {
      final hay = [
        dict.menuName(m.displayName, m.translationKey),
        m.displayName,
        m.representative.nameClean,
        m.representative.name,
        dict.brand(m.brand),
        m.brand,
      ].join(' ').toLowerCase();
      return tokens.every(hay.contains);
    }).toList();
  }

  /// (브랜드, 기본명)별로 변형을 묶어 FranchiseMenu 생성.
  List<FranchiseMenu> _grouped(List<FranchiseDrink> all) {
    final byKey = <String, List<FranchiseDrink>>{};
    for (final d in all) {
      (byKey['${d.brand}|${d.baseName}'] ??= []).add(d);
    }

    final menus = <FranchiseMenu>[];
    for (final variants in byKey.values) {
      // 대표: 가장 작은 용량 → 온도는 ICE 우선(가장 많이 찾음).
      variants.sort((a, b) {
        final va = a.volumeMl ?? 1 << 30;
        final vb = b.volumeMl ?? 1 << 30;
        if (va != vb) return va.compareTo(vb);
        return _tempRank(a.temperature).compareTo(_tempRank(b.temperature));
      });
      final rep = variants.first;
      // 변형이 하나뿐이면 원래 이름 유지(아이스만 있는 메뉴를 오표기하지 않도록).
      final display = variants.length == 1 ? rep.nameClean : rep.baseName;
      menus.add(FranchiseMenu(
        brand: rep.brand,
        category: rep.category,
        displayName: display,
        representative: rep,
        variants: variants,
      ));
    }
    return menus;
  }

  static int _tempRank(String? t) => switch (t) {
        'ICE' => 0,
        'HOT' => 1,
        _ => 2,
      };

  List<FranchiseMenu> _sorted(List<FranchiseMenu> list, FranchiseSort sort) {
    // null 값은 항상 뒤로.
    int cmpNullable(double? a, double? b, {bool desc = false}) {
      if (a == null && b == null) return 0;
      if (a == null) return 1;
      if (b == null) return -1;
      return desc ? b.compareTo(a) : a.compareTo(b);
    }

    final sorted = [...list];
    switch (sort) {
      case FranchiseSort.sugarAsc:
        sorted.sort((a, b) =>
            cmpNullable(a.representative.sugarG, b.representative.sugarG));
      case FranchiseSort.sugarDesc:
        sorted.sort((a, b) => cmpNullable(
            a.representative.sugarG, b.representative.sugarG,
            desc: true));
      case FranchiseSort.calories:
        sorted.sort((a, b) =>
            cmpNullable(a.representative.calories, b.representative.calories));
    }
    return sorted;
  }
}
