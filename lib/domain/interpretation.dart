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
  const SweetenerChip({
    required this.slug,
    required this.name,
    required this.klass,
    required this.glycemic,
    this.amountG,
    required this.isRisky,
  });
}

/// 한 제품에 대한 CUBED 해석 결과 (UI가 그대로 그리는 ViewModel).
/// 모든 값은 rulebook/explain으로 런타임 계산 — DB 미저장.
class Interpretation {
  final Product product;
  final Grade grade;
  final double netCarb;
  final double per100NetCarb;
  final List<String> trapCodes;
  final String headline;
  final List<TrapLine> trapLines;
  final String reason;
  final List<SweetenerChip> chips;
  final ComboRule? combo; // 매칭된 맞춤 조합 메시지
  final String? topSweetenerName;

  const Interpretation({
    required this.product,
    required this.grade,
    required this.netCarb,
    required this.per100NetCarb,
    required this.trapCodes,
    required this.headline,
    required this.trapLines,
    required this.reason,
    required this.chips,
    required this.combo,
    required this.topSweetenerName,
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

    // 등급이 가장 높은(혈당 위험 큰) 감미료 표시명 — class='기타' 제외
    String? topName;
    var worst = -1;
    for (final ps in p.sweeteners) {
      final sw = ref.sweeteners[ps.slug];
      if (sw == null || sw.isEtc) continue;
      final r = switch (sw.glycemicImpact) { Grade.caution => 2, Grade.mid => 1, Grade.low => 0 };
      if (r > worst) {
        worst = r;
        topName = sw.standardName;
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
      );
    }).toList();

    return Interpretation(
      product: p,
      grade: grade,
      netCarb: nc,
      per100NetCarb: p100,
      trapCodes: trapCodes,
      headline: ex.headline(input),
      trapLines: ex.trapLines(input),
      reason: ex.reasonLine(input),
      chips: chips,
      combo: _matchCombo(slugs, ref.comboRules),
      topSweetenerName: topName,
    );
  }

  /// combo_key의 slug들이 제품 감미료 집합의 부분집합이면 매칭. priority 최고 우선.
  static ComboRule? _matchCombo(List<String> slugs, List<ComboRule> rules) {
    final set = slugs.toSet();
    ComboRule? best;
    for (final r in rules) {
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
