-- 공식몰의 서로 다른 행사를 SKU별로 함께 저장하고 구매 조건을 명시한다.
alter table public.product_prices
  add column if not exists offer_key text,
  add column if not exists offer_title text,
  add column if not exists offer_note text;

-- 기존 라라스윗 데이터에 안정적인 행사 키를 부여한다.
update public.product_prices
set offer_key = 'lalasweet-regular'
where offer_key is null
  and store = '정가'
  and promo_type = 'regular';

update public.product_prices
set offer_key = 'lalasweet-249',
    offer_title = coalesce(offer_title, '초코바 2박스 묶음')
where offer_key is null
  and link_url like '%product_no=249%';

update public.product_prices
set offer_key = 'legacy-' || id::text
where offer_key is null;

alter table public.product_prices
  alter column offer_key set not null;

alter table public.product_prices
  drop constraint if exists product_prices_product_id_channel_store_promo_type_key;

create unique index if not exists product_prices_product_offer_key_idx
  on public.product_prices (product_id, offer_key);

-- 할인특가 252: 4개 옵션을 같은 SKU로 고른 경우의 총수량과 개당 환산가.
insert into public.product_prices
  (product_id, channel, store, price, unit_count, promo_type,
   offer_key, offer_title, offer_note, link_url, fetched_at)
values
  ('05T6YY762TB8B', 'brand_mall', '라라스윗 공식몰', 26900, 24, 'bundle',
   'lalasweet-252', '얼리 썸머 4가지 골라담기',
   '같은 SKU를 4개 옵션으로 선택했을 때 · 6개입 4세트',
   'https://lalasweet.kr/product/detail.html?product_no=252', '2026-08-02T10:00:00+09:00'),
  ('0PZK9WE3G83K9', 'brand_mall', '라라스윗 공식몰', 26900, 24, 'bundle',
   'lalasweet-252', '얼리 썸머 4가지 골라담기',
   '같은 SKU를 4개 옵션으로 선택했을 때 · 6개입 4세트',
   'https://lalasweet.kr/product/detail.html?product_no=252', '2026-08-02T10:00:00+09:00'),
  ('097MPZMG249YX', 'brand_mall', '라라스윗 공식몰', 26900, 24, 'bundle',
   'lalasweet-252', '얼리 썸머 4가지 골라담기',
   '같은 SKU를 4개 옵션으로 선택했을 때 · 6개입 4세트',
   'https://lalasweet.kr/product/detail.html?product_no=252', '2026-08-02T10:00:00+09:00'),
  ('0R7YJKKP96S6K', 'brand_mall', '라라스윗 공식몰', 26900, 24, 'bundle',
   'lalasweet-252', '얼리 썸머 4가지 골라담기',
   '같은 SKU를 4개 옵션으로 선택했을 때 · 6개입 4세트',
   'https://lalasweet.kr/product/detail.html?product_no=252', '2026-08-02T10:00:00+09:00'),
  ('0Q2MMCDAB4X67', 'brand_mall', '라라스윗 공식몰', 26900, 24, 'bundle',
   'lalasweet-252', '얼리 썸머 4가지 골라담기',
   '같은 SKU를 4개 옵션으로 선택했을 때 · 6개입 4세트',
   'https://lalasweet.kr/product/detail.html?product_no=252', '2026-08-02T10:00:00+09:00'),
  ('0DGPRV6MH432E', 'brand_mall', '라라스윗 공식몰', 26900, 16, 'bundle',
   'lalasweet-252', '얼리 썸머 4가지 골라담기',
   '같은 SKU를 4개 옵션으로 선택했을 때 · 4개입 4세트',
   'https://lalasweet.kr/product/detail.html?product_no=252', '2026-08-02T10:00:00+09:00'),
  ('0KUT9XKRU7X28', 'brand_mall', '라라스윗 공식몰', 26900, 16, 'bundle',
   'lalasweet-252', '얼리 썸머 4가지 골라담기',
   '같은 SKU를 4개 옵션으로 선택했을 때 · 4개입 4세트',
   'https://lalasweet.kr/product/detail.html?product_no=252', '2026-08-02T10:00:00+09:00'),
  ('0KUUNRPXQ6KYF', 'brand_mall', '라라스윗 공식몰', 26900, 16, 'bundle',
   'lalasweet-252', '얼리 썸머 4가지 골라담기',
   '같은 SKU를 4개 옵션으로 선택했을 때 · 4개입 4세트',
   'https://lalasweet.kr/product/detail.html?product_no=252', '2026-08-02T10:00:00+09:00'),
  ('028CRJXQGCK3P', 'brand_mall', '라라스윗 공식몰', 26900, 16, 'bundle',
   'lalasweet-252', '얼리 썸머 4가지 골라담기',
   '같은 SKU를 4개 옵션으로 선택했을 때 · 4개입 4세트',
   'https://lalasweet.kr/product/detail.html?product_no=252', '2026-08-02T10:00:00+09:00')
