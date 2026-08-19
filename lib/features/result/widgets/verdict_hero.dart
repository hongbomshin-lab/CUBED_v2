// lib/features/result/widgets/verdict_hero.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/explain.dart';
import '../../../core/rulebook.dart';
import '../../../core/sugar_judge.dart';
import '../../../core/theme.dart';
import '../../../domain/interpretation.dart';
import '../../../domain/verdict.dart';
import '../../../providers/providers.dart';

/// 답 + 이유 히어로.
/// - 프로필 미설정: 혈당 등급이 메인 — [라벨 vs 실제] 스트립 또는 등급 배지.
/// - 프로필 설정: 개인 당류 판정이 메인 신호등(게이지 포함), 혈당 등급은 보조 칩으로 강등.
///   양 슬라이더(portionFactorProvider)와 실시간 연동.
/// - 당류 미확인([sugarUnknown]): 혈당 히어로 유지 + "당류 정보 없음" 표시.
/// 어느 모드든 함정 불릿·zeroBusted 스트립·핵심 수치 3칸은 유지한다.
class VerdictHero extends ConsumerWidget {
  const VerdictHero({super.key, required this.it, this.sugarUnknown = false});
  final Interpretation it;
  final bool sugarUnknown;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = Verdict.of(it);
    final profile = ref.watch(sugarProfileProvider);

    SugarVerdict? sv;
    if (profile != null && !sugarUnknown) {
      final p = it.product;
      final factor = ref.watch(portionFactorProvider(p.productId));
      sv = judgeSugar(
        sugarG: p.sugar * factor,
        sugarAlcoholG:
            judgedSugarAlcoholG(p.sugarAlcohol, p.sweeteners) * factor,
        sweetenerSlugs: p.slugs,
        profile: profile,
      );
    }

