-- [1단계] fire_event 가 '근거'를 검증하게 한다.
--
-- 찾은 구멍: fire_event 는 p_ref_id 를 받기만 하고 쓰지 않았다.
-- 로그인만 하면 아무것도 하지 않고
--     select fire_event('product_log', '{"grade":"low"}')   × 5
-- 를 호출해 주간 미션(50P)과 일일 미션(20P)을 즉시 완료할 수 있었다.
--
-- 조치 둘:
--   ① checkin 을 제외한 모든 트리거는 근거 id 를 요구하고, 그것이 실제로
--      '본인 것'인지 원본 테이블에서 확인한다.
--   ② 같은 근거로 두 번 진행되지 않도록 mission_events 에 기록한다.
--      (같은 먹은 기록으로 두 번 부르면 두 번째는 무시된다)

-- ── 이미 반영된 근거 기록 ────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.mission_events (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  trigger text NOT NULL,
  ref_id text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, trigger, ref_id)
);

ALTER TABLE public.mission_events ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "mission_events 본인 읽기" ON public.mission_events;
CREATE POLICY "mission_events 본인 읽기" ON public.mission_events
  FOR SELECT TO authenticated USING (auth.uid() = user_id);
GRANT SELECT ON public.mission_events TO authenticated;

-- ── 근거 소유 확인 ───────────────────────────────────────────
-- 트리거마다 원본 테이블과 소유자 칼럼이 다르다(user_id / reported_by).
CREATE OR REPLACE FUNCTION public.owns_ref(
  p_user uuid, p_trigger text, p_ref_id text
)
RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_ok boolean := false;
  v_uuid uuid;
BEGIN
  IF p_ref_id IS NULL OR p_ref_id = '' THEN
    RETURN false;
  END IF;

  -- store_favorite 의 근거는 store_id (복합키라 행 id 가 없다).
  IF p_trigger = 'store_favorite' THEN
    BEGIN v_uuid := p_ref_id::uuid; EXCEPTION WHEN others THEN RETURN false; END;
    SELECT EXISTS(SELECT 1 FROM public.store_favorites
                   WHERE user_id = p_user AND store_id = v_uuid) INTO v_ok;
    RETURN v_ok;
  END IF;

  BEGIN v_uuid := p_ref_id::uuid; EXCEPTION WHEN others THEN RETURN false; END;

  CASE p_trigger
    WHEN 'product_log' THEN
      SELECT EXISTS(SELECT 1 FROM public.product_logs
                     WHERE id = v_uuid AND user_id = p_user) INTO v_ok;
    WHEN 'store_review' THEN
      SELECT EXISTS(SELECT 1 FROM public.store_reviews
                     WHERE id = v_uuid AND user_id = p_user) INTO v_ok;
    WHEN 'menu_board_report' THEN
      SELECT EXISTS(SELECT 1 FROM public.menu_board_reports
                     WHERE id = v_uuid AND reported_by = p_user) INTO v_ok;
    WHEN 'store_report' THEN
      SELECT EXISTS(SELECT 1 FROM public.store_reports
                     WHERE id = v_uuid AND reported_by = p_user) INTO v_ok;
    WHEN 'product_comment' THEN
      SELECT EXISTS(SELECT 1 FROM public.product_comments
                     WHERE id = v_uuid AND user_id = p_user) INTO v_ok;
    ELSE
      v_ok := false;
  END CASE;

  RETURN v_ok;
END;
$$;

REVOKE ALL ON FUNCTION public.owns_ref(uuid, text, text) FROM PUBLIC, anon, authenticated;

-- ── fire_event 재정의 ────────────────────────────────────────
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
  v_room int;
  m record;
  v_key text;
  v_count int;
  v_done timestamptz;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION '로그인이 필요합니다';
  END IF;

  IF p_trigger = 'checkin' THEN
    -- 출석은 하루 한 번. 근거는 '오늘 날짜' 자체다.
    SELECT * INTO v_streak FROM public.user_streaks
      WHERE user_id = v_user AND kind = 'checkin' FOR UPDATE;

    IF FOUND AND v_streak.last_date = v_today THEN
      RETURN;
    END IF;

    v_continues := FOUND AND v_streak.last_date = v_today - 1;

    INSERT INTO public.user_streaks (user_id, kind, current, best, last_date, start_date)
    VALUES (v_user, 'checkin', 1, 1, v_today, v_today)
    ON CONFLICT (user_id, kind) DO UPDATE SET
      current    = CASE WHEN v_continues THEN public.user_streaks.current + 1 ELSE 1 END,
      best       = greatest(public.user_streaks.best,
                     CASE WHEN v_continues THEN public.user_streaks.current + 1 ELSE 1 END),
      last_date  = v_today,
      start_date = CASE WHEN v_continues
                     THEN coalesce(public.user_streaks.start_date, v_today)
                     ELSE v_today END,
      updated_at = now();
  ELSE
    -- 나머지 트리거는 반드시 '본인이 만든 실제 행'을 근거로 요구한다.
    IF NOT public.owns_ref(v_user, p_trigger, p_ref_id) THEN
      RETURN;
    END IF;
    -- 같은 근거로 두 번 진행하지 않는다.
    BEGIN
      INSERT INTO public.mission_events (user_id, trigger, ref_id)
      VALUES (v_user, p_trigger, p_ref_id);
    EXCEPTION WHEN unique_violation THEN
      RETURN;
    END;
  END IF;

  SELECT * INTO v_streak FROM public.user_streaks
    WHERE user_id = v_user AND kind = 'checkin';

  -- 미션 보상도 일일 상한을 함께 쓴다.
  v_room := public.daily_earn_room();

  FOR m IN
    SELECT * FROM public.missions
    WHERE is_active
      AND trigger = p_trigger
      AND (starts_at IS NULL OR starts_at <= now())
      AND (ends_at   IS NULL OR ends_at   >= now())
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
      CONTINUE;
    END IF;

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
      -- 상한을 넘으면 잘라서 준다. 다 찼으면 진행만 남기고 적립은 하지 않는다.
      IF v_room <= 0 THEN
        CONTINUE;
      END IF;

      INSERT INTO public.point_ledger
        (user_id, delta, reason, subject, ref_type, ref_id)
      VALUES (v_user, least(m.reward, v_room), 'mission', m.title, 'mission',
              m.code || '@' || v_key)
      ON CONFLICT DO NOTHING;

      IF FOUND THEN
        mission_code := m.code;
        title := m.title;
        reward := least(m.reward, v_room);
        v_room := v_room - reward;
        RETURN NEXT;
      END IF;
    END IF;
  END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION public.fire_event(text, jsonb, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fire_event(text, jsonb, text) TO authenticated;
