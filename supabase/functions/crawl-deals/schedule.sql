-- ============================================================
-- crawl-deals 자동 실행 스케줄 (pg_cron + pg_net) — 하루 1회
-- 실행 순서: ① crawl-deals 함수 배포(--no-verify-jwt) ② 시크릿(CRAWL_SECRET) 설정
--           ③ 아래 <project-ref>/<CRAWL_SECRET> 채우고 SQL Editor 에서 실행
-- 앱은 이 스케줄과 무관 — brand_deals 테이블을 읽기만 한다.
-- ============================================================

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- 재설정 대비 기존 잡 제거
select cron.unschedule('crawl-deals-daily')
where exists (select 1 from cron.job where jobname = 'crawl-deals-daily');

-- 매일 UTC 00:00 (= KST 09:00) 실행.
select cron.schedule(
  'crawl-deals-daily',
  '0 0 * * *',
  $$
  select net.http_post(
    url     := 'https://<project-ref>.supabase.co/functions/v1/crawl-deals',
    headers := jsonb_build_object(
      'Content-Type',   'application/json',
      'x-crawl-secret', '<CRAWL_SECRET>'
    ),
    timeout_milliseconds := 120000
  );
  $$
);

-- 확인: select * from cron.job;
-- 수동 1회 실행(테스트): 위 net.http_post 블록만 따로 실행.
