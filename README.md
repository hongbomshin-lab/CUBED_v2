# ZERO DOT

저당·제로 제품이 **진짜 저당인지** 사진 한 장으로 판정하고, 더 나은 대안·살 곳·먹은 기록까지 이어주는 Flutter 앱.

> 📘 **전체 기획·스펙은 [`docs/product-spec.md`](docs/product-spec.md)가 정본입니다.**
> 이 README는 개발자가 처음 붙을 때 필요한 것만 담습니다.

## 화면 구조 (하단 4탭)

| 탭 | 기능 |
|---|---|
| **① 제품분석** | AI 사진 분석(메인) · 이름 검색 · AI 채팅 · 먹은 기록 |
| **② 저당맵** | 네이버 지도 매장 + 프랜차이즈 음료 당류 · 리뷰/즐겨찾기/제보 · 한영일중 |
| **③ 핫딜** | 저당 브랜드 공식몰 특가 (크롤러가 하루 1회 갱신) |
| **④ 마이** | 슈가포인트 · 즐겨찾기 매장 · 작성한 리뷰/댓글 |

## 핵심 기능

1. **AI 사진 분석** — 진입 즉시 카메라. 전면 1장으로 등록 제품 빠른 매칭 → 실패하면 원재료·영양성분 2장 추가 촬영 후 파싱. 미등록 제품은 `user_submissions`로 제보 축적 → 관리자 검수 → DB 성장 루프.
2. **결과 화면** — 혈당 신호등 판정 + `[라벨 vs 실제]` 스트립 + 0g 함정 근거 + 대체당 칩 + **대안 추천** + 양 슬라이더 + 가격 비교 + 좋아요·코멘트.
3. **저당맵** — 저당 전문 매장 지도(전주 14곳) + 프랜차이즈 카페(191곳) 반경 토글 + 프랜차이즈 음료 당류 검색. 매장/메뉴판 제보와 리뷰는 관리자 승인 후 반영.
4. **먹은 기록 + 슈가포인트** — 하루 1건 토글 기록, 달력 뷰. `포인트 = 일반 제품 기준 당류 − 제품 당류` (1P = 아낀 설탕 1g).
5. **AI 도우미 채팅** — Edge Function `chat`이 전 제품 룰북 요약을 주입해 **데이터에 있는 제품만 근거로** 답변.
6. **핫딜** — 라라스윗·널담·마이노멀 공식몰 특가.

## 아키텍처

```
lib/
├── core/       룰북·표현층·테마·i18n·위치캐시·기준값   [순수 로직, 테스트 대상]
├── domain/     Product → 해석 ViewModel (interpretation / verdict)
├── data/       Supabase 조회 + 모델
├── providers/  Riverpod 프로바이더 (단일 파일)
├── features/   화면 — {home,capture,scan,result,ocr,search,chat,diary,map,franchise,hotdeals,account,auth,report,review,prices,shell}
└── admin/      관리자 콘솔 (별도 entrypoint main_admin.dart)
```

**절대 원칙**: 해석값(순탄수·혈당등급·0g함정)은 **DB에 저장하지 않고 런타임 계산**한다.
`lib/core/rulebook.dart`가 유일한 진실원천이고, 채팅 Edge Function이 같은 룰북을 1:1 포팅해
앱 등급과 채팅 등급이 항상 일치한다. (룰북 상세는 [기획서 §3-3](docs/product-spec.md))

- **상태관리**: Riverpod (`lib/providers/providers.dart`)
- **디자인**: "Matcha Ink" 토큰 — `lib/core/theme.dart`, 폰트 Pretendard

## 실행

```bash
flutter pub get
flutter run
```
Android/iOS 플랫폼 폴더는 저장소에 포함돼 있고 카메라 권한도 설정돼 있다.

**관리자 콘솔** (별도 빌드):
```bash
flutter run -d chrome --target lib/admin/main_admin.dart
```

## Edge Functions

