-- 먹은 기록 (푸드 다이어리): 결과 화면 '오늘 이거 먹었어요' 체크.
-- product_id null = 촬영(OCR) 제품 → 이름/브랜드/등급 스냅샷으로만 식별.
create table public.product_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  eaten_on date not null,
  product_id text,                 -- products.product_id (FK 제약 없음: 삭제·미승격 제품 기록 유지)
  name text not null,              -- 스냅샷
  brand text,
  category text,
  grade text check (grade in ('low','mid','caution')),
  image_path text,                 -- submission-images 폴더 uuid (DB 제품이면 null)
  created_at timestamptz not null default now()
);

comment on table public.product_logs is
  '사용자 먹은 기록. 같은 사용자·같은 날·같은 제품 1건(토글).';

-- 같은 사용자·같은 날·같은 제품 1건 (촬영 제품은 소문자 이름으로 동일성 판정)
create unique index product_logs_dedup
  on public.product_logs (user_id, eaten_on, coalesce(product_id, lower(name)));

-- 월별 조회용
create index product_logs_month on public.product_logs (user_id, eaten_on);

alter table public.product_logs enable row level security;

create policy "product_logs own rows" on public.product_logs
  for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- 달력 썸네일: 로그인 사용자가 제보 원본 사진(submission-images) 읽기 허용 (스펙 §3)
create policy "submission images authenticated read" on storage.objects
  for select to authenticated
  using (bucket_id = 'submission-images');
