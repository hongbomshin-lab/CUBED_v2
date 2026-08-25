-- 미션 정의. 미션 추가는 이 표에 한 줄 넣는 것으로 끝난다(앱 배포 불필요).
-- 생성: build_missions.py · 6개

insert into public.missions
  (code, title, description, icon, trigger, condition, period, target, reward, sort_order, is_active)
values
  ('daily_checkin', '매일 출석체크', '하루 한 번 앱에 들르면 적립', 'event_available', 'checkin', '{}'::jsonb, 'daily', 1, 10, 10, true),
  ('streak_3', '3일 연속 출석', '사흘만 이어가도 보너스', 'local_fire_department', 'checkin', '{}'::jsonb, 'streak', 3, 30, 20, true),
  ('streak_7', '7일 연속 출석', '일주일을 채우면 크게 적립', 'local_fire_department', 'checkin', '{}'::jsonb, 'streak', 7, 100, 21, true),
  ('streak_30', '30일 연속 출석', '한 달을 채운 사람에게', 'workspace_premium', 'checkin', '{}'::jsonb, 'streak', 30, 500, 22, true),
  ('low_sugar_daily', '저당 제품 인증', '오늘 먹은 저당 제품을 기록하세요', 'restaurant', 'product_log', '{"grade": "low"}'::jsonb, 'daily', 1, 20, 30, true),
  ('weekly_5_logs', '이번 주 5번 기록', '꾸준히 기록하면 보너스', 'edit_calendar', 'product_log', '{}'::jsonb, 'weekly', 5, 50, 40, true)
on conflict (code) do update set
  title = excluded.title, description = excluded.description,
  icon = excluded.icon, trigger = excluded.trigger,
  condition = excluded.condition, period = excluded.period,
  target = excluded.target, reward = excluded.reward,
  sort_order = excluded.sort_order, is_active = excluded.is_active;
