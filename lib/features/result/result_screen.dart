import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/explain.dart';
import '../../core/product_thumb.dart';
import '../../core/rulebook.dart';
import '../../core/theme.dart';
import '../../data/models/product.dart';
import '../../domain/interpretation.dart';
import '../../providers/providers.dart';
import '../chat/chat_screen.dart';
import '../diary/eaten_today_button.dart';
import '../prices/price_comparison_section.dart';
import 'widgets/portion_slider.dart';
import 'widgets/social_section.dart';
import 'widgets/sweetener_chips.dart';
import 'widgets/verdict_hero.dart';

class ResultScreen extends ConsumerWidget {
  const ResultScreen(
      {super.key, required this.product, this.submissionImagePath});
  final Product product;

  /// 촬영(OCR) 제품의 submission-images 폴더 uuid — 먹은기록 썸네일용
  final String? submissionImagePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interp = ref.watch(interpretationProvider(product));
    return Scaffold(
      appBar: AppBar(title: const Text('분석 결과')),
      body: interp.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('해석 오류: $e')),
        data: (it) => _Body(it: it, submissionImagePath: submissionImagePath),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.it, this.submissionImagePath});
  final Interpretation it;
  final String? submissionImagePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = it.product;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        _ProductHeader(it: it),
        const SizedBox(height: 16),

        // ── 1층: 답 + 이유 (VerdictHero가 판정 스트립·불릿·핵심 수치 통합)
        VerdictHero(it: it),

        // 단맛 레시피 한 줄 (다중 조합 규칙 매칭 시)
        if (it.recipeCombo != null) ...[
          const SizedBox(height: 10),
          _RecipeLine(combo: it.recipeCombo!),
        ],

        PriceComparisonSection(productId: p.productId),

        // ── 2층: 행동 — 주의 등급이면 대안을 먼저
        if (it.grade == Grade.caution) ...[
          const SizedBox(height: 24),
          _AlternativesSection(product: p),
        ],

        // 먹은 기록 토글 (푸드 다이어리)
        const SizedBox(height: 12),
        EatenTodayButton(
          product: p,
          grade: it.grade,
          submissionImagePath: submissionImagePath,
        ),

        // 대체당 칩 (탭하면 성분 설명)
        const SizedBox(height: 20),
        _SectionTitle('포함된 대체당', trailing: '${it.chips.length}종 · 탭해서 보기'),
        const SizedBox(height: 10),
        SweetenerChips(chips: it.chips, notes: it.slugNotes),

        // ── 3층: 근거 (접힘) — 영양성분·양 슬라이더·계산 근거
        const SizedBox(height: 20),
        _NumbersSection(it: it),

        // 낮음/중간 등급이면 대안은 여기
        if (it.grade != Grade.caution) ...[
          const SizedBox(height: 24),
          _AlternativesSection(product: p),
        ],

        // AI에게 이 제품 질문
        const SizedBox(height: 20),
        _AskAiButton(product: p),

        // ── 4층: 커뮤니티
        const SizedBox(height: 28),
        const Divider(height: 1, color: CubedColors.line),
        const SizedBox(height: 20),
        SocialSection(productId: p.productId),

        // 검수 안내
        if (!p.verified) ...[
          const SizedBox(height: 24),
          _DraftNotice(notes: p.notes),
        ],
      ],
    );
  }
}

class _ProductHeader extends StatelessWidget {
  const _ProductHeader({required this.it});
  final Interpretation it;
  @override
  Widget build(BuildContext context) {
    final p = it.product;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProductThumb(imageFile: p.imageFile, size: 72),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (p.brand != null)
                Text(p.brand!,
                    style: const TextStyle(
                        color: CubedColors.inkSoft,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(p.name,
                  style: const TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w800, height: 1.25)),
              const SizedBox(height: 6),
              if (p.category != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: CubedColors.brand.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(p.category!,
                      style: const TextStyle(
                          color: CubedColors.brand,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 다중 조합 규칙 → "단맛 레시피" 한 줄 아이덴티티. 탭하면 조합 설명 시트.
class _RecipeLine extends StatelessWidget {
  const _RecipeLine({required this.combo});
  final ComboRule combo;

  void _showSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.auto_awesome_rounded,
                      size: 18, color: CubedColors.brand),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(combo.headline,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                  ),
                ]),
                const SizedBox(height: 12),
                Text(combo.message,
                    style: const TextStyle(fontSize: 15, height: 1.55)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showSheet(context),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: CubedColors.brand.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: CubedColors.brand.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome_rounded,
                size: 16, color: CubedColors.brand),
            const SizedBox(width: 8),
            const Text('단맛 레시피: ',
                style: TextStyle(color: CubedColors.inkSoft, fontSize: 13)),
            Expanded(
              child: Text(combo.headline,
                  style: const TextStyle(
                      color: CubedColors.brand,
                      fontWeight: FontWeight.w800,
                      fontSize: 14)),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 16, color: CubedColors.inkSoft),
          ],
        ),
      ),
    );
  }
}

