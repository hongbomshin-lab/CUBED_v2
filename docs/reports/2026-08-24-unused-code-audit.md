# 미사용 기능·코드 감사

> **작성일** 2026-08-24 · **기준 커밋** `451e255` (v0.2.0+1)
> "코드에는 있는데 안 쓰는 것"을 전수 조사한 결과. Flutter SDK가 없는 환경이라
> `flutter analyze` 대신 참조 그래프를 직접 훑어 확인했다(파일 import / 심볼 참조 / 테이블 접근 / 함수 호출).

## 요약

| 분류 | 건수 | 권고 |
|---|---|---|
| 🔴 즉시 조치 (출시 사고 위험) | 1 | 지금 고친다 |
| 🟠 완전 사망 — 참조 0 | 4 | 삭제 |
| 🟡 의도적 비활성 — 플래그·정책 | 2 | 유지 (기한 정하기) |
| 🟢 만들었는데 UI가 없음 | 2 | 살리거나 접거나 결정 |
| ⚪ 문서·주석 stale | 4 | 정리 |

---

## 🔴 즉시 조치

### 1. `FeatureFlags.useDemoLocation = true` — 데모 좌표가 켜진 채로 남아 있음
**위치** `lib/core/feature_flags.dart:24`

```dart
static const bool useDemoLocation = true;
static const double demoLat = 35.8156;   // 전주 신시가지
static const double demoLng = 127.1064;
```

IR 시연용으로 GPS 대신 전주 좌표를 강제하는 스위치가 **켜진 상태**다. 이대로 스토어에 올라가면
전 사용자의 저당맵이 위치와 무관하게 전주 신시가지를 가리킨다. 플래그 주석 자체가
"시연이 끝나면 `false`로만 바꾸면 된다"고 적고 있다.

**권고**: 지금 `false`로. 출시 체크리스트에도 항목으로 넣는다.
(전주 데이터만 있어 서울에서는 매장이 안 잡히는 문제가 원인이므로, 되돌리면
"내 주변에 등록 매장이 없어요" 빈 상태 문구가 필요하다.)

---

## 🟠 완전 사망 — 참조 0건, 삭제 대상

### 2. `dealsProvider` — 선언만 있고 아무도 watch 하지 않음
**위치** `lib/providers/providers.dart:98-106`

```dart
final dealsProvider = FutureProvider.autoDispose
    .family<List<BrandDeal>, DealQuery>((ref, query) async { ... });
```

핫딜 화면이 페이지네이션(더보기)을 직접 관리하려고 `ref.read(dealRepositoryProvider).deals(...)`를
쓰도록 바뀌면서 이 프로바이더는 남겨진 채 아무도 안 쓴다.
`DealQuery` 클래스(`deal_repository.dart:63`)도 이 프로바이더의 family 키 전용이라 함께 사망.

**권고**: `dealsProvider` + `DealQuery` 삭제.

### 3. `lookupByBarcodeProvider` — 선언만 있고 참조 0
**위치** `lib/providers/providers.dart:222-225`

