-- 매장 대표 메뉴 (저당 메뉴 + 시그니처 메뉴)
--
-- 왜 필요한가: menu_board_reports 는 사진(image_url)만 담고, franchise_drinks 는
-- 커피 6개 브랜드 전용이라 개별 매장의 메뉴를 담을 자리가 없었다.
--
-- 원칙: 근거 없는 행을 막는다.
--   source_url·confidence 가 NOT NULL 이라 출처 없이는 INSERT 가 실패한다.
--   당류가 공개되지 않은 메뉴는 sugar_g 를 null 로 두고 앱에서 '정보 준비 중'으로 표시한다
--   (임의 추정값을 넣지 않는다).

CREATE TABLE public.store_menus (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,

  name text NOT NULL,
  -- low_sugar: 당류가 낮아 저당맵 관점에서 추천하는 메뉴
  -- signature: 매장/브랜드가 대표로 내세우는 메뉴 (당류와 무관)
  kind text NOT NULL CHECK (kind = ANY (ARRAY['low_sugar', 'signature'])),

  sugar_g numeric,            -- 미공개면 null
  calories numeric,           -- 미공개면 null
  price_won integer,          -- 미공개면 null
  serving text,               -- '160g', '1L' 등 기준량 (있을 때만)
  note text,                  -- '제로슈거 옵션 가능' 같은 한 줄 설명

  -- 근거. official = 브랜드 공식 영양성분표/메뉴판, menu_board = 매장 메뉴판 사진,
  -- estimated = 추정(앱에서 '추정' 배지 노출 대상)
  source_url text NOT NULL,
  confidence text NOT NULL CHECK (confidence = ANY (ARRAY[
    'official', 'menu_board', 'estimated'
  ])),

  sort_order smallint NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),

  -- 같은 매장에 같은 메뉴가 두 번 들어가지 않도록.
  UNIQUE (store_id, name)
);

-- 매장 상세를 열 때마다 store_id 로 조회하고 sort_order 로 정렬한다.
CREATE INDEX idx_store_menus_store ON public.store_menus(store_id, sort_order);

ALTER TABLE public.store_menus ENABLE ROW LEVEL SECURITY;

-- 읽기는 전체 공개(매장 정보와 동일 수준). 쓰기는 service_role 만.
CREATE POLICY "store_menus 공개 읽기"
  ON public.store_menus FOR SELECT
  USING (true);
