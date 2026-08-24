# ZERO DOT — 제품 기획서 (통합본)

> **버전** v0.2.0+1 · **작성일** 2026-08-24 · **기준 커밋** `451e255`
> 이 문서는 흩어져 있던 개별 기획/설계 문서(`docs/superpowers/`)를 **현재 코드 기준으로 총정리한 단일 기준 문서**다.
> 개별 문서는 "그때의 설계 이력"으로 남기고, **현재 스펙은 이 문서를 정본으로 삼는다.**

---

## 1. 제품 개요

### 1-1. 한 줄 정의
**저당·제로 제품이 "진짜 저당인지" 사진 한 장으로 판정하고, 더 나은 대안·살 곳·먹은 기록까지 이어주는 앱.**

### 1-2. 풀려는 문제
| 문제 | 사용자가 겪는 것 |
|---|---|
| **0g 마케팅 함정** | "무설탕/제로" 표기인데 말티톨·말토덱스트린 때문에 실제로는 혈당이 오른다 |
| **라벨 해독 불가** | 순탄수·당알코올·희소당 계산을 소비자가 직접 할 수 없다 |
| **정보 파편화** | 편의점 제품 / 프랜차이즈 음료 / 저당 전문 매장 / 브랜드 특가가 전부 다른 곳에 있다 |
| **행동 연결 부재** | "이건 나쁘다"까지만 알려주고, 그래서 뭘 먹어야 하는지는 안 알려준다 |

### 1-3. 해결 방식 — 3단 구조
```
판정(Verdict)  →  대안(Alternative)  →  기록·보상(Habit)
 "이거 진짜 저당?"    "그럼 대신 뭘?"        "잘 먹었네, +12P"
```

### 1-4. 타깃
- **1차**: 혈당을 신경 쓰는 사람 (당뇨 전단계·당뇨·저탄고지·다이어트)
- **2차**: 제로 제품을 즐기지만 성분을 모르는 일반 소비자
- **3차**: 전주 지역 방문 외국인 (저당맵 다국어 — 한/영/일/중)

### 1-5. 절대 원칙
> **해석값(순탄수·혈당등급·0g함정)은 DB에 저장하지 않고 항상 런타임 계산한다.**
> 룰북이 바뀌면 전 제품 판정이 즉시 따라 바뀌어야 하기 때문. 앱(`lib/core/rulebook.dart`)과
> 서버(`supabase/functions/chat/index.ts`)가 같은 룰북을 1:1 포팅으로 유지한다.

---

## 2. 정보 구조 (IA)

앱 최상위는 **하단 4탭 셸**(`lib/features/shell/main_shell.dart`). `IndexedStack`이라 탭 전환 시 상태(지도 위치 등)가 보존된다.

```
MainShell
├── ① 제품분석 (HomeScreen)
│   ├── AI 사진 분석 → CaptureScreen → ResultScreen        [메인 CTA]
│   ├── 이름으로 검색 → SearchScreen → ResultScreen
│   ├── AI에게 묻기 → ChatScreen
│   ├── 내가 먹은 기록 → DiaryScreen
│   └── (숨김) 바코드 스캔 → ScanScreen                      [FeatureFlags.barcodeScan=false]
│
├── ② 저당맵 (MapScreen)  ※ 웹에서는 안내 화면으로 대체
│   ├── [지도 모드] 네이버 지도 + 매장 마커 + 유형 필터 + 검색
│   │   ├── StoreDetailSheet → 리뷰/즐겨찾기/메뉴판 제보
│   │   └── 프랜차이즈 토글(반경 500m) → 브랜드 저당 메뉴 추천
│   ├── [메뉴 정보 모드] FranchiseBrowser → FranchiseDetailSheet
│   └── LanguageFab (한/영/일/중)
│
├── ③ 핫딜 (HotDealsScreen)
│   └── 브랜드 공식몰 특가 — 검색·브랜드·카테고리·정렬 + 20개씩 더보기
│
└── ④ 마이 (AccountScreen)
    ├── 슈가포인트 카드
    ├── 즐겨찾기 매장 / 작성한 리뷰 / 작성한 댓글
    └── 로그아웃
```

