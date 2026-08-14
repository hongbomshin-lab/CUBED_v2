// lib/features/result/widgets/verdict_hero.dart
import 'package:flutter/material.dart';

import '../../../core/explain.dart';
import '../../../core/rulebook.dart';
import '../../../core/theme.dart';
import '../../../domain/interpretation.dart';
import '../../../domain/verdict.dart';

/// 답 + 이유 히어로: [라벨 vs 실제] 스트립(무설탕 표기 제품) 또는 등급 배지,
/// 그 아래 중복 제거된 이유 불릿 최대 3개, 핵심 수치 3칸.
class VerdictHero extends StatelessWidget {
  const VerdictHero({super.key, required this.it});
  final Interpretation it;

  @override
  Widget build(BuildContext context) {
    final v = Verdict.of(it);
    final c = CubedColors.grade(v.grade);
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
              _SignalLights(active: v.grade),
              const SizedBox(width: 14),
              Expanded(
                child: v.kind == VerdictKind.generic
                    ? _GradeBadge(grade: v.grade)
                    : _LabelVsReality(v: v),
              ),
            ],
          ),
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
