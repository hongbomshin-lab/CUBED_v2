-- 포인트 보안 강화 + 일일 상한 조정.
--
-- 찾은 구멍: earn_sugar_saved 가 적립 금액을 클라이언트에서 받고 있었다.
-- 로그인만 하면 아무것도 먹지 않고 포인트를 만들 수 있었다.
-- 기준표를 DB 로 옮겨 서버가 직접 계산하게 한다 — 앱이 넘긴 금액은 무시한다.

-- ── 기준표 (lib/core/sugar_baselines.dart 와 같은 내용) ──────────
CREATE TABLE IF NOT EXISTS public.sugar_baselines (
  id int PRIMARY KEY,
  category text NOT NULL,
  keywords text[],              -- null 이면 카테고리 기본값
  baseline_g int NOT NULL CHECK (baseline_g >= 0),
  basis text NOT NULL
);

ALTER TABLE public.sugar_baselines ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "sugar_baselines 공개 읽기" ON public.sugar_baselines;
CREATE POLICY "sugar_baselines 공개 읽기"
  ON public.sugar_baselines FOR SELECT USING (true);
GRANT SELECT ON public.sugar_baselines TO anon, authenticated;

TRUNCATE public.sugar_baselines;
INSERT INTO public.sugar_baselines (category, keywords, baseline_g, basis, id) VALUES
  ('탄산음료', null, 27, '일반 콜라 250ml 캔', 0),
  ('에너지드링크', null, 27, '일반 에너지드링크 250ml 캔', 1),
  ('스포츠/이온음료', null, 30, '일반 이온음료 500ml', 2),
  ('과일음료', null, 36, '일반 주스 350ml', 3),
  ('건강/기능성음료', null, 10, '일반 기능성음료 100ml 병', 4),
  ('차/티음료', array['아이스티','에이드','블렌딩','밀크티'], 25, '일반 아이스티 500ml', 5),
  ('차/티음료', array['식혜','수정과'], 20, '일반 식혜 238ml 캔', 6),
  ('차/티음료', array['유자차','꿀'], 20, '일반 유자차 음료', 7),
  ('차/티음료', null, 3, '일반 차음료', 8),
  ('커피', array['아메리카노'], 10, '일반 가당 아메리카노 275ml', 9),
  ('커피', array['믹스'], 6, '일반 커피믹스 1봉', 10),
  ('커피', null, 22, '일반 라떼 275ml', 11),
  ('우유/요거트음료', array['우유','쉐이크','셰이크','밀크'], 26, '일반 가공유 240ml', 12),
  ('우유/요거트음료', null, 12, '일반 요거트드링크 1병', 13),
  ('두유/식물성음료', null, 8, '일반 두유 190ml', 14),
  ('단백질음료', null, 5, '일반 단백질음료 1병', 15),
  ('아이스크림/빙과', array['쉐이크','셰이크'], 26, '일반 밀크쉐이크 1컵', 16),
  ('아이스크림/빙과', array['콘'], 22, '일반 콘 1개', 17),
  ('아이스크림/빙과', array['모나카','샌드'], 24, '일반 모나카 1개', 18),
  ('아이스크림/빙과', array['파인트','파르페','컵','아이스크림'], 20, '일반 컵 아이스크림 1개', 19),
  ('아이스크림/빙과', array['쭈쭈바','쮸쮸바','튜브','아이스팝'], 15, '일반 튜브 빙과 1개', 20),
  ('아이스크림/빙과', null, 14, '일반 아이스바 1개', 21),
  ('젤리', null, 40, '일반 젤리 1봉', 22),
  ('초콜릿/캔디/껌', array['캔디','민트','홀스','호올스'], 7, '일반 캔디 1회', 23),
  ('초콜릿/캔디/껌', array['껌'], 2, '일반 껌 1회', 24),
  ('초콜릿/캔디/껌', null, 20, '일반 초콜릿 1개', 25),
  ('과자/스낵', array['그래놀라','오트','오즈'], 15, '일반 그래놀라 50g', 26),
  ('과자/스낵', array['팝콘'], 23, '일반 카라멜팝콘 1봉(75g)', 27),
  ('과자/스낵', array['웨하스'], 6, '일반 웨하스 1회', 28),
  ('과자/스낵', null, 7, '일반 쿠키 1회(2~3개)', 29),
  ('빵/디저트', array['단팥','호빵'], 18, '일반 단팥빵 1개', 30),
  ('빵/디저트', array['도넛'], 9, '일반 도넛 1개', 31),
  ('빵/디저트', array['티라미수','케이크'], 30, '일반 티라미수 1컵', 32),
  ('빵/디저트', array['소금빵'], 3, '일반 소금빵 1개', 33),
  ('빵/디저트', array['초코파이'], 13, '일반 초코파이 1개', 34),
  ('빵/디저트', null, 15, '일반 크림빵 1개', 35),
  ('간편식/식사', array['비빔면'], 12, '일반 비빔면 1봉', 36),
  ('간편식/식사', array['떡볶이'], 16, '일반 떡볶이 1인분', 37),
  ('간편식/식사', array['비빔밥'], 6, '일반 비빔밥 1인분', 38),
  ('간편식/식사', array['덮밥','도시락'], 12, '일반 고기양념 도시락 1인분', 39),
  ('간편식/식사', array['샌드'], 7, '일반 샌드위치 1개', 40),
  ('간편식/식사', null, 8, '일반 샐러드 1팩(드레싱 포함)', 41),
  ('단백질/에너지바', null, 15, '일반 에너지바 1개', 42),
  ('소스/장류', array['초고추장'], 8, '일반 초고추장 20g', 43),
  ('소스/장류', array['드레싱'], 4, '일반 드레싱 30g', 44),
  ('소스/장류', null, 5, '일반 쌈장 20g', 45);

