-- 랜딩 페이지 출시 알림 신청 연락처 (이메일 또는 휴대폰 번호)
create table public.launch_notifications (
  id uuid primary key default gen_random_uuid(),
  contact text not null unique
    check (
      contact ~* '^[^\s@]+@[^\s@]+\.[a-z]{2,}$'
      or contact ~ '^01[016789][0-9]{7,8}$'
    ),
  created_at timestamptz not null default now()
);

alter table public.launch_notifications enable row level security;

-- 익명 방문자는 등록만 가능.
create policy "anon insert launch_notifications"
  on public.launch_notifications
  for insert
  to anon
  with check (true);

-- 열람은 관리자 계정(랜딩 페이지 숨은 콘솔에서 로그인)만.
create policy "admin read launch_notifications"
  on public.launch_notifications
  for select
  to authenticated
  using ((auth.jwt() ->> 'email') = 'hongbomshin@gmail.com');
