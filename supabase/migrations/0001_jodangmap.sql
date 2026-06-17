-- 저당맵(Jodangmap) 스키마 — Step 1
-- Supabase SQL Editor에서 위에서부터 순서대로 실행한다.
-- (이 파일은 레포 추적용. 실제 적용은 SQL Editor 또는 supabase db push.)

-- ============================================================
-- 1-1. Extensions
-- ============================================================
CREATE EXTENSION IF NOT EXISTS postgis;

-- NOTE: profiles 테이블은 이 단계에서 만들지 않는다.
--   원본 스펙의 "... 관리자" RLS 정책만 profiles.is_admin 을 참조하는데,
--   - 매장/사진 자동 생성은 승인 트리거(SECURITY DEFINER)가 처리하고
--   - 제보 승인/핫딜 등록 등 운영 작업은 대시보드 service_role(=RLS 우회)로 처리한다.
--   따라서 아래 1-8에서는 관리자 정책을 제외하고 사용자 정책만 둔다.
--   추후 앱 내 관리자 UI가 필요해지면 profiles + is_admin + 관리자 정책을 추가한다.

-- ============================================================
-- 1-2. stores
-- ============================================================
CREATE TABLE public.stores (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  address text NOT NULL,
  lat double precision NOT NULL,
  lng double precision NOT NULL,
  phone text,
  instagram_url text,
  naver_place_url text,
  naver_place_id text UNIQUE,
  store_type text NOT NULL CHECK (store_type = ANY (ARRAY[
    'cafe', 'restaurant', 'zero_store', 'delivery'
  ])),
  geom geometry(Point, 4326) GENERATED ALWAYS AS (
    ST_SetSRID(ST_MakePoint(lng, lat), 4326)
  ) STORED,
  district text,
  hours text,
  is_active boolean DEFAULT true,
  review_count integer DEFAULT 0,
  recommend_count integer DEFAULT 0,
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
CREATE INDEX idx_stores_geom ON public.stores USING GIST(geom);
CREATE INDEX idx_stores_type ON public.stores(store_type);
CREATE INDEX idx_stores_active ON public.stores(is_active);

-- ============================================================
-- 1-3. store_photos
-- ============================================================
CREATE TABLE public.store_photos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  photo_type text NOT NULL CHECK (photo_type = ANY (ARRAY[
    'exterior', 'interior', 'product', 'menu_board'
  ])),
  image_url text NOT NULL,
  is_primary boolean DEFAULT false,
  sort_order integer DEFAULT 0,
  uploaded_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now()
);

-- ============================================================
-- 1-4. store_reviews (+ 카운트 트리거)
-- ============================================================
CREATE TABLE public.store_reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  is_recommended boolean NOT NULL,
  content text CHECK (char_length(content) <= 500),
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE (store_id, user_id)
);

CREATE OR REPLACE FUNCTION update_store_review_counts()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.stores SET
      review_count = review_count + 1,
      recommend_count = recommend_count + CASE WHEN NEW.is_recommended THEN 1 ELSE 0 END
    WHERE id = NEW.store_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.stores SET
      review_count = review_count - 1,
      recommend_count = recommend_count - CASE WHEN OLD.is_recommended THEN 1 ELSE 0 END
    WHERE id = OLD.store_id;
  ELSIF TG_OP = 'UPDATE' THEN
    IF OLD.is_recommended != NEW.is_recommended THEN
      UPDATE public.stores SET
        recommend_count = recommend_count
          + CASE WHEN NEW.is_recommended THEN 1 ELSE -1 END
      WHERE id = NEW.store_id;
    END IF;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER trg_store_review_counts
  AFTER INSERT OR UPDATE OR DELETE ON public.store_reviews
  FOR EACH ROW EXECUTE FUNCTION update_store_review_counts();

-- ============================================================
-- 1-5. menu_board_reports (+ 승인 시 store_photos 자동 등록)
-- ============================================================
CREATE TABLE public.menu_board_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  reported_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  image_url text NOT NULL,
  note text,
  status text NOT NULL DEFAULT 'pending' CHECK (status = ANY (ARRAY[
    'pending', 'approved', 'rejected'
  ])),
  admin_memo text,
  reviewed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewed_at timestamptz,
  created_at timestamptz DEFAULT now()
);

CREATE OR REPLACE FUNCTION handle_menu_board_approved()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'approved' AND OLD.status != 'approved' THEN
    INSERT INTO public.store_photos (store_id, photo_type, image_url, uploaded_by)
    VALUES (NEW.store_id, 'menu_board', NEW.image_url, NEW.reported_by);
    NEW.reviewed_at := now();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER trg_menu_board_approved
  BEFORE UPDATE OF status ON public.menu_board_reports
  FOR EACH ROW EXECUTE FUNCTION handle_menu_board_approved();

