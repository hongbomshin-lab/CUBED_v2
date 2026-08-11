-- ============================================================
-- crawl-deals 자동 실행 스케줄 (pg_cron + pg_net) — 하루 1회
-- 실행 순서: ① crawl-deals 함수 배포(--no-verify-jwt) ② 시크릿(CRAWL_SECRET) 설정
--           ③ 아래 <project-ref>/<CRAWL_SECRET> 채우고 SQL Editor 에서 실행
-- 앱은 이 스케줄과 무관 — brand_deals 테이블을 읽기만 한다.
--
-- ⚠️ 브랜드별로 나눠 호출한다.
--    3개를 한 호출에 몰면 HTML 파싱 누적으로 Edge Function 컴퓨트 한도를 넘어
--    WORKER_RESOURCE_LIMIT 로 실패한다(실측). 단독 실행은 각각 4~45초로 여유.
--    KST 09:00 / 09:05 / 09:10 로 5분씩 띄워 실행.
--
-- 안전장치: crawl_settings.auto_update_enabled 가 false 면 호출돼도 no-op.
--          켜기: select set_auto_update(true);   끄기: select set_auto_update(false);
-- ============================================================

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- 재설정 대비 기존 잡 제거(구버전 통합 잡 포함)
select cron.unschedule(jobname)
from cron.job
where jobname in (
  'crawl-deals-daily',            -- 구버전(3브랜드 통합) — 있으면 제거
  'crawl-deals-lalasweet',
  'crawl-deals-nuldam',
  'crawl-deals-mynormal'
);

-- 브랜드별 잡 (UTC 00:00/00:05/00:10 = KST 09:00/09:05/09:10)
select cron.schedule('crawl-deals-nuldam', '0 0 * * *', $$
  select net.http_post(
    url     := 'https://<project-ref>.supabase.co/functions/v1/crawl-deals?brand=nuldam',
    headers := jsonb_build_object(
      'Content-Type',   'application/json',
      'x-crawl-secret', '<CRAWL_SECRET>'
    ),
    timeout_milliseconds := 120000
  );
$$);

select cron.schedule('crawl-deals-lalasweet', '5 0 * * *', $$
  select net.http_post(
    url     := 'https://<project-ref>.supabase.co/functions/v1/crawl-deals?brand=lalasweet',
    headers := jsonb_build_object(
      'Content-Type',   'application/json',
      'x-crawl-secret', '<CRAWL_SECRET>'
    ),
    timeout_milliseconds := 120000
  );
$$);

select cron.schedule('crawl-deals-mynormal', '10 0 * * *', $$
  select net.http_post(
    url     := 'https://<project-ref>.supabase.co/functions/v1/crawl-deals?brand=mynormal',
    headers := jsonb_build_object(
      'Content-Type',   'application/json',
      'x-crawl-secret', '<CRAWL_SECRET>'
    ),
    timeout_milliseconds := 120000
  );
$$);

-- 확인:   select jobname, schedule, active from cron.job order by jobname;
-- 해제:   select cron.unschedule('crawl-deals-nuldam');  -- 등
-- 수동 1회: 위 net.http_post 블록에 &force=true 붙여 실행(플래그 무시).
