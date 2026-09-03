-- 이벤트 처리 RPC.
--
-- 앱은 "무슨 일이 일어났다"만 보낸다. 어떤 미션이 걸리고 얼마를 주는지는
-- 서버가 missions 표를 읽어 정한다 — 그래서 앱에 금액이 없고 조작이 불가능하다.
--
--   select * from fire_event('checkin');
--   select * from fire_event('product_log', '{"grade":"low"}'::jsonb, 'log-uuid');

-- 기간키 — 앱의 PeriodKey 와 같은 규칙이어야 한다.
CREATE OR REPLACE FUNCTION public.period_key_for(p_period text, p_start date)
RETURNS text
LANGUAGE sql IMMUTABLE SET search_path = public
AS $$
  SELECT CASE p_period
    WHEN 'daily'  THEN to_char(current_date, 'YYYY-MM-DD')
    WHEN 'weekly' THEN to_char(current_date, 'IYYY-"W"IW')
    WHEN 'streak' THEN coalesce(to_char(p_start, 'YYYY-MM-DD'), to_char(current_date, 'YYYY-MM-DD'))
    ELSE ''
  END;
$$;

CREATE OR REPLACE FUNCTION public.fire_event(
  p_trigger text,
  p_data jsonb DEFAULT '{}'::jsonb,
  p_ref_id text DEFAULT NULL
)
RETURNS TABLE (mission_code text, title text, reward int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user uuid := auth.uid();
  v_today date := current_date;
  v_streak public.user_streaks%ROWTYPE;
  v_continues boolean;
  m record;
  v_key text;
  v_count int;
  v_done timestamptz;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION '로그인이 필요합니다';
  END IF;

  -- 출석 성격의 트리거는 연속 상태를 먼저 갱신한다.
  IF p_trigger = 'checkin' THEN
    SELECT * INTO v_streak FROM public.user_streaks
      WHERE user_id = v_user AND kind = 'checkin' FOR UPDATE;

    IF FOUND AND v_streak.last_date = v_today THEN
      RETURN;                      -- 오늘 이미 출석 — 아무것도 주지 않는다
    END IF;

    v_continues := FOUND AND v_streak.last_date = v_today - 1;

    INSERT INTO public.user_streaks (user_id, kind, current, best, last_date, start_date)
    VALUES (
      v_user, 'checkin', 1, 1, v_today, v_today
    )
    ON CONFLICT (user_id, kind) DO UPDATE SET
      current    = CASE WHEN v_continues THEN public.user_streaks.current + 1 ELSE 1 END,
      best       = greatest(public.user_streaks.best,
                     CASE WHEN v_continues THEN public.user_streaks.current + 1 ELSE 1 END),
      last_date  = v_today,
      start_date = CASE WHEN v_continues
                     THEN coalesce(public.user_streaks.start_date, v_today)
                     ELSE v_today END,
      updated_at = now();
  END IF;

  SELECT * INTO v_streak FROM public.user_streaks
    WHERE user_id = v_user AND kind = 'checkin';

  FOR m IN
    SELECT * FROM public.missions
    WHERE is_active
      AND trigger = p_trigger
      AND (starts_at IS NULL OR starts_at <= now())
      AND (ends_at   IS NULL OR ends_at   >= now())
      -- 조건은 이벤트 데이터가 정의를 포함해야 통과 (@> 로 AND 매칭)
      AND p_data @> condition
    ORDER BY sort_order
  LOOP
    v_key := public.period_key_for(m.period, v_streak.start_date);

    SELECT mp.count, mp.completed_at INTO v_count, v_done
      FROM public.mission_progress mp
     WHERE mp.user_id = v_user AND mp.mission_code = m.code
       AND mp.period_key = v_key
     FOR UPDATE;

    IF v_done IS NOT NULL THEN
      CONTINUE;                    -- 이 기간엔 이미 받았다
    END IF;

    -- 연속 미션은 누적이 아니라 현재 연속 일수가 곧 진행도다.
    IF m.period = 'streak' THEN
      v_count := coalesce(v_streak.current, 0);
    ELSE
      v_count := coalesce(v_count, 0) + 1;
    END IF;

    INSERT INTO public.mission_progress
      (user_id, mission_code, period_key, count, completed_at)
    VALUES (v_user, m.code, v_key, v_count,
            CASE WHEN v_count >= m.target THEN now() ELSE NULL END)
    ON CONFLICT (user_id, mission_code, period_key) DO UPDATE SET
      count = excluded.count,
      completed_at = excluded.completed_at,
      updated_at = now();

    IF v_count >= m.target AND m.reward > 0 THEN
      -- ref_id 를 미션코드+기간키로 두면 유니크 인덱스가 재적립을 막는다.
      INSERT INTO public.point_ledger
        (user_id, delta, reason, subject, ref_type, ref_id)
      VALUES (v_user, m.reward, 'mission', m.title, 'mission',
              m.code || '@' || v_key)
      ON CONFLICT DO NOTHING;

      mission_code := m.code;
      title := m.title;
      reward := m.reward;
      RETURN NEXT;
    END IF;
  END LOOP;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fire_event(text, jsonb, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.fire_event(text, jsonb, text) TO authenticated;

-- ── 아낀 설탕 적립 ───────────────────────────────────────────
-- 금액은 앱이 계산해 넘기지만, ref_id(먹은 기록 id)로 중복을 막고
-- 하루 상한을 서버에서 건다. (기준표를 DB 로 옮기면 금액도 서버가 정하게 된다)
CREATE OR REPLACE FUNCTION public.earn_sugar_saved(
  p_log_id text,
  p_amount int,
  p_subject text
)
RETURNS int
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user uuid := auth.uid();
  v_today_total int;
  v_cap constant int := 300;     -- 하루 적립 상한
  v_grant int;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION '로그인이 필요합니다';
  END IF;
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN 0;
  END IF;

  SELECT coalesce(sum(delta), 0) INTO v_today_total
    FROM public.point_ledger
   WHERE user_id = v_user
     AND delta > 0
     AND created_at >= current_date;

  -- 상한을 넘는 만큼은 잘라서 준다. 고기준 제품만 골라 기록하는 걸 막는다.
  v_grant := least(p_amount, greatest(v_cap - v_today_total, 0));
  IF v_grant <= 0 THEN
    RETURN 0;
  END IF;

  INSERT INTO public.point_ledger
    (user_id, delta, reason, subject, ref_type, ref_id)
  VALUES (v_user, v_grant, 'sugar_saved', p_subject, 'product_log', p_log_id)
  ON CONFLICT DO NOTHING;

  RETURN v_grant;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.earn_sugar_saved(text, int, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.earn_sugar_saved(text, int, text) TO authenticated;

-- ── 포인트 사용 ──────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.spend_points(
  p_amount int,
  p_subject text,
  p_ref_id text DEFAULT NULL
)
RETURNS int
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user uuid := auth.uid();
  v_balance int;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION '로그인이 필요합니다';
  END IF;
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN 0;
  END IF;

  SELECT coalesce(sum(delta), 0) INTO v_balance
    FROM public.point_ledger WHERE user_id = v_user;

  IF p_amount > v_balance THEN
    RAISE EXCEPTION '포인트가 부족합니다 (보유 %P, 요청 %P)', v_balance, p_amount;
  END IF;

  INSERT INTO public.point_ledger
    (user_id, delta, reason, subject, ref_type, ref_id)
  VALUES (v_user, -p_amount, 'redeem', p_subject, 'order', p_ref_id);

  RETURN p_amount;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.spend_points(int, text, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.spend_points(int, text, text) TO authenticated;
