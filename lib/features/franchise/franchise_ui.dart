import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// 당류 구간별 신호 색 (기존 혈당 신호등 팔레트 재사용).
/// 5g↓ 좋음(green) / 5–15g 보통(amber) / 15g↑ 경고(red).
Color sugarColor(double? g) {
  if (g == null) return CubedColors.inkSoft;
  if (g < 5) return CubedColors.low;
  if (g <= 15) return CubedColors.mid;
  return CubedColors.caution;
}

/// 소수 첫째까지, 정수면 정수로. null이면 '-'.
String fmtNum(double? v, {String unit = ''}) {
  if (v == null) return '-';
  final s = v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
  return '$s$unit';
}
