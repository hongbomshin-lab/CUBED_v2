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
  });

  static double? _d(dynamic v) => v == null ? null : (v as num).toDouble();
  static int? _i(dynamic v) => v == null ? null : (v as num).toInt();

  factory FranchiseDrink.fromMap(Map<String, dynamic> m) => FranchiseDrink(
        id: m['id'] as String,
        brand: m['brand'] as String,
        category: m['category'] as String?,
        name: m['name'] as String,
        nameClean: (m['name_clean'] as String?) ?? m['name'] as String,
        size: m['size'] as String?,
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
      );
}

/// 목록 정렬 기준.
enum FranchiseSort {
  sugarAsc('당 낮은순'),
  sugarDesc('당 높은순'),
  calories('칼로리순');

  const FranchiseSort(this.label);
  final String label;
}
