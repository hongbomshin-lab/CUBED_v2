# 제품 해석 페이지 UX 재편 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 해석 결과 화면을 "답 → 이유 → 행동 → 근거(접힘)" 4층 구조로 재편하고, "라벨 vs 실제" 판정 스트립·칩 바텀시트·양 슬라이더·AI 질문 진입점을 추가한다.

**Architecture:** 룰북/DB 로직은 불변. 새 도메인 표현층 `Verdict`(순수 Dart, 중복 제거 로직 포함)를 `Interpretation` 위에 얹고, `combo_rules`를 다중 조합(레시피 한 줄)과 단일 성분(칩 바텀시트)으로 역할 분리한다. UI는 `lib/features/result/` 안에서 재조립.

**Tech Stack:** Flutter + Riverpod, flutter_test. Supabase 스키마 변경 없음.

---

## ⚠️ 실행 전 필독: 충돌 관리

- 현재 브랜치 `feature/food-diary`에서 **다른 에이전트가 편집 중**이었음. `providers.dart`의 `todayLogProvider` 주석("결과 화면 토글 버튼 상태")으로 보아 **food-diary 작업이 `result_screen.dart`에 기록 버튼을 추가할 가능성이 높음**.
- 본 계획의 수정 범위: `lib/features/result/`, `lib/domain/`, `lib/core/explain.dart`, `lib/features/chat/chat_screen.dart`(생성자만), `test/`.
- **Task 7에서 `result_screen.dart`를 다시 읽고**, food-diary가 추가한 위젯(기록 토글 등)이 있으면 새 레이아웃의 "행동 층"(대안 추천 근처)에 보존할 것.

## 파일 구조

| 파일 | 책임 | 작업 |
|---|---|---|
| `lib/core/explain.dart` | TrapLine에 `code` 필드 추가(중복 제거의 키) | 수정 |
| `lib/domain/interpretation.dart` | `combo` → `recipeCombo`(다중) + `slugNotes`(단일) 분리; chips에 `note`·`cariogenic` 추가 | 수정 |
| `lib/domain/verdict.dart` | 판정 모델: kind(무설탕 반전/진짜/일반) + 중복 제거된 whyBullets | 생성 |
| `lib/features/result/widgets/verdict_hero.dart` | 라벨vs실제 스트립 + 신호등 + 불릿 히어로 | 생성 |
| `lib/features/result/widgets/sweetener_chips.dart` | 위험순 정렬, 탭→바텀시트, 범례 제거 | 수정 |
| `lib/features/result/widgets/sweetener_sheet.dart` | 칩 바텀시트(단일 성분 설명 + 치아 영향) | 생성 |
| `lib/features/result/widgets/portion_slider.dart` | "n회분 먹으면" 순탄수·열량 재계산 | 생성 |
| `lib/features/chat/chat_screen.dart` | `initialPrompt` 파라미터(제품 질문 딥링크) | 수정 |
| `lib/features/result/result_screen.dart` | 4층 재조립, 죽은 위젯 제거 | 수정 |
| `lib/features/result/widgets/grade_hero.dart` | verdict_hero로 대체 | 삭제 |
| `test/domain/interpretation_combo_test.dart` | recipe/slugNotes 매칭 | 생성 |
| `test/domain/verdict_test.dart` | 판정 종류·불릿 중복 제거·상한 | 생성 |
| `test/features/result/verdict_hero_test.dart` | 히어로 렌더링(프로바이더 불필요) | 생성 |

**보류(이번 스코프 아님):** ① food-diary 연동 카드("오늘 누적 순탄수 Xg") — `todayLogProvider`/`monthLogsProvider` 기반, diary 머지 후 후속. ② 각설탕 앵커("각설탕 약 N개 분량") — 순탄수≠당류 커뮤니케이션 리스크 문구 검토 후.

---

### Task 0: 작업 공간 준비

**Files:** 없음 (git만)

- [ ] **Step 1: 현재 상태 확인**

```bash
git -C C:/Users/hongb/Desktop/CUBED_app status
git -C C:/Users/hongb/Desktop/CUBED_app log --oneline -5
```

다른 에이전트의 미커밋 변경이 `lib/features/result/` 또는 `lib/features/chat/`에 있으면 **중단하고 사용자에게 보고**. 없으면 진행.

- [ ] **Step 2: 브랜치 생성** (food-diary 커밋들을 포함한 지점에서 분기 — result_screen의 diary 변경을 흡수하기 위해)

```bash
git checkout -b feature/result-ux
```

- [ ] **Step 3: 베이스라인 테스트 통과 확인**

Run: `flutter test`
Expected: 기존 테스트 전부 PASS. 실패 시 중단·보고(내 작업이 아닌 회귀).

---

### Task 1: TrapLine 코드 필드 + combo 역할 분리

**Files:**
- Modify: `lib/core/explain.dart` (TrapLine, trapLines)
- Modify: `lib/domain/interpretation.dart` (combo → recipeCombo/slugNotes, chips 확장)
- Test: `test/domain/interpretation_combo_test.dart`

- [ ] **Step 1: 실패하는 테스트 작성**

