import '../core/explain.dart';
import '../core/explain.dart' as ex;
import '../core/rulebook.dart';
import '../core/rulebook.dart' as rb;
import '../data/models/product.dart';
import '../data/product_repository.dart';

/// 대체당 칩 표시용
class SweetenerChip {
  final String slug;
  final String name;
  final String klass; // 천연/인공/당알코올/기타
  final Grade glycemic;
  final double? amountG;
  final bool isRisky; // 혈당 올리는 당알코올
  final String? note; // sweeteners.note (바텀시트 보조 설명)
  final String cariogenic; // 억제 | 중립 | 유발
  const SweetenerChip({
    required this.slug,
    required this.name,
    required this.klass,
    required this.glycemic,
    this.amountG,
    required this.isRisky,
    this.note,
    required this.cariogenic,
  });
}

/// 한 제품에 대한 ZERO DOT 해석 결과 (UI가 그대로 그리는 ViewModel).
/// 모든 값은 rulebook/explain으로 런타임 계산 — DB 미저장.
class Interpretation {
  final Product product;
  final Grade grade;
  final double netCarb;
  final double per100NetCarb;
  final List<String> trapCodes;
  final List<TrapLine> trapLines;
  final String reason;
  final List<SweetenerChip> chips;
  final ComboRule? recipeCombo; // 다중(2+ slug) 조합 — "단맛 레시피" 한 줄
  final Map<String, ComboRule> slugNotes; // 단일 slug 규칙 — 칩 바텀시트/불릿 승격용
  final String? topSweetenerName;
  final String? topSweetenerSlug; // topSweetenerName과 같은 성분의 slug — 표시층 노트 매칭용

  const Interpretation({
    required this.product,
    required this.grade,
    required this.netCarb,
    required this.per100NetCarb,
    required this.trapCodes,
    required this.trapLines,
    required this.reason,
    required this.chips,
    required this.recipeCombo,
    required this.slugNotes,
    required this.topSweetenerName,
    this.topSweetenerSlug,
  });

  bool get hasTrap => trapLines.any((t) => t.tier == TrapTier.trap);

  static Interpretation of(Product p, ReferenceData ref) {
    final isLiq = ref.isLiquid(p.category);
    final slugs = p.slugs;
    final giMap = ref.giMap;

    final nc = rb.netCarb(p.carb, p.fiber, p.sugarAlcohol, p.rareSugarG);
    final p100 = rb.per100NetCarb(p.servingSize, p.carb, p.fiber, p.sugarAlcohol, p.rareSugarG);
    final grade = glycemicGrade(
      isLiquid: isLiq,
      servingSize: p.servingSize,
      carb: p.carb,
      fiber: p.fiber,
      sugarAlcohol: p.sugarAlcohol,
      rareSugarG: p.rareSugarG,
      slugs: slugs,
      giMap: giMap,
    );
    final trapCodes = traps(
      isLiquid: isLiq,
      servingSize: p.servingSize,
      kcal: p.kcal,
      sugar: p.sugar,
      sugarAlcohol: p.sugarAlcohol,
      carb: p.carb,
      fiber: p.fiber,
      rareSugarG: p.rareSugarG,
      slugs: slugs,
    );

    // 등급이 가장 높은(혈당 위험 큰) 감미료 표시명·slug — class='기타' 제외
    String? topName;
    String? topSlug;
    var worst = -1;
    for (final ps in p.sweeteners) {
      final sw = ref.sweeteners[ps.slug];
      if (sw == null || sw.isEtc) continue;
      final r = switch (sw.glycemicImpact) { Grade.caution => 2, Grade.mid => 1, Grade.low => 0 };
      if (r > worst) {
        worst = r;
        topName = sw.standardName;
        topSlug = ps.slug;
      }
    }

    final input = ExplainInput(
      unit: p.unit,
      unitDesc: p.unitDesc,
      kcal: p.kcal,
      sugar: p.sugar,
      netCarb: nc,
      per100NetCarb: p100,
      grade: grade,
      traps: trapCodes,
      topSweetenerName: topName,
    );

    final chips = p.sweeteners.map((ps) {
      final sw = ref.sweeteners[ps.slug];
      return SweetenerChip(
        slug: ps.slug,
        name: sw?.standardName ?? ps.slug,
        klass: sw?.klass ?? '기타',
        glycemic: sw?.glycemicImpact ?? Grade.low,
        amountG: ps.amountG,
        isRisky: riskySugarAlcohol.contains(ps.slug),
        note: sw?.note,
        cariogenic: sw?.cariogenicImpact ?? '중립',
      );
    }).toList();

    return Interpretation(
      product: p,
      grade: grade,
      netCarb: nc,
      per100NetCarb: p100,
      trapCodes: trapCodes,
      trapLines: ex.trapLines(input),
      reason: ex.reasonLine(input),
      chips: chips,
      recipeCombo: _matchRecipe(slugs, ref.comboRules),
      slugNotes: _slugNotes(slugs, ref.comboRules),
      topSweetenerName: topName,
      topSweetenerSlug: topSlug,
    );
  }

  /// 2개 이상 slug 조합 규칙 중 부분집합 매칭 최우선 1개 — "단맛 레시피" 한 줄용.
  static ComboRule? _matchRecipe(List<String> slugs, List<ComboRule> rules) {
    final set = slugs.toSet();
    ComboRule? best;
    for (final r in rules) {
      if (r.keySlugs.length < 2) continue;
      if (r.keySlugs.every(set.contains)) {
        if (best == null ||
            r.priority > best.priority ||
            (r.priority == best.priority && r.keySlugs.length > best.keySlugs.length)) {
          best = r;
        }
      }
    }
    return best;
  }

  /// 단일 slug 규칙: 제품에 든 감미료만 slug -> rule 매핑.
  static Map<String, ComboRule> _slugNotes(List<String> slugs, List<ComboRule> rules) {
    final set = slugs.toSet();
    final out = <String, ComboRule>{};
    for (final r in rules) {
      if (r.keySlugs.length != 1) continue;
      final s = r.keySlugs.first;
      if (set.contains(s)) out[s] = r;
    }
    return out;
  }
}

/// 대안 추천(킬러 피처): 같은 카테고리에서 등급이 더 좋은 제품 상위 N개.
List<Interpretation> rankAlternatives(
  List<Product> candidates,
  ReferenceData ref,
  Grade currentGrade, {
  int take = 3,
}) {
  int rankOf(Grade g) => switch (g) { Grade.low => 0, Grade.mid => 1, Grade.caution => 2 };
  final cur = rankOf(currentGrade);
  final scored = candidates
      .map((p) => Interpretation.of(p, ref))
      .where((i) => rankOf(i.grade) < cur) // 더 나은 등급만
      .toList()
    ..sort((a, b) {
      final byGrade = rankOf(a.grade).compareTo(rankOf(b.grade));
      if (byGrade != 0) return byGrade;
      return a.netCarb.compareTo(b.netCarb); // 동급이면 순탄수 낮은 순
    });
  return scored.take(take).toList();
}