-- ============================================================
-- 1-6. store_reports (+ 승인 시 stores 자동 생성)
-- ============================================================
CREATE TABLE public.store_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reported_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  name text NOT NULL,
  address text NOT NULL,
  lat double precision,
  lng double precision,
  phone text,
  store_type text NOT NULL CHECK (store_type = ANY (ARRAY[
    'cafe', 'restaurant', 'zero_store', 'delivery'
  ])),
  instagram_url text,
  naver_place_url text,
  description text,
  image_urls text[] DEFAULT '{}',
  status text NOT NULL DEFAULT 'pending' CHECK (status = ANY (ARRAY[
    'pending', 'approved', 'rejected', 'duplicate'
  ])),
  admin_memo text,
  reviewed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewed_at timestamptz,
  store_id uuid REFERENCES public.stores(id),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE OR REPLACE FUNCTION handle_store_report_approved()
RETURNS TRIGGER AS $$
DECLARE v_store_id uuid;
BEGIN
  IF NEW.status = 'approved' AND OLD.status != 'approved' THEN
    INSERT INTO public.stores (
      name, address, lat, lng, phone,
      store_type, instagram_url, naver_place_url,
      is_active, created_by
    ) VALUES (
      NEW.name, NEW.address,
      COALESCE(NEW.lat, 37.5665), COALESCE(NEW.lng, 126.9780),
      NEW.phone, NEW.store_type,
      NEW.instagram_url, NEW.naver_place_url,
      true, NEW.reported_by
    ) RETURNING id INTO v_store_id;
    NEW.store_id := v_store_id;
    NEW.reviewed_at := now();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER trg_store_report_approved
  BEFORE UPDATE OF status ON public.store_reports
  FOR EACH ROW EXECUTE FUNCTION handle_store_report_approved();

-- ============================================================
-- 1-7. hot_deals
-- ============================================================
CREATE TABLE public.hot_deals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  brand_name text,
  barcode text,
  original_price integer,
  sale_price integer,
  discount_rate integer,
  image_url text,
  link_url text NOT NULL,
  source text CHECK (source = ANY (ARRAY[
    'coupang', 'smartstore', 'oliveyoung', 'kurly', 'manual'
  ])),
  starts_at timestamptz,
  ends_at timestamptz,
  is_active boolean DEFAULT true,
  like_count integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

-- ============================================================
-- 1-8. RLS  (profiles 미사용 버전 — 사용자 정책만)
--   "... 관리자" 정책은 profiles.is_admin 의존이라 제외.
--   운영 작업은 대시보드 service_role(RLS 우회) + 승인 트리거(SECURITY DEFINER)로 처리.
-- ============================================================
ALTER TABLE public.stores ENABLE ROW LEVEL SECURITY;
CREATE POLICY "stores 읽기" ON public.stores
  FOR SELECT USING (is_active = true);

ALTER TABLE public.store_photos ENABLE ROW LEVEL SECURITY;
CREATE POLICY "photos 읽기" ON public.store_photos FOR SELECT USING (true);

ALTER TABLE public.store_reviews ENABLE ROW LEVEL SECURITY;
CREATE POLICY "reviews 읽기" ON public.store_reviews FOR SELECT USING (true);
CREATE POLICY "reviews 작성" ON public.store_reviews
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "reviews 수정" ON public.store_reviews
  FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "reviews 삭제" ON public.store_reviews
  FOR DELETE USING (auth.uid() = user_id);

ALTER TABLE public.store_reports ENABLE ROW LEVEL SECURITY;
CREATE POLICY "reports 본인 읽기" ON public.store_reports
  FOR SELECT USING (auth.uid() = reported_by);
CREATE POLICY "reports 작성" ON public.store_reports
  FOR INSERT WITH CHECK (auth.uid() = reported_by);

ALTER TABLE public.menu_board_reports ENABLE ROW LEVEL SECURITY;
CREATE POLICY "menu_board 본인 읽기" ON public.menu_board_reports
  FOR SELECT USING (auth.uid() = reported_by);
CREATE POLICY "menu_board 작성" ON public.menu_board_reports
  FOR INSERT WITH CHECK (auth.uid() = reported_by);

ALTER TABLE public.hot_deals ENABLE ROW LEVEL SECURITY;
CREATE POLICY "hotdeals 읽기" ON public.hot_deals
  FOR SELECT USING (is_active = true);

-- ============================================================
-- 1-9. Storage 버킷
--   대시보드(Storage)에서 직접 생성 — SQL 아님:
--     - store-photos  (public)
--     - store-reports (public)
-- ============================================================
