# 먹은 기록(푸드 다이어리) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 분석 결과 화면에 "오늘 이거 먹었어요" 토글을 추가하고, 홈에서 진입하는 월 달력(DiaryScreen)으로 날짜별 먹은 제품을 보여준다.

**Architecture:** Supabase 테이블 1개(`product_logs`, RLS own-rows)에 제품 스냅샷을 기록. DB 제품은 `product_id` 참조, 촬영(OCR) 제품은 `submit-product` 응답에 새로 추가하는 `image_path`로 촬영 원본 썸네일을 재사용. 달력은 `table_calendar`, 등급은 기록 시점 `Interpretation.grade` 스냅샷.

**Tech Stack:** Flutter + Riverpod 2 (기존), supabase_flutter, table_calendar ^3.1.3, Supabase Edge Function (Deno)

**Spec:** `docs/superpowers/specs/2026-07-11-food-diary-design.md`

**중요 컨텍스트 (코드베이스 관례):**
- 해석값은 DB에 저장하지 않는 것이 원칙이나, 이 기능의 `grade`는 **표시용 스냅샷**으로 예외 (스펙 §3에서 확정).
- 촬영 제품은 `productId == 'ocr-temp'` 인 메모리상 Product다 (`lib/features/ocr/ocr_service.dart`).
- 사용자 단위 테이블 접근 패턴은 `lib/data/social_repository.dart` 참고 (`_uid` getter, 토글 = 조회 후 insert/delete).
- 테스트는 순수 로직만 (`test/features/ocr/ocr_result_test.dart` 스타일, mock 없음).
- Supabase 프로젝트: `aqhfddvvxnakgkdtirem` (CUBED_v2).
- `flutter analyze`/`flutter test`는 Windows PowerShell/Git Bash에서 그대로 실행 가능.

**File Structure (전체 지도):**

| 파일 | 작업 | 책임 |
|---|---|---|
| `supabase/migrations/20260711090000_product_logs.sql` | Create | 테이블 + dedup index + RLS + 스토리지 읽기 정책 |
| `lib/data/models/food_log.dart` | Create | FoodLog 모델, dateKey, matches (순수 로직) |
| `lib/data/food_log_repository.dart` | Create | product_logs CRUD + 토글 |
| `lib/providers/providers.dart` | Modify | foodLogRepository / monthLogs / todayLog 프로바이더 |
| `supabase/functions/submit-product/index.ts` | Modify | 응답에 `image_path` 추가 |
| `lib/features/ocr/ocr_service.dart` | Modify | `OcrResult.imagePath` 파싱 |
| `lib/features/capture/capture_screen.dart` | Modify | imagePath를 ResultScreen에 전달 |
| `lib/features/result/result_screen.dart` | Modify | `submissionImagePath` 파라미터 + 버튼 배치 |
| `lib/features/diary/eaten_today_button.dart` | Create | '오늘 이거 먹었어요' 토글 버튼 |
| `lib/features/diary/log_image_url.dart` | Create | 썸네일 URL 분기 (순수 함수) |
| `lib/features/diary/diary_screen.dart` | Create | 달력 + 일별 리스트 + 삭제 |
| `lib/features/home/home_screen.dart` | Modify | `_ChatAction` → `_BannerAction` 일반화 + 진입 카드 |
| `pubspec.yaml` | Modify | table_calendar 추가 |
| `test/data/food_log_test.dart` | Create | 모델·키 로직 테스트 |
| `test/features/ocr/ocr_result_test.dart` | Modify | imagePath 파싱 테스트 |
| `test/features/diary/log_image_url_test.dart` | Create | URL 분기 테스트 |

---

### Task 1: DB 마이그레이션 — `product_logs` + submission-images 읽기 정책

**Files:**
- Create: `supabase/migrations/20260711090000_product_logs.sql`

- [ ] **Step 1: 마이그레이션 파일 작성**

```sql
-- 먹은 기록 (푸드 다이어리): 결과 화면 '오늘 이거 먹었어요' 체크.
-- product_id null = 촬영(OCR) 제품 → 이름/브랜드/등급 스냅샷으로만 식별.
create table public.product_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  eaten_on date not null,
  product_id text,                 -- products.product_id (FK 제약 없음: 삭제·미승격 제품 기록 유지)
  name text not null,              -- 스냅샷
  brand text,
  category text,
  grade text check (grade in ('low','mid','caution')),
  image_path text,                 -- submission-images 폴더 uuid (DB 제품이면 null)
  created_at timestamptz not null default now()
);

comment on table public.product_logs is
  '사용자 먹은 기록. 같은 사용자·같은 날·같은 제품 1건(토글).';

-- 같은 사용자·같은 날·같은 제품 1건 (촬영 제품은 소문자 이름으로 동일성 판정)
create unique index product_logs_dedup
  on public.product_logs (user_id, eaten_on, coalesce(product_id, lower(name)));

-- 월별 조회용
create index product_logs_month on public.product_logs (user_id, eaten_on);

alter table public.product_logs enable row level security;

create policy "product_logs own rows" on public.product_logs
  for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- 달력 썸네일: 로그인 사용자가 제보 원본 사진(submission-images) 읽기 허용 (스펙 §3)
create policy "submission images authenticated read" on storage.objects
  for select to authenticated
  using (bucket_id = 'submission-images');
```