---

## 3. 기능 스펙

### 3-1. 제품 분석 — AI 사진 분석 (메인 진입점)

**화면**: `lib/features/capture/capture_screen.dart` · `capture_controller.dart`

2단계 플로우로 "이미 아는 제품"과 "처음 보는 제품"을 나눈다.

```
진입 즉시 카메라 실행 (슬롯 화면 안 보여줌)
        │
   [전면 1장 촬영]
        │
        ├─ submit-product { quick:true } → CLOVA 폐쇄형 분류로 등록 제품 매칭
        │       │
        │       ├─ 매칭 성공 → 즉시 ResultScreen (촬영 1장으로 끝)
        │       └─ 실패(null) → quickChecked=true, 3장 슬롯 열림
        │
   [원재료 + 영양성분 2장 추가 촬영]
        │
        └─ submit-product (풀 파싱) → CLOVA 멀티이미지 파싱
                → submission-images 업로드 + user_submissions(pending) 적재
                → 파싱 결과를 메모리 Product로 ResultScreen에 전달 (DB 미저장)
```

- 이미지 제약: `maxWidth/maxHeight 1280, quality 80` — CLOVA 비전이 긴 변 2240px 초과를 거부(40063)하기 때문.
- 1단계에서 카메라를 취소하면 화면 자체를 닫는다(촬영을 그만둔 것으로 간주).
- **성장 루프**: 미등록 제품 촬영 → `user_submissions` 적재 → 관리자 콘솔에서 검수·승격 → `products` 증가.

### 3-2. 제품 분석 — 결과 화면 (앱의 심장)

**화면**: `lib/features/result/result_screen.dart`

정보를 **4층 구조**로 쌓는다. 위로 갈수록 "답", 아래로 갈수록 "근거".

| 층 | 구성 | 위젯 |
|---|---|---|
| **1층 — 답** | 판정 히어로: `[라벨 vs 실제]` 스트립 또는 등급 배지 + 이유 불릿(최대 3) + 핵심 수치 3칸 | `VerdictHero` / `domain/verdict.dart` |
| — | 단맛 레시피 한 줄 (다중 조합 규칙 매칭 시) | `_RecipeLine` |
| — | 가격 비교 (라라스윗 카탈로그 매칭 시) | `PriceComparisonSection` |
| **2층 — 행동** | 주의 등급이면 **대안 추천을 먼저**, 그 외엔 3층 아래로 | `_AlternativesSection` |
| — | '오늘 이거 먹었어요' 토글 (+포인트 적립) | `EatenTodayButton` |
| — | 포함된 대체당 칩 — 탭하면 성분 설명 시트 | `SweetenerChips` / `SweetenerSheet` |
| **3층 — 근거** | 영양성분 표 + 양 슬라이더(0.5~3회분) + 계산 근거 | `_NumbersSection` / `PortionSlider` |
| — | "이 제품 AI에게 묻기" | `_AskAiButton` |
| **4층 — 커뮤니티** | 좋아요 + 코멘트 | `SocialSection` |
| — | 미검수 제품이면 초안 안내 | `_DraftNotice` |

**판정 표현층(`Verdict`)의 3분기**
| kind | 조건 | 표시 |
|---|---|---|
| `zeroBusted` | 당류 ≤ 0.5g 인데 함정 있음 or 등급이 '낮음' 아님 | `무설탕·제로 → 혈당 올라요` |
| `zeroTrue` | 당류 ≤ 0.5g 이고 함정 없고 등급 '낮음' | `무설탕·제로 → 진짜예요` (참고 불릿 생략) |
| `generic` | 무설탕 표기 아님 | 스트립 없이 등급 배지 + 불릿 |

### 3-3. 판정 엔진 — 룰북

