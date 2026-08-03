-- 매일 03:10 KST(18:10 UTC)에 라라스윗 가격 동기화 Edge Function을 호출한다.
-- 아래 Vault secret은 배포 시 1회 생성해야 한다.
-- zero_dot_project_url, zero_dot_publishable_key, lalasweet_sync_secret
create extension if not exists pg_cron;
create extension if not exists pg_net;

do $$
declare
  existing_job_id bigint;
begin
  select jobid into existing_job_id
  from cron.job
  where jobname = 'sync-lalasweet-prices-daily';

  if existing_job_id is not null then
    perform cron.unschedule(existing_job_id);
  end if;
end
$$;

select cron.schedule(
  'sync-lalasweet-prices-daily',
  '10 18 * * *',
  $cron$
  select net.http_post(
    url := (
      select decrypted_secret
      from vault.decrypted_secrets
      where name = 'zero_dot_project_url'
    ) || '/functions/v1/sync-lalasweet-prices',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (
        select decrypted_secret
        from vault.decrypted_secrets
        where name = 'zero_dot_publishable_key'
      ),
      'apikey', (
        select decrypted_secret
        from vault.decrypted_secrets
        where name = 'zero_dot_publishable_key'
      ),
      'x-sync-secret', (
        select decrypted_secret
        from vault.decrypted_secrets
        where name = 'lalasweet_sync_secret'
      )
    ),
    body := '{}'::jsonb
  );
  $cron$
);
