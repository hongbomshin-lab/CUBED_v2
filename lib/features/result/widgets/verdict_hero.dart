// lib/features/result/widgets/verdict_hero.dart
import 'package:flutter/material.dart';

import '../../../core/explain.dart';
import '../../../core/sugar_cube.dart';
import '../../../core/theme.dart';
import '../../../domain/interpretation.dart';
import '../../../domain/verdict.dart';

/// 답 + 이유 히어로 — 혈당 등급이 메인 신호등.
/// [라벨 vs 실제] 스트립 또는 등급 배지 + 함정 불릿 + 핵심 수치 3칸.
class VerdictHero extends StatelessWidget {
  const VerdictHero({super.key, required this.it});
  final Interpretation it;

  @override
  Widget build(BuildContext context) {
    final v = Verdict.of(it);
    final c = CubedColors.grade(v.grade);
    final gt = gradeText[v.grade]!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(CubedFx.radiusHero),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 왼쪽에 판정, 오른쪽에 큐브. 수치는 아래 3칸이 맡는다.
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(gt.badge,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4)),
              ),
              const Spacer(),
              GradeCubes(grade: v.grade, cubeSize: 42),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: v.kind == VerdictKind.generic
                    ? const SizedBox.shrink()
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

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: -0.6)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: CubedColors.inkSoft, fontSize: 11)),
        ],
      ),
    );
  }
}