on conflict (product_id, offer_key) do update set
  price = excluded.price,
  unit_count = excluded.unit_count,
  promo_type = excluded.promo_type,
  offer_title = excluded.offer_title,
  offer_note = excluded.offer_note,
  link_url = excluded.link_url,
  is_active = true,
  fetched_at = excluded.fetched_at;

-- 할인특가 250: 제과 2세트 구매 후 추가할 수 있는 3개 2,970원 옵션.
insert into public.product_prices
  (product_id, channel, store, price, unit_count, promo_type,
   offer_key, offer_title, offer_note, link_url, fetched_at)
values
  ('0J74N7FN8M2N6', 'brand_mall', '라라스윗 공식몰', 2970, 3, 'sale',
   'lalasweet-250-addon', '제과 베스트 990원딜',
   '제과 2세트 구매 후 추가 옵션 선택 시 · 개당 990원',
   'https://lalasweet.kr/product/detail.html?product_no=250', '2026-08-02T10:00:00+09:00'),
  ('0PDZAJ48BK3UT', 'brand_mall', '라라스윗 공식몰', 2970, 3, 'sale',
   'lalasweet-250-addon', '제과 베스트 990원딜',
   '제과 2세트 구매 후 추가 옵션 선택 시 · 개당 990원',
   'https://lalasweet.kr/product/detail.html?product_no=250', '2026-08-02T10:00:00+09:00'),
  ('0WUN6AE4MZM3S', 'brand_mall', '라라스윗 공식몰', 2970, 3, 'sale',
   'lalasweet-250-addon', '제과 베스트 990원딜',
   '제과 2세트 구매 후 추가 옵션 선택 시 · 개당 990원',
   'https://lalasweet.kr/product/detail.html?product_no=250', '2026-08-02T10:00:00+09:00')
on conflict (product_id, offer_key) do update set
  price = excluded.price,
  unit_count = excluded.unit_count,
  promo_type = excluded.promo_type,
  offer_title = excluded.offer_title,
  offer_note = excluded.offer_note,
  link_url = excluded.link_url,
  is_active = true,
  fetched_at = excluded.fetched_at;

-- 할인특가 245: 파인트 3개 구매 후 추가할 수 있는 제로바/파인트 옵션.
insert into public.product_prices
  (product_id, channel, store, price, unit_count, promo_type,
   offer_key, offer_title, offer_note, link_url, fetched_at)
values
  ('097MPZMG249YX', 'brand_mall', '라라스윗 공식몰', 5940, 6, 'sale',
   'lalasweet-245-addon', '파인트 & 제로바 990원딜',
   '파인트 3개 구매 후 제로바 6개 추가 옵션 선택 시 · 개당 990원',
   'https://lalasweet.kr/product/detail.html?product_no=245', '2026-08-02T10:00:00+09:00'),
  ('0R7YJKKP96S6K', 'brand_mall', '라라스윗 공식몰', 5940, 6, 'sale',
   'lalasweet-245-addon', '파인트 & 제로바 990원딜',
   '파인트 3개 구매 후 제로바 6개 추가 옵션 선택 시 · 개당 990원',
   'https://lalasweet.kr/product/detail.html?product_no=245', '2026-08-02T10:00:00+09:00'),
  ('0Q2MMCDAB4X67', 'brand_mall', '라라스윗 공식몰', 5940, 6, 'sale',
   'lalasweet-245-addon', '파인트 & 제로바 990원딜',
   '파인트 3개 구매 후 제로바 6개 추가 옵션 선택 시 · 개당 990원',
   'https://lalasweet.kr/product/detail.html?product_no=245', '2026-08-02T10:00:00+09:00'),
  ('02JR494H5WRKQ', 'brand_mall', '라라스윗 공식몰', 990, 1, 'sale',
   'lalasweet-245-addon', '파인트 & 제로바 990원딜',
   '파인트 3개 구매 후 파인트 추가 옵션 선택 시 · 1개 990원',
   'https://lalasweet.kr/product/detail.html?product_no=245', '2026-08-02T10:00:00+09:00'),
  ('0WDRWPPT2QP9M', 'brand_mall', '라라스윗 공식몰', 990, 1, 'sale',
   'lalasweet-245-addon', '파인트 & 제로바 990원딜',
   '파인트 3개 구매 후 파인트 추가 옵션 선택 시 · 1개 990원',
   'https://lalasweet.kr/product/detail.html?product_no=245', '2026-08-02T10:00:00+09:00')
on conflict (product_id, offer_key) do update set
  price = excluded.price,
  unit_count = excluded.unit_count,
  promo_type = excluded.promo_type,
  offer_title = excluded.offer_title,
  offer_note = excluded.offer_note,
  link_url = excluded.link_url,
  is_active = true,
  fetched_at = excluded.fetched_at;
