-- ============================================================
-- 0002. 매장 제보 간소화
--   제보 폼은 "이름(필수) + 네이버/카카오 URL(선택) + 사진 URL(선택)"만 받음.
--   주소·좌표·store_type 은 관리자가 승인 시 대시보드에서 채우므로 NOT NULL 완화.
--   (승인 트리거는 승인 직전 관리자가 채운 값으로 stores 를 생성하므로 영향 없음)
-- ============================================================
ALTER TABLE public.store_reports ALTER COLUMN address   DROP NOT NULL;
ALTER TABLE public.store_reports ALTER COLUMN store_type DROP NOT NULL;
