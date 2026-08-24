> ⚠️ **아카이브 문서** — 작성 시점의 설계 기록입니다. 현재 스펙은 [`docs/product-spec.md`](../../product-spec.md)를 보세요.

# 먹은 기록(푸드 다이어리) 설계 — '오늘 이거 먹었어요' 체크 + 홈 달력

- 상태: 설계 확정 (구현 대기)
- 작성일: 2026-07-11
- 대상 프로젝트: CUBED (Flutter + Supabase `aqhfddvvxnakgkdtirem`)
- 목적: 분석 결과 화면에서 "오늘 이거 먹었어요"를 체크하면 날짜별로 기록되고, 홈에서 달력으로 먹은 제품 목록을 되돌아볼 수 있게 한다. DB 등록 제품과 사진 촬영(OCR) 제품 모두 동일하게 기록.

---

## 1. 배경 / 문제

- 사용자는 제품을 스캔/촬영/검색해 혈당 영향 해석(`ResultScreen`)을 보지만, **그날 무엇을 먹었는지 남길 방법이 없다.**
- 촬영(OCR) 제품은 `products`에 저장되지 않는 메모리상 Product(`productId='ocr-temp'`)라서 제품 FK만으로는 기록할 수 없다.
- 촬영한 사진 3장은 이미 `submission-images` 버킷에 업로드되지만(`submit-product`), **폴더 경로(uuid)를 앱에 반환하지 않아** 앱이 그 사진을 다시 보여줄 수 없다.

## 2. 목표

- `ResultScreen`에 **"오늘 이거 먹었어요" 토글 버튼** — 누르면 오늘 날짜로 기록, 다시 누르면 취소.
- **홈에 "내가 먹은 기록" 카드** → 월 달력 화면(`DiaryScreen`): 기록 있는 날 마커, 날짜 선택 시 그날 먹은 제품 리스트(썸네일·이름·등급).
- DB 제품/촬영 제품 **모두 지원**: DB 제품은 `product_id` 참조 + 스냅샷, 촬영 제품은 스냅샷 + 촬영 원본 사진.
- 기록은 **Supabase에 저장** — 기기 변경·재설치에도 유지.

## 3. 확정된 결정 (브레인스토밍)

| 항목 | 결정 |
|---|---|
| 저장 위치 | **Supabase 새 테이블 1개** (`product_logs`). 로컬 저장 안 함 |
| 로그인 | **카카오 로그인 필수.** 로그아웃 상태에서 버튼 누르면 로그인 안내 → `LoginScreen` |
| 기록 시점 | **오늘만.** 과거 날짜 수동 추가 없음. 달력은 보기 + 삭제만 |
| 중복 방지 | 같은 사용자·같은 날·같은 제품 1건 (unique index). 버튼은 토글로 동작 |
| 달력 UI | **`table_calendar`** 패키지 (클라이언트 의존성, 스키마 무관) |
| 촬영 제품 이미지 | `submit-product`가 이미 업로드하는 `submission-images` 사진 재사용. 응답에 `image_path` 추가 |
| 이미지 읽기 권한 | `submission-images` 버킷에 **authenticated 읽기 정책** 추가 (공개 전환 안 함) |
| 등급 표시 | 기록 시점의 `Interpretation.grade`(`low`/`mid`/`caution`)를 **스냅샷으로 저장** — 목록에서 재계산 불필요 |

## 4. 현재 인프라 (재사용 자산)

- **사용자 단위 테이블 RLS 패턴**: `product_likes` · `product_comments` · `store_favorites` (auth.uid() = user_id)
- **인증**: 카카오 OAuth (`AuthRepository.isLoggedIn`, `authStateProvider`), 홈 `_AccountChip` · `LoginScreen`
- **썸네일**: `ProductThumb` 위젯 + `Env.imageBaseUrl`(공개 `product-images` 버킷)
- **해석 엔진**: `interpretationProvider(product)` → `Interpretation.grade`
- **촬영 파이프라인**: `CaptureScreen` → `OcrService.parseAndSubmit()` → `submit-product`(3장 업로드 + `user_submissions` insert, 폴더 uuid 생성)

## 5. 아키텍처 / 데이터 흐름

```
[기록하기]
ResultScreen (DB 제품 or 촬영 제품)
  → "오늘 이거 먹었어요" 버튼
     - 로그아웃 → 로그인 안내 다이얼로그 → LoginScreen
     - 로그인 → FoodLogRepository.toggleToday(...)
        · 오늘 같은 제품 기록 없음 → insert (product_id | 스냅샷 + grade + image_path)
        · 이미 있음 → delete (토글 해제)
  → 버튼 상태: '오늘 먹었어요 ✓' ↔ '오늘 이거 먹었어요'

[촬영 제품의 image_path 전달]
submit-product 응답에 image_path(폴더 uuid) 추가
  → OcrResult.imagePath 파싱
  → CaptureScreen이 ResultScreen(product, submissionImagePath:) 으로 전달
  → 기록 시 product_logs.image_path 에 저장
  (저장 실패로 image_path 없으면 null → placeholder)

[돌아보기]
홈 "내가 먹은 기록" 카드 → DiaryScreen
  → table_calendar 월 뷰: 해당 월 로그 조회, 기록 있는 날 마커
  → 날짜 선택 → 그날 리스트: 썸네일 + 이름/브랜드 + 등급 뱃지
     · 썸네일: product_id 있음 → product-images 공개 URL
              image_path 있음 → submission-images authenticated URL
              (…/storage/v1/object/authenticated/…, Authorization 헤더)
              둘 다 없음 → 카메라 아이콘 placeholder
  → 항목 삭제: Dismissible(스와이프) → removeLog(id)
```

