-- ============================================================
-- 0007. 브랜드 특가 수집 스키마 (라라스윗·널담)
-- 3층 구조: raw snapshot / current state / price history
-- 기존 hot_deals(0001) 은 건드리지 않는다. 크롤러 전용 신규 테이블.
-- 데이터는 Edge Function crawl-deals 가 service_role 로 apply_crawl_result 호출해 채운다.
-- ============================================================

create extension if not exists pgcrypto;

-- ------------------------------------------------------------
-- 브랜드 마스터
-- ------------------------------------------------------------
create table if not exists crawl_brands (
  slug          text primary key,              -- 'lalasweet', 'nuldam'
  display_name  text not null,
  base_url      text not null,
  platform      text not null,                 -- 'cafe24'
  is_active     boolean not null default true,
  created_at    timestamptz not null default now()
);

insert into crawl_brands (slug, display_name, base_url, platform) values
  ('lalasweet', '라라스윗', 'https://lalasweet.kr', 'cafe24'),
  ('nuldam',    '널담',     'https://nuldam.com',   'cafe24'),
  ('mynormal',  '마이노멀', 'https://mynormal.shop', 'imweb')
on conflict (slug) do nothing;

-- ------------------------------------------------------------
-- 1층: 원본 스냅샷
--   파싱 로직이 바뀌어도 과거 데이터를 재처리할 수 있게 원형 보관.
--   raw_hash 가 직전과 같으면 append 하지 않음(용량 절약).
-- ------------------------------------------------------------
create table if not exists deal_snapshots (
  id           bigserial primary key,
  brand_slug   text not null references crawl_brands(slug),
  source_url   text not null,
  raw_hash     text not null,
  raw_payload  jsonb not null,
  crawled_at   timestamptz not null default now()
);

create index if not exists idx_snapshots_brand_time
  on deal_snapshots (brand_slug, crawled_at desc);

-- ------------------------------------------------------------
-- 2층: 현재 상태 (앱이 읽는 테이블)
-- ------------------------------------------------------------
create table if not exists brand_deals (
  id             uuid primary key default gen_random_uuid(),
  brand_slug     text not null references crawl_brands(slug),
  external_id    text not null,                -- 카페24 product_no
  name           text not null,
  summary        text,                         -- 상품요약정보
  list_price     integer,                      -- 판매가(할인 전)
  sale_price     integer not null,             -- 실제 결제가
  discount_rate  numeric(5,1)
    generated always as (
      case when list_price is not null and list_price > 0 and sale_price < list_price
           then round((1 - sale_price::numeric / list_price) * 100, 1)
           else 0 end
    ) stored,
  product_url    text not null,
  image_url      text,
  category       text,                         -- 아이스크림/빵/디저트/과자/음료/단백바/기타 (상품명 기반 분류)
  is_soldout     boolean not null default false,
  is_deal        boolean not null default false,
  deal_signals   text[] not null default '{}', -- {'category','title_tag','price_diff'}
  first_seen_at  timestamptz not null default now(),
  last_seen_at   timestamptz not null default now(),
  ended_at       timestamptz,                  -- soft delete. 절대 물리 삭제 금지
  constraint brand_deals_unique unique (brand_slug, external_id)
);

create index if not exists idx_deals_active
  on brand_deals (brand_slug, discount_rate desc)
  where ended_at is null and is_deal;

-- ------------------------------------------------------------
-- 3층: 가격 이력 (변동 있을때만 append)
--   저당맵의 진짜 자산. 브랜드 쇼핑몰도 공개하지 않는 데이터.
-- ------------------------------------------------------------
create table if not exists deal_price_history (
  id          bigserial primary key,
  deal_id     uuid not null references brand_deals(id) on delete cascade,
  list_price  integer,
  sale_price  integer not null,
  is_soldout  boolean not null default false,
  observed_at timestamptz not null default now()
);

create index if not exists idx_history_deal_time
  on deal_price_history (deal_id, observed_at desc);

-- 역대 최저가 조회용 뷰 ("역대 최저가!" 배지)
create or replace view deal_price_stats as
select
  d.id            as deal_id,
  d.brand_slug,
  d.name,
  d.sale_price    as current_price,
  min(h.sale_price) as all_time_low,
  max(h.sale_price) as all_time_high,
  count(*)          as observation_count,
  (d.sale_price <= min(h.sale_price)) as is_all_time_low
from brand_deals d
join deal_price_history h on h.deal_id = d.id
where d.ended_at is null
group by d.id, d.brand_slug, d.name, d.sale_price;

-- ------------------------------------------------------------
-- 실행 로그 (조용한 고장 추적용)
-- ------------------------------------------------------------
create table if not exists crawl_runs (
  id             bigserial primary key,
  brand_slug     text not null,
  status         text not null,                -- 'ok' | 'aborted' | 'error'
  parsed_count   integer not null default 0,
  deal_count     integer not null default 0,
  prev_count     integer,
  error_message  text,
  duration_ms    integer,
  started_at     timestamptz not null default now()
);

