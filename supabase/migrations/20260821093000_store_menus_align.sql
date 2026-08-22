-- store_menus 스키마 정렬.
--
-- 테이블이 초안 스키마(serving·updated_at 없음)로 먼저 만들어져 있어
-- 정식 마이그레이션과 어긋났다. 이미 있는 환경에서도 안전하도록 IF NOT EXISTS 로 맞춘다.

ALTER TABLE public.store_menus
  ADD COLUMN IF NOT EXISTS serving text;

ALTER TABLE public.store_menus
  ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

-- 같은 매장에 같은 메뉴가 두 번 들어가지 않도록 (재적재 시 upsert 기준).
-- 제약 대신 유니크 인덱스로 만들어야 IF NOT EXISTS 로 반복 실행이 안전하다.
CREATE UNIQUE INDEX IF NOT EXISTS store_menus_store_name_uidx
  ON public.store_menus (store_id, name);

-- 읽기 정책. 테이블이 정책 없이 만들어졌으면 RLS 가 모든 행을 조용히 걸러내
-- SQL Editor 에선 보이는데 앱(anon)에선 0건이 된다.
ALTER TABLE public.store_menus ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "store_menus 공개 읽기" ON public.store_menus;
CREATE POLICY "store_menus 공개 읽기"
  ON public.store_menus FOR SELECT
  USING (true);

-- 쓰기는 service_role 만 (정책을 안 만들었으므로 anon/authenticated 는 INSERT 불가).
GRANT SELECT ON public.store_menus TO anon, authenticated;

COMMENT ON COLUMN public.store_menus.serving IS
  '영양성분의 기준량 (예: 160g, 1L). 공개된 값이 없으면 null.';
