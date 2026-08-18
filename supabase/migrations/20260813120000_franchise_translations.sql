-- ============================================================
-- 프랜차이즈 메뉴 다국어 번역 (en / ja / zh)
-- 설계: 메뉴 ID 가 아닌 "한국어 원문 텍스트"를 키로 사용.
--   · 같은 이름(아메리카노 등)은 브랜드 무관 1회만 번역
--   · 크롤 재적재로 franchise_drinks 행이 갈려도 번역은 영향 없음
--   · menu 의 source = 앱 그룹핑 기준인 base 메뉴명
--     (name_clean 에서 아이스/따뜻한/핫 접두어와 "(ICED)" 를 제거한 것)
-- 채우는 경로:
--   ① 이 마이그레이션의 brand/size 시드(수작업 검수본)
--   ② scripts/output/franchise_i18n_en_seed.sql (원본 CSV name_en 유래)
--   ③ translate-franchise Edge Function (Gemini 배치 — 나머지 자동 번역)
-- ============================================================

create table if not exists public.franchise_translations (
  kind        text not null check (kind in ('menu', 'brand', 'size', 'category')),
  source      text not null,                       -- 한국어 원문
  lang        text not null check (lang in ('en', 'ja', 'zh')),
  value       text not null,
  is_reviewed boolean not null default false,      -- 수작업 검수 여부(기계번역=false)
  updated_at  timestamptz not null default now(),
  primary key (kind, source, lang)
);

-- 언어별 일괄 로드(앱이 선택 언어의 맵을 통째로 캐시)용 인덱스
create index if not exists idx_franchise_tr_lang on public.franchise_translations (lang, kind);

alter table public.franchise_translations enable row level security;

drop policy if exists "franchise_translations 읽기" on public.franchise_translations;
create policy "franchise_translations 읽기" on public.franchise_translations
  for select using (true);
-- 쓰기 정책 없음 = service_role(Edge Function·대시보드)만 가능

-- ------------------------------------------------------------
-- base 메뉴명 계산 — 앱의 FranchiseDrink.parseTemp 와 동일 규칙이어야 한다.
--   아이스/따뜻한/핫 접두어 제거 + "(ICED)" 제거. 결과가 비면 원문 유지.
-- ------------------------------------------------------------
create or replace function public.franchise_base_name(p_name_clean text)
returns text
language sql
immutable
as $$
  select coalesce(
    nullif(
      btrim(
        regexp_replace(
          regexp_replace(btrim(p_name_clean), '^(아이스|따뜻한|핫)\s*', ''),
          '\s*\(ICED\)', '', 'gi'
        )
      ),
      ''
    ),
    btrim(p_name_clean)
  );
$$;

-- 번역 대상 메뉴명 목록(중복 제거) — 크롤로 데이터가 바뀌면 자동 반영
create or replace view public.franchise_menu_names as
select distinct public.franchise_base_name(coalesce(name_clean, name)) as source
from public.franchise_drinks;

-- 아직 번역 안 된 (메뉴명 × 언어) 조합 — translate-franchise 함수가 이걸 채운다
create or replace view public.franchise_translation_todo as
select n.source, l.lang
from public.franchise_menu_names n
cross join (values ('en'), ('ja'), ('zh')) as l(lang)
where not exists (
  select 1 from public.franchise_translations t
  where t.kind = 'menu' and t.source = n.source and t.lang = l.lang
);

-- ------------------------------------------------------------
-- 시드 ①: 브랜드명 (공식 표기 기준, 검수본)
--   ja/zh 도 라틴 브랜드명 관행 유지(스타벅스만 현지 공식 표기 존재)
-- ------------------------------------------------------------
insert into public.franchise_translations (kind, source, lang, value, is_reviewed) values
  ('brand', '스타벅스',     'en', 'Starbucks',        true),
  ('brand', '스타벅스',     'ja', 'スターバックス',    true),
  ('brand', '스타벅스',     'zh', '星巴克',            true),
  ('brand', '메가커피',     'en', 'MEGA COFFEE',      true),
  ('brand', '메가커피',     'ja', 'MEGA COFFEE',      true),
  ('brand', '메가커피',     'zh', 'MEGA COFFEE',      true),
  ('brand', '컴포즈커피',   'en', 'COMPOSE COFFEE',   true),
  ('brand', '컴포즈커피',   'ja', 'COMPOSE COFFEE',   true),
  ('brand', '컴포즈커피',   'zh', 'COMPOSE COFFEE',   true),
  ('brand', '빽다방',       'en', "PAIK'S COFFEE",    true),
  ('brand', '빽다방',       'ja', "PAIK'S COFFEE",    true),
  ('brand', '빽다방',       'zh', "PAIK'S COFFEE",    true),
  ('brand', '이디야',       'en', 'EDIYA COFFEE',     true),
  ('brand', '이디야',       'ja', 'EDIYA COFFEE',     true),
  ('brand', '이디야',       'zh', 'EDIYA COFFEE',     true),
  ('brand', '투썸플레이스', 'en', 'A TWOSOME PLACE',  true),
  ('brand', '투썸플레이스', 'ja', 'A TWOSOME PLACE',  true),
  ('brand', '투썸플레이스', 'zh', 'A TWOSOME PLACE',  true)
