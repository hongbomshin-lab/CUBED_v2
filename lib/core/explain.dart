/// CUBED 결과 표현 계층 (explain) — explain.ts 포팅.
/// 룰북 계산값을 "일반 사용자 문장"으로 변환만 한다(수치 새로 만들지 않음).
library;

import 'rulebook.dart';

class ExplainInput {
  final String unit; // 'ml' | 'g'
  final String? unitDesc; // 예: "1캔(355ml)"
  final double kcal;
  final double sugar;
  final double netCarb;
  final double per100NetCarb;
  final Grade grade;
  final List<String> traps;
  final String? topSweetenerName; // 등급이 가장 높은 감미료 표시명

  const ExplainInput({
    required this.unit,
    this.unitDesc,
    required this.kcal,
    required this.sugar,
    required this.netCarb,
    required this.per100NetCarb,
    required this.grade,
    required this.traps,
    this.topSweetenerName,
  });
}

class GradeText {
  final String emoji;
  final String badge;
  final String desc;
  const GradeText(this.emoji, this.badge, this.desc);
}

const gradeText = {
  Grade.low: GradeText('🟢', '혈당 낮음', '혈당을 거의 올리지 않아요.'),
  Grade.mid: GradeText('🟡', '혈당 중간', '혈당을 어느 정도 올릴 수 있어 섭취량에 주의하세요.'),
  Grade.caution: GradeText('🔴', '혈당 주의', '혈당을 올릴 수 있어요. ‘무설탕’ 표기여도 안심은 일러요.'),
};

enum TrapTier { trap, info }

class TrapLine {
  final TrapTier tier;
  final String emoji;
  final String text;
  final String code; // 룰북 함정 코드 ('당알코올 함정' 등) — 표시층 중복 제거 키
  const TrapLine(this.tier, this.emoji, this.text, this.code);
}

String _unitWord(ExplainInput i) {
  final d = i.unitDesc?.trim();
  return (d != null && d.isNotEmpty) ? d : '1회분';
}

String _n(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/// 함정 코드 → 사용자 문장(2단계: 🚩 함정 / ℹ️ 참고)
List<TrapLine> trapLines(ExplainInput i) {
  if (i.traps.isEmpty || i.traps.contains('없음')) return [];
  final out = <TrapLine>[];
  final name = i.topSweetenerName ?? '혈당 올리는 당알코올';
  if (i.traps.contains('당알코올 함정')) {
    out.add(TrapLine(TrapTier.trap, '🚩',
        '무설탕이지만 $name 때문에 혈당이 오를 수 있어요.', '당알코올 함정'));
  }
  if (i.traps.contains('칼로리 함정')) {
    out.add(TrapLine(TrapTier.trap, '🚩',
        '당 0g이지만 열량은 있어요 — ${_unitWord(i)} ${_n(i.kcal)}kcal.', '칼로리 함정'));
  }
  if (i.traps.contains('당류 함정')) {
    out.add(TrapLine(TrapTier.info, 'ℹ️', '당류가 ${_n(i.sugar)}g으로 높은 편이에요.', '당류 함정'));
  }
  if (i.traps.contains('탄수 함정')) {
    out.add(TrapLine(TrapTier.info, 'ℹ️',
        '당은 낮지만 100${i.unit}당 순탄수 ${_n(i.per100NetCarb)}g — 탄수는 있어요.', '탄수 함정'));
  }
  return out;
}

/// 등급 근거 한 줄
String reasonLine(ExplainInput i) {
  final sw = i.topSweetenerName != null ? '${i.topSweetenerName}(감미료)' : '감미료 없음';
  return '근거: $sw + 100${i.unit}당 순탄수 ${_n(i.per100NetCarb)}g → 혈당 ${i.grade.ko}';
}