```dart
// test/domain/interpretation_combo_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cubed_app/core/rulebook.dart';
import 'package:cubed_app/data/models/product.dart';
import 'package:cubed_app/data/models/sweetener.dart';
import 'package:cubed_app/data/product_repository.dart';
import 'package:cubed_app/domain/interpretation.dart';

Sweetener sw(String slug, String name, String klass, Grade gi) => Sweetener(
      slug: slug, standardName: name, klass: klass, glycemicImpact: gi,
      cariogenicImpact: '중립', kcalPerG: 0,
    );

Product product({
  double sugar = 0, double carb = 0, double fiber = 0, double sa = 0,
  double kcal = 0, double serving = 100, String? category,
  List<ProductSweetener> sweeteners = const [],
}) => Product(
      productId: 'p1', name: '테스트', category: category,
      servingSize: serving, unit: 'g', kcal: kcal, carb: carb, sugar: sugar,
      protein: 0, fat: 0, fiber: fiber, sugarAlcohol: sa, rareSugarG: 0,
      sweetenerCount: sweeteners.length, verified: true, sweeteners: sweeteners,
    );

ReferenceData refData(List<ComboRule> rules) => ReferenceData(
      sweeteners: {
        'maltitol': sw('maltitol', '말티톨', '당알코올', Grade.caution),
        'erythritol': sw('erythritol', '에리스리톨', '당알코올', Grade.low),
        'sucralose': sw('sucralose', '수크랄로스', '인공', Grade.low),
        'maltodextrin': sw('maltodextrin', '말토덱스트린', '기타', Grade.caution),
      },
      categoryLiquid: {'음료': true, '과자': false},
      comboRules: rules,
    );

const zeroDuo = ComboRule(
    comboKey: 'erythritol+sucralose', headline: '제로의 정석',
    message: '에리스리톨 + 수크랄로스 조합.', tone: 'info', priority: 100);
const maltitolNote = ComboRule(
    comboKey: 'maltitol', headline: '말티톨 주의보',
    message: '말티톨은 무설탕 표기여도 혈당을 올릴 수 있어요.', tone: 'warn', priority: 90);

void main() {
  test('다중 조합 규칙만 recipeCombo로 매칭', () {
    final p = product(carb: 3, sa: 3, serving: 355, category: '음료', sweeteners: const [
      ProductSweetener(slug: 'erythritol', sortOrder: 0),
      ProductSweetener(slug: 'sucralose', sortOrder: 1),
    ]);
    final it = Interpretation.of(p, refData(const [zeroDuo, maltitolNote]));
    expect(it.recipeCombo?.headline, '제로의 정석');
    expect(it.slugNotes, isEmpty);
  });

  test('단일 규칙은 slugNotes로만 매칭 (recipeCombo 아님)', () {
    final p = product(carb: 20, fiber: 1, sa: 15, kcal: 120, serving: 30,
        category: '과자', sweeteners: const [ProductSweetener(slug: 'maltitol', sortOrder: 0)]);
    final it = Interpretation.of(p, refData(const [zeroDuo, maltitolNote]));
    expect(it.recipeCombo, isNull);
    expect(it.slugNotes['maltitol']?.headline, '말티톨 주의보');
  });

  test('trapLines에 룰북 코드가 실린다', () {
    final p = product(carb: 20, fiber: 1, sa: 15, kcal: 120, serving: 30,
        category: '과자', sweeteners: const [ProductSweetener(slug: 'maltitol', sortOrder: 0)]);
    final it = Interpretation.of(p, refData(const []));
    expect(it.trapLines.map((l) => l.code), contains('당알코올 함정'));
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/domain/interpretation_combo_test.dart`
Expected: FAIL — `recipeCombo`, `slugNotes`, `code` 미정의 컴파일 에러.

- [ ] **Step 3: explain.dart — TrapLine에 code 추가**

`lib/core/explain.dart`의 `TrapLine`과 `trapLines()`를 다음으로 교체:

```dart
class TrapLine {
  final TrapTier tier;
  final String emoji;
  final String text;
  final String code; // 룰북 함정 코드 ('당알코올 함정' 등) — 표시층 중복 제거 키
  const TrapLine(this.tier, this.emoji, this.text, this.code);
}
```

```dart
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
```

- [ ] **Step 4: interpretation.dart — combo 분리 + chips 확장**

`Interpretation`에서 `final ComboRule? combo;` 를 다음 두 필드로 교체(생성자 파라미터 포함):

```dart
  final ComboRule? recipeCombo; // 다중(2+ slug) 조합 — "단맛 레시피" 한 줄
  final Map<String, ComboRule> slugNotes; // 단일 slug 규칙 — 칩 바텀시트/불릿 승격용
```

`SweetenerChip`에 두 필드 추가(생성자 포함):

```dart
  final String? note; // sweeteners.note (바텀시트 보조 설명)
  final String cariogenic; // 억제 | 중립 | 유발
```

`Interpretation.of()`의 chips 매핑을 다음으로 교체:

```dart
    final chips = p.sweeteners.map((ps) {
      final sw = ref.sweeteners[ps.slug];
      return SweetenerChip(
        slug: ps.slug,
        name: sw?.standardName ?? ps.slug,
        klass: sw?.klass ?? '기타',
        glycemic: sw?.glycemicImpact ?? Grade.low,
        amountG: ps.amountG,
        isRisky: riskySugarAlcohol.contains(ps.slug),
        note: sw?.note,
        cariogenic: sw?.cariogenicImpact ?? '중립',
      );
    }).toList();
```

