-- 기준데이터(감미료/카테고리/조합)는 비로그인(anon)뿐 아니라 로그인(authenticated) 사용자도
-- 읽어야 한다(관리자 콘솔은 로그인 상태). 정책 대상을 anon → {anon, authenticated}로 확장.
-- 공개 마스터 데이터라 민감하지 않음.
drop policy if exists "public read sw" on public.sweeteners;
create policy "public read sw" on public.sweeteners
  for select to anon, authenticated using (true);

drop policy if exists "public read cat" on public.category_meta;
create policy "public read cat" on public.category_meta
  for select to anon, authenticated using (true);

drop policy if exists "public read combo" on public.combo_rules;
create policy "public read combo" on public.combo_rules
  for select to anon, authenticated using (active);
