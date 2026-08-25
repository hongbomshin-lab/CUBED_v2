-- fire_event 가 42702 로 항상 실패하던 것을 고친다.
--
-- 원인: RETURNS TABLE 의 출력 컬럼 이름(mission_code, title, reward)이
-- 함수 안에서 조회하는 테이블 컬럼과 겹쳐, PL/pgSQL 이 어느 쪽인지 판단하지 못했다.
--     column reference "mission_code" is ambiguous
-- 출석·미션 적립이 한 번도 성공한 적이 없다(앱은 예외를 삼켜 조용히 0 을 돌려줬다).
--
-- 조치: 출력 컬럼을 out_ 접두어로 바꿔 이름 충돌을 없앤다.
--       테이블 참조에도 별칭을 붙여 의도를 분명히 한다.

CREATE OR REPLACE FUNCTION public.fire_event(
  p_trigger text,
  p_data jsonb DEFAULT '{}'::jsonb,
  p_ref_id text DEFAULT NULL
)
RETURNS TABLE (out_mission_code text, out_title text, out_reward int)
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
  v_grant int;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION '로그인이 필요합니다';
  END IF;

  IF p_trigger = 'checkin' THEN
    SELECT * INTO v_streak FROM public.user_streaks s
      WHERE s.user_id = v_user AND s.kind = 'checkin' FOR UPDATE;

    IF FOUND AND v_streak.last_date = v_today THEN
      RETURN;                                   -- 오늘 이미 출석
    END IF;

    v_continues := FOUND AND v_streak.last_date = v_today - 1;

    INSERT INTO public.user_streaks AS us
      (user_id, kind, current, best, last_date, start_date)
    VALUES (v_user, 'checkin', 1, 1, v_today, v_today)
    ON CONFLICT (user_id, kind) DO UPDATE SET
      current    = CASE WHEN v_continues THEN us.current + 1 ELSE 1 END,
      best       = greatest(us.best,
                     CASE WHEN v_continues THEN us.current + 1 ELSE 1 END),
      last_date  = v_today,
      start_date = CASE WHEN v_continues
                     THEN coalesce(us.start_date, v_today) ELSE v_today END,
      updated_at = now();
  ELSE
    IF NOT public.owns_ref(v_user, p_trigger, p_ref_id) THEN
      RETURN;
    END IF;
    BEGIN
      INSERT INTO public.mission_events (user_id, trigger, ref_id)
      VALUES (v_user, p_trigger, p_ref_id);
    EXCEPTION WHEN unique_violation THEN
      RETURN;                                   -- 같은 근거 재사용
    END;
  END IF;

  SELECT * INTO v_streak FROM public.user_streaks s
    WHERE s.user_id = v_user AND s.kind = 'checkin';

  v_room := public.daily_earn_room();

  FOR m IN
    SELECT * FROM public.missions ms
    WHERE ms.is_active
      AND ms.trigger = p_trigger
      AND (ms.starts_at IS NULL OR ms.starts_at <= now())
      AND (ms.ends_at   IS NULL OR ms.ends_at   >= now())
      AND p_data @> ms.condition
    ORDER BY ms.sort_order
  LOOP
    v_key := public.period_key_for(m.period, v_streak.start_date);

    SELECT mp.count, mp.completed_at INTO v_count, v_done
      FROM public.mission_progress mp
     WHERE mp.user_id = v_user AND mp.mission_code = m.code
       AND mp.period_key = v_key
     FOR UPDATE;

    IF v_done IS NOT NULL THEN
      CONTINUE;                                 -- 이 기간엔 이미 받았다
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

    IF v_count >= m.target AND m.reward > 0 AND v_room > 0 THEN
      v_grant := least(m.reward, v_room);

      INSERT INTO public.point_ledger
        (user_id, delta, reason, subject, ref_type, ref_id)
      VALUES (v_user, v_grant, 'mission', m.title, 'mission',
              m.code || '@' || v_key)
      ON CONFLICT DO NOTHING;

      IF FOUND THEN
        v_room := v_room - v_grant;
        out_mission_code := m.code;
        out_title := m.title;
        out_reward := v_grant;
        RETURN NEXT;
      END IF;
    END IF;
  END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION public.fire_event(text, jsonb, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fire_event(text, jsonb, text) TO authenticated;
