/// 프랜차이즈 음료 당류/영양 정보 (franchise_drinks).
class FranchiseDrink {
  final String id;
  final String brand;
  final String? category;
  final String name;
  final String nameClean;
  final String? size;
  final int? volumeMl;
  final double? calories;
  final double? sugarG;
  final double? sugarCubes; // 각설탕 환산(생성컬럼)
  final double? carbsG;
  final double? proteinG;
  final double? fatG;
  final double? sodiumMg;
  final double? caffeineMg;
  final bool hasZeroOption;
  final String? altSweetener;
  final String? sourceUrl;

  /// 온도 구분('ICE'/'HOT'/null) — name_clean 접두어로 판별(그룹화·탭용).
  final String? temperature;

  /// 온도 접두어를 제거한 기본 메뉴명 — 같은 메뉴 그룹화 키.
  final String baseName;

  const FranchiseDrink({
    required this.id,
    required this.brand,
    this.category,
    required this.name,
    required this.nameClean,
    this.size,
    this.volumeMl,
    this.calories,
    this.sugarG,
    this.sugarCubes,
    this.carbsG,
    this.proteinG,
    this.fatG,
    this.sodiumMg,
    this.caffeineMg,
    this.hasZeroOption = false,
    this.altSweetener,
    this.sourceUrl,
    this.temperature,
    required this.baseName,
  });

  static double? _d(dynamic v) => v == null ? null : (v as num).toDouble();
  static int? _i(dynamic v) => v == null ? null : (v as num).toInt();

  /// name_clean에서 온도 접두어/(ICED)를 떼어 (기본명, 온도) 반환.
  static (String, String?) parseTemp(String nameClean) {
    var n = nameClean.trim();
    String? temp;
    if (n.startsWith('아이스')) {
      temp = 'ICE';
      n = n.substring('아이스'.length).trim();
    } else if (n.startsWith('따뜻한')) {
      temp = 'HOT';
      n = n.substring('따뜻한'.length).trim();
    } else if (n.startsWith('핫')) {
      temp = 'HOT';
      n = n.substring(1).trim();
    }
    final iced = RegExp(r'\s*\(ICED\)', caseSensitive: false);
    if (iced.hasMatch(n)) {
      temp = 'ICE';
      n = n.replaceAll(iced, '').trim();
    }
    return (n.isEmpty ? nameClean.trim() : n, temp);
  }

  factory FranchiseDrink.fromMap(Map<String, dynamic> m) {
    final nameClean = (m['name_clean'] as String?) ?? m['name'] as String;
    final (base, temp) = parseTemp(nameClean);
    return FranchiseDrink(
      id: m['id'] as String,
      brand: m['brand'] as String,
      category: m['category'] as String?,
      name: m['name'] as String,
      nameClean: nameClean,
      size: (m['size'] as String?)?.trim().isEmpty ?? true
          ? null
          : (m['size'] as String).trim(),
      volumeMl: _i(m['volume_ml']),
      calories: _d(m['calories']),
      sugarG: _d(m['sugar_g']),
      sugarCubes: _d(m['sugar_cubes']),
      carbsG: _d(m['carbs_g']),
      proteinG: _d(m['protein_g']),
      fatG: _d(m['fat_g']),
      sodiumMg: _d(m['sodium_mg']),
      caffeineMg: _d(m['caffeine_mg']),
      hasZeroOption: (m['has_zero_option'] as bool?) ?? false,
      altSweetener: (m['alt_sweetener'] as String?)?.trim().isEmpty ?? true
          ? null
          : (m['alt_sweetener'] as String).trim(),
      sourceUrl: m['source_url'] as String?,
      temperature: temp,
      baseName: base,
    );
  }
}

/// 같은 메뉴(브랜드+기본명)로 묶은 그룹. 변형이 여러 개면 상세에서 온도/사이즈 탭.
class FranchiseMenu {
  final String brand;
  final String? category;
  final String displayName;

  /// 대표 변형(목록 표시·정렬 기준) — 보통 가장 작은 용량.
  final FranchiseDrink representative;

  /// 온도/사이즈로 구분되는 변형들 (대표 우선 정렬).
  final List<FranchiseDrink> variants;

  const FranchiseMenu({
    required this.brand,
    required this.category,
    required this.displayName,
    required this.representative,
    required this.variants,
  });

  bool get hasVariants => variants.length > 1;

  /// 존재하는 온도 종류 (없으면 빈 목록).
  List<String> get temperatures =>
      variants.map((v) => v.temperature).whereType<String>().toSet().toList();

  /// 존재하는 사이즈 종류 (없으면 빈 목록).
  List<String> get sizes =>
      variants.map((v) => v.size).whereType<String>().toSet().toList();
}

/// 목록 정렬 기준.
enum FranchiseSort {
  sugarAsc('당 낮은순'),
  sugarDesc('당 높은순'),
  calories('칼로리순');

  const FranchiseSort(this.label);
  final String label;
}