`_matchCombo`를 삭제하고 두 헬퍼로 교체, 생성 부분은 `recipeCombo: _matchRecipe(slugs, ref.comboRules), slugNotes: _slugNotes(slugs, ref.comboRules),`:

```dart
  /// 2개 이상 slug 조합 규칙 중 부분집합 매칭 최우선 1개 — "단맛 레시피" 한 줄용.
  static ComboRule? _matchRecipe(List<String> slugs, List<ComboRule> rules) {
    final set = slugs.toSet();
    ComboRule? best;
    for (final r in rules) {
      if (r.keySlugs.length < 2) continue;
      if (r.keySlugs.every(set.contains)) {
        if (best == null ||
            r.priority > best.priority ||
            (r.priority == best.priority && r.keySlugs.length > best.keySlugs.length)) {
          best = r;
        }
      }
    }
    return best;
  }

  /// 단일 slug 규칙: 제품에 든 감미료만 slug -> rule 매핑.
  static Map<String, ComboRule> _slugNotes(List<String> slugs, List<ComboRule> rules) {
    final set = slugs.toSet();
    final out = <String, ComboRule>{};
    for (final r in rules) {
      if (r.keySlugs.length != 1) continue;
      final s = r.keySlugs.first;
      if (set.contains(s)) out[s] = r;
    }
    return out;
  }
```

컴파일 에러가 나는 기존 소비처: `result_screen.dart`의 `it.combo` — Task 7에서 전면 교체하므로 **임시로** `it.recipeCombo`로 치환해 컴파일만 유지.

- [ ] **Step 5: 테스트 통과 확인**

Run: `flutter test test/domain/interpretation_combo_test.dart && flutter test`
Expected: 신규 3건 PASS + 기존 전체 PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/core/explain.dart lib/domain/interpretation.dart lib/features/result/result_screen.dart test/domain/interpretation_combo_test.dart
git commit -m "feat(result): combo_rules를 레시피(다중)/성분노트(단일)로 역할 분리 + TrapLine 코드 필드

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Verdict 도메인 모델 (판정 + 불릿 중복 제거)

**Files:**
- Create: `lib/domain/verdict.dart`
- Test: `test/domain/verdict_test.dart`

- [ ] **Step 1: 실패하는 테스트 작성**

```dart
// test/domain/verdict_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cubed_app/core/rulebook.dart';
import 'package:cubed_app/data/models/product.dart';
import 'package:cubed_app/data/models/sweetener.dart';
import 'package:cubed_app/data/product_repository.dart';
import 'package:cubed_app/domain/interpretation.dart';
import 'package:cubed_app/domain/verdict.dart';

Sweetener sw(String slug, String name, String klass, Grade gi) => Sweetener(
      slug: slug, standardName: name, klass: klass, glycemicImpact: gi,
      cariogenicImpact: '중립', kcalPerG: 0,
    );

Product product({
  double sugar = 0, double carb = 0, double fiber = 0, double sa = 0,
  double kcal = 0, double serving = 100, String? category,
  List<ProductSweetener> sweeteners = const [],
}) => Product(
      productId: 'p1', name: '테스트', category: category,
      servingSize: serving, unit: 'g', kcal: kcal, carb: carb, sugar: sugar,
      protein: 0, fat: 0, fiber: fiber, sugarAlcohol: sa, rareSugarG: 0,
      sweetenerCount: sweeteners.length, verified: true, sweeteners: sweeteners,
    );

ReferenceData refData(List<ComboRule> rules) => ReferenceData(
      sweeteners: {
        'maltitol': sw('maltitol', '말티톨', '당알코올', Grade.caution),
        'erythritol': sw('erythritol', '에리스리톨', '당알코올', Grade.low),
        'sucralose': sw('sucralose', '수크랄로스', '인공', Grade.low),
        'maltodextrin': sw('maltodextrin', '말토덱스트린', '기타', Grade.caution),
      },
      categoryLiquid: {'음료': true, '과자': false},
      comboRules: rules,
    );

const maltitolNote = ComboRule(
    comboKey: 'maltitol', headline: '말티톨 주의보',
    message: '말티톨은 무설탕 표기여도 혈당을 올릴 수 있어요.', tone: 'warn', priority: 90);
const maltodextrinNote = ComboRule(
    comboKey: 'maltodextrin', headline: '숨은 고GI 주의',
    message: '말토덱스트린은 혈당을 빨리 올릴 수 있어요.', tone: 'warn', priority: 85);

Interpretation interp(Product p, List<ComboRule> rules) =>
    Interpretation.of(p, refData(rules));

void main() {
  final maltitolSnack = product(carb: 20, fiber: 1, sa: 15, kcal: 120, serving: 30,
      category: '과자', sweeteners: const [ProductSweetener(slug: 'maltitol', sortOrder: 0)]);
  final zeroDrink = product(carb: 3, sa: 3, serving: 355, category: '음료',
      sweeteners: const [
        ProductSweetener(slug: 'erythritol', sortOrder: 0),
        ProductSweetener(slug: 'sucralose', sortOrder: 1),
      ]);

  test('무설탕인데 함정 → zeroBusted, 혈당 올라요', () {
    final v = Verdict.of(interp(maltitolSnack, const []));
    expect(v.kind, VerdictKind.zeroBusted);
    expect(v.realityText, '혈당 올라요');
  });

  test('당알코올 함정 불릿은 단일 규칙 카피로 대체(중복 제거)', () {
    final v = Verdict.of(interp(maltitolSnack, const [maltitolNote]));
    expect(v.whyBullets, contains(maltitolNote.message));
    expect(v.whyBullets.where((b) => b.contains('때문에 혈당이 오를 수')), isEmpty);
  });

  test('진짜 제로 → zeroTrue, 진짜예요', () {
    final v = Verdict.of(interp(zeroDrink, const []));
    expect(v.kind, VerdictKind.zeroTrue);
    expect(v.realityText, '진짜예요');
    expect(v.whyBullets, isNotEmpty); // 폴백: 등급 설명 문장
  });

  test('당류 있는 일반 제품 → generic, 스트립 없음', () {
    final p = product(sugar: 12, carb: 20, kcal: 150, serving: 50, category: '과자');
    final v = Verdict.of(interp(p, const []));
    expect(v.kind, VerdictKind.generic);
    expect(v.labelText, '');
  });

  test('함정에 안 잡힌 warn 단일 규칙은 불릿으로 승격, 최대 3개', () {
    final p = product(carb: 25, sa: 15, kcal: 200, serving: 30, category: '과자',
        sweeteners: const [
          ProductSweetener(slug: 'maltitol', sortOrder: 0),
          ProductSweetener(slug: 'maltodextrin', sortOrder: 1),
        ]);
    final v = Verdict.of(interp(p, const [maltitolNote, maltodextrinNote]));
    expect(v.whyBullets, contains(maltodextrinNote.message));
    expect(v.whyBullets.length, lessThanOrEqualTo(3));
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/domain/verdict_test.dart`
Expected: FAIL — verdict.dart 없음.

