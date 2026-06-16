-- ============================================================
-- 0003. 매장 제보 승인 가드
--   유저 제보 단계: address·lat·lng·store_type 모두 NULL 허용(0002).
--   관리자 승인 단계: 위 4개가 반드시 채워져 있어야 함.
--   → 비어 있으면 승인(approved)을 막고 명확한 에러를 던진다.
--     (기존엔 COALESCE 로 서울시청 좌표가 조용히 들어가던 문제 제거)
-- ============================================================
CREATE OR REPLACE FUNCTION handle_store_report_approved()
RETURNS TRIGGER AS $$
DECLARE v_store_id uuid;
BEGIN
  IF NEW.status = 'approved' AND OLD.status != 'approved' THEN
    -- 승인 전 필수값 검증 (관리자가 대시보드에서 채워야 함)
    IF NEW.address IS NULL OR btrim(NEW.address) = '' THEN
      RAISE EXCEPTION '승인 불가: 주소(address)를 먼저 입력하세요. report_id=%', NEW.id;
    END IF;
    IF NEW.lat IS NULL OR NEW.lng IS NULL THEN
      RAISE EXCEPTION '승인 불가: 좌표(lat/lng)를 먼저 입력하세요. report_id=%', NEW.id;
    END IF;
    IF NEW.store_type IS NULL THEN
      RAISE EXCEPTION '승인 불가: store_type 을 먼저 선택하세요. report_id=%', NEW.id;
    END IF;

    INSERT INTO public.stores (
      name, address, lat, lng, phone,
      store_type, instagram_url, naver_place_url,
      is_active, created_by
    ) VALUES (
      NEW.name, NEW.address,
      NEW.lat, NEW.lng,
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
