-- ============================================================
-- 0004. 메뉴판 사진 업로드용 Storage 버킷 + 정책
-- 유저가 앱에서 찍은 메뉴판 사진(클라이언트 압축본)을 직접 업로드한다.
-- 경로 규칙: {store_id}/{user_id}/{millis}.jpg
--   - 2번째 세그먼트(user_id)로 소유자를 판별해 본인 파일만 쓰기/삭제 허용.
--   - 승인/반려 정리 시 유저·매장 단위로 접근하기 쉽게 분리.
-- 무료 플랜 보호: public 읽기(서명 URL 불필요) + 1MB 파일 상한 + jpeg만 허용.
-- ============================================================

-- 버킷 생성 (이미 있으면 상한/타입만 갱신)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'menu-boards',
  'menu-boards',
  true,
  1048576, -- 1 MB (클라이언트에서 800KB 이하로 압축해 올림)
  ARRAY['image/jpeg']
)
ON CONFLICT (id) DO UPDATE
  SET public = EXCLUDED.public,
      file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;

-- 읽기: 누구나 (public 버킷 — getPublicUrl 로 조회)
CREATE POLICY "menu-boards 읽기"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'menu-boards');

-- 업로드: 로그인 유저가 본인 경로(2번째 세그먼트 = 본인 uid)에만
CREATE POLICY "menu-boards 업로드"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'menu-boards'
    AND (storage.foldername(name))[2] = auth.uid()::text
  );

-- 삭제: 본인이 올린 파일만 (제보 취소/재업로드 대비)
CREATE POLICY "menu-boards 삭제"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'menu-boards'
    AND (storage.foldername(name))[2] = auth.uid()::text
  );
