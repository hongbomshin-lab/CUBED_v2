-- ============================================================
-- 0006. 프랜차이즈 음료 당류/영양 정보 (franchise_drinks)
-- 스타벅스/메가/컴포즈/빽다방/이디야/투썸 음료 데이터.
-- 데이터 적재는 scripts/output/franchise_drinks_seed.sql (자동 생성)로 별도 실행.
--   → 이 마이그레이션(테이블 생성) 먼저 실행 후 seed 실행.
-- ============================================================

CREATE TABLE public.franchise_drinks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  brand text NOT NULL,
  category text,
  name text NOT NULL,
  name_clean text NOT NULL,      -- 사이즈 토큰 제거한 순수 메뉴명(검색/대표 노출용)
  size text,                     -- Tall / L / 아이스 레귤러 등
  volume_ml integer,
  calories numeric,
  sugar_g numeric,
  -- 각설탕 환산(1개 ≈ 3.3g). 생성컬럼이라 seed에 넣지 않는다.
  sugar_cubes numeric GENERATED ALWAYS AS (sugar_g / 3.3) STORED,
  carbs_g numeric,
  protein_g numeric,
  fat_g numeric,
  sodium_mg numeric,
  caffeine_mg numeric,
  has_zero_option boolean DEFAULT false,
  alt_sweetener text,
  confidence text,
  source_url text,
  created_at timestamptz DEFAULT now()
);

-- 검색(name_clean/name 부분일치)·브랜드 필터·당류 정렬용 인덱스.
CREATE INDEX idx_franchise_brand ON public.franchise_drinks(brand);
CREATE INDEX idx_franchise_name_clean ON public.franchise_drinks(name_clean);
CREATE INDEX idx_franchise_sugar ON public.franchise_drinks(sugar_g);

-- 공개 읽기 전용(누구나 조회, 쓰기는 대시보드/서비스롤만).
ALTER TABLE public.franchise_drinks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "franchise 읽기" ON public.franchise_drinks
  FOR SELECT USING (true);
