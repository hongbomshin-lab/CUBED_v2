import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// 배수 → 표시 문자열 (순수 함수, 테스트 대상). kcal은 정수 반올림, 순탄수는 소수 1자리.
///
/// 슬라이더의 factor는 항상 0.5 단위(1, 1.5, 2 ...)이므로 factor*2는 정수다.
/// netCarb*factor를 곧바로 double로 곱하면 4.1*1.5=6.1499999999999995 같은
/// 부동소수점 오차로 반올림이 한 자리 어긋날 수 있어, 정수 연산(10분의 1 단위)으로
/// 계산해 오차를 없앤다.
String portionSummary({required double factor, required double netCarb, required double kcal}) {
  final netCarbTenths = (netCarb * 10).round();
  final factorHalves = (factor * 2).round();
  final ncTenths = (netCarbTenths * factorHalves / 2).round();
  final k = (kcal * factor).round();
  final ncText = ncTenths % 10 == 0
      ? (ncTenths ~/ 10).toString()
      : (ncTenths / 10).toStringAsFixed(1);
  return '순탄수 ${ncText}g · ${k}kcal';
}

/// "이만큼 먹으면?" — 0.5~3회분 슬라이더로 순탄수·열량 총량을 즉시 재계산.
/// 등급은 농도(100당) 기준이라 바뀌지 않는다 — 총량 정보만 제공.
class PortionSlider extends StatefulWidget {
  const PortionSlider({super.key, required this.netCarb, required this.kcal, required this.unitDesc});
  final double netCarb;
  final double kcal;
  final String unitDesc; // "1회분(355ml)"

  @override
  State<PortionSlider> createState() => _PortionSliderState();
}

class _PortionSliderState extends State<PortionSlider> {
  double _factor = 1;

  @override
  Widget build(BuildContext context) {
    final f = _factor == _factor.roundToDouble()
        ? _factor.toInt().toString()
        : _factor.toString();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(
        color: CubedColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CubedColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('이만큼 먹으면?',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              Text('${widget.unitDesc} × $f',
                  style: const TextStyle(color: CubedColors.inkSoft, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            portionSummary(factor: _factor, netCarb: widget.netCarb, kcal: widget.kcal),
            style: const TextStyle(
                fontWeight: FontWeight.w800, fontSize: 16, color: CubedColors.ink),
          ),
          Slider(
            value: _factor,
            min: 0.5,
            max: 3,
            divisions: 5,
            activeColor: CubedColors.brand,
            label: '×$f',
            onChanged: (v) => setState(() => _factor = v),
          ),
        ],
      ),
    );
  }
}