- [ ] **Step 3: 구현**

```dart
// lib/domain/verdict.dart
/// 판정 표현층 — Interpretation을 "답 한 줄 + 이유 불릿(중복 제거)"로 압축한다.
/// 수치를 새로 만들지 않는다(절대 원칙). 룰북 코드가 유일한 중복 제거 키.
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
      whyBullets: _bullets(it),
    );
  }

  static String _bustedReality(Interpretation it) {
    if (it.trapCodes.contains('당알코올 함정') || it.grade == Grade.caution) {
      return '혈당 올라요';
    }
    if (it.grade == Grade.mid) return '혈당 조금 올라요';
    return '열량은 있어요'; // 남는 경우: 칼로리 함정만
  }

  /// 함정 라인 기반 + 단일 성분 warn 규칙 승격. 같은 성분을 두 번 말하지 않는다.
  static List<String> _bullets(Interpretation it) {
    final out = <String>[];
    final usedSlugs = <String>{};
    for (final line in it.trapLines) {
      if (line.code == '당알코올 함정') {
        final risky = it.chips.where((c) => c.isRisky);
        final note = risky.isEmpty ? null : it.slugNotes[risky.first.slug];
        if (note != null) {
          out.add(note.message); // 함정 문장 대신 더 풍부한 성분 카피
          usedSlugs.add(risky.first.slug);
          continue;
        }
      }
      out.add(line.text);
    }
    for (final e in it.slugNotes.entries) {
      if (e.value.tone == 'warn' && !usedSlugs.contains(e.key)) {
        out.add(e.value.message);
      }
    }
    if (out.isEmpty) out.add(gradeText[it.grade]!.desc);
    return out.take(3).toList();
  }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/domain/verdict_test.dart`
Expected: 5건 PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/verdict.dart test/domain/verdict_test.dart
git commit -m "feat(result): Verdict 판정 모델 — 답 한 줄 + 이유 불릿 중복 제거

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: VerdictHero 위젯 (라벨 vs 실제 스트립)

**Files:**
- Create: `lib/features/result/widgets/verdict_hero.dart`
- Test: `test/features/result/verdict_hero_test.dart`

- [ ] **Step 1: 실패하는 위젯 테스트 작성** (프로바이더 불필요 — Interpretation을 직접 주입)

```dart
// test/features/result/verdict_hero_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cubed_app/core/rulebook.dart';
import 'package:cubed_app/data/models/product.dart';
import 'package:cubed_app/data/models/sweetener.dart';
import 'package:cubed_app/data/product_repository.dart';
import 'package:cubed_app/domain/interpretation.dart';
import 'package:cubed_app/features/result/widgets/verdict_hero.dart';

Sweetener sw(String slug, String name, String klass, Grade gi) => Sweetener(
      slug: slug, standardName: name, klass: klass, glycemicImpact: gi,
      cariogenicImpact: '중립', kcalPerG: 0,
    );

Product product({
  double sugar = 0, double carb = 0, double fiber = 0, double sa = 0,
  double kcal = 0, double serving = 100, String? category,
  List<ProductSweetener> sweeteners = const [],
}) => Product(
      productId: 'p1', name: '테스트', category: category,
      servingSize: serving, unit: 'g', kcal: kcal, carb: carb, sugar: sugar,
      protein: 0, fat: 0, fiber: fiber, sugarAlcohol: sa, rareSugarG: 0,
      sweetenerCount: sweeteners.length, verified: true, sweeteners: sweeteners,
    );

ReferenceData refData() => ReferenceData(
      sweeteners: {
        'maltitol': sw('maltitol', '말티톨', '당알코올', Grade.caution),
        'erythritol': sw('erythritol', '에리스리톨', '당알코올', Grade.low),
      },
      categoryLiquid: {'음료': true, '과자': false},
      comboRules: const [],
    );

Widget host(Interpretation it) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: VerdictHero(it: it))));

void main() {
  testWidgets('반전 케이스: 라벨 vs 실제 스트립 표시', (tester) async {
    final p = product(carb: 20, fiber: 1, sa: 15, kcal: 120, serving: 30,
        category: '과자', sweeteners: const [ProductSweetener(slug: 'maltitol', sortOrder: 0)]);
    await tester.pumpWidget(host(Interpretation.of(p, refData())));
    expect(find.text('무설탕·제로'), findsOneWidget);
    expect(find.text('혈당 올라요'), findsOneWidget);
  });

  testWidgets('진짜 제로: 진짜예요 확인 스트립', (tester) async {
    final p = product(carb: 3, sa: 3, serving: 355, category: '음료',
        sweeteners: const [ProductSweetener(slug: 'erythritol', sortOrder: 0)]);
    await tester.pumpWidget(host(Interpretation.of(p, refData())));
    expect(find.text('진짜예요'), findsOneWidget);
  });

  testWidgets('일반 제품: 스트립 없이 등급 배지', (tester) async {
    final p = product(sugar: 12, carb: 20, kcal: 150, serving: 50, category: '과자');
    await tester.pumpWidget(host(Interpretation.of(p, refData())));
    expect(find.text('무설탕·제로'), findsNothing);
    expect(find.text('혈당 주의'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/features/result/verdict_hero_test.dart`
