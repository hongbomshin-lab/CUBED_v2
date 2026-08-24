> ⚠️ **아카이브 문서** — 작성 시점의 설계 기록입니다. 현재 스펙은 [`docs/product-spec.md`](../../product-spec.md)를 보세요.

# 라라스윗 독립 가격 카탈로그와 일일 동기화

## 동작

1. `sync-lalasweet-prices`가 할인특가 목록과 모든 상세 옵션을 읽는다.
2. 기존 `products`와 매칭되는 옵션은 `product_id`를 연결한다.
3. 미등록 옵션도 `catalog_product_key`로 `product_prices`에 저장한다.
4. 3장 분석은 등록 제품과 활성 가격 카탈로그의 합집합을 CLOVA로 분류한다.
5. 미등록 제품은 OCR 영양 분석값을 유지하고 `price_match`로 공식몰 가격을 표시한다.
6. 전체 페이지 파싱이 성공한 경우에만 upsert하고, 목록에서 사라진 행사만 비활성화한다.

## 운영 설정

- Edge Function: `sync-lalasweet-prices`
- Cron: `sync-lalasweet-prices-daily`
- 실행 시각: 매일 18:10 UTC, 03:10 KST
- Vault: `zero_dot_project_url`, `zero_dot_publishable_key`, `lalasweet_sync_secret`
- Edge secret: `LALASWEET_SYNC_SECRET`

비밀값은 저장소에 넣지 않는다. `LALASWEET_SYNC_SECRET`과 Vault의
`lalasweet_sync_secret`에는 같은 값을 설정한다.

## 배포

```powershell
npx.cmd supabase@latest db query --linked `
  --file supabase/migrations/20260803150000_price_catalog_matching.sql

npx.cmd supabase@latest functions deploy submit-product `
  --project-ref aqhfddvvxnakgkdtirem --use-api

npx.cmd supabase@latest functions deploy sync-lalasweet-prices `
  --project-ref aqhfddvvxnakgkdtirem --use-api

npx.cmd supabase@latest db query --linked `
  --file supabase/migrations/20260803160000_schedule_lalasweet_price_sync.sql
```

## 응답 지표

- `pages_seen`: 확인한 행사 상세 페이지 수
- `offers_parsed`: 파싱한 행사 옵션 수
- `catalog_products`: 중복 제거한 가격 카탈로그 제품 수
- `registered_matches`: `products`에 연결된 가격 행 수
- `unregistered_matches`: 가격 카탈로그에만 있는 행 수
- `upserted`: 갱신한 행 수
- `deactivated`: 이번 목록에서 사라져 비활성화한 행 수

목록이 비거나 상세 페이지 하나라도 파싱되지 않으면 함수는 500을 반환하고 DB를
변경하지 않는다. 수동 점검은 비밀 헤더를 포함해 `{ "dry_run": true }`로 호출한다.
