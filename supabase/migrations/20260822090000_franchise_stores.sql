-- 저당맵에 프랜차이즈 카페 매장 추가.
--
-- 별도 테이블을 만들지 않고 stores 에 합친다 — 매장 상세·즐겨찾기·리뷰·다국어를
-- 그대로 재사용할 수 있고, 지도 토글은 store_type 필터 하나로 끝난다.

-- store_type 에 'franchise' 추가.
ALTER TABLE public.stores
  DROP CONSTRAINT IF EXISTS stores_store_type_check;
ALTER TABLE public.stores
  ADD CONSTRAINT stores_store_type_check
  CHECK (store_type = ANY (ARRAY[
    'cafe', 'restaurant', 'zero_store', 'delivery', 'franchise'
  ]));

-- 프랜차이즈 브랜드. franchise_drinks.brand 와 같은 값이어야
-- 매장 상세에서 그 브랜드의 저당 메뉴를 이어 붙일 수 있다.
-- (저당 전문 매장은 null)
ALTER TABLE public.stores
  ADD COLUMN IF NOT EXISTS brand text;

COMMENT ON COLUMN public.stores.brand IS
  '프랜차이즈 브랜드명. franchise_drinks.brand 와 조인해 저당 메뉴를 추천한다. 저당 전문 매장은 null.';

-- 지도에서 '프랜차이즈만' 또는 '프랜차이즈 제외'로 자주 거르므로 인덱스를 둔다.
CREATE INDEX IF NOT EXISTS idx_stores_brand ON public.stores(brand)
  WHERE brand IS NOT NULL;
