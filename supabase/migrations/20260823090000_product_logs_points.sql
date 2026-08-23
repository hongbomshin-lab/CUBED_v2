-- 슈가포인트: 기록 시점에 계산된 '아낀 설탕 g' 스냅샷.
-- 기준표는 앱 상수(lib/core/sugar_baselines.dart, 근거 docs/sugar-baselines.md).
-- 기존 행은 0 유지 (기능 도입 전 기록에는 소급 적립하지 않음).
alter table public.product_logs
  add column if not exists points integer not null default 0
  check (points >= 0);

comment on column public.product_logs.points is
  '아낀 설탕 g (일반 제품 기준값 - 제품 당류, 기록 시점 스냅샷)';
