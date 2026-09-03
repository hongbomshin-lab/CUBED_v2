-- 매장 제보(store_reports) 사용자 INSERT 하드닝.
--
-- 발견(코너케이스 테스트):
--   ① 사용자가 제보하면서 status='approved' / store_id / reviewed_by /
--      reviewed_at / admin_memo 를 임의로 넣을 수 있었다. RLS INSERT 정책은
--      reported_by 만 확인하고 다른 칼럼은 제한하지 않기 때문이다.
--      → 매장 자가발행은 안 되지만(승인 트리거는 UPDATE 전용) 관리자 검토 큐가
--        '승인됨'처럼 보이는 가짜 행으로 오염된다.
--   ② name 이 빈 문자열('')이어도 NOT NULL 을 통과해 저장됐다(앱은 막지만 API 직접).
--
-- 조치: BEFORE INSERT 트리거로 관리자 전용 칼럼을 강제 초기화하고 이름을 검증한다.
--   (관리자 승인은 UPDATE 경로라 이 트리거의 영향을 받지 않는다)

CREATE OR REPLACE FUNCTION public.store_reports_sanitize_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  -- 이름은 필수 — 공백만 있는 것도 거부.
  IF btrim(coalesce(NEW.name, '')) = '' THEN
    RAISE EXCEPTION '가게 이름을 입력해 주세요';
  END IF;
  NEW.name := btrim(NEW.name);

  -- 관리자만 정할 수 있는 값은 제보 시점에 강제로 초기화한다.
  NEW.status      := 'pending';
  NEW.store_id    := NULL;
  NEW.reviewed_by := NULL;
  NEW.reviewed_at := NULL;
  NEW.admin_memo  := NULL;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_store_reports_sanitize_insert ON public.store_reports;
CREATE TRIGGER trg_store_reports_sanitize_insert
  BEFORE INSERT ON public.store_reports
  FOR EACH ROW EXECUTE FUNCTION public.store_reports_sanitize_insert();
