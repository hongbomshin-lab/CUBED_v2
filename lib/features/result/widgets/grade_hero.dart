import 'package:flutter/material.dart';

import '../../../core/explain.dart';
import '../../../core/rulebook.dart';
import '../../../core/theme.dart';
import '../../../domain/interpretation.dart';

/// 혈당 등급 신호등 + 헤드라인 히어로 카드
class GradeHero extends StatelessWidget {
  const GradeHero({super.key, required this.it});
  final Interpretation it;

  @override
  Widget build(BuildContext context) {
    final c = CubedColors.grade(it.grade);
    final gt = gradeText[it.grade]!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SignalLights(active: it.grade),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(gt.badge,
                        style: TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: 22)),
                    const SizedBox(height: 2),
                    Text(gt.desc,
                        style: const TextStyle(color: CubedColors.inkSoft, fontSize: 13, height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(it.headline,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, height: 1.35)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
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

class _SignalLights extends StatelessWidget {
  const _SignalLights({required this.active});
  final Grade active;
  @override
  Widget build(BuildContext context) {
    Widget dot(Grade g) {
      final on = g == active;
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        width: 18,
        height: 18,
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
        color: const Color(0xFF20242A),
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