- [ ] **Step 2: 원격 프로젝트에 적용**

Supabase MCP `apply_migration` 사용 (project_id: `aqhfddvvxnakgkdtirem`, name: `product_logs`, query: 위 SQL 전체).
MCP를 못 쓰는 환경이면: `supabase db push --project-ref aqhfddvvxnakgkdtirem` (링크·로그인 필요).

- [ ] **Step 3: 적용 검증**

MCP `execute_sql`로 실행:
```sql
select indexname from pg_indexes where tablename = 'product_logs';
select policyname from pg_policies
  where tablename in ('product_logs', 'objects')
    and (policyname like '%product_logs%' or policyname like '%submission%');
```
Expected: `product_logs_dedup`, `product_logs_month` 인덱스와 `product_logs own rows`, `submission images authenticated read` 정책이 보인다.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260711090000_product_logs.sql
git commit -m "feat(db): product_logs 테이블 + submission-images 읽기 정책"
```

---

### Task 2: FoodLog 모델 + 순수 헬퍼 (TDD)

**Files:**
- Test: `test/data/food_log_test.dart`
- Create: `lib/data/models/food_log.dart`

- [ ] **Step 1: 실패하는 테스트 작성**

`test/data/food_log_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cubed_app/data/models/food_log.dart';

void main() {
  test('fromMap: DB row → FoodLog', () {
    final log = FoodLog.fromMap({
      'id': 'uuid-1',
      'eaten_on': '2026-07-11',
      'product_id': '0TKKSWYBWCTQH',
      'name': '1500저당바더블초코',
      'brand': '서주',
      'category': '아이스크림/빙과',
      'grade': 'mid',
      'image_path': null,
    });
    expect(log.id, 'uuid-1');
    expect(log.eatenOn, DateTime(2026, 7, 11));
    expect(log.productId, '0TKKSWYBWCTQH');
    expect(log.grade, 'mid');
    expect(log.imagePath, isNull);
  });

  test('dateKey: 한 자리 월·일 zero-pad', () {
    expect(FoodLog.dateKey(DateTime(2026, 7, 3)), '2026-07-03');
    expect(FoodLog.dateKey(DateTime(2026, 11, 25)), '2026-11-25');
  });

  test('insertMap: eaten_on은 dateKey 포맷', () {
    final m = FoodLog.insertMap(
      userId: 'u1',
      eatenOn: DateTime(2026, 7, 11, 23, 59), // 시각은 무시
      productId: null,
      name: '촬영한 제품',
      grade: 'low',
      imagePath: 'folder-uuid',
    );
    expect(m['user_id'], 'u1');
    expect(m['eaten_on'], '2026-07-11');
    expect(m['product_id'], isNull);
    expect(m['image_path'], 'folder-uuid');
  });

  test('matches: DB 제품은 product_id로 판정', () {
    final log = FoodLog.fromMap({
      'id': 'a', 'eaten_on': '2026-07-11',
      'product_id': 'P1', 'name': '제로콜라',
    });
    expect(log.matches(productId: 'P1', name: '다른이름'), isTrue);
    expect(log.matches(productId: 'P2', name: '제로콜라'), isFalse);
    // 촬영 제품(productId null) 쿼리는 DB 제품 기록과 매칭 안 됨
    expect(log.matches(productId: null, name: '제로콜라'), isFalse);
  });

  test('matches: 촬영 제품은 소문자 이름으로 판정 (dedup index와 동일 규칙)', () {
    final log = FoodLog.fromMap({
      'id': 'b', 'eaten_on': '2026-07-11',
      'product_id': null, 'name': 'Zero Bar',
    });
    expect(log.matches(productId: null, name: 'zero bar'), isTrue);
    expect(log.matches(productId: null, name: '딴제품'), isFalse);
    expect(log.matches(productId: 'P1', name: 'Zero Bar'), isFalse);
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/data/food_log_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'cubed_app/data/models/food_log.dart'` 류의 컴파일 에러.

- [ ] **Step 3: 최소 구현**

`lib/data/models/food_log.dart`:
```dart
/// 먹은 기록 (product_logs 테이블) — 제품 스냅샷 1건.
/// product_id가 null이면 촬영(OCR) 제품, 아니면 DB 제품.
class FoodLog {
  final String id;
  final DateTime eatenOn; // 날짜만 의미 (로컬 기준, 스펙 §6)
  final String? productId;
  final String name;
  final String? brand;
  final String? category;
  final String? grade; // 'low' | 'mid' | 'caution' 스냅샷
  final String? imagePath; // submission-images 폴더 uuid

  const FoodLog({
    required this.id,
    required this.eatenOn,
    this.productId,
    required this.name,
    this.brand,
    this.category,
    this.grade,
    this.imagePath,
  });

  /// 로컬 날짜 → 'yyyy-MM-dd' (eaten_on 컬럼 키)
  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// 이 기록이 해당 제품과 같은 항목인지 — dedup 인덱스
  /// coalesce(product_id, lower(name)) 와 동일 규칙.
  bool matches({String? productId, required String name}) {
    if (productId != null) return this.productId == productId;
    return this.productId == null &&
        this.name.toLowerCase() == name.toLowerCase();
  }

  factory FoodLog.fromMap(Map<String, dynamic> m) => FoodLog(
        id: m['id'] as String,
        eatenOn: DateTime.parse(m['eaten_on'] as String),
        productId: m['product_id'] as String?,
        name: m['name'] as String? ?? '',
        brand: m['brand'] as String?,
        category: m['category'] as String?,
        grade: m['grade'] as String?,
        imagePath: m['image_path'] as String?,
      );

  /// insert용 맵 (id·created_at은 DB 기본값 사용)
  static Map<String, dynamic> insertMap({
    required String userId,
    required DateTime eatenOn,
    String? productId,
    required String name,
    String? brand,
    String? category,
    String? grade,
    String? imagePath,
  }) =>
      {
        'user_id': userId,
        'eaten_on': dateKey(eatenOn),
        'product_id': productId,
        'name': name,
        'brand': brand,
        'category': category,
        'grade': grade,
        'image_path': imagePath,
      };
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/data/food_log_test.dart`
Expected: `All tests passed!` (5 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/data/models/food_log.dart test/data/food_log_test.dart
git commit -m "feat: FoodLog 모델 (dateKey·dedup 매칭 로직 포함)"
```

---

### Task 3: FoodLogRepository + 프로바이더

**Files:**
- Create: `lib/data/food_log_repository.dart`
- Modify: `lib/providers/providers.dart`

리포지토리는 얇은 Supabase 호출이라 단위 테스트 없음 (SocialRepository와 동일한 관례). 로직(dedup 매칭)은 Task 2에서 테스트 완료.

- [ ] **Step 1: 리포지토리 작성**

`lib/data/food_log_repository.dart`:
```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/food_log.dart';

/// 먹은 기록 데이터 접근. 카카오 로그인(auth.uid()) 기반 소유권 (RLS own-rows).
class FoodLogRepository {
  FoodLogRepository(this._db);
  final SupabaseClient _db;

  String? get _uid => _db.auth.currentUser?.id;

  /// 하루치 기록 (오늘 토글 상태 판정용)
  Future<List<FoodLog>> logsForDay(DateTime day) async {
    final uid = _uid;
    if (uid == null) return const [];
    final rows = await _db
        .from('product_logs')
        .select()
        .eq('user_id', uid)
        .eq('eaten_on', FoodLog.dateKey(day))
        .order('created_at');
    return rows.map((m) => FoodLog.fromMap(m)).toList();
  }

  /// 한 달치 기록 (달력 마커 + 일별 리스트 공용)
  Future<List<FoodLog>> logsForMonth(DateTime month) async {
    final uid = _uid;
    if (uid == null) return const [];
    final first = DateTime(month.year, month.month, 1);
    final next = DateTime(month.year, month.month + 1, 1);
    final rows = await _db
        .from('product_logs')
        .select()
        .eq('user_id', uid)
        .gte('eaten_on', FoodLog.dateKey(first))
        .lt('eaten_on', FoodLog.dateKey(next))
        .order('eaten_on');
    return rows.map((m) => FoodLog.fromMap(m)).toList();
  }

  /// 오늘 이 제품의 기록 (없으면 null) — 결과 화면 버튼 상태
  Future<FoodLog?> todayLogFor({String? productId, required String name}) async {
    final today = await logsForDay(DateTime.now());
    for (final log in today) {
      if (log.matches(productId: productId, name: name)) return log;
    }
    return null;
  }

  /// '오늘 이거 먹었어요' 토글 → 기록됐으면 true, 해제됐으면 false
  Future<bool> toggleToday({
    String? productId,
    required String name,
    String? brand,
    String? category,
    String? grade,
    String? imagePath,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('로그인이 필요해요');
    final existing = await todayLogFor(productId: productId, name: name);
    if (existing != null) {
      await _db.from('product_logs').delete().eq('id', existing.id);
      return false;
    }
    await _db.from('product_logs').insert(FoodLog.insertMap(
          userId: uid,
          eatenOn: DateTime.now(),
          productId: productId,
          name: name,
          brand: brand,
          category: category,
          grade: grade,
          imagePath: imagePath,
        ));
    return true;
  }

  Future<void> removeLog(String id) async {
    await _db.from('product_logs').delete().eq('id', id);
  }
}
```

- [ ] **Step 2: 프로바이더 추가**

`lib/providers/providers.dart` — import 블록에 추가:
```dart
import '../data/food_log_repository.dart';
import '../data/models/food_log.dart';
```

파일 끝(`searchProvider` 아래)에 추가:
```dart
/// 먹은 기록 데이터 접근
final foodLogRepositoryProvider = Provider<FoodLogRepository>(
  (ref) => FoodLogRepository(ref.watch(supabaseProvider)),
);

/// 월별 먹은 기록 (달력). key는 DateTime(year, month, 1)로 정규화해 넘길 것.
final monthLogsProvider =
    FutureProvider.family<List<FoodLog>, DateTime>((ref, month) async {
  ref.watch(authStateProvider); // 로그인/로그아웃 시 갱신
  return ref.watch(foodLogRepositoryProvider).logsForMonth(month);
});

/// 오늘 이 제품을 기록했는지 (결과 화면 토글 버튼 상태)
final todayLogProvider = FutureProvider.family<FoodLog?,
    ({String? productId, String name})>((ref, key) async {
  ref.watch(authStateProvider);
  return ref
      .watch(foodLogRepositoryProvider)
      .todayLogFor(productId: key.productId, name: key.name);
});
```

- [ ] **Step 3: 정적 분석**

Run: `flutter analyze lib/data/food_log_repository.dart lib/providers/providers.dart`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/data/food_log_repository.dart lib/providers/providers.dart
git commit -m "feat: FoodLogRepository + 먹은기록 프로바이더"
```

---

### Task 4: submit-product 응답에 image_path 추가 + 배포

**Files:**
- Modify: `supabase/functions/submit-product/index.ts:40-61`

- [ ] **Step 1: 코드 수정**

`supabase/functions/submit-product/index.ts`의 아래 블록을:
```ts
    // 제보 영속화(비치명적). 실패해도 파싱 결과는 돌려준다.
    try {
      const db = createClient(SUPABASE_URL, SERVICE_ROLE);
      const folder = crypto.randomUUID();
```
다음으로 교체 (`let imagePath` 선언 + 성공 시 대입 + 응답 포함):
```ts
    // 제보 영속화(비치명적). 실패해도 파싱 결과는 돌려준다.
    // 성공 시 폴더 uuid를 image_path로 반환 → 앱의 먹은기록 썸네일 재사용 (스펙 §7)
    let imagePath: string | null = null;
    try {
      const db = createClient(SUPABASE_URL, SERVICE_ROLE);
      const folder = crypto.randomUUID();
```
그리고 같은 try 블록의 `user_submissions` insert 직후(catch 이전)에 추가:
```ts
      imagePath = folder;
```
마지막으로 성공 응답 한 줄을:
```ts
    return json(parsed, 200);
```
다음으로 교체:
```ts
    return json({ ...parsed, image_path: imagePath }, 200);
```

- [ ] **Step 2: 로컬 타입 확인 (Deno가 있다면)**

Run: `deno check supabase/functions/submit-product/index.ts` (Deno 미설치면 생략 — 배포 시 검증됨)
Expected: 에러 없음.

- [ ] **Step 3: 배포**

```bash
supabase functions deploy submit-product --project-ref aqhfddvvxnakgkdtirem
```
CLI가 없으면 Supabase MCP `deploy_edge_function` (name: `submit-product`, entrypoint: `index.ts`) 에 `submit-product/index.ts`와 `_shared/parse.ts` 두 파일 모두 포함해 배포.
Expected: 배포 성공, 버전 증가 (현재 v3 → v4).

- [ ] **Step 4: Commit**

```bash
git add supabase/functions/submit-product/index.ts
git commit -m "feat(edge): submit-product 응답에 image_path 반환"
```

---

### Task 5: OcrResult.imagePath (TDD) + ResultScreen 파라미터 + CaptureScreen 연결

**Files:**
- Test: `test/features/ocr/ocr_result_test.dart`
- Modify: `lib/features/ocr/ocr_service.dart`
- Modify: `lib/features/result/result_screen.dart:14-30`
- Modify: `lib/features/capture/capture_screen.dart:47-50`

- [ ] **Step 1: 실패하는 테스트 추가**

`test/features/ocr/ocr_result_test.dart`의 `main()` 안 마지막에 추가:
```dart
  test('fromParsed: image_path → imagePath', () {
    final r = OcrResult.fromParsed({
      'category': '과자/스낵', 'unit': 'g', 'sweeteners': [],
      'image_path': 'abc-123-folder',
    });
    expect(r.imagePath, 'abc-123-folder');
  });

  test('fromParsed: image_path 없으면 imagePath null', () {
    final r = OcrResult.fromParsed({'category': '과자/스낵', 'unit': 'g', 'sweeteners': []});
    expect(r.imagePath, isNull);
  });
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/features/ocr/ocr_result_test.dart`
Expected: FAIL — `The getter 'imagePath' isn't defined for the class 'OcrResult'`

- [ ] **Step 3: OcrResult에 imagePath 추가**

`lib/features/ocr/ocr_service.dart`:

클래스 필드/생성자를:
```dart
class OcrResult {
  final Product product;
  final List<String> unknownSweeteners;
  final String? rawText;
  const OcrResult({required this.product, this.unknownSweeteners = const [], this.rawText});
```
다음으로 교체:
```dart
class OcrResult {
  final Product product;
  final List<String> unknownSweeteners;
  final String? rawText;
  final String? imagePath; // submission-images 폴더 uuid (서버 저장 실패 시 null)
  const OcrResult(
      {required this.product,
      this.unknownSweeteners = const [],
      this.rawText,
      this.imagePath});
```

`fromParsed`의 return 문을:
```dart
    return OcrResult(
      product: product,
      unknownSweeteners: ((m['unknown_sweeteners'] as List?) ?? const []).cast<String>(),
      rawText: m['ingredients_raw'] as String?,
    );
```
다음으로 교체:
```dart
    return OcrResult(
      product: product,
      unknownSweeteners: ((m['unknown_sweeteners'] as List?) ?? const []).cast<String>(),
      rawText: m['ingredients_raw'] as String?,
      imagePath: m['image_path'] as String?,
    );
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/features/ocr/ocr_result_test.dart`
Expected: `All tests passed!` (4 tests)

- [ ] **Step 5: ResultScreen에 submissionImagePath 파라미터 추가**

`lib/features/result/result_screen.dart`:

```dart
class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key, required this.product});
  final Product product;
```
→
```dart
class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key, required this.product, this.submissionImagePath});
  final Product product;

  /// 촬영(OCR) 제품의 submission-images 폴더 uuid — 먹은기록 썸네일용
  final String? submissionImagePath;
```

같은 파일:
```dart
        data: (it) => _Body(it: it),
```
→
```dart
        data: (it) => _Body(it: it, submissionImagePath: submissionImagePath),
```

```dart
class _Body extends ConsumerWidget {
  const _Body({required this.it});
  final Interpretation it;
```
→
```dart
class _Body extends ConsumerWidget {
  const _Body({required this.it, this.submissionImagePath});
  final Interpretation it;
  final String? submissionImagePath;
```

(버튼 배치는 Task 6에서 — 이 태스크는 전달 경로만.)

- [ ] **Step 6: CaptureScreen에서 전달**

`lib/features/capture/capture_screen.dart`:
```dart
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ResultScreen(product: result.product)),
      );
```
→
```dart
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
            builder: (_) => ResultScreen(
                product: result.product,
                submissionImagePath: result.imagePath)),
      );
```

- [ ] **Step 7: 정적 분석 + 전체 테스트**

Run (두 명령 순서대로): `flutter analyze lib/features` 그리고 `flutter test`
Expected: `No issues found!` / `All tests passed!`

- [ ] **Step 8: Commit**

```bash
git add lib/features/ocr/ocr_service.dart lib/features/result/result_screen.dart lib/features/capture/capture_screen.dart test/features/ocr/ocr_result_test.dart
git commit -m "feat: 촬영 제품 image_path를 OcrResult→ResultScreen으로 전달"
```

---

### Task 6: EatenTodayButton + ResultScreen 배치

**Files:**
- Create: `lib/features/diary/eaten_today_button.dart`
- Modify: `lib/features/result/result_screen.dart` (GradeHero 아래)

버튼은 Riverpod 상태 + Supabase 호출 조합이라 위젯 테스트 대신 `flutter analyze` + 이후 수동 검증 (기존 SocialSection과 동일 관례).

- [ ] **Step 1: 버튼 위젯 작성**

`lib/features/diary/eaten_today_button.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../core/rulebook.dart';
import '../../core/theme.dart';
import '../../data/models/product.dart';
import '../../providers/providers.dart';
import '../auth/login_screen.dart';

/// '오늘 이거 먹었어요' 토글 — DB 제품/촬영 제품 공용. 카카오 로그인 필요.
class EatenTodayButton extends ConsumerWidget {
  const EatenTodayButton({
    super.key,
    required this.product,
    required this.grade,
    this.submissionImagePath,
  });
  final Product product;
  final Grade grade;
  final String? submissionImagePath;

  /// 촬영 제품(ocr-temp)은 product_id 없이 스냅샷으로만 기록 (스펙 §6)
  String? get _productId =>
      product.productId == 'ocr-temp' ? null : product.productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (productId: _productId, name: product.name);
    final user = ref.watch(currentUserProvider);
    final today = ref.watch(todayLogProvider(key));
    final logged = today.valueOrNull != null;
    final busy = today.isLoading;

    Future<void> onTap() async {
      if (user == null) {
        // 로그인 후 사용자가 다시 버튼을 누른다 (자동 재시도 없음, 스펙 §9)
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        return;
      }
      try {
        final added = await ref.read(foodLogRepositoryProvider).toggleToday(
              productId: _productId,
              name: product.name,
              brand: product.brand,
              category: product.category,
              grade: grade.name,
              imagePath: submissionImagePath,
            );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(added ? '오늘 먹은 기록에 추가했어요' : '기록을 취소했어요'),
            duration: const Duration(seconds: 1),
          ));
        }
      } on PostgrestException catch (e) {
        // 동시 중복(unique 충돌)은 이미 기록된 것으로 간주 (스펙 §9)
        if (e.code != '23505' && context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('기록 실패: ${e.message}')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('기록 실패: $e')));
        }
      } finally {
        ref.invalidate(todayLogProvider(key));
        ref.invalidate(monthLogsProvider); // 달력 전체 갱신
      }
    }

    final label = logged ? '오늘 먹었어요 ✓' : '오늘 이거 먹었어요';
    final icon = logged ? Icons.check_circle_rounded : Icons.restaurant_rounded;

    return SizedBox(
      width: double.infinity,
      child: logged
          ? FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: CubedColors.brand,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: busy ? null : onTap,
              icon: Icon(icon, size: 20),
              label: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15)),
            )
          : OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: CubedColors.brand,
                side: const BorderSide(color: CubedColors.brand),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: busy ? null : onTap,
              icon: Icon(icon, size: 20),
              label: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15)),
            ),
    );
  }
}
```

- [ ] **Step 2: ResultScreen에 배치**

`lib/features/result/result_screen.dart` import 블록에 추가:
```dart
import '../diary/eaten_today_button.dart';
```

`_Body`의 build에서:
```dart
        GradeHero(it: it),
```
→
```dart
        GradeHero(it: it),
        const SizedBox(height: 12),
        EatenTodayButton(
          product: p,
          grade: it.grade,
          submissionImagePath: submissionImagePath,
        ),
```

- [ ] **Step 3: 정적 분석**

Run: `flutter analyze lib/features/diary lib/features/result`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/features/diary/eaten_today_button.dart lib/features/result/result_screen.dart
git commit -m "feat: 결과 화면 '오늘 이거 먹었어요' 토글 버튼"
```

---

### Task 7: 썸네일 URL 헬퍼 (TDD) + DiaryScreen + table_calendar

**Files:**
- Modify: `pubspec.yaml` (dependencies)
- Test: `test/features/diary/log_image_url_test.dart`
- Create: `lib/features/diary/log_image_url.dart`
- Create: `lib/features/diary/diary_screen.dart`

- [ ] **Step 1: table_calendar 의존성 추가**

`pubspec.yaml` dependencies의 `url_launcher: ^6.3.2` 아래에 추가:
```yaml
  # 먹은 기록 달력
  table_calendar: ^3.1.3
```
Run: `flutter pub get`
Expected: 성공 (table_calendar 3.1.x 해석).

- [ ] **Step 2: URL 헬퍼 실패 테스트 작성**

`test/features/diary/log_image_url_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cubed_app/data/models/food_log.dart';
import 'package:cubed_app/features/diary/log_image_url.dart';

FoodLog _log({String? productId, String? imagePath}) => FoodLog(
      id: 'x',
      eatenOn: DateTime(2026, 7, 11),
      productId: productId,
      name: '테스트',
      imagePath: imagePath,
    );

void main() {
  test('DB 제품 → product-images 공개 URL ({product_id}.png 규칙)', () {
    final r = logImageUrl(_log(productId: 'P1'));
    expect(r, isNotNull);
    expect(r!.needsAuth, isFalse);
    expect(r.url, endsWith('/storage/v1/object/public/product-images/P1.png'));
  });

  test('촬영 제품 → submission-images authenticated URL', () {
    final r = logImageUrl(_log(imagePath: 'folder-1'));
    expect(r, isNotNull);
    expect(r!.needsAuth, isTrue);
    expect(
        r.url,
        endsWith(
            '/storage/v1/object/authenticated/submission-images/folder-1/full.jpg'));
  });

  test('둘 다 없으면 null (placeholder)', () {
    expect(logImageUrl(_log()), isNull);
  });
}
```

- [ ] **Step 3: 테스트 실패 확인**

Run: `flutter test test/features/diary/log_image_url_test.dart`
Expected: FAIL — `log_image_url.dart` 미존재 컴파일 에러.

- [ ] **Step 4: URL 헬퍼 구현**

`lib/features/diary/log_image_url.dart`:
```dart
import '../../core/env.dart';
import '../../data/models/food_log.dart';

/// 먹은 기록 썸네일 URL 분기 (스펙 §5).
/// - DB 제품: product-images 공개 URL. 규칙 products.image_file = "{product_id}.png"
///   (이미지 없는 제품은 404 → 위젯 errorWidget 폴백)
/// - 촬영 제품: submission-images authenticated URL (Authorization 헤더 필요)
/// - 둘 다 없으면 null → placeholder
({String url, bool needsAuth})? logImageUrl(FoodLog log) {
  if (log.productId != null) {
    return (
      url: '${Env.imageBaseUrl}/${log.productId}.png',
      needsAuth: false,
    );
  }
  final path = log.imagePath;
  if (path != null && path.isNotEmpty) {
    return (
      url:
          '${Env.supabaseUrl}/storage/v1/object/authenticated/submission-images/$path/full.jpg',
      needsAuth: true,
    );
  }
  return null;
}
```

- [ ] **Step 5: 테스트 통과 확인**

Run: `flutter test test/features/diary/log_image_url_test.dart`
Expected: `All tests passed!` (3 tests)

- [ ] **Step 6: DiaryScreen 구현**

`lib/features/diary/diary_screen.dart`:
```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/rulebook.dart';
import '../../core/theme.dart';
import '../../data/models/food_log.dart';
import '../../providers/providers.dart';
import '../auth/login_screen.dart';
import 'log_image_url.dart';

/// 먹은 기록 달력 — 월 뷰 + 선택일 리스트. 보기·스와이프 삭제 전용 (스펙 §3).
class DiaryScreen extends ConsumerStatefulWidget {
  const DiaryScreen({super.key});
  @override
  ConsumerState<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends ConsumerState<DiaryScreen> {
  late DateTime _focused;
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focused = now;
    _selected = DateTime(now.year, now.month, now.day);
  }

  DateTime get _monthKey => DateTime(_focused.year, _focused.month, 1);

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const _LoginNeeded();

    final logs = ref.watch(monthLogsProvider(_monthKey));
    final byDay = <String, List<FoodLog>>{};
    for (final log in logs.valueOrNull ?? const <FoodLog>[]) {
      byDay.putIfAbsent(FoodLog.dateKey(log.eatenOn), () => []).add(log);
    }
    final dayLogs = byDay[FoodLog.dateKey(_selected)] ?? const <FoodLog>[];

    return Scaffold(
      appBar: AppBar(title: const Text('내가 먹은 기록')),
      body: Column(
        children: [
          TableCalendar<FoodLog>(
            firstDay: DateTime(2026, 1, 1),
            lastDay: DateTime.now().add(const Duration(days: 366)),
            focusedDay: _focused,
            selectedDayPredicate: (d) => isSameDay(d, _selected),
            eventLoader: (d) => byDay[FoodLog.dateKey(d)] ?? const [],
            onDaySelected: (sel, foc) =>
                setState(() { _selected = sel; _focused = foc; }),
            onPageChanged: (foc) => setState(() => _focused = foc),
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextFormatter: (date, _) => '${date.year}년 ${date.month}월',
              titleTextStyle:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            calendarBuilders: CalendarBuilders(
              dowBuilder: (context, day) {
                const names = ['월', '화', '수', '목', '금', '토', '일'];
                return Center(
                    child: Text(names[day.weekday - 1],
                        style: const TextStyle(
                            fontSize: 12, color: CubedColors.inkSoft)));
              },
            ),
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                  color: CubedColors.brand.withValues(alpha: 0.25),
                  shape: BoxShape.circle),
              selectedDecoration: const BoxDecoration(
                  color: CubedColors.brand, shape: BoxShape.circle),
              markerDecoration: const BoxDecoration(
                  color: CubedColors.brand, shape: BoxShape.circle),
              markersMaxCount: 3,
              outsideDaysVisible: false,
            ),
          ),
          const SizedBox(height: 4),
          const Divider(height: 1, color: CubedColors.line),
          Expanded(
            child: logs.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('기록을 불러오지 못했어요',
                      style: TextStyle(color: CubedColors.inkSoft)),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(monthLogsProvider(_monthKey)),
                    child: const Text('다시 시도'),
                  ),
                ]),
              ),
              data: (_) => dayLogs.isEmpty
                  ? const Center(
                      child: Text('이 날은 기록이 없어요',
                          style: TextStyle(color: CubedColors.inkSoft)))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: dayLogs.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: CubedColors.line),
                      itemBuilder: (_, i) => _LogTile(
                        log: dayLogs[i],
                        onRemoved: () =>
                            ref.invalidate(monthLogsProvider(_monthKey)),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogTile extends ConsumerWidget {
  const _LogTile({required this.log, required this.onRemoved});
  final FoodLog log;
  final VoidCallback onRemoved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey(log.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: CubedColors.caution.withValues(alpha: 0.12),
        child: const Icon(Icons.delete_outline_rounded,
            color: CubedColors.caution),
      ),
      onDismissed: (_) async {
        await ref.read(foodLogRepositoryProvider).removeLog(log.id);
        onRemoved();
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 6),
        leading: _LogThumb(log: log),
        title: Text(log.name,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          log.brand ?? (log.productId == null ? '사진으로 분석한 제품' : ''),
          style: const TextStyle(color: CubedColors.inkSoft, fontSize: 12),
        ),
        trailing: _GradeBadge(grade: log.grade),
      ),
    );
  }
}

/// product-images(공개) / submission-images(인증 헤더) / placeholder 분기
class _LogThumb extends ConsumerWidget {
  const _LogThumb({required this.log});
  final FoodLog log;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final src = logImageUrl(log);
    Widget fallback() => Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: CubedColors.bg,
            border: Border.all(color: CubedColors.line),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.photo_camera_outlined,
              size: 20, color: CubedColors.inkSoft),
        );
    if (src == null) return fallback();

    final token =
        ref.watch(supabaseProvider).auth.currentSession?.accessToken;
    final headers = src.needsAuth && token != null
        ? {'Authorization': 'Bearer $token'}
        : null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 44,
        height: 44,
        child: CachedNetworkImage(
          imageUrl: src.url,
          httpHeaders: headers,
          fit: BoxFit.cover,
          placeholder: (_, __) => fallback(),
          errorWidget: (_, __, ___) => fallback(),
        ),
      ),
    );
  }
}

