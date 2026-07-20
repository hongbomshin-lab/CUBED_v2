-- ============================================================
-- 0005. 매장 즐겨찾기 (store_favorites)
-- 유저가 저당맵 매장을 즐겨찾기한다. (user_id, store_id) 복합 PK로 중복 방지.
-- 본인 것만 읽기/추가/삭제 가능.
-- ============================================================

CREATE TABLE public.store_favorites (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  PRIMARY KEY (user_id, store_id)
);

CREATE INDEX idx_store_favorites_user ON public.store_favorites(user_id, created_at DESC);

ALTER TABLE public.store_favorites ENABLE ROW LEVEL SECURITY;

CREATE POLICY "favorites 본인 읽기" ON public.store_favorites
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "favorites 추가" ON public.store_favorites
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "favorites 삭제" ON public.store_favorites
  FOR DELETE USING (auth.uid() = user_id);
