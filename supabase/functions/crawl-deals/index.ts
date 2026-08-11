// CUBED 브랜드 특가 수집 Edge Function (Deno)
// 라라스윗·널담 공식몰(카페24, SSR)을 fetch+HTML 파싱으로 긁어 brand_deals 에 반영.
// 앱/웹은 DB만 읽는다. 이 함수는 수집·적재만.
//
// 배포: supabase functions deploy crawl-deals --no-verify-jwt
//       (project-ref aqhfddvvxnakgkdtirem. pg_cron+pg_net 호출이라 JWT 대신 CRAWL_SECRET 헤더로 보호)
// 시크릿(대시보드 Edge Functions → Secrets, 코드/레포엔 절대 넣지 않음):
//   SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY (자동 주입) · CRAWL_SECRET · DISCORD_WEBHOOK_URL(선택)
// 스케줄: pg_cron 으로 하루 1회(KST 09시 = UTC 00시) 호출. x-crawl-secret 헤더 필수.
//         설정 SQL: supabase/functions/crawl-deals/schedule.sql

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { BRANDS } from "./config.ts";
import { crawlBrand, type ParsedItem } from "./crawlers.ts";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

const DISCORD_WEBHOOK = Deno.env.get("DISCORD_WEBHOOK_URL");

async function notify(message: string) {
  if (!DISCORD_WEBHOOK) return;
  try {
    await fetch(DISCORD_WEBHOOK, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ content: message.slice(0, 1900) }),
    });
  } catch (_) { /* 알림 실패가 크롤을 죽이면 안 됨 */ }
}

async function sha256(text: string): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return Array.from(new Uint8Array(buf))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

async function runBrand(cfg: typeof BRANDS[number]) {
  const startedAt = Date.now();

  const { count: prevCount } = await supabase
    .from("brand_deals")
    .select("*", { count: "exact", head: true })
    .eq("brand_slug", cfg.slug)
    .is("ended_at", null);

  let items: ParsedItem[];
  try {
    items = await crawlBrand(cfg);
  } catch (err) {
    const msg = String(err);
    await supabase.from("crawl_runs").insert({
      brand_slug: cfg.slug,
      status: "error",
      error_message: msg,
      prev_count: prevCount ?? null,
      duration_ms: Date.now() - startedAt,
    });
    await notify(`🔴 **${cfg.displayName}** 크롤 실패\n\`${msg}\``);
    return { brand: cfg.slug, status: "error", error: msg };
  }

  const dealCount = items.filter((i) => i.is_deal).length;

  // ── 안전 장치: 파싱 결과가 급감하면 커밋하지 않는다 ──────────────
  // 크롤러의 1위 실패 모드는 "에러 없이 0개 파싱"이다.
  // 그대로 반영하면 전 상품이 ended_at 처리되어 앱이 빈다.
  if ((prevCount ?? 0) > 5 && items.length < (prevCount ?? 0) * cfg.minRetainRatio) {
    await supabase.from("crawl_runs").insert({
      brand_slug: cfg.slug,
      status: "aborted",
      parsed_count: items.length,
      deal_count: dealCount,
      prev_count: prevCount,
      error_message: "sanity check failed",
      duration_ms: Date.now() - startedAt,
    });
    await notify(
      `⚠️ **${cfg.displayName}** 파싱 급감: ${prevCount} → ${items.length}건. ` +
      `커밋 중단하고 기존 데이터 유지. 셀렉터 확인 필요.`,
    );
    return { brand: cfg.slug, status: "aborted", parsed: items.length, prev: prevCount };
  }

  // ── 원본 스냅샷 (해시가 직전과 같으면 skip) ────────────────────
  const payload = JSON.stringify(items);
  const hash = await sha256(payload);
  const { data: last } = await supabase
    .from("deal_snapshots")
    .select("raw_hash")
    .eq("brand_slug", cfg.slug)
    .order("crawled_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (last?.raw_hash !== hash) {
    await supabase.from("deal_snapshots").insert({
      brand_slug: cfg.slug,
      source_url: cfg.baseUrl,
      raw_hash: hash,
      raw_payload: items,
    });
  }

  // ── 반영 (원자적 upsert + 이력 append + 미등장 종료처리) ──────────
  const { data: result, error } = await supabase.rpc("apply_crawl_result", {
    p_brand_slug: cfg.slug,
    p_items: items,
  });

  if (error) {
    await supabase.from("crawl_runs").insert({
      brand_slug: cfg.slug,
      status: "error",
      parsed_count: items.length,
      deal_count: dealCount,
      prev_count: prevCount,
      error_message: error.message,
      duration_ms: Date.now() - startedAt,
    });
    await notify(`🔴 **${cfg.displayName}** DB 반영 실패\n\`${error.message}\``);
    return { brand: cfg.slug, status: "error", error: error.message };
  }

  const stats = Array.isArray(result) ? result[0] : result;

  await supabase.from("crawl_runs").insert({
    brand_slug: cfg.slug,
    status: "ok",
    parsed_count: items.length,
    deal_count: dealCount,
    prev_count: prevCount,
    duration_ms: Date.now() - startedAt,
  });

  // 새 특가 / 가격 변동이 있으면 알림
  if ((stats?.inserted ?? 0) > 0 || (stats?.price_changed ?? 0) > 0) {
    await notify(
      `🟢 **${cfg.displayName}** 갱신: 신규 ${stats?.inserted ?? 0} · ` +
      `가격변동 ${stats?.price_changed ?? 0} · 종료 ${stats?.ended ?? 0} ` +
      `(특가 ${dealCount}/${items.length}건)`,
    );
  }

  return { brand: cfg.slug, status: "ok", parsed: items.length, deals: dealCount, ...stats };
}

Deno.serve(async (req) => {
  // pg_cron 이외의 호출 차단
  const secret = Deno.env.get("CRAWL_SECRET");
  if (secret && req.headers.get("x-crawl-secret") !== secret) {
    return new Response("forbidden", { status: 403 });
  }

  const url = new URL(req.url);
  const only = url.searchParams.get("brand");
  const targets = only ? BRANDS.filter((b) => b.slug === only) : BRANDS;

  // 브랜드별 독립 실행 → 하나가 깨져도 나머지는 정상 갱신
  const results = [];
  for (const cfg of targets) {
    results.push(await runBrand(cfg));
  }

  return new Response(JSON.stringify({ results }, null, 2), {
    headers: { "Content-Type": "application/json" },
  });
});