Expected: FAIL — verdict_hero.dart 없음.

- [ ] **Step 3: 구현**

```dart
// lib/features/result/widgets/verdict_hero.dart
import 'package:flutter/material.dart';

import '../../../core/explain.dart';
import '../../../core/rulebook.dart';
import '../../../core/theme.dart';
import '../../../domain/interpretation.dart';
import '../../../domain/verdict.dart';

/// 답 + 이유 히어로: [라벨 vs 실제] 스트립(무설탕 표기 제품) 또는 등급 배지,
/// 그 아래 중복 제거된 이유 불릿 최대 3개, 핵심 수치 3칸.
class VerdictHero extends StatelessWidget {
  const VerdictHero({super.key, required this.it});
  final Interpretation it;

  @override
  Widget build(BuildContext context) {
    final v = Verdict.of(it);
    final c = CubedColors.grade(v.grade);
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _SignalLights(active: v.grade),
              const SizedBox(width: 14),
              Expanded(
                child: v.kind == VerdictKind.generic
                    ? _GradeBadge(grade: v.grade)
                    : _LabelVsReality(v: v),
              ),
            ],
          ),
          if (v.whyBullets.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final b in v.whyBullets)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 7),
                            width: 5, height: 5,
                            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(b,
                                style: const TextStyle(fontSize: 14, height: 1.45)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
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

/// "라벨이 말하는 것 → 몸이 겪는 것" 두 칸 스트립
class _LabelVsReality extends StatelessWidget {
  const _LabelVsReality({required this.v});
  final Verdict v;

  @override
  Widget build(BuildContext context) {
    final good = v.kind == VerdictKind.zeroTrue;
    final c = good ? CubedColors.low : CubedColors.grade(v.grade);
    Widget cell(String caption, String text, {required bool strong}) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: strong ? c.withValues(alpha: 0.16) : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(caption,
                    style: const TextStyle(fontSize: 11, color: CubedColors.inkSoft)),
                const SizedBox(height: 2),
                Text(text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800,
                        color: strong ? c : CubedColors.ink)),
              ],
            ),
          ),
        );
    return Row(
      children: [
        cell('라벨이 말하는 것', v.labelText, strong: false),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.arrow_forward_rounded, size: 18, color: c),
        ),
        cell('몸이 겪는 것', v.realityText, strong: true),
      ],
    );
  }
}

class _GradeBadge extends StatelessWidget {
  const _GradeBadge({required this.grade});
  final Grade grade;
  @override
  Widget build(BuildContext context) {
    final gt = gradeText[grade]!;
    final c = CubedColors.grade(grade);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(gt.badge, style: TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: 22)),
        const SizedBox(height: 2),
        Text(gt.desc, style: const TextStyle(color: CubedColors.inkSoft, fontSize: 13, height: 1.4)),
      ],
    );
  }
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
        width: 18, height: 18,
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
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/features/result/verdict_hero_test.dart`
Expected: 3건 PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/result/widgets/verdict_hero.dart test/features/result/verdict_hero_test.dart
git commit -m "feat(result): VerdictHero — 라벨 vs 실제 판정 스트립 + 이유 불릿

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: 칩 재작업 + 성분 바텀시트

**Files:**
- Create: `lib/features/result/widgets/sweetener_sheet.dart`
- Modify: `lib/features/result/widgets/sweetener_chips.dart` (전면 교체)

- [ ] **Step 1: 바텀시트 구현**