**코드**: `lib/core/rulebook.dart` (Dart) ↔ `supabase/functions/chat/index.ts` (TS 포팅)

#### 순탄수
```
netCarb = carb − fiber − sugarAlcohol − rareSugarG      (음수 방지, 소수 2자리)
per100NetCarb = netCarb × 100 / servingSize             (액상 100ml / 고형 100g)
```

#### 열량 정합 클램프
라벨 kcal로 물리적으로 가능한 최대 흡수 탄수는 `kcal/4` g. 순탄수가 이를 넘으면 미기재 알룰로스가
탄수에 섞인 것으로 보고 유효 순탄수를 클램프한다. (kcal=0이면 클램프 안 함 — OCR null 보호)

#### 등급 = 감미료 단계 + 순탄수 단계 (누적, 상한 '주의')
> `max`가 아니라 **누적**인 것이 핵심. 감미료도 애매하고 순탄수도 애매한 제품이 '낮음'으로 빠져나가지 않는다.

**순탄수 단계** = `max(밀도 기준, 1회분 절대 g 기준)`
- 밀도: 액상 `_tCarbLiq` / 고형 `_tCarbSolid` 임계
- 1회분 절대: `5g` → +1, `15g` → +2
- (밀도만 보면 1회분이 큰 저밀도 제품이 빠져나가기 때문)

**감미료 단계** — 양 감응 보정 2가지
- 혈당 올리는 당알코올(`maltitol·xylitol·sorbitol·polyglycitol`)이 **명시적으로 0 < SA < 2g**이면 미량 → 0단계 (SA 미기재(0)는 알 수 없으므로 보수 유지)
- `maltodextrin`은 유효 순탄수 < 2g이고 순탄수 계산이 신뢰 가능하면 +1(중간)로 완화

**등급 계산 제외**: `class='기타'` 중 혈당영향 '낮음'인 것만 (`gum-arabic`, `monosodium-glutamate`).
말토덱스트린은 **제외하지 않는다** — 개별 g이 라벨에 안 잡히는 실사례(딥앤쫀득초코)가 있어 감미료 경로로 반드시 반영.

#### 함정 코드 (0g 마케팅 함정)
| 코드 | 조건 | 티어 |
|---|---|---|
| `당알코올 함정` | 당류 ≤ 0.5g **&&** SA ≥ 2g **&&** risky 당알코올 포함 | 🚩 오해유발 |
| `칼로리 함정` | 당류 ≤ 0.5g **&&** 100단위당 kcal ≥ 4(액상)/40(고형) | 🚩 오해유발 |
| `당류 함정` | 100단위당 당류 > 2.5(액상)/5(고형) | ℹ️ 참고 |
| `탄수 함정` | 당류 함정 아니고 순탄수 단계 > 0 | ℹ️ 참고 |

> `탄수 함정`은 **당 0g 제품에도** 보여준다 — "당은 0인데 왜 주의냐"의 핵심 근거이기 때문.

#### 대안 추천 (킬러 피처)
같은 `category`에서 최대 30개를 뽑아 등급 상향 순으로 랭킹 → 상위 N개. `alternativesIn()` + `rankAlternatives()`.

### 3-4. 제품 분석 — 이름 검색
`SearchScreen` → `products.name` 부분일치(ilike, 최대 20) → `ResultScreen`. 홈 카드 서브텍스트는 "408개 제품".

### 3-5. 제품 분석 — AI 도우미 채팅

**앱**: `lib/features/chat/` · **서버**: `supabase/functions/chat/index.ts`

