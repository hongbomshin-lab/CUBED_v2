import 'package:flutter/material.dart';

import 'rulebook.dart';

/// CUBED 디자인 토큰 — 깔끔하고 신뢰감 있는 미니멀 톤.
class CubedColors {
  static const bg = Color(0xFFF7F8FA);
  static const surface = Colors.white;
  static const ink = Color(0xFF1A1D21);
  static const inkSoft = Color(0xFF606770);
  static const line = Color(0xFFE6E8EB);
  static const brand = Color(0xFF12B886); // 민트 그린(저당의 상쾌함)

  // 혈당 등급 신호등
  static const low = Color(0xFF22C55E);
  static const mid = Color(0xFFF59E0B);
  static const caution = Color(0xFFEF4444);

  // 감미료 class 색
  static const natural = Color(0xFF16A34A); // 천연
  static const artificial = Color(0xFF6366F1); // 인공
  static const sugarAlcohol = Color(0xFFF59E0B); // 당알코올
  static const etc = Color(0xFF94A3B8); // 기타

  static Color grade(Grade g) => switch (g) {
        Grade.low => low,
        Grade.mid => mid,
        Grade.caution => caution,
      };

  static Color klass(String k) => switch (k) {
        '천연' => natural,
        '인공' => artificial,
        '당알코올' => sugarAlcohol,
        _ => etc,
      };
}

ThemeData buildCubedTheme() {
  final base = ThemeData.light(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: CubedColors.bg,
    colorScheme: base.colorScheme.copyWith(
      primary: CubedColors.brand,
      surface: CubedColors.surface,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: CubedColors.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: CubedColors.ink,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
      iconTheme: IconThemeData(color: CubedColors.ink),
    ),
    cardTheme: CardThemeData(
      color: CubedColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: CubedColors.line),
      ),
      margin: EdgeInsets.zero,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: CubedColors.ink,
      displayColor: CubedColors.ink,
    ),
  );
}
