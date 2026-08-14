import 'package:flutter/material.dart';

/// 진입 스태거 모션 — 페이드 + 위로 슬라이드.
/// [delayMs]로 순차 등장을 만든다. 시스템 '동작 줄이기' 설정 시 즉시 표시.
class Reveal extends StatelessWidget {
  const Reveal({super.key, required this.child, this.delayMs = 0});
  final Widget child;
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return child;
    final total = 420 + delayMs;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delayMs / total, 1, curve: Curves.easeOutCubic),
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 18 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}