- 전 제품의 **룰북 요약**(name·brand·category·grade·per100NetCarb·sugar·kcal·unit·traps·sweeteners)을 시스템 프롬프트에 주입 → CLOVA HCX-005가 **데이터에 있는 제품만 근거로** 답변.
- 비스트리밍(완성 답변 1회), 대화는 메모리만(autoDispose — 화면 나가면 초기화, DB 미저장).
- 예시 질문 칩 제공. 결과 화면에서 진입하면 `"{제품명}, 혈당 관리 중인데 먹어도 괜찮아?"`로 프리필.
- 서버가 룰북을 1:1 포팅해 갖고 있어 **앱 등급과 채팅 등급이 항상 일치**한다.
- ⚠️ **스케일 한계**: 전 제품 주입 방식이라 제품 수에 비례해 프롬프트 토큰이 커진다(408개 ≈ 4만 토큰). 한도에 닿으면 검색형(RAG) 전환 필요.

### 3-6. 먹은 기록 (푸드 다이어리) + 슈가포인트

**화면**: `lib/features/diary/` · **테이블**: `product_logs` (RLS own-rows)

- 결과 화면의 `EatenTodayButton`으로 하루 1건 토글 등록/취소. DB 제품·촬영 제품 공용(촬영분은 `product_id=null` + `submission_image_path`).
- `DiaryScreen`: `table_calendar` 월 뷰 + 선택일 리스트. **보기·스와이프 삭제 전용**(수정 없음).
- 썸네일 분기(`log_image_url.dart`): DB 제품 → `product-images` 공개 URL / 촬영 제품 → `submission-images` 인증 URL / 없으면 placeholder.

**슈가포인트 산식** (`lib/core/sugar_baselines.dart`, 근거: `docs/sugar-baselines.md`)
```
포인트 = max(0, 카테고리 기준값 − 제품 당류)      1P = 아낀 설탕 1g
```
- 기준값은 **"일반 제품 1회 섭취 당류" 고정값**. 제품 용량에 비례시키지 않는다
  (1.5L 제로콜라를 기록해도 캔 1개 기준 포인트만 적립).
- 매칭 우선순위 = 선언 순서. 키워드 규칙(`아메리카노`, `믹스`, `콘`, `모나카` 등)이 카테고리 기본값보다 먼저.
- 예: 탄산음료 27g(콜라 250ml 캔) / 커피 22g(라떼 275ml), 아메리카노 10g / 과일음료 36g.
- 모르는 카테고리는 기준값 없음 → **포인트 0** (억지 적립 안 함).
- 적립 시점에 **스냅샷으로 저장**(`product_logs.points`) — 나중에 기준값이 바뀌어도 과거 기록은 안 흔들린다.
- 체감 환산: 각설탕 1개 ≈ 3g. 마이 탭에 `설탕 148g 아꼈어요 · 각설탕 약 49개` 형태로 표시.

### 3-7. 저당맵

**화면**: `lib/features/map/map_screen.dart` (873줄, 최대 화면) · 상세 `widgets/store_detail_sheet.dart` (972줄)

두 개 모드를 상단 세그먼트로 전환한다.

**[지도 모드]**
- 네이버 지도 SDK(`flutter_naver_map`) — 웹 미지원이라 `kIsWeb`이면 안내 화면으로 대체.
- 매장 마커: `store_type` 별 아이콘(위젯→이미지 변환 비용 때문에 캐시), 지도 idle 디바운스 후 영역 조회.
- 매장명 검색(300ms 디바운스) → 탭하면 카메라 이동 + 상세 시트.
- **프랜차이즈 토글**(기본 꺼짐): 켜면 내 위치 반경 500m 프랜차이즈 카페를 함께 표시. 저당맵의 주인공은 저당 전문 매장이라 기본 비노출. 영역 조회에는 포함되지 않는다.
- 위치 캐시: `SharedPreferences['jodangmap_location']`, TTL 24h. 권한 거부/실패 시 서울 중심 폴백.