-- 선언 순서 = 매칭 우선순위. 키워드 규칙이 기본값보다 먼저 와야 한다.
CREATE OR REPLACE FUNCTION public.sugar_points_for(
  p_category text, p_name text, p_sugar numeric
)
RETURNS int
LANGUAGE plpgsql STABLE SET search_path = public
AS $$
DECLARE
  v_base int;
  v_sugar numeric;
BEGIN
  IF p_category IS NULL THEN RETURN 0; END IF;

  -- 키워드 규칙 우선, 없으면 카테고리 기본값.
  SELECT baseline_g INTO v_base FROM public.sugar_baselines
   WHERE category = p_category AND keywords IS NOT NULL
     AND EXISTS (SELECT 1 FROM unnest(keywords) k
                  WHERE position(lower(k) in lower(coalesce(p_name,''))) > 0)
   ORDER BY id LIMIT 1;

  IF v_base IS NULL THEN
    SELECT baseline_g INTO v_base FROM public.sugar_baselines
     WHERE category = p_category AND keywords IS NULL
     ORDER BY id LIMIT 1;
  END IF;

  IF v_base IS NULL THEN RETURN 0; END IF;

  -- 당류가 음수인 데이터가 오면 기준값보다 큰 적립이 나온다. 0 으로 막는다.
  v_sugar := greatest(coalesce(p_sugar, 0), 0);
  RETURN greatest(round(v_base - v_sugar)::int, 0);
END;
$$;

-- ── 적립: 금액을 서버가 정한다 ───────────────────────────────
-- 앱은 '이 먹은 기록으로 적립해 달라'만 요청하고, 금액은 넘기지 않는다.
DROP FUNCTION IF EXISTS public.earn_sugar_saved(text, int, text);

CREATE OR REPLACE FUNCTION public.earn_sugar_saved(p_log_id uuid)
RETURNS int
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user uuid := auth.uid();
  v_log public.product_logs%ROWTYPE;
  v_sugar numeric;
  v_amount int;
  v_today_total int;
  v_cap constant int := 30;      -- 하루 적립 상한
  v_grant int;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION '로그인이 필요합니다';
  END IF;

  -- 본인 기록만. 남의 기록으로 적립할 수 없다.
  SELECT * INTO v_log FROM public.product_logs
   WHERE id = p_log_id AND user_id = v_user;
  IF NOT FOUND THEN
    RETURN 0;
  END IF;

  -- 당류는 DB 제품에서 읽는다 — 앱이 보낸 값을 믿지 않는다.
  -- 촬영(OCR) 제품은 서버가 확인할 방법이 없어 적립하지 않는다.
  IF v_log.product_id IS NULL THEN
    RETURN 0;
  END IF;
  SELECT sugar INTO v_sugar FROM public.products
   WHERE product_id = v_log.product_id;
  IF v_sugar IS NULL THEN
    RETURN 0;
  END IF;

  v_amount := public.sugar_points_for(v_log.category, v_log.name, v_sugar);
  IF v_amount <= 0 THEN RETURN 0; END IF;

  SELECT coalesce(sum(delta), 0) INTO v_today_total
    FROM public.point_ledger
   WHERE user_id = v_user AND delta > 0 AND created_at >= current_date;

  -- 상한을 넘는 만큼은 잘라서 준다.
  v_grant := least(v_amount, greatest(v_cap - v_today_total, 0));
  IF v_grant <= 0 THEN RETURN 0; END IF;

  INSERT INTO public.point_ledger
    (user_id, delta, reason, subject, ref_type, ref_id)
  VALUES (v_user, v_grant, 'sugar_saved', v_log.name, 'product_log', p_log_id::text)
  ON CONFLICT DO NOTHING;

  -- 이미 적립된 기록이면 위 INSERT 가 무시된다 — 그때는 0 을 돌려준다.
  IF NOT FOUND THEN RETURN 0; END IF;
  RETURN v_grant;
END;
$$;

-- ── 미션 보상에도 같은 상한을 건다 ───────────────────────────
CREATE OR REPLACE FUNCTION public.daily_earn_room()
RETURNS int
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT greatest(30 - coalesce((
    SELECT sum(delta) FROM public.point_ledger
     WHERE user_id = auth.uid() AND delta > 0 AND created_at >= current_date
  ), 0), 0)::int;
$$;

-- ── 실행 권한: PUBLIC 기본 부여를 회수한다 ────────────────────
-- Postgres 는 함수 EXECUTE 를 PUBLIC 에 기본 부여한다.
-- anon 만 REVOKE 해서는 막히지 않는다(지금은 auth.uid() 검사로만 걸러졌다).
REVOKE ALL ON FUNCTION public.fire_event(text, jsonb, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.spend_points(int, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.earn_sugar_saved(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.daily_earn_room() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.fire_event(text, jsonb, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.spend_points(int, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.earn_sugar_saved(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.daily_earn_room() TO authenticated;

-- ── product_logs.points 는 표시용일 뿐 적립 근거가 아니다 ──────
COMMENT ON COLUMN public.product_logs.points IS
  '화면 표시용 스냅샷. 적립 근거는 point_ledger 이며 금액은 서버(earn_sugar_saved)가 정한다.';