/// 접히는 근거 층: 양 슬라이더 + 영양성분 그리드 + 계산 근거 문장
class _NumbersSection extends StatelessWidget {
  const _NumbersSection({required this.it});
  final Interpretation it;
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        // maintainState 필수: 접었다 펴도 PortionSlider의 배수 선택이 유지된다.
        maintainState: true,
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: const Text('숫자로 보기',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        subtitle: const Text('영양성분 · 양 조절 · 계산 근거',
            style: TextStyle(color: CubedColors.inkSoft, fontSize: 12)),
        children: [
          PortionSlider(
              netCarb: it.netCarb,
              kcal: it.product.kcal,
              unitDesc: it.product.unitDesc),
          const SizedBox(height: 12),
          _NutritionGrid(p: it.product),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(it.reason,
                style: const TextStyle(
                    color: CubedColors.inkSoft, fontSize: 12, height: 1.5)),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// AI 채팅 딥링크 — 제품명을 들고 질문과 함께 진입
class _AskAiButton extends StatelessWidget {
  const _AskAiButton({required this.product});
  final Product product;
  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: CubedColors.brand,
        side: BorderSide(color: CubedColors.brand.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              ChatScreen(initialPrompt: '${product.name}, 혈당 관리 중인데 먹어도 괜찮아?'),
        ),
      ),
      icon: const Icon(Icons.forum_rounded, size: 18),
      label: const Text('AI에게 이 제품 물어보기',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
    );
  }
}

class _NutritionGrid extends StatelessWidget {
  const _NutritionGrid({required this.p});
  final Product p;
  @override
  Widget build(BuildContext context) {
    String n(double? v, String u) =>
        v == null ? '–' : (v == v.roundToDouble() ? '${v.toInt()}$u' : '$v$u');
    final items = <(String, String)>[
      ('열량', n(p.kcal, 'kcal')),
      ('탄수화물', n(p.carb, 'g')),
      ('당류', n(p.sugar, 'g')),
      ('단백질', n(p.protein, 'g')),
      ('지방', n(p.fat, 'g')),
      ('나트륨', n(p.sodiumMg, 'mg')),
      if (p.fiber > 0) ('식이섬유', n(p.fiber, 'g')),
      if (p.sugarAlcohol > 0) ('당알코올', n(p.sugarAlcohol, 'g')),
      if (p.rareSugarG > 0) ('알룰로스', n(p.rareSugarG, 'g')),
    ];
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: CubedColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CubedColors.line),
      ),
      child: Wrap(
        children: items.map((e) {
          return SizedBox(
            width: (MediaQuery.of(context).size.width - 40 - 12) / 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Column(
                children: [
                  Text(e.$2,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 3),
                  Text(e.$1,
                      style: const TextStyle(
                          color: CubedColors.inkSoft, fontSize: 11)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// "대신 이건 어때요?" 섹션 — 주의 등급이면 판정 직후, 그 외엔 근거 아래 배치
class _AlternativesSection extends StatelessWidget {
  const _AlternativesSection({required this.product});
  final Product product;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('대신 이건 어때요?'),
        const SizedBox(height: 4),
        const Text('같은 칸에서 혈당 부담이 더 낮은 제품',
            style: TextStyle(color: CubedColors.inkSoft, fontSize: 13)),
        const SizedBox(height: 12),
        _Alternatives(product: product),
      ],
    );
  }
}

class _Alternatives extends ConsumerWidget {
  const _Alternatives({required this.product});
  final Product product;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alts = ref.watch(alternativesProvider(product));
    return alts.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (list) {
        if (list.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CubedColors.low.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(children: [
              Text('👍', style: TextStyle(fontSize: 18)),
              SizedBox(width: 10),
              Expanded(
                  child: Text('이 칸에서 이미 좋은 선택이에요.',
                      style: TextStyle(fontWeight: FontWeight.w600))),
            ]),
          );
        }
        return Column(
          children: list.map((alt) {
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => ResultScreen(product: alt.product)),
                ),
                leading: CircleAvatar(
                  backgroundColor:
                      CubedColors.grade(alt.grade).withValues(alpha: 0.15),
                  child: Text(gradeText[alt.grade]!.emoji),
                ),
                title: Text(alt.product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                subtitle: Text(
                    '순탄수 ${_n(alt.netCarb)}g · ${gradeText[alt.grade]!.badge}',
                    style: const TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  static String _n(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.trailing});
  final String title;
  final String? trailing;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        if (trailing != null)
          Text(trailing!,
              style: const TextStyle(color: CubedColors.inkSoft, fontSize: 13)),
      ],
    );
  }
}

class _DraftNotice extends StatelessWidget {
  const _DraftNotice({this.notes});
  final String? notes;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CubedColors.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CubedColors.line),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info_outline_rounded,
            size: 16, color: CubedColors.inkSoft),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '검수 전 자동 추출 데이터예요. 실제 라벨과 다를 수 있어요.${notes != null && notes!.isNotEmpty ? '\n· $notes' : ''}',
            style: const TextStyle(
                color: CubedColors.inkSoft, fontSize: 12, height: 1.5),
          ),
        ),
      ]),
    );
  }
}