`ScanScreen`이 프로바이더 대신 `ref.read(repositoryProvider).findByBarcode(code)`를 직접 호출한다.
게다가 스캔 기능 자체가 비활성(#8).

**권고**: 삭제. `findByBarcode()` 자체는 스캔 재도입 시 필요하므로 남긴다.

### 4. `ProductRepository.byCategory()` — 호출자 없음
**위치** `lib/data/product_repository.dart:79-86`

주석은 "카테고리별 목록 (둘러보기)"인데 **둘러보기 화면이 존재하지 않는다.**
대안 추천은 별도의 `alternativesIn()`을 쓴다.

**권고**: 삭제. 카테고리 둘러보기를 로드맵에 넣을 거라면 그때 다시 만드는 편이 싸다.

### 5. `ReferenceData.nameOf()` — 호출자 없음
**위치** `lib/data/product_repository.dart:25`

감미료 slug → 표준명 변환. 표시층이 `SweetenerChip`에서 이미 이름을 들고 오면서 남았다.

**권고**: 삭제.

### 6. Edge Function `ocr-parse` — 앱에서 호출하지 않음
**위치** `supabase/functions/ocr-parse/`

`submit-product`가 파싱 + 제보 적재를 모두 흡수했다. 앱의 `OcrService`는
`submit-product`만 두 가지 모드(`quick` / 풀 파싱)로 호출한다.
파싱 엔진(`_shared/parse.ts`)은 두 함수가 공유하므로 **`_shared`는 살아 있다.**

**권고**: 함수 디렉터리 삭제 + 배포된 함수 제거. README의 배포 명령에서도 뺀다.
(`parse.ts`의 "ocr-parse, submit-product 가 공유한다" 주석도 함께 수정)

### 7. Edge Function `recognize-product` — 앱에서 호출하지 않음
**위치** `supabase/functions/recognize-product/`

전면 1장 제품 인식 기능이 `submit-product`의 `quick:true` 모드로 흡수됐다.
인식 엔진(`_shared/recognize.ts`)은 `submit-product`가 직접 import 하므로 **`_shared`는 살아 있다.**

**권고**: 함수 디렉터리 삭제 + 배포된 함수 제거.

---

## 🟡 의도적 비활성 — 유지하되 기한을 정한다

### 8. 바코드 스캔 전체 — `FeatureFlags.barcodeScan = false`
**영향 범위**
```
lib/features/scan/scan_screen.dart        153줄   진입점만 숨김, 코드는 온전
lib/providers/providers.dart              lookupByBarcodeProvider (#3 — 이건 그냥 죽었음)
lib/data/product_repository.dart          findByBarcode()
lib/features/capture/capture_screen.dart  prefillBarcode 파라미터
pubspec.yaml                              mobile_scanner ^5.1.1  ← 앱 용량에 실린다
```

플래그 주석대로 **의도적 비노출**이다. 다만 비용이 있다:
- `mobile_scanner`가 여전히 번들에 들어간다 (`scan_screen.dart`가 유일한 import처)
- 사진 분석의 빠른 매칭이 사실상 바코드를 대체했으므로, 스캔 재도입 계획이 없다면 계속 실릴 이유가 없다

**권고**: 재도입 여부를 **결정**한다.
- 재도입한다 → 플래그 유지, 그대로 둔다
- 안 한다 → `scan_screen.dart` + `mobile_scanner` 의존성 + `prefillBarcode` + `findByBarcode` 일괄 제거
  (카메라 권한 자체는 사진 분석이 쓰므로 그대로 필요)

### 9. `products.verified` 가 전부 `false`
408개 제품이 전부 미검수 초안이라 결과 화면에 항상 `_DraftNotice`가 뜬다.
"검수됨" 상태의 UI 경로는 사실상 한 번도 사용자에게 노출된 적이 없다.

**권고**: 기능 문제가 아니라 **운영 처리량 문제**. 관리자 콘솔 일괄 승인을 Phase 3로.

---

## 🟢 만들었는데 UI가 없음 — 살리거나 접거나

### 10. `deal_price_stats` 뷰 — "역대 최저가!" 배지가 없다
**위치** `supabase/migrations/0007_brand_deals.sql:94-110`

```sql
-- 역대 최저가 조회용 뷰 ("역대 최저가!" 배지)
create or replace view deal_price_stats as ...
```

- `deal_price_history` 테이블에 `apply_crawl_result` RPC가 **매일 가격을 실제로 쌓고 있다**
- 조회용 뷰도 있고 public read RLS도 열려 있다
- **그런데 앱이 이 뷰를 한 번도 읽지 않는다** — `BrandDeal` 모델에도 필드가 없다

즉 "역대 최저가" 배지는 **데이터·인프라만 완성되고 UI가 안 붙은 상태**다.
데이터는 계속 쌓이고 있으므로 지금 붙이면 과거 이력까지 바로 쓸 수 있다.

**권고**: 핫딜 카드에 배지 추가 (구현 비용 대비 체감 효과가 큰 편). 접을 거면 뷰·테이블을 정리.

### 11. i18n 키 `seeAllMenus` — 4개 언어 번역만 있고 쓰는 화면이 없음
**위치** `lib/core/i18n/ui_strings.dart:252-257`

"메뉴 전체 보기 / See all menus / メニューをすべて見る / 查看全部菜单".
매장 상세 시트의 브랜드 저당 메뉴 5개 아래에 "전체 보기" 진입점을 넣으려다 만 흔적으로 보인다.

**권고**: 진입점을 붙이거나(프랜차이즈 브라우저를 해당 브랜드 필터로 열기), 키를 삭제.

---

## ⚪ 문서·주석 stale

### 12. `README.md` 가 v0.1 시절 기준
- "핵심 기능" 4개만 나열 — **저당맵·핫딜·마이·먹은기록·슈가포인트·가격비교·다국어가 전부 빠져 있다**
- 하단 4탭 구조 언급 없음
- 1번 기능이 "바코드 스캔 → 해석 UI"인데 **현재 비활성**(#8)
- AI 채팅 엔진을 "Gemini"로 표기 — 실제로는 CLOVA HCX-005 (같은 문서 아래쪽 배포 섹션은 CLOVA로 맞게 적혀 있어 자기모순)
- 배포 명령에 죽은 `ocr-parse`가 남아 있음(#6)

**권고**: 갱신. (이번 작업에서 함께 처리)

### 13. `lib/core/env.dart:19` — 해결된 TODO
```dart
/// TODO: 발급받은 값으로 교체. 비어 있으면 지도 인증 실패...
static const naverMapClientId = 'fxapwfixct';   // ← 이미 채워져 있음
```
**권고**: TODO 주석 삭제.

### 14. `lib/features/home/home_screen.dart:250` — `'카카오 로그인됨'` 고정 문구
로그인 경로가 이메일·카카오·Apple 3가지인데 계정 시트가 항상 "카카오 로그인됨"이라고 표시한다.
같은 오표기가 다른 곳에도 있다:
- `social_section.dart:9` 주석 "카카오 로그인한 사용자만"
- `social_section.dart:278` 익명 표시명 폴백 `'카카오회원'`
- `eaten_today_button.dart:12` 주석 "카카오 로그인 필요"
- `food_log_repository.dart:5` 주석 "카카오 로그인(auth.uid()) 기반"

**권고**: 사용자에게 보이는 문구(`home_screen`, `social_section:278`)는 로그인 방식과 무관한
표현으로 교체("로그인됨", "회원"). 주석은 "로그인 필요"로 정리.

### 15. 설계 문서와 코드의 불일치
- `docs/superpowers/specs/2026-08-19-sugar-personal-verdict-design.md` — **개인화 판정은 `72c94a9`에서 전면 제거됐다.** 문서만 남아 있어 읽는 사람이 현재 스펙으로 오해할 수 있다.
- `flutter_porting_context.md` (루트) — 2026-06 Next.js→Flutter 포팅 당시의 as-is 분석. 지금 스키마와 다르다.

**권고**: 두 문서를 "아카이브"로 명시. `docs/product-spec.md` §9 문서 지도에 이미 반영했다.

---

## 참고 — 살아 있음을 확인한 것들 (오해 방지)

조사 중 "안 쓰는 것 아닌가" 의심됐지만 **실제로 사용 중**인 항목:

| 항목 | 사용처 |
|---|---|
| `lib/admin/main_admin.dart` | 별도 Flutter Web entrypoint (import 0건이 정상) |
| Edge Function `translate-franchise` | 수동 운영용 배치 번역 (curl 호출) |
| Edge Function `crawl-deals` | pg_cron 하루 1회 자동 실행 |
| `deal_price_history` 테이블 | `apply_crawl_result` RPC가 매일 write (읽는 UI만 없음 → #10) |
| `launch_notifications` 테이블 | `landing/index.html` 대기자 등록에서 사용 |
| `SugarCubeStack` | 마이 포인트 카드 + 적립 팝업 |
| `domain/verdict.dart` | `VerdictHero`가 사용 (개인화 제거 후에도 살아남은 표현층) |
| `_shared/parse.ts`, `_shared/recognize.ts` | `submit-product`가 직접 import |
| `cupertino_icons` | Flutter 기본 템플릿 의존성 (import 0건이 정상) |

`hot_deals` 테이블(`0001_jodangmap.sql`)은 크롤러용 `brand_deals`로 대체됐지만,
0007 마이그레이션이 "기존 hot_deals는 건드리지 않는다"고 명시적으로 남겨둔 것이라 의도된 잔존이다.

---

## 정리 작업 제안 (우선순위 순)

1. **`useDemoLocation = false`** — 출시 전 필수 (#1)
2. **README 갱신** (#12) — 신규 참여자가 가장 먼저 읽는 문서
3. **죽은 코드 5건 삭제** (#2 #3 #4 #5) + stale 주석 2건 (#13 #14) — 한 커밋으로 처리 가능
4. **바코드 스캔 존치 결정** (#8) — 결정에 따라 의존성 1개가 빠진다
5. **죽은 Edge Function 2개 제거** (#6 #7) — 배포 제거가 동반되므로 별도 작업
6. **"역대 최저가" 배지 붙이기** (#10) — 데이터가 이미 쌓이는 중, 가성비 좋음
