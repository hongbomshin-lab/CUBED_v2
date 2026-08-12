-- 관리자 열람 계정에 zerodot@zerodot.kr 추가
drop policy "admin read launch_notifications" on public.launch_notifications;
create policy "admin read launch_notifications"
  on public.launch_notifications
  for select
  to authenticated
  using ((auth.jwt() ->> 'email') in ('hongbomshin@snu.ac.kr', 'zerodot@zerodot.kr'));
