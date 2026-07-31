# ZERO DOT 라라스윗 사진 인식·가격 비교 설계

- 상태: 설계 확정
- 작성일: 2026-07-31
- 대상: ZERO DOT Flutter 앱 + Supabase `aqhfddvvxnakgkdtirem`
- 데모일: 2026-08-05

## 1. 목표와 범위

사용자가 라라스윗 제품 앞면 사진 한 장을 촬영하면 등록된 라라스윗 SKU 중 하나를 찾아 기존 분석 결과 화면으로 이동한다. 결과 화면에는 채널별 가격 비교를 표시하고, 핫딜 탭에는 현재 구매 가능한 할인 제안을 모아 보여준다.

이번 데모 범위는 다음 네 가지다.

1. 라라스윗 제품 한 장 폐쇄형 인식
2. `product_prices` 한 테이블과 수동 데모 데이터
3. 결과 화면의 가격 비교 섹션
4. 실데이터 기반 핫딜 탭

네이버 쇼핑·편의점·자사몰 자동 수집기, 바코드 보강, 제휴 추적, 가격 알림은 후속 범위다.

## 2. 확인된 현재 상태

- 2026-07-31 운영 DB 조회 결과 `products.brand = '라라스윗'` 제품이 44개 존재한다. 제품 시딩은 필요 없다.
- 기존 홈의 `사진으로 찾기`는 3장 OCR 제보 화면으로 바로 이동한다.
- 기존 `ResultScreen`은 DB `Product`를 받아 룰북 해석·대안·먹은 기록을 표시한다.
- `hot_deals` 테이블은 존재하지만 제품 FK, 묶음 수량, 개당가 계산에 필요한 정보가 없다.
- CLOVA HCX-005 호출과 JSON 추출 방식은 `supabase/functions/_shared/parse.ts`에 검증돼 있다.

## 3. 확정된 UX 결정

### 3.1 진입점

홈의 `사진으로 찾기`는 새 `RecognizeProductScreen`으로 연결한다. 첫 화면은 제품 앞면 한 장만 받는다.

화면 하단에는 `원재료·영양정보까지 직접 분석` 보조 명령을 두어 기존 `CaptureScreen`으로 이동할 수 있게 한다. 기존 3장 분석 기능은 삭제하지 않는다.

### 3.2 인식 성공

1. 카메라 또는 앨범에서 앞면 사진 한 장을 선택한다.
2. 앱이 `recognize-product` Edge Function에 JPEG base64를 전송한다.
3. 함수는 DB의 라라스윗 후보 목록을 읽고 CLOVA에 폐쇄형 분류를 요청한다.
4. 반환된 `product_id`가 후보에 실제 존재할 때만 해당 제품과 감미료 조인을 반환한다.
5. 앱은 기존 `ResultScreen(product:)`으로 이동한다.

분류 결과를 제품명 문자열로 다시 검색하지 않는다. 서버가 허용 후보의 `product_id`를 검증해 오매칭과 프롬프트 이탈을 막는다.

### 3.3 인식 실패·비라라스윗

모델 응답은 `product_id`, `confidence`, `reason`을 포함한다. 다음 중 하나면 `matched=false`로 처리한다.

- `product_id`가 null 또는 `none`
- 반환 ID가 후보 목록에 없음
- confidence가 0.7 미만

앱은 임의의 제품을 보여주지 않고 `라라스윗 제품을 찾지 못했어요` 상태를 표시한다. 사용자는 `다시 촬영`하거나 기존 3장 정밀 분석으로 이동할 수 있다. 네트워크/서버 오류도 같은 화면에서 별도 오류 문구와 재시도를 제공한다.

## 4. 가격 데이터 모델

기존 `hot_deals`는 유지하되 이번 기능의 단일 진실 원천은 새 `product_prices` 테이블로 한다.

```sql
create table public.product_prices (
  id uuid primary key default gen_random_uuid(),
  product_id text not null references public.products(product_id) on delete cascade,
  channel text not null check (channel in ('convenience', 'online', 'brand_mall')),
  store text not null,
  price integer not null check (price > 0),
  unit_count integer not null default 1 check (unit_count > 0),
  promo_type text not null default 'regular'
    check (promo_type in ('regular', 'sale', 'one_plus_one', 'two_plus_one', 'bundle')),
  link_url text,
  is_active boolean not null default true,
  fetched_at timestamptz not null default now(),
  unique (product_id, channel, store, promo_type)
);
```