**[매장 상세 시트]** — 사진 / 정보 / 대표 메뉴(저당·시그니처) / 리뷰 / 즐겨찾기 / 길찾기(외부 앱)
- **리뷰**: 👍/👎 필수 + 내용 선택(500자), 매장당 1인 1리뷰(upsert). `ReviewSheet`
- **즐겨찾기**: 하트 토글 → 마이 탭 목록
- **제보 2종**: `StoreReportSheet`(신규 매장 — 이름 필수 + 플레이스 URL·사진 선택) / `MenuBoardReportSheet`(메뉴판 사진 — 촬영·압축 후 업로드 또는 URL). 둘 다 **관리자 승인 시** 실제 데이터로 반영(승인 트리거가 `stores`/`store_photos` 자동 생성).
- 프랜차이즈 매장이면 **그 브랜드의 저당 메뉴 5개** 추천(`brandLowSugarProvider`).

**[메뉴 정보 모드]** — `FranchiseBrowser`
- 프랜차이즈 음료 당류 검색 + 브랜드 필터 + 정렬(당 낮은순/높은순 등).
- 같은 메뉴는 `브랜드+기본명`으로 그룹핑 → 상세 시트에서 **온도/사이즈 변형을 탭으로 전환**.
- 당류 신호색: `5g↓ 좋음 / 5–15g 보통 / 15g↑ 경고`.

**[다국어]** — 한/영/일/중, `LanguageFab`으로 전환
- 고정 UI 문구: `lib/core/i18n/ui_strings.dart` (코드 상수)
- 메뉴명·브랜드·사이즈·카테고리·매장명: `franchise_translations` 테이블(언어당 ~1,000건을 통째로 받아 메모리 맵)
- 외국어 표시 중에는 서버 검색어를 비우고 **번역 사전 기준으로 클라이언트 필터** — 화면에 보이는 이름으로 검색되게.
- 지도 마커 캡션도 선택 언어를 따른다.
- ⚠️ **다국어는 저당맵 영역에만 적용**. 제품분석·핫딜·마이 탭은 한국어 전용.

### 3-8. 핫딜

**화면**: `lib/features/hotdeals/hot_deals_screen.dart` · **테이블**: `brand_deals` + `crawl_brands`

- 저당 브랜드 공식몰(라라스윗·널담·마이노멀) 특가 모음. 앱은 **읽기 전용**.
- 필터: 검색어(토큰 AND 부분일치) · 브랜드 · 카테고리(9종) · 정렬(할인율/최신).
- `is_deal=true && ended_at is null`만, **20개씩 페이지**(더보기)로 부하 절감.
- 탭하면 외부 브라우저로 상품 페이지 이동.
- 데이터는 `crawl-deals` Edge Function이 pg_cron으로 하루 1회 채운다.

### 3-9. 마이

`AccountScreen` — 비로그인이면 로그인 유도 화면.
- 프로필 헤더(닉네임·이메일)
- **슈가포인트 히어로 카드** (다크 잉크 + 라임 숫자 + `SugarCubeStack` 장식)
- 즐겨찾기 매장 / 작성한 리뷰 / 작성한 댓글 (각 건수 배지)
- 로그아웃

### 3-10. 계정·인증

**`lib/data/auth_repository.dart`** — Supabase Auth 기반, 3가지 경로
| 방식 | 구현 | 비고 |
|---|---|---|
| 이메일/비밀번호 | 직접 가입·로그인 + 닉네임 | |
| 카카오 OAuth | 외부 브라우저 → 딥링크 `cubed://login-callback` 복귀 | |
| Apple 로그인 | `sign_in_with_apple` 네이티브 시트 | App Store 4.8 — 카카오 제공 시 필수 |

- 비로그인 사용자는 **조회만** 가능. 좋아요·코멘트·리뷰·먹은기록은 로그인 후.
- **회원 탈퇴**: `delete-account` Edge Function이 계정 + 전 데이터 삭제 (Apple 5.1.1(v)·Google Play 필수 요건).

---

## 4. 아키텍처