create index if not exists idx_runs_brand_time
  on crawl_runs (brand_slug, started_at desc);

-- ------------------------------------------------------------
-- RLS: 공개 읽기 / 쓰기는 service_role 만
-- ------------------------------------------------------------
alter table brand_deals         enable row level security;
alter table deal_price_history  enable row level security;
alter table crawl_brands        enable row level security;
alter table deal_snapshots      enable row level security;
alter table crawl_runs          enable row level security;

drop policy if exists "public read active deals" on brand_deals;
create policy "public read active deals" on brand_deals
  for select using (true);

drop policy if exists "public read price history" on deal_price_history;
create policy "public read price history" on deal_price_history
  for select using (true);

drop policy if exists "public read brands" on crawl_brands;
create policy "public read brands" on crawl_brands
  for select using (true);

-- deal_snapshots / crawl_runs 는 정책 없음 = service_role 만 접근

-- ------------------------------------------------------------
-- upsert RPC: 한 브랜드 결과를 원자적으로 반영
--   p_items: [{external_id,name,summary,list_price,sale_price,
--              product_url,image_url,is_soldout,is_deal,deal_signals}]
-- ------------------------------------------------------------
create or replace function apply_crawl_result(
  p_brand_slug text,
  p_items      jsonb
)
returns table (inserted int, updated int, ended int, price_changed int)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inserted int := 0;
  v_updated  int := 0;
  v_ended    int := 0;
  v_changed  int := 0;
  v_seen     text[];
  it         jsonb;
  v_deal_id  uuid;
  v_prev_sale int;
  v_prev_list int;
  v_is_new   boolean;
begin
  select coalesce(array_agg(x->>'external_id'), '{}')
    into v_seen
  from jsonb_array_elements(p_items) x;

  for it in select * from jsonb_array_elements(p_items)
  loop
    select id, sale_price, list_price
      into v_deal_id, v_prev_sale, v_prev_list
    from brand_deals
    where brand_slug = p_brand_slug
      and external_id = it->>'external_id';

    v_is_new := v_deal_id is null;

    insert into brand_deals (
      brand_slug, external_id, name, summary, list_price, sale_price,
      product_url, image_url, category, is_soldout, is_deal, deal_signals, last_seen_at, ended_at
    ) values (
      p_brand_slug,
      it->>'external_id',
      it->>'name',
      nullif(it->>'summary', ''),
      nullif(it->>'list_price', '')::int,
      (it->>'sale_price')::int,
      it->>'product_url',
      nullif(it->>'image_url', ''),
      nullif(it->>'category', ''),
      coalesce((it->>'is_soldout')::boolean, false),
      coalesce((it->>'is_deal')::boolean, false),
      coalesce(
        (select array_agg(v::text) from jsonb_array_elements_text(it->'deal_signals') v),
        '{}'
      ),
      now(),
      null                              -- 재등장 시 종료 해제
    )
    on conflict (brand_slug, external_id) do update set
      name         = excluded.name,
      summary      = excluded.summary,
      list_price   = excluded.list_price,
      sale_price   = excluded.sale_price,
      product_url  = excluded.product_url,
      image_url    = coalesce(excluded.image_url, brand_deals.image_url),
      category     = excluded.category,
      is_soldout   = excluded.is_soldout,
      is_deal      = excluded.is_deal,
      deal_signals = excluded.deal_signals,
      last_seen_at = now(),
      ended_at     = null
    returning id into v_deal_id;

    if v_is_new then
      v_inserted := v_inserted + 1;
    else
      v_updated := v_updated + 1;
    end if;

    -- 가격이 바뀐 경우에만 이력 append (최초 관측은 항상 기록)
    if v_is_new
       or v_prev_sale is distinct from (it->>'sale_price')::int
       or v_prev_list is distinct from nullif(it->>'list_price', '')::int
    then
      insert into deal_price_history (deal_id, list_price, sale_price, is_soldout)
      values (
        v_deal_id,
        nullif(it->>'list_price', '')::int,
        (it->>'sale_price')::int,
        coalesce((it->>'is_soldout')::boolean, false)
      );
      if not v_is_new then
        v_changed := v_changed + 1;
      end if;
    end if;
  end loop;

  -- 이번 크롤에 없는 상품 = 종료 처리 (물리 삭제 안함)
  update brand_deals
     set ended_at = now()
   where brand_slug = p_brand_slug
     and ended_at is null
     and not (external_id = any(v_seen));
  get diagnostics v_ended = row_count;

  return query select v_inserted, v_updated, v_ended, v_changed;
end;
$$;

-- 보안: security definer 함수라 EXECUTE 를 열어두면 anon/authenticated 가
-- PostgREST RPC 로 임의 딜을 주입할 수 있다. service_role(Edge Function) 만 허용.
revoke execute on function apply_crawl_result(text, jsonb) from public;
revoke execute on function apply_crawl_result(text, jsonb) from anon, authenticated;
grant  execute on function apply_crawl_result(text, jsonb) to service_role;