/// 기록 시점 등급 스냅샷 뱃지 (낮음/중간/주의)
class _GradeBadge extends StatelessWidget {
  const _GradeBadge({required this.grade});
  final String? grade;

  @override
  Widget build(BuildContext context) {
    Grade? g;
    if (grade != null) {
      try {
        g = Grade.values.byName(grade!);
      } catch (_) {
        g = null;
      }
    }
    if (g == null) return const SizedBox.shrink();
    final c = CubedColors.grade(g);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(g.ko,
          style:
              TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }
}

class _LoginNeeded extends StatelessWidget {
  const _LoginNeeded();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('내가 먹은 기록')),
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('로그인하면 먹은 기록을 볼 수 있어요',
              style: TextStyle(color: CubedColors.inkSoft)),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: CubedColors.brand),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            ),
            icon: const Icon(Icons.login_rounded, size: 18),
            label: const Text('로그인'),
          ),
        ]),
      ),
    );
  }
}
```

- [ ] **Step 7: 정적 분석**

Run: `flutter analyze lib/features/diary`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/features/diary/log_image_url.dart lib/features/diary/diary_screen.dart test/features/diary/log_image_url_test.dart
git commit -m "feat: 먹은 기록 달력 화면 (table_calendar + 썸네일 분기)"
```