### 4-1. 레이어
```
lib/
├── core/        룰북·표현층·테마·i18n·위치캐시·기준값        [순수 로직 — 테스트 대상]
│   ├── rulebook.dart      해석 엔진 (수치 계산)
│   ├── explain.dart       룰북 값 → 사용자 문장 (수치 새로 안 만듦)
│   ├── sugar_baselines.dart  포인트 기준값
│   └── theme.dart         디자인 토큰 "Matcha Ink"
├── domain/      Product → ViewModel
│   ├── interpretation.dart   해석 결과(등급·함정·칩·combo·대안)
│   └── verdict.dart          답 한 줄 + 이유 불릿 (중복 제거)
├── data/        Supabase 조회 + 모델                        [8 repository / 13 model]
├── providers/   Riverpod 프로바이더 단일 파일               [38개]
├── features/    화면 (기능별 폴더)
└── admin/       관리자 콘솔 — 별도 entrypoint (main_admin.dart)
```

**의존 방향**: `features → domain → core` / `features → data → core`. `core`는 아무것도 모른다.

### 4-2. 상태 관리 — Riverpod
- 전 프로바이더가 `lib/providers/providers.dart` 한 파일에 모여 있다(38개, 285줄).
- `family` 키는 **불변 값 동등 타입**으로 강제 (`DealQuery`, `FranchiseQuery`, `({int year, int month})`, `PriceLookup` 레코드).
- 기준 데이터(`referenceProvider`)는 앱 시작 시 1회 로드 후 캐시.

### 4-3. 디자인 시스템 — "Matcha Ink"
| 역할 | 토큰 | 값 |
|---|---|---|
| 캔버스 | `bg` | `#F3F6F1` 페이퍼 그린 |
| 잉크 | `ink` / `inkSoft` | `#10231B` / `#5F7168` |
| 브랜드 | `brand` / `brandDeep` | `#0FA678` / `#0A6B4F` |
| 액센트 | `lime` | `#C9F158` — **잉크(다크) 표면 위 전용** |
| 신호등 | `low` / `mid` / `caution` | `#17A05B` / `#DB8A00` / `#E5484D` |

- 폰트: Pretendard (400/500/700/800)
- 형태: `radiusHero 28 / radiusCard 20 / radiusField 16`, 경계선 대신 소프트 섀도우로 깊이 구분
- 모션: `Reveal` 위젯 — 페이드 + 위로 슬라이드, `delayMs`로 스태거. 시스템 '동작 줄이기' 설정 시 즉시 표시
- 아이덴티티: 워드마크 `ZERO DOT ●`, 히어로 카드 배경의 라임 도트 그리드, `SugarCubeStack` 각설탕 3개

---

## 5. 데이터

### 5-1. 테이블
| 도메인 | 테이블 | 앱 사용 |
|---|---|---|
| **제품** | `products`, `product_sweeteners`, `sweeteners`, `category_meta`, `combo_rules` | 읽기 |
| | `user_submissions`, `sweetener_review` | 촬영 제보 적재 / 관리자 검수 |
| **가격** | `product_prices` | 읽기 (라라스윗 카탈로그) |
| **소셜** | `product_likes`, `product_like_counts`(뷰), `product_comments` | 읽기·쓰기 |
| **기록** | `product_logs` | 읽기·쓰기 (RLS own-rows) |
| **저당맵** | `stores`, `store_photos`, `store_menus`, `store_reviews`, `store_favorites` | 읽기·쓰기 |
| | `store_reports`, `menu_board_reports` | 쓰기 (승인 시 트리거로 반영) |
| **프랜차이즈** | `franchise_drinks`, `franchise_translations` | 읽기 |
| **핫딜** | `brand_deals`, `crawl_brands` | 읽기 |
| | `crawl_runs`, `crawl_settings`, `deal_snapshots`, `deal_price_history` | 크롤러 전용 |
| **랜딩** | `launch_notifications` | 랜딩 페이지(`landing/index.html`) 대기자 등록 |

**Storage 버킷**: `product-images`(공개, `{product_id}.png`) · `submission-images`(비공개) · `store-images` / `menu-images`