시크릿은 앱·코드에 없고 **Edge Functions Secrets에만** 둔다(RLS 보호되는 anon 키로 호출).

| 함수 | 호출자 | 역할 |
|---|---|---|
| `submit-product` | 앱 | 전면 1장 빠른 매칭 + 3장 풀 파싱 + 제보 적재 |
| `chat` | 앱 | 전 제품 룰북 요약 주입 → CLOVA HCX-005 답변 |
| `delete-account` | 앱 | 회원 탈퇴 (계정 + 전 데이터 삭제) |
| `admin` | 관리자 콘솔 | 제보 큐 조회·편집·승격 (JWT 이메일 ↔ `ADMIN_EMAILS`) |
| `crawl-deals` | pg_cron | 브랜드 공식몰 특가 크롤 (하루 1회) |
| `translate-franchise` | 수동 | 미번역 메뉴 CLOVA 배치 번역 |

```bash
supabase functions deploy submit-product  --project-ref aqhfddvvxnakgkdtirem
supabase functions deploy chat            --project-ref aqhfddvvxnakgkdtirem
supabase functions deploy delete-account  --project-ref aqhfddvvxnakgkdtirem
supabase functions deploy admin           --project-ref aqhfddvvxnakgkdtirem
```

**시크릿**
- `CLOVA_API_KEY` — 파싱·인식·채팅·번역 공용
- `ADMIN_EMAILS` — 쉼표 구분 관리자 이메일
- `OCR_PROVIDER` (선택) — 미설정/`clova`(기본) = CLOVA HCX-005 단일콜, `gemini` = Gemini 멀티이미지 롤백(`GEMINI_API_KEY` 필요)
- `CHAT_MODEL` (선택) — 기본 `HCX-005`

> ⚠️ 채팅은 전 제품을 프롬프트에 주입한다 (408개 ≈ 4만 토큰). 제품이 늘면 검색형 전환 필요.

## 연결 정보

- Supabase 프로젝트: `CUBED_v2` (ref `aqhfddvvxnakgkdtirem`) — `lib/core/env.dart`
- publishable(anon) 키는 클라이언트 노출이 정상(RLS 보호). service_role 키는 앱에 절대 포함하지 않는다.
- ⚠️ `.mcp.json`은 Supabase 액세스 토큰을 포함하므로 `.gitignore`로 제외됨 — **커밋 금지**.

## 데이터 현황

products 408 · product_sweeteners 896 · sweeteners 28 · category_meta 18 · combo_rules 12 ·
전주 매장 14 · 전주 프랜차이즈 191 · 프랜차이즈 번역 573행(191곳 × 3언어).

⚠️ products는 전부 `verified=false` (사람 검수 전 초안) — 결과 화면에 초안 안내가 표시된다.

## 알려진 이슈

- 🔴 `FeatureFlags.useDemoLocation = true` — IR 시연용 전주 좌표 고정. **출시 전 `false` 필수.**
- 바코드 스캔은 `FeatureFlags.barcodeScan = false`로 비활성 (코드는 유지).
- 전체 목록: [`docs/reports/2026-08-24-unused-code-audit.md`](docs/reports/2026-08-24-unused-code-audit.md)

## 문서

| 문서 | 내용 |
|---|---|
| [`docs/product-spec.md`](docs/product-spec.md) | **제품 기획서 (정본)** |
| [`docs/reports/2026-08-24-unused-code-audit.md`](docs/reports/2026-08-24-unused-code-audit.md) | 미사용 기능·코드 감사 |
| [`docs/sugar-baselines.md`](docs/sugar-baselines.md) | 슈가포인트 기준값 근거 |
| [`docs/admin-deploy.md`](docs/admin-deploy.md) | 관리자 콘솔 배포·운영 |
| [`docs/store-release-checklist.md`](docs/store-release-checklist.md) | 스토어 출시 체크리스트 |
| `docs/superpowers/` | 설계 이력 아카이브 (현재 스펙 아님) |