```dart
// lib/features/result/widgets/sweetener_sheet.dart
import 'package:flutter/material.dart';

import '../../../core/rulebook.dart';
import '../../../core/theme.dart';
import '../../../data/models/product.dart';
import '../../../domain/interpretation.dart';

/// 칩 탭 → 성분 상세 바텀시트. 단일 성분 combo 규칙(slugNotes)이 본문,
/// 없으면 등급 기반 기본 문장. 치아 영향(cariogenic)도 함께 표시.
void showSweetenerSheet(BuildContext context, SweetenerChip c, ComboRule? note) {
  showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _SheetBody(c: c, note: note),
  );
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({required this.c, required this.note});
  final SweetenerChip c;
  final ComboRule? note;

  String get _fallback => switch (c.glycemic) {
        Grade.caution => '${c.name}은(는) 혈당을 올릴 수 있는 감미료예요. 양 조절이 필요해요.',
        Grade.mid => '${c.name}은(는) 혈당을 약간 올릴 수 있어요.',
        Grade.low => '${c.name}은(는) 혈당에 거의 영향이 없어요.',
      };

  @override
  Widget build(BuildContext context) {
    final gc = CubedColors.grade(c.glycemic);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(note?.headline ?? c.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: gc.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('혈당 ${c.glycemic.ko}',
                      style: TextStyle(color: gc, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('${c.klass} 감미료${c.amountG != null ? ' · ${_n(c.amountG!)}g 함유' : ''}',
                style: const TextStyle(color: CubedColors.inkSoft, fontSize: 13)),
            const SizedBox(height: 14),
            Text(note?.message ?? _fallback,
                style: const TextStyle(fontSize: 15, height: 1.55)),
            if (c.note != null && c.note!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(c.note!,
                  style: const TextStyle(color: CubedColors.inkSoft, fontSize: 13, height: 1.5)),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.emoji_emotions_outlined, size: 16, color: CubedColors.inkSoft),
                const SizedBox(width: 6),
                Text(
                  switch (c.cariogenic) {
                    '억제' => '치아: 충치균 억제에 도움',
                    '유발' => '치아: 충치 유발 가능',
                    _ => '치아: 중립',
                  },
                  style: const TextStyle(color: CubedColors.inkSoft, fontSize: 13),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _n(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}
```

- [ ] **Step 2: 칩 위젯 교체** — 위험순 정렬, 탭 가능, class 4색/범례 제거, 2단계 마커만

`lib/features/result/widgets/sweetener_chips.dart` 전체를 다음으로 교체:

```dart
import 'package:flutter/material.dart';

import '../../../core/rulebook.dart';
import '../../../core/theme.dart';
import '../../../data/models/product.dart';
import '../../../domain/interpretation.dart';
import 'sweetener_sheet.dart';

/// 대체당 칩 — 혈당 위험 내림차순 정렬, 탭하면 성분 바텀시트.
/// 분류색·범례 없이 '혈당 올림' 마커 하나로 단순화.
class SweetenerChips extends StatelessWidget {
  const SweetenerChips({super.key, required this.chips, required this.notes});
  final List<SweetenerChip> chips;
  final Map<String, ComboRule> notes; // slug -> 단일 성분 규칙

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) {
      return const Text('표시된 대체당이 없어요.',
          style: TextStyle(color: CubedColors.inkSoft, fontSize: 13));
    }
    int rank(SweetenerChip c) =>
        switch (c.glycemic) { Grade.caution => 2, Grade.mid => 1, Grade.low => 0 };
    final sorted = [...chips]..sort((a, b) => rank(b).compareTo(rank(a)));
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: sorted
          .map((c) => _Chip(c: c, onTap: () => showSweetenerSheet(context, c, notes[c.slug])))
          .toList(),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.c, required this.onTap});
  final SweetenerChip c;
  final VoidCallback onTap;

  bool get _raises => c.isRisky || c.glycemic != Grade.low;

  @override
  Widget build(BuildContext context) {
    final color = _raises ? CubedColors.grade(c.glycemic) : CubedColors.inkSoft;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _raises ? color.withValues(alpha: 0.07) : CubedColors.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: _raises ? color.withValues(alpha: 0.35) : CubedColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            if (c.amountG != null) ...[
              const SizedBox(width: 4),
              Text('${_n(c.amountG!)}g',
                  style: const TextStyle(color: CubedColors.inkSoft, fontSize: 12)),
            ],
            if (_raises) ...[
              const SizedBox(width: 5),
              const Text('🩸', style: TextStyle(fontSize: 11)),
            ],
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 14, color: CubedColors.inkSoft),
          ],
        ),
      ),
    );
  }

  static String _n(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}
```

주의: `result_screen.dart`의 호출부가 `SweetenerChips(chips: it.chips)`라 컴파일 에러 발생 → 같은 커밋에서 `SweetenerChips(chips: it.chips, notes: it.slugNotes)`로 수정하고 `_ChipLegend` 사용 줄과 클래스를 삭제(전면 재조립은 Task 7).

- [ ] **Step 3: 전체 테스트 + 분석 확인**

Run: `flutter analyze && flutter test`
Expected: 에러 0, 전체 PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/features/result/widgets/sweetener_sheet.dart lib/features/result/widgets/sweetener_chips.dart lib/features/result/result_screen.dart
git commit -m "feat(result): 칩 위험순 정렬 + 탭 바텀시트, 분류색·범례 제거

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: 양 슬라이더 ("이만큼 먹으면")

**Files:**
- Create: `lib/features/result/widgets/portion_slider.dart`
- Test: `test/features/result/portion_slider_test.dart`

- [ ] **Step 1: 실패하는 테스트 작성** (표시 문자열 생성은 순수 함수로 분리해 테스트)

