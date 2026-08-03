-- 열람 정책의 관리자 이메일을 실제 관리자 계정으로 수정
drop policy "admin read launch_notifications" on public.launch_notifications;
create policy "admin read launch_notifications"
  on public.launch_notifications
  for select
  to authenticated
  using ((auth.jwt() ->> 'email') = 'hongbomshin@snu.ac.kr');
