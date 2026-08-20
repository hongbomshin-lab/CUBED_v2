import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../providers/providers.dart';

/// 배수 → 표시 문자열 (순수 함수, 테스트 대상). kcal은 정수 반올림, 순탄수는 소수 1자리.
///
/// 순탄수는 룰북이 소수 2자리로 주므로 백분위 정수 공간에서 계산해 이중 반올림을 피한다.
/// factor는 슬라이더 특성상 항상 0.5의 배수 → factor*2는 정확한 정수.
/// (netCarb*factor를 곧바로 double로 곱하면 4.1*1.5=6.1499999999999995 같은
/// 부동소수점 오차로 반올림이 한 자리 어긋날 수 있다.)
String portionSummary({required double factor, required double netCarb, required double kcal}) {
  final ncHundredths = (netCarb * 100).round();
  final factorHalves = (factor * 2).round();
  final ncTenths = (ncHundredths * factorHalves / 20).round();
  final nc = ncTenths / 10;
  final k = (kcal * factor).round();
  final ncText = nc == nc.roundToDouble() ? nc.toInt().toString() : nc.toStringAsFixed(1);
  return '순탄수 ${ncText}g · ${k}kcal';
}

/// "이만큼 먹으면?" — 0.5~3회분 슬라이더로 순탄수·열량 총량을 즉시 재계산.
/// 등급은 농도(100당) 기준이라 바뀌지 않는다 — 총량 정보만 제공.
/// 배수는 portionFactorProvider(제품별) 공유 상태 — 개인 당류 판정 히어로가 실시간 연동된다.
class PortionSlider extends ConsumerWidget {
  const PortionSlider(
      {super.key,
      required this.productId,
      required this.netCarb,
      required this.kcal,
      required this.unitDesc});
  final String productId;
  final double netCarb;
  final double kcal;
  final String unitDesc; // "1회분(355ml)"

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final factor = ref.watch(portionFactorProvider(productId));
    final f = factor == factor.roundToDouble()
        ? factor.toInt().toString()
        : factor.toString();
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
              Flexible(
                child: Text('$unitDesc × $f',
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: CubedColors.inkSoft, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            portionSummary(factor: factor, netCarb: netCarb, kcal: kcal),
            style: const TextStyle(
                fontWeight: FontWeight.w800, fontSize: 16, color: CubedColors.ink),
          ),
          Slider(
            value: factor,
            min: 0.5,
            max: 3,
            divisions: 5,
            activeColor: CubedColors.brand,
            label: '×$f',
            onChanged: (v) =>
                ref.read(portionFactorProvider(productId).notifier).state = v,
          ),
        ],
      ),
    );
  }
}
