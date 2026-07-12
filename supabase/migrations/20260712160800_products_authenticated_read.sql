-- products·product_sweeteners 읽기 정책에 authenticated 역할 추가.
-- 20260617100000_reference_authenticated_read.sql 가 기준 테이블(감미료/카테고리/조합)만 열고
-- products·product_sweeteners 를 빠뜨려, 로그인(authenticated) 사용자는 제품 조회·검색·바코드·
-- 대안 추천이 전부 빈 결과였다(RLS가 0행 반환, 에러 아님). 참고 테이블과 정합을 맞춘다.
-- 공개 카탈로그라 민감하지 않음(이미 anon 전체 읽기 허용).
drop policy if exists "public read products" on public.products;
create policy "public read products" on public.products
  for select to anon, authenticated using (true);

drop policy if exists "public read ps" on public.product_sweeteners;
create policy "public read ps" on public.product_sweeteners
  for select to anon, authenticated using (true);
