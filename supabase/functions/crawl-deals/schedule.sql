-- ============================================================
-- crawl-deals 자동 실행 스케줄 (pg_cron + pg_net) — 하루 1회
--
-- 실행 순서
--   ① crawl-deals 함수 배포: supabase functions deploy crawl-deals --no-verify-jwt
--   ② 시크릿 등록:          supabase secrets set CRAWL_SECRET="<값>"
--   ③ 아래 SQL 을 SQL Editor 에서 실행 (<project-ref>, <CRAWL_SECRET> 채워서)
--   ④ 켜기:                 select set_auto_update(true);
--
-- 시크릿은 Vault 에 저장하고 크론은 참조만 한다(평문 하드코딩 금지).
--   기존 sync-lalasweet-prices-daily 잡과 동일한 패턴.
--
-- ⚠️ 브랜드별로 나눠 호출한다.
--    3개를 한 호출에 몰면 HTML 파싱 누적으로 Edge Function 컴퓨트 한도를 넘어
--    WORKER_RESOURCE_LIMIT 로 실패한다(실측). 단독 실행은 각각 4~45초로 여유.
--
-- 안전장치: crawl_settings.auto_update_enabled 가 false 면 호출돼도 no-op.
--          켜기 select set_auto_update(true); / 끄기 select set_auto_update(false);
-- ============================================================

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- ------------------------------------------------------------
-- 1) 시크릿을 Vault 에 저장 (최초 1회. 값 변경 시 vault.update_secret 사용)
-- ------------------------------------------------------------
select vault.create_secret('<CRAWL_SECRET>', 'crawl_deals_secret')
where not exists (
  select 1 from vault.decrypted_secrets where name = 'crawl_deals_secret'
);

-- ------------------------------------------------------------
-- 2) 기존 잡 정리 (재실행 안전. 구버전 통합 잡 포함)
-- ------------------------------------------------------------
select cron.unschedule(jobname)
from cron.job
where jobname in (
  'crawl-deals-daily',            -- 구버전(3브랜드 통합)
  'crawl-deals-lalasweet',
  'crawl-deals-nuldam',
  'crawl-deals-mynormal'
);

-- ------------------------------------------------------------
-- 3) 브랜드별 잡 (UTC 00:00/00:05/00:10 = KST 09:00/09:05/09:10)
-- ------------------------------------------------------------
select cron.schedule('crawl-deals-nuldam', '0 0 * * *', $$
  select net.http_post(
    url     := 'https://<project-ref>.supabase.co/functions/v1/crawl-deals?brand=nuldam',
    headers := jsonb_build_object(
      'Content-Type',   'application/json',
      'x-crawl-secret', (select decrypted_secret from vault.decrypted_secrets
                         where name = 'crawl_deals_secret')
    ),
    timeout_milliseconds := 120000
  );
$$);

select cron.schedule('crawl-deals-lalasweet', '5 0 * * *', $$
  select net.http_post(
    url     := 'https://<project-ref>.supabase.co/functions/v1/crawl-deals?brand=lalasweet',
    headers := jsonb_build_object(
      'Content-Type',   'application/json',
      'x-crawl-secret', (select decrypted_secret from vault.decrypted_secrets
                         where name = 'crawl_deals_secret')
    ),
    timeout_milliseconds := 120000
  );
$$);

select cron.schedule('crawl-deals-mynormal', '10 0 * * *', $$
  select net.http_post(
    url     := 'https://<project-ref>.supabase.co/functions/v1/crawl-deals?brand=mynormal',
    headers := jsonb_build_object(
      'Content-Type',   'application/json',
      'x-crawl-secret', (select decrypted_secret from vault.decrypted_secrets
                         where name = 'crawl_deals_secret')
    ),
    timeout_milliseconds := 120000
  );
$$);

-- ------------------------------------------------------------
-- 확인 / 운영
-- ------------------------------------------------------------
-- 등록 확인:   select jobname, schedule, active from cron.job order by jobname;
-- 실행 결과:   select brand_slug, status, parsed_count, deal_count, started_at
--              from crawl_runs order by started_at desc limit 10;
-- 잡 해제:     select cron.unschedule('crawl-deals-nuldam');
-- 수동 1회:    url 에 &force=true 를 붙여 net.http_post 블록만 실행(플래그 무시).
