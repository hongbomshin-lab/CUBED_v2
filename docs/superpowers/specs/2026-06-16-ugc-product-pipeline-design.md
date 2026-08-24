> ⚠️ **아카이브 문서** — 작성 시점의 설계 기록입니다. 현재 스펙은 [`docs/product-spec.md`](../../product-spec.md)를 보세요.

# UGC 제품 확장 파이프라인 설계 (3장 촬영 → 제보 → 관리자 검수 → DB 승격)

- 상태: 설계 확정 (구현 대기)
- 작성일: 2026-06-16
- 대상 프로젝트: CUBED (Flutter + Supabase `aqhfddvvxnakgkdtirem`)
- 목적: 바코드 미등록 제품을 사용자가 사진 3장으로 제보 → AI 분석 → 관리자 검수 후 정식 DB로 승격하여, 서비스 사용만으로 제품 DB가 성장하는 루프 구축.

---

## 1. 배경 / 문제

현재 바코드 스캔 실패 시 흐름:

1. `findByBarcode(code)` → null
2. "등록되지 않은 제품" 바텀시트 → `OcrScreen(prefillBarcode)`
3. **사진 1장**만 촬영 → `ocr-parse` Edge Function(Gemini)으로 영양성분·원재료 파싱
4. 결과를 메모리상 `Product`로 `ResultScreen`에 표시 (DB 저장 안 함)
5. `submitOcr()`가 `user_submissions`에 `barcode` + `parsed{name,category}`만 기록 (**이미지 미업로드**, 영양성분 전체 미저장)

**문제점**

- 사진 1장으로는 카테고리 판정·품질이 낮다.
- 제보 데이터가 빈약(이미지 없음, 파싱 일부만)해서 나중에 검수·승격이 불가능하다.
- 미등록 제품을 정식 DB로 키울 경로가 없다.

## 2. 목표

- 미등록 제품 제보 시 **사진 3장 필수**(제품 전체샷 · 원재료명 · 영양성분표), 단계별 가이드 촬영.
- 전체샷으로 **카테고리·제품명 추론**, 원재료·영양성분은 **기존 AI OCR/해석 로직 그대로**.
- 제보를 [바코드 + 사진 3장 + AI 파싱 전체(영양성분 + 원재료에서 추출한 대체당 종류)] 형태로 **DB에 저장**.
- 관리자가 검수·보정·승인하면 **정식 `products`로 승격**(verified=true). 승격 전에는 다른 사용자에게 노출 안 함.
- 제보 검수 + 기존 408개 제품을 함께 관리하는 **관리자 콘솔(Flutter Web)**.

## 3. 확정된 결정 (브레인스토밍)

| 항목 | 결정 |
|---|---|
| 관리자 콘솔 | **Flutter Web, 같은 레포** (`Product`/`Interpretation`/`rulebook`/`ReferenceData` 재사용) |
| 미검증 제보 노출 | **검수 후에만** → staging 모델. 제보는 `user_submissions`에 머물고 승인 시 `products`로 승격 |
| 촬영 강제도 | **3장 필수**, 단계별 가이드(각 단계 재촬영 허용, 3장 다 차야 제출 가능) |
| 관리자 쓰기/승격 | **Edge Function(service_role)** 으로 원자적 처리. 클라이언트엔 service_role 절대 노출 안 함 |
| 스키마 | **최대한 단순.** 새 테이블 0개, `user_submissions`에 새 컬럼 1개(`promoted_product_id`)만 |

## 4. 현재 인프라 (재사용 자산)

- **테이블**: `products`(408) · `product_sweeteners`(896) · `sweeteners`(28) · `category_meta`(18) · `combo_rules`(12) · `user_submissions`(2) · `sweetener_review`(0) · `product_likes` · `product_comments`
- **Edge Functions**: `ocr-parse`(Gemini 3.1 Flash Lite 비전), `chat`
- **`products` 컬럼**: `verified`(bool, default false), `source_type`(default '패키지촬영'), `image_file`, `barcode`, 모든 영양성분, `ingredients_raw`, `sweetener_summary`/`count` — **변경 불필요**
- **`user_submissions` 컬럼**: `id`(bigint) · `barcode` · `ocr_text` · `parsed`(jsonb) · `image_path` · `status`(default 'pending') · `created_at`
- **Storage**: `product-images`(공개), 규칙 `products.image_file = "{product_id}.png"`
- **RLS 현황**
  - `products`/`product_sweeteners`: anon **SELECT만** (쓰기 전면 차단 → service_role만)
  - `user_submissions`: anon **INSERT만** (`status='pending'`, 바코드 `^[0-9]{8,14}$`, ocr_text ≤4000 체크). SELECT/UPDATE 정책 없음 → 클라이언트에서 못 읽음
  - `sweetener_review`: 정책 없음 (service_role만)
