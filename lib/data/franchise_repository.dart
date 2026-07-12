import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/franchise_drink.dart';

/// 프랜차이즈 검색 파라미터 — provider family 키(값 동등성 필요).
class FranchiseQuery {
  final String query;
  final Set<String> brands;
  final FranchiseSort sort;
  const FranchiseQuery({
    this.query = '',
    this.brands = const {},
    this.sort = FranchiseSort.sugarAsc,
  });

  @override
  bool operator ==(Object other) =>
      other is FranchiseQuery &&
      other.query == query &&
      other.sort == sort &&
      other.brands.length == brands.length &&
      other.brands.containsAll(brands);

  @override
  int get hashCode => Object.hash(
        query,
        sort,
        Object.hashAllUnordered(brands),
      );
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

  /// 검색 + 브랜드 필터 + 정렬. 같은 (브랜드, name_clean)은 대표 1개만 반환.
  /// - [query] name_clean·name 부분일치(대소문자 무시). 공백은 토큰 AND로 처리.
  /// - 대표 선택: 가장 작은 용량(기본 사이즈) 기준.
  Future<List<FranchiseDrink>> search({
    String query = '',
    Set<String> brands = const {},
    FranchiseSort sort = FranchiseSort.sugarAsc,
  }) async {
    var q = _db.from('franchise_drinks').select();

    if (brands.isNotEmpty) {
      q = q.inFilter('brand', brands.toList());
    }
    // 공백으로 나눈 각 토큰이 name_clean 또는 name에 포함(토큰 간 AND).
    for (final tok in query.trim().split(RegExp(r'\s+'))) {
      if (tok.isEmpty) continue;
      final esc = tok.replaceAll('%', r'\%').replaceAll('_', r'\_');
      q = q.or('name_clean.ilike.%$esc%,name.ilike.%$esc%');
    }

    final rows = await q.limit(3000);
    final drinks = rows
        .map((m) => FranchiseDrink.fromMap(m))
        .toList();

    return _sorted(_representatives(drinks), sort);
  }

  /// (브랜드, name_clean)별 대표 1개 — 가장 작은 용량(없으면 첫 항목).
  List<FranchiseDrink> _representatives(List<FranchiseDrink> all) {
    final byKey = <String, FranchiseDrink>{};
    for (final d in all) {
      final key = '${d.brand}|${d.nameClean}';
      final cur = byKey[key];
      if (cur == null) {
        byKey[key] = d;
      } else {
        final a = d.volumeMl ?? 1 << 30;
        final b = cur.volumeMl ?? 1 << 30;
        if (a < b) byKey[key] = d;
      }
    }
    return byKey.values.toList();
  }

  List<FranchiseDrink> _sorted(List<FranchiseDrink> list, FranchiseSort sort) {
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
        sorted.sort((a, b) => cmpNullable(a.sugarG, b.sugarG));
      case FranchiseSort.sugarDesc:
        sorted.sort((a, b) => cmpNullable(a.sugarG, b.sugarG, desc: true));
      case FranchiseSort.calories:
        sorted.sort((a, b) => cmpNullable(a.calories, b.calories));
    }
    return sorted;
  }
}