- `price`는 결제 총액이다.
- 개당가는 앱에서 `price / unit_count`로 계산한다.
- 정가는 편의점 낱개 판매가를 `channel='convenience'`, `promo_type='regular'`로 저장한다.
- 공식몰 묶음은 실제 결제 총액과 구성 수량을 저장한다.
- 해석 문구와 할인율은 DB에 저장하지 않고 런타임에 계산한다.
- 공개 읽기만 허용하고 쓰기는 service role/운영 배치만 수행한다.

가격 레코드가 하나뿐이면 단일 제안으로 표시한다. 두 개 이상이면 가장 낮은 개당가를 강조하고, 정가가 있으면 `정가 A원 → 최저 B원`을 계산한다. 오래된 값을 현재가처럼 보이지 않도록 확인일을 함께 표시한다.

## 5. 데모 시딩 원칙

- 수치와 링크가 확인된 제안만 넣는다.
- 2026-07-31 확인된 라라스윗 공식몰 `저당 초코바` 묶음은 20,900원이며, 2박스 × 4개 기준 `unit_count=8`로 기록한다.
- 대상 SKU는 운영 DB에 존재하는 바닐라·초콜릿·쿠키앤크림 초코바 세 종이다.
- 편의점 정가는 영수증·앱·매대 등으로 확인된 값만 추가한다. 미확인 값은 마이그레이션에 추정해 넣지 않는다.
- `fetched_at`은 시드 확인 시각이며 UI에 `7월 31일 확인`처럼 표시한다.

## 6. 앱 구조

### 6.1 모델·리포지토리

- `ProductPrice`: 총액, 수량, 계산된 개당가, 프로모션, 링크, 확인시각
- `ProductRepository.findById`: 인식 결과 조회용
- `PriceRepository.forProduct`: 제품별 활성 가격 조회
- `PriceRepository.hotDeals`: 할인/묶음 제안을 개당가 오름차순으로 조회
- Riverpod family provider로 결과 화면과 핫딜 탭에 연결

### 6.2 결과 화면

판정과 주요 근거 다음, 대안 추천 전에 `가격 비교` 섹션을 둔다. 가격 조회가 실패해도 제품 분석 화면 전체는 정상 동작한다.

각 행은 채널/판매처, 총액 또는 낱개가, 묶음 개당가, 행사 유형을 표시한다. 링크가 있으면 외부 브라우저로 연다. 최저 제안은 색과 `최저가` 라벨로 한 번만 강조한다.

### 6.3 핫딜 탭

`product_prices`에서 `is_active=true`이며 `promo_type != 'regular'`인 행을 제품과 조인한다. 카드에는 제품 이미지, 제품명, 판매처, 총액, 개당가, 할인/묶음 유형, 확인일, 구매 링크를 표시한다.

빈 상태·로딩·재시도 상태를 제공한다. 할인율은 동일 제품의 정가 행이 있을 때만 계산해 표시한다.

## 7. Edge Function 계약

요청:

```json
{ "image": "<jpeg base64>" }
```

성공 응답:

```json
{
  "matched": true,
  "confidence": 0.94,
  "reason": "전면의 제품명과 맛 표기가 일치",
  "product": { "product_id": "...", "name": "...", "product_sweeteners": [] }
}
```

미인식 응답은 HTTP 200으로 `matched=false`, `product=null`을 반환한다. 입력 오류는 400, 후보/DB/CLOVA 장애는 500으로 반환한다. 이미지 원본은 저장하지 않는다.

## 8. 테스트와 데모 수용 기준

- CLOVA 요청 본문에 이미지 한 장과 모든 후보 ID/이름이 들어간다.
- JSON 코드펜스·confidence 문자열 편차를 정규화한다.
- 후보에 없는 ID와 confidence 0.7 미만을 거부한다.
- 가격 모델의 개당가·정가 대비 할인율 계산을 단위 테스트한다.
- 결과 화면은 가격 로딩 실패와 가격 없음에서도 렌더링된다.
- 핫딜 탭은 로딩·데이터·빈 상태를 렌더링하고 링크를 열 수 있다.
- 홈 → 한 장 촬영 → 라라스윗 인식 → 결과 → 가격 비교 흐름을 실제 기기에서 확인한다.
- 비라라스윗 사진 → 미인식 → 재촬영/3장 분석 흐름을 확인한다.

## 9. 후속 작업

1. 편의점 정가와 행사 데이터의 수동 검수·확대
2. 네이버 쇼핑 일 1회 수집기
3. Cafe24 브랜드몰 어댑터와 구성 수량 파서
4. 바코드 확보 후 이름 매칭에서 바코드 매칭으로 승격
5. 쿠팡 파트너스 링크와 클릭 추적