- **인증**: 이메일/비밀번호(`AuthRepository`). 닉네임은 user metadata. 관리자 식별은 **이메일 allowlist**로.

## 5. 아키텍처 / 데이터 흐름

```
[바코드 스캔 실패]
  → 3단계 가이드 촬영 (전체샷 → 원재료명 → 영양성분표, 3장 필수)
  → submit-product Edge Function (3장 base64 + 바코드)
       1) Gemini 멀티이미지 1회 호출
          - 전체샷 → category · name · brand 추론
          - 원재료 · 영양성분 → 기존 SYSTEM 규칙대로 파싱 (28종 감미료 slug, 18종 카테고리)
       2) submission-images 버킷에 3장 업로드 (service_role), 폴더 = uuid
       3) user_submissions insert: barcode, image_path=폴더uuid, parsed=전체JSON, ocr_text, status=pending
       4) 파싱 결과를 앱에 반환 → 사용자는 즉시 분석 결과(ResultScreen) 확인
  → (status=pending → 다른 사용자에게 노출 안 됨)

[관리자 콘솔 = Flutter Web]
  → admin Edge Function 통해 pending 제보 목록 (바코드 + 파싱 name/category + 썸네일 + signed URL 3장)
  → 파싱값 폼 보정 + 실시간 등급 미리보기(Interpretation 재사용)
  → 승인 → admin 함수가 products로 원자적 승격(verified=true) + product_sweeteners + 전체샷을 product-images로 복사 + submission.status=approved, promoted_product_id 기록
  → 거절 → status=rejected
  → 기존 408개 제품도 같은 콘솔에서 검색·수정·verified 토글
  → 승격 후 같은 바코드 스캔 시 정식 데이터로 노출
```

## 6. 스키마 변경 (최소)

`supabase/migrations/<timestamp>_ugc_submissions.sql` 에 SQL로 작성 (git 추적, 재현 가능).

**새 테이블 없음. `user_submissions`에 컬럼 1개만 추가:**

```sql
alter table public.user_submissions
  add column if not exists promoted_product_id text references public.products(product_id);
```

**기존 컬럼 용도 재정의 (스키마 변경 없음):**

- `parsed` (jsonb): 파싱 **전체** 페이로드 저장
  ```json
  {
    "name": "...", "brand": "...", "category": "...",
    "serving_size": 0, "unit": "g|ml",
    "kcal": 0, "carb": 0, "sugar": 0, "protein": 0, "fat": 0,
    "sodium_mg": null, "fiber": 0, "sugar_alcohol": 0, "rare_sugar_g": 0,
    "ingredients_raw": "...",
    "sweeteners": [{"slug": "allulose", "amount_g": null}],
    "unknown_sweeteners": ["..."],
    "notes": null
  }
  ```
- `image_path` (text): 사진 **폴더 uuid** 저장. 3장 경로 = `submissions/{image_path}/full.jpg|ingredients.jpg|nutrition.jpg`
- `barcode` (text, 기존): pending 목록에 그대로 노출
- `ocr_text` (text, 기존): 원재료 원문(`ingredients_raw`)

**RLS 추가 (마이그레이션에 포함):**

- `user_submissions`: 기존 anon INSERT 정책 유지. SELECT/UPDATE는 **추가하지 않음** — 모든 읽기/수정은 admin Edge Function(service_role) 경유.
- 클라이언트의 직접 제보 INSERT 경로는 더 이상 사용하지 않음(서버 함수가 대신 insert). 단, 기존 정책은 호환을 위해 유지.

## 7. Storage

- 신규 **비공개** 버킷 `submission-images` (사용자 원본 사진 = 비공개).
- 업로드/읽기 모두 service_role(Edge Function) 경유 → 클라이언트 스토리지 정책 불필요.
- 관리자 열람: admin 함수가 `createSignedUrl`로 1시간짜리 URL 발급.
- 승격 시: 전체샷을 공개 버킷 `product-images/{product_id}.png` 로 복사하여 초기 대표 이미지로 사용(관리자가 나중에 더 나은 이미지로 교체 가능).

## 8. 백엔드 Edge Functions

