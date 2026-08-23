import 'package:flutter/material.dart';

import 'rulebook.dart';

/// ZERO DOT 디자인 토큰 — "Matcha Ink".
/// 페이퍼 그린 캔버스 위 딥 포레스트 잉크, 라임 펀치 액센트.
/// 라임은 잉크(다크) 표면 위에서만 사용한다 — 흰 배경 위 라임 텍스트 금지(대비 부족).
class CubedColors {
  // 캔버스
  static const bg = Color(0xFFF3F6F1); // 페이퍼 그린
  static const surface = Colors.white;
  static const ink = Color(0xFF10231B); // 딥 포레스트 잉크
  static const inkSoft = Color(0xFF5F7168); // 그린 틴트 그레이
  static const line = Color(0xFFE3EAE3);

  // 브랜드 투톤
  static const brand = Color(0xFF0FA678); // 코어 그린
  static const brandDeep = Color(0xFF0A6B4F); // 딥 그린 (텍스트/강조)
  static const lime = Color(0xFFC9F158); // 라임 펀치 — 잉크 위 전용
  static const inkCard = Color(0xFF13261E); // 다크 히어로 카드

  // 혈당 등급 신호등 (흰 배경 텍스트로도 쓰이므로 대비 확보 톤)
  static const low = Color(0xFF17A05B);
  static const mid = Color(0xFFDB8A00);
  static const caution = Color(0xFFE5484D);

  static Color grade(Grade g) => switch (g) {
        Grade.low => low,
        Grade.mid => mid,
        Grade.caution => caution,
      };
}

/// 형태 언어 — 라운드·그림자 토큰.
class CubedFx {
  static const radiusHero = 28.0;
  static const radiusCard = 20.0;
  static const radiusField = 16.0;

  /// 카드용 소프트 섀도우 (경계선 대신 깊이로 구분)
  static const shadowCard = [
    BoxShadow(color: Color(0x0D10231B), blurRadius: 20, offset: Offset(0, 6)),
  ];

  /// 히어로·독(dock)용 리프트 섀도우
  static const shadowLift = [
    BoxShadow(color: Color(0x1A10231B), blurRadius: 32, offset: Offset(0, 10)),
  ];
}

/// 각설탕 스택 장식 — CUBED 아이덴티티의 미니 큐브 3개.
/// 다크(inkCard) 표면 위 사용 전제 (라임은 잉크 위 전용).
class SugarCubeStack extends StatelessWidget {
  const SugarCubeStack({super.key, this.size = 64});
  final double size;

  Widget _cube(double s, double alpha, double angle) => Transform.rotate(
        angle: angle,
        child: Container(
          width: s,
          height: s,
          decoration: BoxDecoration(
            color: CubedColors.lime.withValues(alpha: alpha),
            borderRadius: BorderRadius.circular(s * 0.28),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final u = size / 64; // 64px 기준 비율
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
              right: 0, top: 2 * u, child: _cube(26 * u, 0.25, 0.35)),
          Positioned(
              left: 2 * u, bottom: 0, child: _cube(20 * u, 0.45, -0.25)),
          _cube(34 * u, 1, 0.12),
        ],
      ),
    );
  }
}

ThemeData buildCubedTheme() {
  const scheme = ColorScheme.light(
    primary: CubedColors.brand,
    onPrimary: Colors.white,
    secondary: CubedColors.lime,
    onSecondary: CubedColors.ink,
    surface: CubedColors.surface,
    onSurface: CubedColors.ink,
    error: CubedColors.caution,
    outline: CubedColors.line,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Pretendard',
    scaffoldBackgroundColor: CubedColors.bg,
  );
  final text = base.textTheme
      .apply(bodyColor: CubedColors.ink, displayColor: CubedColors.ink);
  return base.copyWith(
    textTheme: text.copyWith(
      headlineMedium: const TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 27,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        height: 1.22,
        color: CubedColors.ink,
      ),
      titleLarge: const TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 19,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        color: CubedColors.ink,
      ),
      bodyMedium: const TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 14,
        height: 1.45,
        color: CubedColors.ink,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: CubedColors.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Pretendard',
        color: CubedColors.ink,
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
      iconTheme: IconThemeData(color: CubedColors.ink),
    ),
    cardTheme: CardThemeData(
      color: CubedColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CubedFx.radiusCard),
        side: const BorderSide(color: CubedColors.line),
      ),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: CubedColors.ink,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CubedFx.radiusField),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: CubedColors.brand,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CubedFx.radiusField),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: CubedColors.brandDeep,
        textStyle: const TextStyle(
          fontFamily: 'Pretendard',
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: CubedColors.surface,
      hintStyle: const TextStyle(color: CubedColors.inkSoft, fontSize: 14),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CubedFx.radiusField),
        borderSide: const BorderSide(color: CubedColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CubedFx.radiusField),
        borderSide: const BorderSide(color: CubedColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CubedFx.radiusField),
        borderSide: const BorderSide(color: CubedColors.brand, width: 1.6),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: CubedColors.ink,
      contentTextStyle: const TextStyle(
        fontFamily: 'Pretendard',
        color: Colors.white,
        fontSize: 14,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: CubedColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: CubedColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: const TextStyle(
        fontFamily: 'Pretendard',
        color: CubedColors.ink,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    ),
    dividerTheme: const DividerThemeData(color: CubedColors.line),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: CubedColors.surface,
      side: const BorderSide(color: CubedColors.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      labelStyle: const TextStyle(
        fontFamily: 'Pretendard',
        color: CubedColors.ink,
        fontWeight: FontWeight.w600,
      ),
    ),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: CubedColors.brand),
    listTileTheme: const ListTileThemeData(iconColor: CubedColors.inkSoft),
  );
}
