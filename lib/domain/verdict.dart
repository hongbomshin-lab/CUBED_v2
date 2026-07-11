// lib/domain/verdict.dart
/// 판정 표현층 — Interpretation을 "답 한 줄 + 이유 불릿(중복 제거)"로 압축한다.
/// 수치를 새로 만들지 않는다(절대 원칙). 룰북 코드가 유일한 중복 제거 키.
library;

import '../core/explain.dart';
import '../core/rulebook.dart';
import 'interpretation.dart';

enum VerdictKind {
  zeroBusted, // 무설탕 표기지만 함정/등급 반전
  zeroTrue, // 무설탕 표기가 진짜
  generic, // 무설탕 표기 아님 — 스트립 없이 등급+불릿
}

class Verdict {
  final VerdictKind kind;
  final Grade grade;
  final String labelText; // 스트립 왼쪽 ("무설탕·제로"). generic은 ''.
  final String realityText; // 스트립 오른쪽. generic은 ''.
  final List<String> whyBullets; // 최대 3, 함정·성분노트 중복 제거됨

  const Verdict({
    required this.kind,
    required this.grade,
    required this.labelText,
    required this.realityText,
    required this.whyBullets,
  });

  static Verdict of(Interpretation it) {
    final zero = it.product.sugar <= 0.5; // rulebook.traps의 zero 기준과 동일
    if (!zero) {
      return Verdict(
        kind: VerdictKind.generic, grade: it.grade,
        labelText: '', realityText: '', whyBullets: _bullets(it),
      );
    }
    final busted = it.hasTrap || it.grade != Grade.low;
    if (busted) {
      return Verdict(
        kind: VerdictKind.zeroBusted, grade: it.grade,
        labelText: '무설탕·제로', realityText: _bustedReality(it),
        whyBullets: _bullets(it),
      );
    }
    return Verdict(
      kind: VerdictKind.zeroTrue, grade: it.grade,
      labelText: '무설탕·제로', realityText: '진짜예요',
      // "진짜예요"와 모순되는 ℹ️ 참고 불릿(당류/탄수 함정)은 싣지 않는다
      whyBullets: _bullets(it, includeInfo: false),
    );
  }

  static String _bustedReality(Interpretation it) {
    if (it.trapCodes.contains('당알코올 함정') || it.grade == Grade.caution) {
      return '혈당 올라요';
    }
    if (it.grade == Grade.mid) return '혈당 조금 올라요';
    return '열량은 있어요'; // 남는 경우: 칼로리 함정만
  }

  /// 함정 라인 기반 + 단일 성분 warn 규칙 승격(priority 내림차순).
  /// 같은 성분을 두 번 말하지 않는다. [includeInfo]가 false면 ℹ️ 참고 라인 제외.
  static List<String> _bullets(Interpretation it, {bool includeInfo = true}) {
    final out = <String>[];
    final usedSlugs = <String>{};
    for (final line in it.trapLines) {
      if (!includeInfo && line.tier == TrapTier.info) continue;
      if (line.code == '당알코올 함정') {
        final slug = it.topSweetenerSlug;
        final note = slug == null ? null : it.slugNotes[slug];
        if (slug != null && note != null) {
          out.add(note.message); // 함정 문장 대신 더 풍부한 성분 카피
          usedSlugs.add(slug);
          continue;
        }
      }
      out.add(line.text);
    }
    final warns = it.slugNotes.entries
        .where((e) => e.value.tone == 'warn' && !usedSlugs.contains(e.key))
        .toList()
      ..sort((a, b) => b.value.priority.compareTo(a.value.priority));
    for (final e in warns) {
      out.add(e.value.message);
    }
    if (out.isEmpty) out.add(gradeText[it.grade]!.desc);
    return out.take(3).toList();
  }
}