공통 파싱 로직은 `supabase/functions/_shared/parse.ts`로 분리해 `ocr-parse`/`submit-product`가 공유.

### 8.1 `ocr-parse` 확장 (하위호환)
- 입력: 기존 단일 `image` 도 받되, 신규 `images: { full, ingredients, nutrition }`(base64) 지원.
- 멀티이미지일 때 프롬프트에 역할 라벨 명시: "1번=제품 전체샷(카테고리·제품명 판정용), 2번=원재료명, 3번=영양성분표".
- 기존 SYSTEM 프롬프트(28종 감미료 slug, 18종 카테고리, 저장기준 규칙) 그대로 재사용.
- 출력 스키마 동일(`name, brand, category, serving_size, unit, kcal, ... , sweeteners[], unknown_sweeteners[], notes`).

### 8.2 `submit-product` 신규 (service_role, verify_jwt=true)
- 입력: `{ images:{full,ingredients,nutrition}(base64), barcode? }`
- 처리:
  1. `_shared/parse.ts`로 Gemini 멀티이미지 파싱
  2. `submission-images/{uuid}/...`에 3장 업로드
  3. `user_submissions` insert (barcode, image_path=uuid, parsed=전체, ocr_text, status='pending')
  4. 파싱 결과 반환(앱이 ResultScreen에 즉시 표시)
- 업로드/insert 실패해도 파싱 결과는 반환(제보 저장 실패는 비치명적, 로깅).
- 클라이언트 RLS/스토리지 정책 불필요(서버가 service_role로 수행).

### 8.3 `admin` 신규 (service_role, verify_jwt=true, 이메일 allowlist)
- 게이트: `Deno.env.get("ADMIN_EMAILS")` 와 JWT의 이메일 비교. 불일치 시 403.
- 액션(`{ action, ... }`):
  - `list_submissions(status='pending')` → 행 + 3장 signed URL + 바코드 + parsed name/category
  - `update_parsed(id, parsed)` → 관리자 보정값 저장
  - `promote(id, override?)` → **원자적**: `product_id` 생성(예: `ugc_{barcode|nanoid}`) → `products` insert(verified=true, source_type='OCR제보', barcode) → `product_sweeteners` insert(override된 sweeteners) → 전체샷 `product-images/{product_id}.png` 복사 → `user_submissions`(status='approved', promoted_product_id) update. (이미 approved면 거부 → 중복 승격 방지)
  - `reject(id)` → status='rejected'
  - `list_products(query?)` / `update_product(productId, fields)` / `set_verified(productId, bool)` → 기존 408개 관리
- 알 수 없는 감미료(`unknown_sweeteners`)는 승격 시 `sweetener_review`에 기록(기존 테이블 재사용).

## 9. 앱 변경 (Flutter)

### 9.1 신규 `lib/features/capture/`
- `capture_controller.dart`: Riverpod StateNotifier — 3장 파일(full/ingredients/nutrition) + 현재 단계 + 상태(idle/uploading/error).
- `capture_screen.dart`: 단계별 가이드 UI(전체샷 → 원재료명 → 영양성분표). 각 단계 카메라/앨범 선택 + **재촬영**. 3장 모두 있어야 "분석·제보" 버튼 활성화. 진행 표시(1/3, 2/3, 3/3).
- 디자인은 기존 `CubedColors`/`theme.dart` 톤 유지.

### 9.2 `OcrService`
- `parseAndSubmit({images, barcode}) → OcrResult`: `submit-product` 호출. 반환값으로 `ResultScreen` 표시.
- 기존 단일 `parseImage`는 제거 또는 내부 호환용으로만 유지.

### 9.3 진입 경로
- `scan_screen.dart`의 "등록되지 않은 제품" 바텀시트 → 기존 `OcrScreen` 대신 `CaptureScreen(prefillBarcode)` 로 교체.
- `product_repository.dart`의 `submitOcr` 클라이언트 insert는 제거(서버 함수가 대체).

## 10. 관리자 콘솔 (Flutter Web, 같은 레포)

- 진입점 `lib/admin/main_admin.dart` (별도 `runApp`). 앱 본체와 분리하되 `data/models`, `domain/interpretation.dart`, `core/rulebook.dart`, `providers` 재사용.
- 데이터 접근: 제보·쓰기는 모두 `admin` Edge Function 경유. 제품 읽기는 anon SELECT(공개)로 직접 가능.
- 화면
  - **제보 큐**: pending 목록(바코드, name/category, 썸네일, 제출시각). 행 클릭 → 상세: 사진 3장(signed URL) + 파싱값 편집 폼 + 실시간 등급 미리보기(`Interpretation.of`) + [승인]/[거절].
  - **제품 브라우저**: 408개 + 신규 승격분 검색·필터(verified/source_type)·수정·verified 토글.
