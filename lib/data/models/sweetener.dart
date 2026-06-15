import '../../core/rulebook.dart';

/// 감미료 마스터 (sweeteners 테이블 28행)
class Sweetener {
  final String slug;
  final String standardName;
  final String? aliases;
  final String klass; // 천연 | 인공 | 당알코올 | 기타
  final Grade glycemicImpact; // 낮음 | 중간 | 주의
  final String cariogenicImpact; // 억제 | 중립 | 유발
  final double kcalPerG;
  final String? note;

  const Sweetener({
    required this.slug,
    required this.standardName,
    this.aliases,
    required this.klass,
    required this.glycemicImpact,
    required this.cariogenicImpact,
    required this.kcalPerG,
    this.note,
  });

  bool get isEtc => klass == '기타';

  static Grade gradeFromKo(String? ko) => switch (ko) {
        '주의' => Grade.caution,
        '중간' => Grade.mid,
        _ => Grade.low,
      };

  factory Sweetener.fromMap(Map<String, dynamic> m) => Sweetener(
        slug: m['slug'] as String,
        standardName: m['standard_name'] as String? ?? m['slug'] as String,
        aliases: m['aliases'] as String?,
        klass: m['class'] as String? ?? '인공',
        glycemicImpact: gradeFromKo(m['glycemic_impact'] as String?),
        cariogenicImpact: m['cariogenic_impact'] as String? ?? '중립',
        kcalPerG: (m['kcal_per_g'] as num?)?.toDouble() ?? 0,
        note: m['note'] as String?,
      );
}

/// 제품에 포함된 감미료(+함량) — product_sweeteners 조인 결과
class ProductSweetener {
  final String slug;
  final double? amountG;
  final int sortOrder;
  const ProductSweetener({required this.slug, this.amountG, required this.sortOrder});

  factory ProductSweetener.fromMap(Map<String, dynamic> m) => ProductSweetener(
        slug: m['slug'] as String,
        amountG: (m['amount_g'] as num?)?.toDouble(),
        sortOrder: (m['sort_order'] as num?)?.toInt() ?? 0,
      );
}