**데이터 현황**: products 408 · product_sweeteners 896 · sweeteners 28 · category_meta 18 · combo_rules 12 · 전주 매장 14 · 전주 프랜차이즈 191 · 프랜차이즈 번역 573행(191곳 × 3언어).
⚠️ **products는 전부 `verified=false`** — 사람 검수 전 초안. 결과 화면에 초안 안내가 뜬다.

### 5-2. Edge Functions
| 함수 | 호출자 | 역할 |
|---|---|---|
| `submit-product` | **앱** (`OcrService`) | 전면 1장 빠른 매칭(`quick:true`) + 3장 풀 파싱 + 제보 적재 |
| `chat` | **앱** (`ChatService`) | 전 제품 룰북 요약 주입 → CLOVA HCX-005 답변 |
| `delete-account` | **앱** (`AuthRepository`) | 회원 탈퇴 — 계정 + 전 데이터 삭제 |
| `admin` | **관리자 콘솔** | 제보 큐 조회·편집·승격·거절 (JWT 이메일 ↔ `ADMIN_EMAILS` 대조) |
| `crawl-deals` | pg_cron (하루 1회) | 브랜드 공식몰 크롤 → `apply_crawl_result` RPC |
| `translate-franchise` | 수동 운영 (curl) | 미번역 (메뉴명 × 언어) 조합 CLOVA 배치 번역 |
| ~~`ocr-parse`~~ | **없음** | `submit-product`에 흡수됨 → §7 참조 |
| ~~`recognize-product`~~ | **없음** | `submit-product`의 quick 모드에 흡수됨 → §7 참조 |

**시크릿**(Edge Functions Secrets에만): `CLOVA_API_KEY`(파싱·인식·채팅·번역 공용) · `ADMIN_EMAILS` · 선택 `OCR_PROVIDER`(`clova` 기본 / `gemini` 롤백) · `CHAT_MODEL`(기본 `HCX-005`).
앱·코드에는 키가 없다. 클라이언트는 anon 키로만 호출하고 RLS가 막는다.

### 5-3. 관리자 콘솔
`lib/admin/main_admin.dart` — **앱 본체와 완전히 분리된 Flutter Web entrypoint**.
```bash
flutter build web --target lib/admin/main_admin.dart --no-tree-shake-icons
```
- **제보 큐**(`SubmissionQueueScreen`): `parsed` jsonb 편집 폼 + 실시간 등급 미리보기 → 승인 시 `promote_submission` 트랜잭션(products + product_sweeteners + 대표 이미지 복사 + sweetener_review)
- **제품 브라우저**(`ProductBrowserScreen`): 기존 408개 + 승격분 검색·상세 편집, `verified` 토글, 웹 클립보드 이미지 붙여넣기
- **이중 방어**: 1차는 서버(`admin` 함수가 JWT 이메일 대조, 불일치 시 전 액션 403) / 2차는 클라이언트 로그인 화면(UX 편의일 뿐 신뢰 경계 아님)

---

## 6. 품질·테스트

**테스트 15개** (`test/`) — 순수 로직 위주. Flutter SDK 필요.
```
core/       rulebook_test · sugar_baselines_test
domain/     interpretation_combo_test · verdict_test
data/       food_log_test · franchise_translation_test · product_price_test
features/   capture_controller · log_image_url · ocr_result · portion_slider · sweetener_chips · verdict_hero
admin/      parsed_form_logic_test
```
**Deno 테스트 4개** (`supabase/functions/`): `parse_test` · `recognize_test` · `price_catalog_test` · `lalasweet_crawler_test` · `admin/gate_test`

커버리지 공백: 저당맵(map_screen 873줄) · 핫딜(645줄) · 매장 상세 시트(972줄) — 전부 위젯/네트워크 결합이라 미테스트.

---

## 7. 현재 상태 & 알려진 갭

### 7-1. 출시 상태
- 코드: 스토어 제출 요건 충족 (개인정보처리방침 링크, 건강정보 면책, 회원 탈퇴, Apple 로그인)
- 남은 것은 계정·콘솔 등록 작업 → `docs/store-release-checklist.md`

