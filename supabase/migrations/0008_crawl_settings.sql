-- ============================================================
-- 0008. 특가 자동 업데이트 on/off (기본 off)
-- pg_cron 이 걸려 있어도 auto_update_enabled=true 일 때만 실제 크롤한다.
-- 단일 행(singleton) 설정 테이블.
-- ============================================================

create table if not exists crawl_settings (
  id                  boolean primary key default true,
  auto_update_enabled boolean not null default false,   -- 기본 off
  updated_at          timestamptz not null default now(),
  constraint crawl_settings_singleton check (id)
);

-- 기본 행(off) 1개 보장
insert into crawl_settings (id, auto_update_enabled)
values (true, false)
on conflict (id) do nothing;

-- 서비스롤/대시보드만 접근 (앱·anon 불가). 정책 없음 = 공개 접근 차단.
alter table crawl_settings enable row level security;

-- 토글 헬퍼: SQL Editor 에서  select set_auto_update(true);  /  select set_auto_update(false);
create or replace function set_auto_update(p_enabled boolean)
returns boolean
language sql
security definer
set search_path = public
as $$
  update crawl_settings set auto_update_enabled = p_enabled, updated_at = now() where id;
  select p_enabled;
$$;

revoke execute on function set_auto_update(boolean) from public, anon, authenticated;
grant  execute on function set_auto_update(boolean) to service_role;
