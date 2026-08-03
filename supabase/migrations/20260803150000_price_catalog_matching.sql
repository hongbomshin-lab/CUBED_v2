-- 가격 카탈로그를 영양성분 products와 분리한다.
-- 자사몰에만 있는 SKU도 product_id 없이 저장하고 사진 분석 결과와 매칭할 수 있다.
alter table public.product_prices
  alter column product_id drop not null,
  add column if not exists catalog_product_key text,
  add column if not exists catalog_name text,
  add column if not exists brand text,
  add column if not exists aliases text[] not null default '{}',
  add column if not exists offer_kind text not null default 'standalone_bundle',
  add column if not exists minimum_order_amount integer;

alter table public.product_prices
  drop constraint if exists product_prices_offer_kind_check,
  add constraint product_prices_offer_kind_check
    check (offer_kind in ('regular', 'standalone_bundle', 'conditional_addon')),
  drop constraint if exists product_prices_minimum_order_amount_check,
  add constraint product_prices_minimum_order_amount_check
    check (minimum_order_amount is null or minimum_order_amount >= 0);

-- 기존 가격은 연결된 제품명으로 카탈로그 필드를 채운다.
update public.product_prices pp
set catalog_product_key = coalesce(pp.catalog_product_key, 'product:' || pp.product_id),
    catalog_name = coalesce(pp.catalog_name, p.name),
    brand = coalesce(pp.brand, p.brand),
    offer_kind = case
      when pp.promo_type = 'regular' then 'regular'
      when pp.offer_key like '%-addon' then 'conditional_addon'
      else 'standalone_bundle'
    end,
    minimum_order_amount = case
      when pp.offer_key = 'lalasweet-250-addon' then 34000
      when pp.offer_key = 'lalasweet-245-addon' then 35700
      else pp.minimum_order_amount
    end
from public.products p
where pp.product_id = p.product_id;

-- 등록된 라라스윗 SKU에는 자사몰 옵션과 동일한 안정적인 키와 별칭을 부여한다.
with mapping(product_id, catalog_product_key, catalog_name, aliases) as (
  values
    ('05T6YY762TB8B', 'lalasweet:deumppeuk-bar:strawberry', '라라스윗 저당 딸기 듬뿍바', array['저당 듬뿍바 딸기', '딸기 듬뿍바']),
    ('0PZK9WE3G83K9', 'lalasweet:yogurt-bar:apple-mango', '라라스윗 저당 애플망고 생요거트바', array['저당 생요거트바 애플망고', '애플망고 생요거트바']),
    ('097MPZMG249YX', 'lalasweet:zero-bar:gold-pine', '라라스윗 골드파인 제로바', array['골드파인 제로바']),
    ('0R7YJKKP96S6K', 'lalasweet:zero-bar:jeju-mandarin', '라라스윗 제주감귤 제로바', array['제주감귤 제로바']),
    ('0Q2MMCDAB4X67', 'lalasweet:zero-bar:grape', '라라스윗 포도 제로바', array['포도 제로바']),
    ('0DGPRV6MH432E', 'lalasweet:choco-bar:vanilla', '라라스윗 저당 바닐라 초코바', array['저당 바닐라초코바', '바닐라 초코바']),
    ('0KUT9XKRU7X28', 'lalasweet:choco-bar:chocolate', '라라스윗 저당 초콜릿 초코바', array['저당 초콜릿 초코바', '초콜릿 초코바']),
    ('0KUUNRPXQ6KYF', 'lalasweet:choco-bar:cookie-cream', '라라스윗 저당 쿠앤크 초코바', array['저당 쿠키앤크림 초코바', '쿠앤크 초코바']),
    ('028CRJXQGCK3P', 'lalasweet:monaka:fresh-milk', '라라스윗 저당 생우유 모나카', array['생우유 모나카', '저당 생우유 모나카']),
    ('0J74N7FN8M2N6', 'lalasweet:popcorn:corn-soup', '라라스윗 저당 콘스프맛 팝콘', array['저당 단짠 콘스프맛 팝콘', '콘스프맛 팝콘']),
    ('0PDZAJ48BK3UT', 'lalasweet:popcorn:choco', '라라스윗 저당 초코범벅 팝콘', array['저당 초코범벅 팝콘', '초코범벅 팝콘']),
    ('0WUN6AE4MZM3S', 'lalasweet:popcorn:caramel', '라라스윗 저당 카라멜 팝콘', array['저당 카라멜팝콘', '카라멜 팝콘']),
    ('02JR494H5WRKQ', 'lalasweet:pint:yogurt-peach', '라라스윗 생요거트 복숭아 파인트', array['저당 생요거트 복숭아', '생요거트 복숭아']),
    ('0WDRWPPT2QP9M', 'lalasweet:pint:yogurt-plain', '라라스윗 생요거트 플레인 파인트', array['저당 생요거트 플레인', '생요거트 플레인'])
)
update public.product_prices pp
set catalog_product_key = m.catalog_product_key,
    catalog_name = m.catalog_name,
    brand = '라라스윗',
    aliases = m.aliases
