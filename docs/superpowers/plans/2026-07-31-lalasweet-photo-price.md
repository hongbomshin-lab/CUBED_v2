> ⚠️ **아카이브 문서** — 작성 시점의 설계 기록입니다. 현재 스펙은 [`docs/product-spec.md`](../../product-spec.md)를 보세요.

# 라라스윗 사진 인식·가격 비교 구현 계획

**Goal:** 라라스윗 앞면 사진 한 장으로 등록 제품을 찾고, 결과 화면과 핫딜 탭에서 실제 가격 제안을 보여준다.

**Architecture:** `recognize-product`가 DB의 라라스윗 후보를 CLOVA 폐쇄형 분류에 전달하고 검증된 `Product`를 반환한다. 가격은 `product_prices` 한 테이블에 원시 제안만 저장하며 개당가·할인율·최저가 문구는 Flutter에서 계산한다.

**Spec:** `docs/superpowers/specs/2026-07-31-lalasweet-photo-price-design.md`

## Task 1: 가격 스키마와 순수 모델

- [x] `20260731190000_product_prices.sql`: 테이블, 인덱스, 공개 읽기 RLS, 확인된 공식몰 데모 시드
- [x] `ProductPrice`와 `HotDealItem`: 파싱, 개당가, 정가 대비 할인율, 표시 문구
- [x] 가격 계산 단위 테스트

## Task 2: 가격 데이터 접근

- [x] `PriceRepository.forProduct(productId)`: 활성 제안을 개당가 순으로 반환
- [x] `PriceRepository.hotDeals()`: 비정가 행과 제품 스냅샷 조인
- [x] Riverpod repository/product/hot-deals provider 추가

## Task 3: 결과 가격 비교 UI

- [x] `PriceComparisonSection`: 로딩, 데이터, 없음, 오류 비차단 상태
- [x] 정가→최저가 요약, 채널별 총액·개당가·확인일, 외부 링크
- [x] `ResultScreen` 판정 아래에 섹션 연결

## Task 4: 핫딜 탭

- [x] 플레이스홀더를 실데이터 목록으로 교체
- [x] 제품 이미지·제품명·판매처·묶음가·개당가·확인일·구매 링크 표시
- [x] 로딩, 빈 상태, 오류 재시도 구현

## Task 5: 폐쇄형 제품 인식 Edge Function

- [x] `_shared/recognize.ts`: 후보 프롬프트, CLOVA 요청, JSON 정규화, 임계값·후보 ID 검증
- [x] `_shared/recognize_test.ts`: 이미지/후보 포함, 코드펜스, 문자열 confidence, 거부 케이스
- [x] `recognize-product/index.ts`: 입력 검증, 라라스윗 후보 조회, CLOVA 호출, 제품 조인 반환

## Task 6: Flutter 인식 서비스와 1장 화면

- [x] `ProductRecognitionResult` 순수 파싱과 `ProductRecognitionService`
- [x] 파싱 단위 테스트
- [x] `RecognizeProductScreen`: 카메라/앨범, 미리보기, 로딩, 성공 이동, 미인식·오류, 재촬영
- [x] 기존 `CaptureScreen`으로 가는 3장 정밀 분석 보조 명령
- [x] 홈 `사진으로 찾기` 진입 교체

## Task 7: 검증

- [x] `dart format`
- [ ] `deno fmt` (로컬 Deno 런타임 없음)
- [x] `flutter analyze`
- [x] `flutter test`
- [ ] `deno test supabase/functions/_shared/parse_test.ts supabase/functions/_shared/recognize_test.ts`
- [x] `git diff --check`와 변경 범위 검토