### 7-2. 즉시 조치 필요
| # | 항목 | 위치 | 영향 |
|---|---|---|---|
| 1 | **`FeatureFlags.useDemoLocation = true`** — IR 시연용 전주 좌표 하드코딩이 켜진 채 | `core/feature_flags.dart` | **출시 시 실제 GPS가 아니라 전주 신시가지로 고정된다.** 출시 전 `false` 필수 |
| 2 | 홈 계정 시트의 `'카카오 로그인됨'` 고정 문구 | `home_screen.dart:250` | 이메일·Apple 로그인 사용자에게 오표기 |
| 3 | `env.dart`의 `TODO: 발급받은 값으로 교체` 주석 | `core/env.dart:19` | 값은 이미 채워져 있음 — 주석만 stale |
| 4 | README가 v0.1 시절 기준 | `README.md` | 4탭·저당맵·핫딜·포인트 미기재, 채팅 엔진을 Gemini로 표기 |

### 7-3. 구조적 갭
- **채팅 토큰 스케일**: 전 제품 주입 방식(408개 ≈ 4만 토큰). 제품이 늘면 검색형 전환 필요.
- **데이터 신뢰도**: products 408개 전부 `verified=false`. 관리자 콘솔 검수 처리량이 병목.
- **다국어 범위 불일치**: 저당맵만 4개국어, 나머지 탭은 한국어 전용.
- **계정 진입점 이원화**: 홈 우상단 계정 칩과 마이 탭이 각각 다른 메뉴를 갖는다(회원 탈퇴는 홈에만, 즐겨찾기·리뷰는 마이에만).
- **먹은 기록 진입점**: 홈 카드에만 있고 마이 탭에는 없다 — 기록·포인트가 같은 축인데 화면이 갈린다.

### 7-4. 미사용 자산
별도 감사 문서 참조 → **`docs/reports/2026-08-24-unused-code-audit.md`**

---

## 8. 로드맵 제안

### Phase 3 — 신뢰도 (다음)
1. `verified=true` 확대 — 관리자 콘솔 일괄 승인/거절, 감사 로그
2. 제보 썸네일 미리보기(`admin` 함수에 `signed_url` 액션)
3. 파싱 프롬프트 강화 — 알룰로스를 `rare_sugar_g`에 자동 반영

### Phase 4 — 습관화
4. 슈가포인트 리워드 설계 (지금은 적립만 있고 사용처가 없다)
5. 주간 리포트 — "이번 주 설탕 000g 아꼈어요"
6. 먹은 기록을 마이 탭으로 승격 (기록·포인트 축 통합)

### Phase 5 — 확장
7. 저당맵 지역 확대 (현재 전주 한정)
8. 채팅 RAG 전환
9. 다국어를 제품분석 탭까지 확장
10. 핫딜 "역대 최저가" 배지 — `deal_price_stats` 뷰는 이미 만들어져 데이터가 쌓이는 중, UI만 없음

---

## 9. 문서 지도

| 문서 | 역할 |
|---|---|
| **`docs/product-spec.md`** (이 문서) | **현재 스펙 정본** |
| `docs/reports/2026-08-24-unused-code-audit.md` | 미사용 기능·코드 감사 |
| `docs/sugar-baselines.md` | 슈가포인트 기준값 조사 근거 |
| `docs/reports/2026-08-20-traffic-light-regrade.md` | 신호등 재판정 리포트 |
| `docs/admin-deploy.md` | 관리자 콘솔 배포·운영 |
| `docs/store-release-checklist.md` | 스토어 출시 체크리스트 |
| `docs/privacy-policy.md` | 개인정보처리방침 (GitHub Pages 게시) |
| `docs/superpowers/plans/*`, `specs/*` | **설계 이력 아카이브** — 현재 스펙 아님 |
| `flutter_porting_context.md` | Next.js→Flutter 포팅 당시 컨텍스트 (2026-06, 아카이브) |