- 관리자 인증: 기존 이메일 로그인 + **서버(allowlist)에서 최종 차단**. UI는 비관리자 이메일이면 메뉴 숨김(편의).
- 빌드/배포: `flutter build web --target lib/admin/main_admin.dart` → Netlify/Vercel/GitHub Pages 정적 호스팅. anon 키는 이미 공개(RLS 보호), 관리자 권한은 서버에서 게이트.

## 11. 보안

- service_role은 Edge Function 안에만. 앱/웹/레포에 절대 미포함.
- 사용자 원본 사진 = 비공개 버킷, 관리자만 signed URL.
- `products` 쓰기는 영구적으로 service_role(Edge Function)만.
- `submit-product`/`admin` = verify_jwt=true. `admin`은 추가로 `ADMIN_EMAILS` 검사.
- `GEMINI_API_KEY` 등 시크릿은 Supabase Edge Functions Secrets에만.

## 12. 단계(Phase) 분리

- **Phase 1 — 앱 성장 루프**: 스키마 마이그레이션 + `submission-images` 버킷 + `ocr-parse` 멀티이미지 확장 + `submit-product` + 3단계 촬영 화면. → 사용자 가치 즉시 제공 + 제보 데이터 수집 시작.
- **Phase 2 — 관리자 콘솔**: `admin` Edge Function + Flutter Web 관리자 앱(제보 큐 + 제품 브라우저) + 배포.

각 Phase는 독립적으로 동작 가능(Phase 1만으로도 제보가 쌓이고, Phase 2가 검수·승격을 담당).

## 13. Git 연속성 (다른 컴퓨터 인수인계)

- 레포 `origin = https://github.com/hongbomshin-lab/CUBED_v2.git`, `origin/main` 연결됨.
- 이 스펙 + 구현 계획(plan) + 마이그레이션 SQL + Edge Function 소스 전부 git 커밋.
- 백엔드(DB·Edge Function·시크릿)는 Supabase 클라우드 → 컴퓨터 무관.
- 다른 컴퓨터: `git pull` → `flutter pub get` → 이어서 작업. (Supabase CLI로 Edge Function 배포 시 `supabase login` 1회 필요.)
- ⚠️ 기존엔 스키마를 MCP로 직접 적용해 git 기록이 없음. **이번부터는 `supabase/migrations/`에 SQL로 남겨** 재현·리뷰 가능하게 함.

## 14. 리스크 / 열린 질문

- **product_id 생성 규칙**: `ugc_{barcode}` (바코드 없으면 nanoid). 기존 ID 충돌 방지 확인 필요. 구현 시 확정.
- **이미지 포맷**: image_picker는 jpeg. `image_file` 규칙은 `.png` → 승격 시 확장자/포맷 처리 확정(현 규칙 유지하되 실제 바이트는 jpeg일 수 있음 → `.jpg`로 통일 검토).
- **카테고리 18종 강제**: 전체샷으로 추론 실패 시 fallback(가장 가까운 카테고리 or null + 관리자 보정).
- **중복 제보**: 같은 바코드가 여러 번 제보될 수 있음 → 관리자 큐에서 병합/선택(승격은 1건만). v1은 수동 처리.
- **이탈률**: 3장 필수가 진입장벽일 수 있음 → 단계별 가이드/예시 이미지로 완화.

---

## 부록: 영향받는 파일

신규
- `lib/features/capture/capture_controller.dart`
- `lib/features/capture/capture_screen.dart`
- `lib/admin/main_admin.dart` (+ 관리자 화면 위젯들)
- `supabase/functions/submit-product/index.ts`
- `supabase/functions/admin/index.ts`
- `supabase/functions/_shared/parse.ts`
- `supabase/migrations/<timestamp>_ugc_submissions.sql`

수정
- `supabase/functions/ocr-parse/index.ts` (멀티이미지)
- `lib/features/scan/scan_screen.dart` (CaptureScreen 진입)
- `lib/features/ocr/ocr_service.dart` (parseAndSubmit)
- `lib/data/product_repository.dart` (submitOcr 제거)
- `lib/providers/providers.dart` (필요 시 provider 추가)

제거/대체
- `lib/features/ocr/ocr_screen.dart` (CaptureScreen으로 대체)