---

### Task 8: 홈 진입 카드 + 전체 검증

**Files:**
- Modify: `lib/features/home/home_screen.dart`

- [ ] **Step 1: `_ChatAction`을 `_BannerAction`으로 일반화**

`lib/features/home/home_screen.dart` import 블록에 추가:
```dart
import '../diary/diary_screen.dart';
```

기존 `_ChatAction` 클래스 전체(아이콘·문구 하드코딩)를 다음 재사용 위젯으로 교체:
```dart
class _BannerAction extends StatelessWidget {
  const _BannerAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: CubedColors.brand.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: CubedColors.brand.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: CubedColors.brand.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: CubedColors.brand, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          color: CubedColors.inkSoft, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: CubedColors.brand, size: 14),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 홈 build에서 배너 2개 사용**

`HomeScreen.build`의:
```dart
            // AI 도우미 진입 — 제품·혈당·당류를 대화로 질문
            _ChatAction(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChatScreen()),
              ),
            ),
```
→
```dart
            // AI 도우미 진입 — 제품·혈당·당류를 대화로 질문
            _BannerAction(
              icon: Icons.forum_rounded,
              title: 'AI에게 물어보기',
              subtitle: '제품·혈당·당류를 대화로 물어보세요',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChatScreen()),
              ),
            ),
            const SizedBox(height: 12),

            // 먹은 기록 달력 진입
            _BannerAction(
              icon: Icons.calendar_month_rounded,
              title: '내가 먹은 기록',
              subtitle: '날짜별로 먹은 제품을 돌아봐요',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DiaryScreen()),
              ),
            ),