## 6. 스키마 변경 (최소: 테이블 1 + 스토리지 정책 1)

```sql
-- 마이그레이션: product_logs
create table public.product_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  eaten_on date not null,
  product_id text,                 -- products.product_id (촬영 제품이면 null)
  name text not null,              -- 스냅샷
  brand text,
  category text,
  grade text check (grade in ('low','mid','caution')),
  image_path text,                 -- submission-images 폴더 uuid (DB 제품이면 null)
  created_at timestamptz not null default now()
);

-- 같은 사용자·같은 날·같은 제품 1건 (촬영 제품은 이름으로 동일성 판정)
create unique index product_logs_dedup
  on public.product_logs (user_id, eaten_on, coalesce(product_id, lower(name)));

alter table public.product_logs enable row level security;
create policy "own rows" on public.product_logs
  for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- submission-images 읽기 (로그인 사용자)
create policy "authenticated read submission images" on storage.objects
  for select to authenticated
  using (bucket_id = 'submission-images');
```

- `product_id`는 의도적으로 **FK 제약 없음**: 승격 전 촬영 제품·삭제된 제품 기록도 스냅샷으로 유지.
- `eaten_on`은 **기기 로컬 날짜** 기준(사용자가 인지하는 "오늘").

## 7. 백엔드 변경 (1곳)

`supabase/functions/submit-product/index.ts`:
- `folder` uuid를 try 블록 밖으로 올리고, 업로드+insert 성공 시 응답에 `image_path: folder` 포함.
- 저장 실패(비치명적) 시 `image_path` 없이 기존과 동일하게 파싱 결과만 반환.

## 8. 앱 구성요소

| 유닛 | 파일 | 책임 |
|---|---|---|
| `FoodLog` 모델 | `lib/data/models/food_log.dart` | fromMap/toMap, 필드 = 스키마 그대로 |
| `FoodLogRepository` | `lib/data/food_log_repository.dart` | `toggleToday()` · `logsForMonth(DateTime)` · `removeLog(id)` · `isLoggedToday()` |
| 프로바이더 | `lib/providers/providers.dart` | `foodLogRepositoryProvider`, 월별 로그 FutureProvider.family, 오늘 기록 여부 provider |
| 기록 버튼 | `lib/features/result/result_screen.dart` | GradeHero 아래 토글 버튼. `ResultScreen`에 `submissionImagePath` 옵션 파라미터 추가 |
| OCR 경로 연결 | `lib/features/ocr/ocr_service.dart` · `capture_screen.dart` | `OcrResult.imagePath` 파싱 → ResultScreen에 전달 |
| 홈 진입 카드 | `lib/features/home/home_screen.dart` | `_ChatAction` 아래 "내가 먹은 기록" 카드 → DiaryScreen push |
| 달력 화면 | `lib/features/diary/diary_screen.dart` | table_calendar 월 뷰 + 선택일 리스트 + 삭제 |
| 로그 썸네일 | `lib/features/diary/` 내 위젯 | product-images / submission-images(auth 헤더) / placeholder 분기 |
| 의존성 | `pubspec.yaml` | `table_calendar` 추가 |

## 9. 에러 처리

- **로그아웃 상태에서 기록 시도**: 안내 다이얼로그("로그인하면 먹은 기록을 저장할 수 있어요") → LoginScreen. 로그인 후 사용자가 다시 버튼 누름(자동 재시도 안 함 — 단순 유지).
- **토글 중 네트워크 실패**: SnackBar로 실패 알림, 버튼 상태 원복.
- **unique 충돌(동시 중복 insert)**: 이미 기록된 것으로 간주 — 에러 무시하고 체크 상태 표시.
- **이미지 로드 실패**: `CachedNetworkImage` errorWidget → placeholder 아이콘.
- **달력 월 로드 실패**: 화면 내 재시도 버튼.

## 10. 테스트

기존 `test/` 패턴(순수 로직 단위 테스트) 준수:
- `FoodLog` fromMap/toMap 왕복.
- 날짜 키(`eaten_on`) 포맷: 로컬 DateTime → `yyyy-MM-dd`.
- 동일성 키 로직: product_id 있음/없음(이름 소문자) 분기.
- 썸네일 URL 분기 로직(순수 함수로 분리): product_id → 공개 URL, image_path → authenticated URL, 둘 다 null → null.

## 11. 범위 밖 (YAGNI)

- 수량·끼니·메모·사진 첨부
- 과거 날짜 수동 기록, 기록 날짜 수정
- 주간/월간 통계, 영양 합계, 혈당 점수 집계
- 로컬 캐시/오프라인 동기화
- 리스트 항목 탭 → 제품 상세 재열람 (v1 리스트는 표시 전용, 탭 동작 없음. 재열람은 DB 제품용 `findById` 추가가 필요해 별도 기능으로)