```dart
// test/features/result/portion_slider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cubed_app/features/result/widgets/portion_slider.dart';

void main() {
  test('1배: 그대로', () {
    expect(portionSummary(factor: 1, netCarb: 4, kcal: 120), '순탄수 4g · 120kcal');
  });
  test('1.5배: 소수 1자리 반올림', () {
    expect(portionSummary(factor: 1.5, netCarb: 4.1, kcal: 120), '순탄수 6.2g · 180kcal');
  });
  test('0.5배', () {
    expect(portionSummary(factor: 0.5, netCarb: 4, kcal: 121), '순탄수 2g · 61kcal');
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/features/result/portion_slider_test.dart`
Expected: FAIL — 파일 없음.

- [ ] **Step 3: 구현**

```dart
// lib/features/result/widgets/portion_slider.dart
import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// 배수 → 표시 문자열 (순수 함수, 테스트 대상). kcal은 정수 반올림, 순탄수는 소수 1자리.
String portionSummary({required double factor, required double netCarb, required double kcal}) {
  final nc = (netCarb * factor * 10).round() / 10;
  final k = (kcal * factor).round();
  final ncText = nc == nc.roundToDouble() ? nc.toInt().toString() : nc.toString();
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
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/features/result/portion_slider_test.dart`
Expected: 3건 PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/result/widgets/portion_slider.dart test/features/result/portion_slider_test.dart
git commit -m "feat(result): 양 슬라이더 — 배수별 순탄수·열량 즉시 재계산

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: ChatScreen 딥링크 (initialPrompt)

**Files:**
- Modify: `lib/features/chat/chat_screen.dart`

- [ ] **Step 1: 생성자 + initState 추가**

`ChatScreen` 클래스 선언을 다음으로 교체:

```dart
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, this.initialPrompt});

  /// 결과 화면 등에서 진입 시 자동으로 보낼 첫 질문 (null이면 기존과 동일)
  final String? initialPrompt;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}
```

`_ChatScreenState`에 initState 추가 (`dispose` 위):

```dart
  @override
  void initState() {
    super.initState();
    final p = widget.initialPrompt;
    if (p != null && p.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _send(p));
    }
  }
```

- [ ] **Step 2: 분석 확인**

Run: `flutter analyze`
Expected: 에러 0. (기존 `const ChatScreen()` 호출부는 optional 파라미터라 그대로 컴파일됨)

- [ ] **Step 3: Commit**

```bash
git add lib/features/chat/chat_screen.dart
git commit -m "feat(chat): initialPrompt 딥링크 — 제품 화면에서 질문 들고 진입

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: 결과 화면 4층 재조립

**Files:**
- Modify: `lib/features/result/result_screen.dart` (전면 재구성)
- Delete: `lib/features/result/widgets/grade_hero.dart`

- [ ] **Step 1: result_screen.dart 최신 상태 재확인** (food-diary 에이전트의 변경 흡수)

Run: `git log --oneline -3 -- lib/features/result/result_screen.dart` 후 파일을 다시 Read.
food-diary가 추가한 위젯(기록 토글 버튼 등)이 있으면 아래 새 레이아웃의 **"행동 층"**(대안 추천 블록 인접)에 그대로 옮겨 보존한다.

- [ ] **Step 2: `_Body.build`의 ListView children을 4층 구조로 교체**

```dart
      children: [
        _ProductHeader(it: it),
        const SizedBox(height: 16),

        // ── 1층: 답 + 이유 (VerdictHero가 판정 스트립·불릿·핵심 수치 통합)
        VerdictHero(it: it),

        // 단맛 레시피 한 줄 (다중 조합 규칙 매칭 시)
        if (it.recipeCombo != null) ...[
          const SizedBox(height: 10),
          _RecipeLine(combo: it.recipeCombo!),
        ],

        // ── 2층: 행동 — 주의 등급이면 대안을 먼저
        if (it.grade == Grade.caution) ...[
          const SizedBox(height: 24),
          const _SectionTitle('대신 이건 어때요?'),
          const SizedBox(height: 4),
          const Text('같은 칸에서 혈당 부담이 더 낮은 제품',
              style: TextStyle(color: CubedColors.inkSoft, fontSize: 13)),
          const SizedBox(height: 12),
          _Alternatives(product: p),
        ],

        // 대체당 칩 (탭하면 성분 설명)
        const SizedBox(height: 20),
        _SectionTitle('포함된 대체당', trailing: '${it.chips.length}종 · 탭해서 보기'),
        const SizedBox(height: 10),
        SweetenerChips(chips: it.chips, notes: it.slugNotes),

        // ── 3층: 근거 (접힘) — 영양성분·양 슬라이더·계산 근거
        const SizedBox(height: 20),
        _NumbersSection(it: it),

        // 낮음/중간 등급이면 대안은 여기
        if (it.grade != Grade.caution) ...[
          const SizedBox(height: 24),
          const _SectionTitle('대신 이건 어때요?'),
          const SizedBox(height: 4),
          const Text('같은 칸에서 혈당 부담이 더 낮은 제품',
              style: TextStyle(color: CubedColors.inkSoft, fontSize: 13)),
          const SizedBox(height: 12),
          _Alternatives(product: p),
        ],

        // AI에게 이 제품 질문
        const SizedBox(height: 20),
        _AskAiButton(product: p),

        // ── 4층: 커뮤니티
        const SizedBox(height: 28),
        const Divider(height: 1, color: CubedColors.line),
        const SizedBox(height: 20),
        SocialSection(productId: p.productId),

        if (!p.verified) ...[
          const SizedBox(height: 24),
          _DraftNotice(notes: p.notes),
        ],
      ],