```

- [ ] **Step 3: 전체 정적 분석 + 전체 테스트**

Run (두 명령 순서대로): `flutter analyze` 그리고 `flutter test`
Expected: `No issues found!` / `All tests passed!`

- [ ] **Step 4: Commit**

```bash
git add lib/features/home/home_screen.dart
git commit -m "feat: 홈에 '내가 먹은 기록' 진입 카드"
```

---

### Task 9: 수동 스모크 체크 (기기/에뮬레이터)

- [ ] **Step 1: 앱 실행 후 시나리오 확인**

`flutter run` 후:
1. 로그아웃 상태 → 검색으로 아무 제품 열기 → "오늘 이거 먹었어요" 탭 → LoginScreen 뜨는지.
2. 카카오 로그인 → 같은 제품에서 버튼 탭 → "오늘 먹은 기록에 추가했어요" + 버튼이 '오늘 먹었어요 ✓'로 바뀌는지.
3. 다시 탭 → 취소되는지 (토글).
4. 다시 기록 → 홈 → "내가 먹은 기록" → 오늘 날짜 마커 + 리스트에 제품(썸네일·등급 뱃지) 표시.
5. 사진 3장 촬영 제보 → 결과 화면에서 기록 → 달력 리스트에 촬영 사진 썸네일 표시 ('사진으로 분석한 제품' 부제).
6. 리스트 항목 왼쪽 스와이프 → 삭제 + 마커 갱신.

- [ ] **Step 2: DB 확인 (선택)**

MCP `execute_sql`: `select eaten_on, name, product_id, grade, image_path from product_logs order by created_at desc limit 5;`
Expected: 방금 기록한 행들이 보임.
