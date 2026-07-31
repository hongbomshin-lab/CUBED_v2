-- 제품별 채널 가격. 원시 가격만 저장하고 개당가·할인율·해석은 앱에서 계산한다.
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

create index product_prices_product_active_idx
  on public.product_prices (product_id, is_active, fetched_at desc);
create index product_prices_deals_idx
  on public.product_prices (is_active, promo_type, fetched_at desc);

alter table public.product_prices enable row level security;
create policy "public read active product prices" on public.product_prices
  for select to anon, authenticated
  using (is_active = true);

-- 2026-07-31 라라스윗 공식몰 확인값.
-- 정가 근거: 저당 초코바 12개 39,600원(개당 3,300원).
-- 묶음 근거: 저당 초코바 2박스, 박스당 4개, 총 20,900원(총 8개).
-- https://lalasweet.kr/product/detail.html?product_no=249
insert into public.product_prices
  (product_id, channel, store, price, unit_count, promo_type, link_url, fetched_at)
values
  ('0DGPRV6MH432E', 'brand_mall', '정가', 3300, 1, 'regular', null, '2026-07-31T12:00:00+09:00'),
  ('0DGPRV6MH432E', 'brand_mall', '라라스윗 공식몰', 20900, 8, 'bundle',
    'https://lalasweet.kr/product/detail.html?product_no=249', '2026-07-31T12:00:00+09:00'),
  ('0KUT9XKRU7X28', 'brand_mall', '정가', 3300, 1, 'regular', null, '2026-07-31T12:00:00+09:00'),
  ('0KUT9XKRU7X28', 'brand_mall', '라라스윗 공식몰', 20900, 8, 'bundle',
    'https://lalasweet.kr/product/detail.html?product_no=249', '2026-07-31T12:00:00+09:00'),
  ('0KUUNRPXQ6KYF', 'brand_mall', '정가', 3300, 1, 'regular', null, '2026-07-31T12:00:00+09:00'),
  ('0KUUNRPXQ6KYF', 'brand_mall', '라라스윗 공식몰', 20900, 8, 'bundle',
    'https://lalasweet.kr/product/detail.html?product_no=249', '2026-07-31T12:00:00+09:00')
on conflict (product_id, channel, store, promo_type) do update set
  price = excluded.price,
  unit_count = excluded.unit_count,
  link_url = excluded.link_url,
  is_active = true,
  fetched_at = excluded.fetched_at;

