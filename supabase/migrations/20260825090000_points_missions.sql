-- 포인트 원장 + 미션 (계정 귀속).
--
-- 핵심 원칙 셋:
--   ① 잔액을 저장하지 않는다. 원장(append-only)의 합으로 구한다 —
--      포인트는 돈이라 '언제 왜 얼마'가 항상 되짚어져야 한다.
--   ② 적립·차감은 RPC 로만. 앱에는 INSERT 권한을 주지 않는다.
--      보상 금액이 앱에 있으면 조작되므로, 금액은 서버가 미션 정의에서 읽는다.
--   ③ 기간키(period_key)가 중복 적립 방어다. 같은 키에 달성 기록이 있으면
--      두 번 주지 않는다. daily=날짜, weekly=ISO주차, once='', streak=연속 시작일.

-- ── 미션 정의 ────────────────────────────────────────────────
-- 미션 추가는 이 표에 한 줄 넣는 것으로 끝난다(앱 배포 불필요).
CREATE TABLE IF NOT EXISTS public.missions (
  code text PRIMARY KEY,
  title text NOT NULL,
  description text NOT NULL DEFAULT '',
  icon text NOT NULL DEFAULT 'flag',

  -- 앱이 보낼 수 있는 이벤트 종류. 이 목록만 코드에 있다.
  trigger text NOT NULL CHECK (trigger = ANY (ARRAY[
    'checkin', 'product_log', 'store_review', 'store_favorite',
    'menu_board_report', 'store_report', 'product_comment'
  ])),

  -- 이벤트에 딸려온 값과 대조할 조건. {} 이면 무조건 통과.
  -- 예) {"grade":"low"} → 저당 등급 기록만 인정.
  condition jsonb NOT NULL DEFAULT '{}'::jsonb,

  period text NOT NULL CHECK (period = ANY (ARRAY[
    'once', 'daily', 'weekly', 'streak'
  ])),

  -- 정의 실수로 포인트가 무너지지 않도록 DB 에서도 막는다.
  -- (target 0 이면 이벤트마다 즉시 달성, reward 음수면 잔액이 깎인다)
  target int NOT NULL CHECK (target >= 1),
  reward int NOT NULL CHECK (reward >= 0),

  sort_order int NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,

  -- 기간 한정 이벤트 미션용. null 이면 상시.
  starts_at timestamptz,
  ends_at timestamptz,

  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.missions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "missions 공개 읽기" ON public.missions FOR SELECT USING (true);
GRANT SELECT ON public.missions TO anon, authenticated;

-- ── 포인트 원장 ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.point_ledger (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- 적립은 +, 사용은 −.
  delta int NOT NULL CHECK (delta <> 0),

  reason text NOT NULL CHECK (reason = ANY (ARRAY[
    'sugar_saved', 'mission', 'redeem', 'adjust'
  ])),

  -- 무엇 때문인지 (제품명·미션명·상품명). 사용자가 대조할 수 있어야 한다.
  subject text,

  -- 어디서 왔는지 (product_logs.id, missions.code, 주문 id).
  ref_type text,
  ref_id text,

  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS point_ledger_user
  ON public.point_ledger (user_id, created_at DESC);

-- 같은 근거로 두 번 적립되지 않게. (같은 먹은 기록·같은 미션 달성)
CREATE UNIQUE INDEX IF NOT EXISTS point_ledger_dedup
  ON public.point_ledger (user_id, reason, ref_type, ref_id)
  WHERE ref_id IS NOT NULL;

ALTER TABLE public.point_ledger ENABLE ROW LEVEL SECURITY;

-- 읽기만 허용한다. 쓰기는 RPC(security definer)로만 —
-- 앱이 INSERT 할 수 있으면 잔액을 마음대로 만들 수 있다.
CREATE POLICY "point_ledger 본인 읽기" ON public.point_ledger
  FOR SELECT TO authenticated USING (auth.uid() = user_id);
GRANT SELECT ON public.point_ledger TO authenticated;

-- ── 미션 진행 ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.mission_progress (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  mission_code text NOT NULL REFERENCES public.missions(code) ON DELETE CASCADE,

  -- 이 진행이 어느 기간의 것인지. 중복 적립 방어의 핵심.
  period_key text NOT NULL DEFAULT '',

  count int NOT NULL DEFAULT 0,
  completed_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now(),

  PRIMARY KEY (user_id, mission_code, period_key)
);

ALTER TABLE public.mission_progress ENABLE ROW LEVEL SECURITY;
CREATE POLICY "mission_progress 본인 읽기" ON public.mission_progress
  FOR SELECT TO authenticated USING (auth.uid() = user_id);
GRANT SELECT ON public.mission_progress TO authenticated;

-- ── 연속 기록 ────────────────────────────────────────────────
-- 연속은 진행 횟수로 표현이 안 된다('어제 했는가'를 봐야 한다) 따로 둔다.
CREATE TABLE IF NOT EXISTS public.user_streaks (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  kind text NOT NULL DEFAULT 'checkin',

  current int NOT NULL DEFAULT 0,
  best int NOT NULL DEFAULT 0,
  last_date date,

  -- 지금 연속이 시작된 날. streak 미션의 기간키로 쓴다 —
  -- 끊겼다 다시 이으면 키가 바뀌어 보상을 다시 받을 수 있다.
  start_date date,

  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, kind)
);

ALTER TABLE public.user_streaks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "user_streaks 본인 읽기" ON public.user_streaks
  FOR SELECT TO authenticated USING (auth.uid() = user_id);
GRANT SELECT ON public.user_streaks TO authenticated;

-- ── 잔액 ─────────────────────────────────────────────────────
-- 저장하지 않고 원장의 합으로 구한다.
CREATE OR REPLACE FUNCTION public.my_point_balance()
RETURNS int
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = public
AS $$
  SELECT coalesce(sum(delta), 0)::int
  FROM public.point_ledger
  WHERE user_id = auth.uid();
$$;

GRANT EXECUTE ON FUNCTION public.my_point_balance() TO authenticated;

COMMENT ON TABLE public.point_ledger IS
  '포인트 원장(append-only). 잔액은 my_point_balance() 로 합산해 구한다. 쓰기는 RPC 로만.';
