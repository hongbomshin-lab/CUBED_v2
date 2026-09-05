-- ============================================================
-- 리뷰 안전장치 (Apple UGC 필수요건): 신고 / 차단 / 필터링
--   1) user_blocks       — 문제 사용자 차단
--   2) review_reports    — 부적절 리뷰 신고
--   3) banned_words      — 금칙어(작성 시 서버 차단)
--   4) 자동 숨김 트리거   — 서로 다른 사용자 3명 이상 신고 시 is_active=false
--   5) visible_store_reviews RPC — 차단/신고/비활성 리뷰를 제외한 목록
-- ============================================================

-- ------------------------------------------------------------
-- 1. user_blocks — 내가 차단한 사용자
-- ------------------------------------------------------------
create table if not exists public.user_blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint no_self_block check (blocker_id <> blocked_id)
);

alter table public.user_blocks enable row level security;

create policy "blocks 내것만 조회" on public.user_blocks
  for select using (auth.uid() = blocker_id);
create policy "blocks 내가 차단" on public.user_blocks
  for insert with check (auth.uid() = blocker_id and blocker_id <> blocked_id);
create policy "blocks 내가 해제" on public.user_blocks
  for delete using (auth.uid() = blocker_id);

-- ------------------------------------------------------------
-- 2. review_reports — 리뷰 신고
-- ------------------------------------------------------------
create table if not exists public.review_reports (
  id uuid primary key default gen_random_uuid(),
  review_id uuid not null references public.store_reviews(id) on delete cascade,
  reporter_id uuid not null references auth.users(id) on delete cascade,
  reason text not null check (reason = any (array[
    'spam', 'abuse', 'sexual', 'illegal', 'false_info', 'other'
  ])),
  detail text check (char_length(detail) <= 500),
  status text not null default 'pending' check (status = any (array[
    'pending', 'reviewed', 'actioned', 'dismissed'
  ])),
  created_at timestamptz not null default now(),
  unique (review_id, reporter_id)  -- 한 사람이 같은 리뷰 중복 신고 방지
);

create index if not exists review_reports_review_idx
  on public.review_reports (review_id);

alter table public.review_reports enable row level security;

-- 내 신고만 조회(관리자 콘솔은 service_role 로 우회).
create policy "reports 내것만 조회" on public.review_reports
  for select using (auth.uid() = reporter_id);

-- 내가(로그인) 남의 리뷰만 신고 가능. 내 리뷰는 신고 불가.
create policy "reports 신고 작성" on public.review_reports
  for insert with check (
    auth.uid() = reporter_id
    and exists (
      select 1 from public.store_reviews r
      where r.id = review_id and r.user_id <> auth.uid()
    )
  );

-- 사용자 update/delete 없음(신고 철회는 지원 안 함 — 무결성 보존).

-- 신고 시 status 등은 서버 기본값 강제(클라이언트 위조 차단).
create or replace function public.review_reports_sanitize()
returns trigger as $$
begin
  new.status := 'pending';
  new.created_at := now();
  if new.detail is not null and char_length(trim(new.detail)) = 0 then
    new.detail := null;
  end if;
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_review_reports_sanitize on public.review_reports;
create trigger trg_review_reports_sanitize
  before insert on public.review_reports
  for each row execute function public.review_reports_sanitize();

-- ------------------------------------------------------------
-- 3. banned_words — 금칙어(작성 시 서버 차단)
-- ------------------------------------------------------------
create table if not exists public.banned_words (
  word text primary key,          -- 정규화된 소문자·공백제거 형태로 저장
  created_at timestamptz not null default now()
);

alter table public.banned_words enable row level security;
-- 일반 사용자는 조회/수정 불가(정책 없음 = 접근 차단). 관리는 service_role.

-- 텍스트 정규화: 소문자화 + 한글/영문/숫자 외 문자 제거(공백·기호 회피 차단).
create or replace function public.normalize_text(t text)
returns text as $$
  select regexp_replace(lower(coalesce(t, '')), '[^0-9a-z가-힣]', '', 'g');
$$ language sql immutable;

-- 금칙어 포함 여부.
create or replace function public.contains_banned_word(t text)
returns boolean as $$
declare
  norm text := public.normalize_text(t);
  w text;
begin
  if norm = '' then
    return false;
  end if;
  for w in select word from public.banned_words loop
    if w <> '' and position(w in norm) > 0 then
      return true;
    end if;
  end loop;
  return false;
end;
$$ language plpgsql stable security definer set search_path = public;

-- 리뷰 작성/수정 시 금칙어 차단.
create or replace function public.store_reviews_content_guard()
returns trigger as $$
begin
  if new.content is not null and public.contains_banned_word(new.content) then
    raise exception '부적절한 표현이 포함되어 있어요'
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$ language plpgsql security definer set search_path = public;

drop trigger if exists trg_store_reviews_content_guard on public.store_reviews;
create trigger trg_store_reviews_content_guard
  before insert or update on public.store_reviews
  for each row execute function public.store_reviews_content_guard();

-- 흔한 한국어 욕설/혐오 표현 시드(정규화 형태). 운영 중 확장 가능.
insert into public.banned_words (word) values
  ('씨발'), ('시발'), ('씨빨'), ('개새끼'), ('새끼'), ('병신'), ('지랄'),
  ('좆'), ('니미'), ('창녀'), ('걸레년'), ('보지'), ('자지'), ('섹스'),
  ('fuck'), ('shit'), ('bitch'), ('asshole'),
  ('죽여버'), ('꺼져'), ('한남'), ('김치녀'), ('된장녀'), ('틀딱'), ('맘충')
on conflict (word) do nothing;

-- ------------------------------------------------------------
-- 4. 자동 숨김 — 서로 다른 사용자 3명 이상 신고 시 리뷰 비활성화
-- ------------------------------------------------------------
create or replace function public.review_reports_autohide()
returns trigger as $$
declare
  distinct_reporters int;
begin
  select count(distinct reporter_id) into distinct_reporters
    from public.review_reports
   where review_id = new.review_id;

  if distinct_reporters >= 3 then
    update public.store_reviews
       set is_active = false
     where id = new.review_id and is_active = true;
  end if;
  return null;
end;
$$ language plpgsql security definer set search_path = public;

drop trigger if exists trg_review_reports_autohide on public.review_reports;
create trigger trg_review_reports_autohide
  after insert on public.review_reports
  for each row execute function public.review_reports_autohide();

-- ------------------------------------------------------------
-- 5. visible_store_reviews — 목록 조회 시 필터 일괄 적용
--    제외 대상: 비활성(is_active=false) / 내가 차단한 작성자 / 내가 신고한 리뷰
--    (미로그인 시 auth.uid()=null → 차단·신고 필터는 비어 있어 활성 리뷰 전체 표시)
-- ------------------------------------------------------------
create or replace function public.visible_store_reviews(
  p_store_id uuid,
  p_limit int default 50
)
returns setof public.store_reviews as $$
  select r.*
    from public.store_reviews r
   where r.store_id = p_store_id
     and r.is_active = true
     and r.user_id not in (
       select b.blocked_id from public.user_blocks b
        where b.blocker_id = auth.uid()
     )
     and r.id not in (
       select rr.review_id from public.review_reports rr
        where rr.reporter_id = auth.uid()
     )
   order by r.created_at desc
   limit greatest(p_limit, 0);
$$ language sql stable security definer set search_path = public;

grant execute on function public.visible_store_reviews(uuid, int) to anon, authenticated;