on conflict (kind, source, lang) do update
  set value = excluded.value, is_reviewed = excluded.is_reviewed, updated_at = now();

-- ------------------------------------------------------------
-- 시드 ②: 사이즈 표기 (데이터에 실존하는 값 기준, 검수본)
-- ------------------------------------------------------------
-- 2026-08-13 기준 franchise_drinks 에 실존하는 15종 전부.
insert into public.franchise_translations (kind, source, lang, value, is_reviewed) values
  ('size', 'Tall',           'en', 'Tall',             true),
  ('size', 'Tall',           'ja', 'トール',            true),
  ('size', 'Tall',           'zh', '中杯',              true),
  ('size', 'Grande',         'en', 'Grande',           true),
  ('size', 'Grande',         'ja', 'グランデ',          true),
  ('size', 'Grande',         'zh', '大杯',              true),
  ('size', 'Short',          'en', 'Short',            true),
  ('size', 'Short',          'ja', 'ショート',          true),
  ('size', 'Short',          'zh', '小杯',              true),
  ('size', 'Solo',           'en', 'Solo',             true),
  ('size', 'Solo',           'ja', 'ソロ',              true),
  ('size', 'Solo',           'zh', '单份',              true),
  ('size', 'Trenta(트렌타)',  'en', 'Trenta',           true),
  ('size', 'Trenta(트렌타)',  'ja', 'トレンタ',          true),
  ('size', 'Trenta(트렌타)',  'zh', 'Trenta',           true),
  ('size', 'Bottle(보틀)',    'en', 'Bottle',           true),
  ('size', 'Bottle(보틀)',    'ja', 'ボトル',            true),
  ('size', 'Bottle(보틀)',    'zh', '瓶装',              true),
  ('size', 'L',              'en', 'L',                true),
  ('size', 'L',              'ja', 'L',                true),
  ('size', 'L',              'zh', 'L',                true),
  ('size', 'EX',             'en', 'EX',               true),
  ('size', 'EX',             'ja', 'EX',               true),
  ('size', 'EX',             'zh', 'EX',               true),
  ('size', '아이스 레귤러',   'en', 'Iced Regular',     true),
  ('size', '아이스 레귤러',   'ja', 'アイス レギュラー',  true),
  ('size', '아이스 레귤러',   'zh', '冰 标准杯',         true),
  ('size', '아이스 맥스',     'en', 'Iced Max',         true),
  ('size', '아이스 맥스',     'ja', 'アイス マックス',    true),
  ('size', '아이스 맥스',     'zh', '冰 特大杯',         true),
  ('size', '아이스 라지',     'en', 'Iced Large',       true),
  ('size', '아이스 라지',     'ja', 'アイス ラージ',      true),
  ('size', '아이스 라지',     'zh', '冰 大杯',           true),
  ('size', '병',             'en', 'Bottle',           true),
  ('size', '병',             'ja', 'ボトル',            true),
  ('size', '병',             'zh', '瓶装',              true),
  ('size', '컵',             'en', 'Cup',              true),
  ('size', '컵',             'ja', 'カップ',            true),
  ('size', '컵',             'zh', '杯装',              true),
  ('size', '콘',             'en', 'Cone',             true),
  ('size', '콘',             'ja', 'コーン',            true),
  ('size', '콘',             'zh', '甜筒',              true)
on conflict (kind, source, lang) do update
  set value = excluded.value, is_reviewed = excluded.is_reviewed, updated_at = now();

-- ------------------------------------------------------------
-- 시드 ③: 카테고리 (앱 필터 칩 라벨. franchise 화면 정렬/필터에 사용)
-- ------------------------------------------------------------
insert into public.franchise_translations (kind, source, lang, value, is_reviewed) values
  ('category', '아이스크림',   'en', 'Ice Cream',   true),
  ('category', '아이스크림',   'ja', 'アイスクリーム', true),
  ('category', '아이스크림',   'zh', '冰淇淋',       true),
  ('category', '빵',          'en', 'Bread',       true),
  ('category', '빵',          'ja', 'パン',         true),
  ('category', '빵',          'zh', '面包',         true),
  ('category', '디저트',       'en', 'Dessert',     true),
  ('category', '디저트',       'ja', 'デザート',      true),
  ('category', '디저트',       'zh', '甜点',         true),
  ('category', '과자',        'en', 'Snacks',      true),
  ('category', '과자',        'ja', 'お菓子',        true),
  ('category', '과자',        'zh', '零食',         true),
  ('category', '음료',        'en', 'Drinks',      true),
  ('category', '음료',        'ja', 'ドリンク',      true),
  ('category', '음료',        'zh', '饮料',         true)
on conflict (kind, source, lang) do update
  set value = excluded.value, is_reviewed = excluded.is_reviewed, updated_at = now();