```

- [ ] **Step 3: 새 보조 위젯 3개 추가, 죽은 코드 제거**

같은 파일에 추가:

```dart
/// 다중 조합 규칙 → "단맛 레시피" 한 줄 아이덴티티
class _RecipeLine extends StatelessWidget {
  const _RecipeLine({required this.combo});
  final ComboRule combo;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: CubedColors.brand.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CubedColors.brand.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, size: 16, color: CubedColors.brand),
          const SizedBox(width: 8),
          Text('단맛 레시피: ',
              style: const TextStyle(color: CubedColors.inkSoft, fontSize: 13)),
          Expanded(
            child: Text(combo.headline,
                style: const TextStyle(
                    color: CubedColors.brand, fontWeight: FontWeight.w800, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

/// 접히는 근거 층: 양 슬라이더 + 영양성분 그리드 + 계산 근거 문장
class _NumbersSection extends StatelessWidget {
  const _NumbersSection({required this.it});
  final Interpretation it;
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: const Text('숫자로 보기',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        subtitle: const Text('영양성분 · 양 조절 · 계산 근거',
            style: TextStyle(color: CubedColors.inkSoft, fontSize: 12)),
        children: [
          PortionSlider(
              netCarb: it.netCarb, kcal: it.product.kcal, unitDesc: it.product.unitDesc),
          const SizedBox(height: 12),
          _NutritionGrid(p: it.product),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(it.reason,
                style: const TextStyle(
                    color: CubedColors.inkSoft, fontSize: 12, height: 1.5)),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// AI 채팅 딥링크 — 제품명을 들고 질문과 함께 진입
class _AskAiButton extends StatelessWidget {
  const _AskAiButton({required this.product});
  final Product product;
  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: CubedColors.brand,
        side: BorderSide(color: CubedColors.brand.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
              initialPrompt: '${product.name}, 혈당 관리 중인데 먹어도 괜찮아?'),
        ),
      ),
      icon: const Icon(Icons.forum_rounded, size: 18),
      label: const Text('AI에게 이 제품 물어보기',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
    );
  }
}
```

제거·수정:
- import 교체: `widgets/grade_hero.dart` → `widgets/verdict_hero.dart`, `widgets/portion_slider.dart`, `../chat/chat_screen.dart`, `../../core/rulebook.dart`(Grade 사용), `../../data/models/product.dart`의 ComboRule 사용 확인.
- `_TrapCard`, `_ComboCard`, `_ChipLegend` 클래스 삭제 (VerdictHero·_RecipeLine·바텀시트가 대체).
- `_Body` 맨 아래의 `Text(it.reason, ...)` 삭제 (_NumbersSection으로 이동).
- 미사용 import(`../../core/explain.dart` 등)는 `flutter analyze` 경고 기준으로 정리.

- [ ] **Step 4: grade_hero.dart 삭제**

```bash
git rm lib/features/result/widgets/grade_hero.dart
```

- [ ] **Step 5: 분석 + 전체 테스트**

Run: `flutter analyze && flutter test`
Expected: 에러 0, 전체 PASS.

- [ ] **Step 6: Commit**

```bash
git add -A lib/features/result
git commit -m "feat(result): 해석 화면 4층 재편 — 답/이유/행동/근거(접힘) + AI 질문 진입점

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 8: 종단 검증 (verify)

**Files:** 없음

- [ ] **Step 1: 정적 검증**

Run: `flutter analyze && flutter test`
Expected: 에러 0, 전체 PASS.

- [ ] **Step 2: 앱 실행 시나리오 검증** (superpowers:verification-before-completion + `/verify` 스킬 사용, 에뮬레이터 또는 `flutter run -d windows`)

세 가지 제품 유형을 검색으로 열어 확인:
1. **말티톨 과자** (예: 무설탕 초콜릿) → "무설탕·제로 → 혈당 올라요" 스트립, 불릿에 말티톨 주의보 카피 1회만(중복 없음), 대안 추천이 칩보다 위, 칩 탭 시 바텀시트.
2. **제로 음료** (에리스리톨/수크랄로스) → "진짜예요" 스트립 + "단맛 레시피: 제로의 정석" 한 줄.
3. **일반 당류 제품** → 스트립 없음, 등급 배지 + 불릿.
공통: "숫자로 보기" 펼침 시 슬라이더 동작(×2 → 순탄수·열량 2배), "AI에게 물어보기" → 채팅이 제품 질문으로 자동 시작.

- [ ] **Step 3: 결과 보고** — 스크린샷/실패 내역 포함해 사용자에게 요약. 머지 여부는 superpowers:finishing-a-development-branch로 사용자와 결정.

---

## Self-Review 결과

- **스펙 커버리지**: A(층위 재편)=Task 2·7, B(라벨vs실제)=Task 2·3, C(combo 재배치)=Task 1·4·7, 양 슬라이더=Task 5, AI 진입점=Task 6·7, 대안 승격·reason 이동·범례 제거=Task 7. 보류 항목 2건 명시.
- **타입 일관성**: `Verdict.of(Interpretation)`, `SweetenerChips(chips:, notes:)`, `it.recipeCombo`/`it.slugNotes`/`line.code` 전 Task 동일 시그니처 확인.
- **플레이스홀더 없음** 확인.
