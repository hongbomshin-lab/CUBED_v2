-- store_menus 스키마 정렬.
--
-- 테이블이 초안 스키마(serving·updated_at 없음)로 먼저 만들어져 있어
-- 정식 마이그레이션과 어긋났다. 이미 있는 환경에서도 안전하도록 IF NOT EXISTS 로 맞춘다.

ALTER TABLE public.store_menus
  ADD COLUMN IF NOT EXISTS serving text;

ALTER TABLE public.store_menus
  ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

COMMENT ON COLUMN public.store_menus.serving IS
  '영양성분의 기준량 (예: 160g, 1L). 공개된 값이 없으면 null.';
