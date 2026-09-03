// lib/core/sugar_cube.dart
import 'package:flutter/material.dart';

import 'rulebook.dart';
import 'theme.dart';

/// 각설탕 큐브 — CUBED 의 이름이 곧 단위가 되는 표현 계층.
///
/// 여기서 새로 판정하지 않는다. 등급·순탄수는 rulebook 값을 그대로 받아 쓰고,
/// 이 파일은 **환산해 그리기만** 한다.
///
/// 큐브는 한 가지 일만 한다 — **판정 표시**. 신호등을 대신한다.
/// 낮음·중간·주의 세 칸 중 rulebook 등급까지 채운다. 수량이 아니라 단계다.
///
/// 당류·순탄수 같은 수치는 결과 화면의 수치 3칸이 이미 보여주므로
/// 여기서 되풀이하지 않는다.

/// 손으로 올려놓은 듯 보이도록 조각마다 다른 각도를 준다.
/// 난수가 아니라 고정 배열 — 같은 제품은 항상 같은 모양이어야 한다.
const List<double> _tilt = [-0.07, 0.05, -0.03, 0.09, -0.06, 0.02, 0.08, -0.04];

/// 각설탕 한 조각.
class SugarCube extends StatelessWidget {
  const SugarCube({
    super.key,
    required this.size,
    required this.color,
    this.fill = 1.0,
    this.tilt = 0,
  });

  final double size;
  final Color color;

  /// 0~1. 1 미만이면 아래에서부터 그만큼만 찬다(0.7조각 같은 표현).
  final double fill;
  final double tilt;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: tilt,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(size * 0.28),
          border: Border.all(color: color.withValues(alpha: 0.55), width: 1.4),
        ),
        clipBehavior: Clip.antiAlias,
        child: fill <= 0
            ? null
            : Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: fill.clamp(0.0, 1.0),
                  widthFactor: 1,
                  child: ColoredBox(color: color),
                ),
              ),
      ),
    );
  }
}

/// 판정 큐브 — 신호등을 대신한다.
/// 낮음·중간·주의 세 칸 중 rulebook 등급까지 채운다. 수량이 아니라 단계다.
class GradeCubes extends StatelessWidget {
  const GradeCubes({
    super.key,
    required this.grade,
    this.cubeSize = 34,
    this.alignment = WrapAlignment.start,
  });

  final Grade grade;
  final double cubeSize;
  final WrapAlignment alignment;

  static const _steps = [Grade.low, Grade.mid, Grade.caution];

  @override
  Widget build(BuildContext context) {
    final active = CubedColors.grade(grade);
    final reached = _steps.indexOf(grade);
    return Wrap(
      spacing: 8,
      alignment: alignment,
      children: [
        for (var i = 0; i < _steps.length; i++)
          SugarCube(
            size: cubeSize,
            color: i <= reached ? active : const Color(0xFFC7D0C9),
            fill: i <= reached ? 1 : 0,
            tilt: _tilt[i % _tilt.length],
          ),
      ],
    );
  }
}

/// 기능 아이콘 — 머티리얼 아이콘 대신 큐브에서 파생한 픽토그램.
enum CubeGlyph { shoot, find, ask, log }

class CubeBadge extends StatelessWidget {
  const CubeBadge({
    super.key,
    required this.glyph,
    this.size = 46,
    this.color = CubedColors.brandDeep,
    this.tilt = -0.06,
  });

  final CubeGlyph glyph;
  final double size;
  final Color color;
  final double tilt;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: tilt,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(size * 0.28),
        ),
        child: CustomPaint(painter: _GlyphPainter(glyph)),
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.glyph);
  final CubeGlyph glyph;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.055
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = size.width, h = size.height;
    final m = w * 0.30;

    switch (glyph) {
      case CubeGlyph.shoot: // 촬영 — 네 모서리 프레임 + 가운데 점
        final r = w * 0.10;
        for (final o in const [
          [1, 1],
          [-1, 1],
          [1, -1],
          [-1, -1],
        ]) {
          final x = w / 2 + o[0] * (w / 2 - m);
          final y = h / 2 + o[1] * (h / 2 - m);
          canvas.drawLine(Offset(x, y), Offset(x - o[0] * r, y), p);
          canvas.drawLine(Offset(x, y), Offset(x, y - o[1] * r), p);
        }
        canvas.drawCircle(
            Offset(w / 2, h / 2), w * 0.09, p..style = PaintingStyle.fill);
        break;

      case CubeGlyph.find: // 검색 — 큐브 윤곽 + 손잡이
        final rect = Rect.fromCenter(
            center: Offset(w * 0.45, h * 0.44),
            width: w * 0.34,
            height: h * 0.34);
        canvas.drawRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(w * 0.09)), p);
        canvas.drawLine(
            Offset(w * 0.60, h * 0.60), Offset(w * 0.74, h * 0.74), p);
        break;

      case CubeGlyph.ask: // 문의 — 말풍선 + 점 셋
        final rect = Rect.fromLTWH(m * 0.85, m * 0.9, w - m * 1.7, h * 0.36);
        canvas.drawRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(w * 0.09)), p);
        canvas.drawLine(Offset(w * 0.36, rect.bottom),
            Offset(w * 0.30, rect.bottom + h * 0.13), p);
        p.style = PaintingStyle.fill;
        for (var i = 0; i < 3; i++) {
          canvas.drawCircle(
              Offset(rect.left + rect.width * (0.25 + 0.25 * i),
                  rect.center.dy),
              w * 0.035,
              p);
        }
        break;

      case CubeGlyph.log: // 기록 — 큐브 넷 중 하나만 채움
        final s = w * 0.17, g = w * 0.07;
        final ox = (w - (s * 2 + g)) / 2, oy = (h - (s * 2 + g)) / 2;
        for (var r = 0; r < 2; r++) {
          for (var c = 0; c < 2; c++) {
            final rect =
                Rect.fromLTWH(ox + c * (s + g), oy + r * (s + g), s, s);
            p.style =
                (r == 1 && c == 0) ? PaintingStyle.fill : PaintingStyle.stroke;
            canvas.drawRRect(
                RRect.fromRectAndRadius(rect, Radius.circular(s * 0.28)), p);
          }
        }
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter old) => old.glyph != glyph;
}

/// 잉크 면에 큐브를 흩뿌린 배경. 격자가 아니라 손으로 놓은 배치.
class CubeScatter extends StatelessWidget {
  const CubeScatter({super.key, this.color = CubedColors.lime});
  final Color color;

  // (좌비율, 상비율, 크기, 기울기, 불투명도)
  static const _spots = [
    [0.06, 0.62, 26.0, 0.22, 0.10],
    [0.24, 0.14, 16.0, -0.35, 0.08],
    [0.52, 0.72, 20.0, 0.10, 0.07],
    [0.71, 0.22, 30.0, -0.18, 0.09],
    [0.88, 0.58, 18.0, 0.30, 0.07],
    [0.40, 0.36, 12.0, -0.12, 0.06],
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) => Stack(
        children: [
          for (final s in _spots)
            Positioned(
              left: c.maxWidth * s[0],
              top: c.maxHeight * s[1],
              child: Transform.rotate(
                angle: s[3],
                child: Container(
                  width: s[2],
                  height: s[2],
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: s[4]),
                    borderRadius: BorderRadius.circular(s[2] * 0.28),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