    final heroGrade = sv == null ? v.grade : _levelGrade(sv.level);
    final c = CubedColors.grade(heroGrade);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(CubedFx.radiusHero),
        border: Border.all(color: c.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _SignalLights(active: heroGrade),
              const SizedBox(width: 14),
              Expanded(
                child: sv != null
                    ? _PersonalBadge(sv: sv, grade: it.grade)
                    : v.kind == VerdictKind.generic
                        ? _GradeBadge(grade: v.grade)
                        : _LabelVsReality(v: v),
              ),
            ],
          ),
          // 개인 판정 모드에서도 "제로 표기 vs 실제" 스토리는 유지
          if (sv != null && v.kind != VerdictKind.generic) ...[
            const SizedBox(height: 12),
            _LabelVsReality(v: v),
          ],
          if (sv != null) ...[
            const SizedBox(height: 14),
            _SugarGauge(sv: sv),
          ],
          if (sugarUnknown) ...[
            const SizedBox(height: 10),
            const Text('⚪ 당류 정보가 없어 내 기준 판정은 어려워요',
                style: TextStyle(color: CubedColors.inkSoft, fontSize: 12)),
          ],
          if (v.whyBullets.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final b in v.whyBullets)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 7),
                            width: 5, height: 5,
                            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(b,
                                style: const TextStyle(fontSize: 14, height: 1.45)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _Stat(label: '순탄수', value: '${_n(it.netCarb)}g'),
              _divider(),
              _Stat(label: '100${it.product.unit}당', value: '${_n(it.per100NetCarb)}g'),
              _divider(),
              _Stat(label: '열량', value: '${_n(it.product.kcal)}kcal'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 28, color: CubedColors.line);
  static String _n(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

/// SugarLevel → 신호등 색(Grade) 매핑. unknown은 개인 히어로에 오지 않는다.
Grade _levelGrade(SugarLevel l) => switch (l) {
      SugarLevel.ok => Grade.low,
      SugarLevel.watch => Grade.mid,
      SugarLevel.avoid || SugarLevel.unknown => Grade.caution,
    };

/// 개인 당류 판정 배지 + 강등된 혈당 등급 보조 칩.
class _PersonalBadge extends StatelessWidget {
  const _PersonalBadge({required this.sv, required this.grade});
  final SugarVerdict sv;
  final Grade grade; // 기존 혈당영향 등급 (보조)

  @override
  Widget build(BuildContext context) {
    final c = CubedColors.grade(_levelGrade(sv.level));
    final (badge, desc) = switch (sv.level) {
      SugarLevel.ok => ('괜찮음', '내 한 끼 당류 한도의 절반 이하예요.'),
      SugarLevel.watch => ('주의', '내 한 끼 당류 한도에 가까워요.'),
      _ => ('피하세요', '내 한 끼 당류 한도를 넘어요.'),
    };
    final gt = gradeText[grade]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(badge,
            style: TextStyle(
                color: c,
                fontWeight: FontWeight.w800,
                fontSize: 24,
                letterSpacing: -0.5)),
        const SizedBox(height: 2),
        Text(desc,
            style: const TextStyle(
                color: CubedColors.inkSoft, fontSize: 13, height: 1.4)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: CubedColors.grade(grade).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('${gt.emoji} ${gt.badge}',
              style: TextStyle(
                  color: CubedColors.grade(grade),
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

/// 게이지 바 1개 + 근거 라벨. "내 한 끼 한도 13g 중 18g (138%)"
class _SugarGauge extends StatelessWidget {
  const _SugarGauge({required this.sv});
  final SugarVerdict sv;

  static String _g(double v) {
    final r = (v * 10).round() / 10;
    return r == r.roundToDouble() ? r.toInt().toString() : r.toStringAsFixed(1);
  }

  void _showFormulaSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('내 한 끼 당류 한도, 어떻게 계산했나요?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Text(
                'WHO는 유리당을 하루 열량의 10% 이내(가급적 5%)로 권고해요.\n\n'
                '내 프로필(목표·체중·식사 횟수)로 하루 열량을 추정해 '
                '한 끼 당류 한도 ${sv.mealLimitG}g을 계산했어요.\n\n'
                '말티톨처럼 혈당을 올리는 당알코올은 절반으로 환산해 당류에 더해요. '
                '에리스리톨·알룰로스 등 혈당에 영향 없는 감미료는 계산에 넣지 않아요.',
                style: const TextStyle(fontSize: 14, height: 1.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = CubedColors.grade(_levelGrade(sv.level));
    final pct = (sv.ratio * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('내 한 끼 한도 ${sv.mealLimitG}g 중 ${_g(sv.effectiveSugarG)}g ($pct%)',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 10,
            color: Colors.white,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: sv.ratio.clamp(0.0, 1.0),
              child: Container(color: c),
            ),
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _showFormulaSheet(context),
          borderRadius: BorderRadius.circular(6),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('WHO 권고 × 내 프로필 기준',
                  style: TextStyle(color: CubedColors.inkSoft, fontSize: 11)),
              SizedBox(width: 3),
              Icon(Icons.info_outline_rounded,
                  size: 12, color: CubedColors.inkSoft),
            ],
          ),
        ),
      ],
    );
  }
}

/// "라벨이 말하는 것 → 몸이 겪는 것" 두 칸 스트립
class _LabelVsReality extends StatelessWidget {
  const _LabelVsReality({required this.v});
  final Verdict v;

  @override
  Widget build(BuildContext context) {
    final good = v.kind == VerdictKind.zeroTrue;
    final c = good ? CubedColors.low : CubedColors.grade(v.grade);
    Widget cell(String caption, String text, {required bool strong}) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: strong ? c.withValues(alpha: 0.16) : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(caption,
                    style: const TextStyle(fontSize: 11, color: CubedColors.inkSoft)),
                const SizedBox(height: 2),
                Text(text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800,
                        color: strong ? c : CubedColors.ink)),
              ],
            ),
          ),
        );
    return Row(
      children: [
        cell('라벨이 말하는 것', v.labelText, strong: false),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.arrow_forward_rounded, size: 18, color: c),
        ),
        cell('몸이 겪는 것', v.realityText, strong: true),
      ],
    );
  }
}

class _GradeBadge extends StatelessWidget {
  const _GradeBadge({required this.grade});
  final Grade grade;
  @override
  Widget build(BuildContext context) {
    final gt = gradeText[grade]!;
    final c = CubedColors.grade(grade);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(gt.badge,
            style: TextStyle(
                color: c,
                fontWeight: FontWeight.w800,
                fontSize: 24,
                letterSpacing: -0.5)),
        const SizedBox(height: 2),
        Text(gt.desc, style: const TextStyle(color: CubedColors.inkSoft, fontSize: 13, height: 1.4)),
      ],
    );
  }
}

class _SignalLights extends StatelessWidget {
  const _SignalLights({required this.active});
  final Grade active;
  @override
  Widget build(BuildContext context) {
    Widget dot(Grade g) {
      final on = g == active;
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        width: 18, height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: on ? CubedColors.grade(g) : CubedColors.grade(g).withValues(alpha: 0.18),
          boxShadow: on
              ? [BoxShadow(color: CubedColors.grade(g).withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 1)]
              : null,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: CubedColors.ink,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: [dot(Grade.caution), dot(Grade.mid), dot(Grade.low)]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: CubedColors.inkSoft, fontSize: 11)),
        ],
      ),
    );
  }
}