from mapping m
where pp.product_id = m.product_id;

alter table public.product_prices
  alter column catalog_product_key set not null,
  alter column catalog_name set not null;

drop index if exists public.product_prices_product_offer_key_idx;
create unique index if not exists product_prices_catalog_offer_idx
  on public.product_prices (store, catalog_product_key, offer_key);

-- 현재 할인특가 목록에서 내려간 이전 초코바 행사는 비활성화한다.
update public.product_prices
set is_active = false
where offer_key = 'lalasweet-249';

-- 기존 products에 없는 현재 라라스윗 공식몰 옵션도 가격 카탈로그에 저장한다.
insert into public.product_prices
  (product_id, catalog_product_key, catalog_name, brand, aliases,
   channel, store, price, unit_count, promo_type, offer_kind,
   minimum_order_amount, offer_key, offer_title, offer_note, link_url, fetched_at)
values
  -- product_no=252: 얼리 썸머 4가지 골라담기
  (null, 'lalasweet:yogurt-bar:strawberry', '라라스윗 저당 딸기 생요거트바', '라라스윗', array['딸기 생요거트바'],
   'brand_mall', '라라스윗 공식몰', 26900, 24, 'bundle', 'standalone_bundle', null,
   'lalasweet-252', '얼리 썸머 4가지 골라담기', '같은 SKU를 4개 옵션으로 선택했을 때 · 6개입 4세트',
   'https://lalasweet.kr/product/detail.html?product_no=252', now()),
  (null, 'lalasweet:yogurt-bar:peach', '라라스윗 저당 복숭아 생요거트바', '라라스윗', array['복숭아 생요거트바'],
   'brand_mall', '라라스윗 공식몰', 26900, 24, 'bundle', 'standalone_bundle', null,
   'lalasweet-252', '얼리 썸머 4가지 골라담기', '같은 SKU를 4개 옵션으로 선택했을 때 · 6개입 4세트',
   'https://lalasweet.kr/product/detail.html?product_no=252', now()),
  (null, 'lalasweet:zero-bar:plum', '라라스윗 자두 제로바', '라라스윗', array['자두맛 제로바'],
   'brand_mall', '라라스윗 공식몰', 26900, 24, 'bundle', 'standalone_bundle', null,
   'lalasweet-252', '얼리 썸머 4가지 골라담기', '같은 SKU를 4개 옵션으로 선택했을 때 · 6개입 4세트',
   'https://lalasweet.kr/product/detail.html?product_no=252', now()),

  -- product_no=250: 제과 2세트 구매 후 추가 가능한 990원딜
  (null, 'lalasweet:popcorn:chicken', '라라스윗 저당 닭강정맛 팝콘', '라라스윗', array['닭강정 팝콘'],
   'brand_mall', '라라스윗 공식몰', 2970, 3, 'sale', 'conditional_addon', 34000,
   'lalasweet-250-addon', '제과 베스트 990원딜', '제과 2세트 구매 후 추가 옵션 선택 시 · 개당 990원',
   'https://lalasweet.kr/product/detail.html?product_no=250', now()),
  (null, 'lalasweet:popcorn:toffee-nut', '라라스윗 저당 토피넛콘', '라라스윗', array['토피넛 팝콘', '토피넛콘'],
   'brand_mall', '라라스윗 공식몰', 2970, 3, 'sale', 'conditional_addon', 34000,
   'lalasweet-250-addon', '제과 베스트 990원딜', '제과 2세트 구매 후 추가 옵션 선택 시 · 개당 990원',
   'https://lalasweet.kr/product/detail.html?product_no=250', now()),

  -- product_no=245: 파인트 3개 구매 후 추가 가능한 제로바/파인트
  (null, 'lalasweet:zero-bar:plum', '라라스윗 자두 제로바', '라라스윗', array['자두맛 제로바'],
   'brand_mall', '라라스윗 공식몰', 5940, 6, 'sale', 'conditional_addon', 35700,
   'lalasweet-245-addon', '파인트 & 제로바 990원딜', '파인트 3개 구매 후 제로바 6개 추가 옵션 선택 시 · 개당 990원',
   'https://lalasweet.kr/product/detail.html?product_no=245', now()),
  (null, 'lalasweet:pint:yogurt-mango', '라라스윗 생요거트 망고 파인트', '라라스윗', array['생요거트 망고'],
   'brand_mall', '라라스윗 공식몰', 990, 1, 'sale', 'conditional_addon', 35700,
   'lalasweet-245-addon', '파인트 & 제로바 990원딜', '파인트 3개 구매 후 파인트 추가 옵션 선택 시 · 1개 990원',
   'https://lalasweet.kr/product/detail.html?product_no=245', now()),
  (null, 'lalasweet:pint:vanilla-bean', '라라스윗 바닐라빈 파인트', '라라스윗', array['바닐라빈'],
   'brand_mall', '라라스윗 공식몰', 990, 1, 'sale', 'conditional_addon', 35700,
   'lalasweet-245-addon', '파인트 & 제로바 990원딜', '파인트 3개 구매 후 파인트 추가 옵션 선택 시 · 1개 990원',
   'https://lalasweet.kr/product/detail.html?product_no=245', now()),
  (null, 'lalasweet:pint:chocolate', '라라스윗 초콜릿 파인트', '라라스윗', array['초콜릿 아이스크림 파인트'],
   'brand_mall', '라라스윗 공식몰', 990, 1, 'sale', 'conditional_addon', 35700,
   'lalasweet-245-addon', '파인트 & 제로바 990원딜', '파인트 3개 구매 후 파인트 추가 옵션 선택 시 · 1개 990원',
   'https://lalasweet.kr/product/detail.html?product_no=245', now()),
  (null, 'lalasweet:pint:cheesecake', '라라스윗 치즈케이크 파인트', '라라스윗', array['치즈케이크 아이스크림'],
   'brand_mall', '라라스윗 공식몰', 990, 1, 'sale', 'conditional_addon', 35700,
   'lalasweet-245-addon', '파인트 & 제로바 990원딜', '파인트 3개 구매 후 파인트 추가 옵션 선택 시 · 1개 990원',
   'https://lalasweet.kr/product/detail.html?product_no=245', now()),
  (null, 'lalasweet:pint:fresh-milk', '라라스윗 생우유 파인트', '라라스윗', array['생우유 아이스크림 파인트'],
   'brand_mall', '라라스윗 공식몰', 990, 1, 'sale', 'conditional_addon', 35700,
   'lalasweet-245-addon', '파인트 & 제로바 990원딜', '파인트 3개 구매 후 파인트 추가 옵션 선택 시 · 1개 990원',
   'https://lalasweet.kr/product/detail.html?product_no=245', now()),
  (null, 'lalasweet:pint:apple-mint', '라라스윗 애플민트 파인트', '라라스윗', array['애플민트 아이스크림'],
   'brand_mall', '라라스윗 공식몰', 990, 1, 'sale', 'conditional_addon', 35700,
   'lalasweet-245-addon', '파인트 & 제로바 990원딜', '파인트 3개 구매 후 파인트 추가 옵션 선택 시 · 1개 990원',
   'https://lalasweet.kr/product/detail.html?product_no=245', now()),
  (null, 'lalasweet:pint:orange-berry', '라라스윗 오렌지앤베리 파인트', '라라스윗', array['오렌지앤베리 아이스크림'],
   'brand_mall', '라라스윗 공식몰', 990, 1, 'sale', 'conditional_addon', 35700,
   'lalasweet-245-addon', '파인트 & 제로바 990원딜', '파인트 3개 구매 후 파인트 추가 옵션 선택 시 · 1개 990원',
   'https://lalasweet.kr/product/detail.html?product_no=245', now()),
  (null, 'lalasweet:pint:matcha', '라라스윗 말차 파인트', '라라스윗', array['말차 아이스크림'],
   'brand_mall', '라라스윗 공식몰', 990, 1, 'sale', 'conditional_addon', 35700,
   'lalasweet-245-addon', '파인트 & 제로바 990원딜', '파인트 3개 구매 후 파인트 추가 옵션 선택 시 · 1개 990원',
   'https://lalasweet.kr/product/detail.html?product_no=245', now()),
  (null, 'lalasweet:pint:gold-kiwi-pine', '라라스윗 골드키위파인셔벗 파인트', '라라스윗', array['골드키위파인셔벗', '골드키위 파인 셔벗'],
   'brand_mall', '라라스윗 공식몰', 990, 1, 'sale', 'conditional_addon', 35700,
   'lalasweet-245-addon', '파인트 & 제로바 990원딜', '파인트 3개 구매 후 파인트 추가 옵션 선택 시 · 1개 990원',
   'https://lalasweet.kr/product/detail.html?product_no=245', now()),

  -- product_no=238: 단백질 쉐이크 1세트(7개입)
  (null, 'lalasweet:protein-shake:choco-crunch', '라라스윗 단백질 쉐이크 초코 크런치', '라라스윗', array['초코 크런치 쉐이크'],
   'brand_mall', '라라스윗 공식몰', 23800, 7, 'bundle', 'standalone_bundle', null,
   'lalasweet-238', '단백질 쉐이크 앵콜 특가', '1세트 선택 시 · 7개입',
   'https://lalasweet.kr/product/detail.html?product_no=238', now()),
  (null, 'lalasweet:protein-shake:grain-crunch', '라라스윗 단백질 쉐이크 곡물 크런치', '라라스윗', array['곡물 크런치 쉐이크'],
   'brand_mall', '라라스윗 공식몰', 23800, 7, 'bundle', 'standalone_bundle', null,
   'lalasweet-238', '단백질 쉐이크 앵콜 특가', '1세트 선택 시 · 7개입',
   'https://lalasweet.kr/product/detail.html?product_no=238', now())
on conflict (store, catalog_product_key, offer_key) do update set
  catalog_name = excluded.catalog_name,
  brand = excluded.brand,
  aliases = excluded.aliases,
  price = excluded.price,
  unit_count = excluded.unit_count,
  promo_type = excluded.promo_type,
  offer_kind = excluded.offer_kind,
  minimum_order_amount = excluded.minimum_order_amount,
  offer_title = excluded.offer_title,
  offer_note = excluded.offer_note,
  link_url = excluded.link_url,
  is_active = true,
  fetched_at = excluded.fetched_at;
