/**
 * 배포 전 셀렉터 검증용. DB 없이 파싱 결과만 콘솔에 찍는다.
 *
 *   deno run --allow-net --allow-read scripts/probe.ts nuldam
 *   deno run --allow-net --allow-read scripts/probe.ts lalasweet
 *   deno run --allow-net --allow-read scripts/probe.ts          # 둘 다
 *
 * 사이트 개편이 의심될 때 제일 먼저 돌려볼 것.
 */
import { BRANDS } from "../supabase/functions/crawl-deals/config.ts";
import { crawlBrand } from "../supabase/functions/crawl-deals/crawlers.ts";

const only = Deno.args[0];
const targets = only ? BRANDS.filter((b) => b.slug === only) : BRANDS;

if (targets.length === 0) {
  console.error(`알 수 없는 브랜드: ${only}`);
  Deno.exit(1);
}

for (const cfg of targets) {
  console.log(`\n${"=".repeat(64)}`);
  console.log(`${cfg.displayName} (${cfg.slug})  listHasPricing=${cfg.listHasPricing}`);
  console.log("=".repeat(64));

  const t0 = performance.now();
  const items = await crawlBrand(cfg);
  const elapsed = ((performance.now() - t0) / 1000).toFixed(1);

  const deals = items.filter((i) => i.is_deal);
  console.log(`총 ${items.length}건 / 특가 ${deals.length}건 / ${elapsed}s\n`);

  // 진단 신호들
  const noListPrice = items.filter((i) => i.list_price === null).length;
  const noImage = items.filter((i) => !i.image_url).length;
  console.log(`⚠️ 원가 없음: ${noListPrice}건, 이미지 없음: ${noImage}건`);
  if (items.length === 0) {
    console.log("❌ 0건 파싱 → 셀렉터가 깨졌거나 차단된 상태입니다.");
  }

  console.log("\n--- 특가 목록 (할인율순) ---");
  for (const d of deals.sort((a, b) => {
    const ra = a.list_price ? 1 - a.sale_price / a.list_price : 0;
    const rb = b.list_price ? 1 - b.sale_price / b.list_price : 0;
    return rb - ra;
  })) {
    const rate = d.list_price
      ? `${Math.round((1 - d.sale_price / d.list_price) * 100)}%`.padStart(4)
      : "   -";
    const from = d.list_price ? `${d.list_price.toLocaleString()}원 → ` : "";
    console.log(
      `${rate}  ${from}${d.sale_price.toLocaleString()}원  ` +
      `[${d.deal_signals.join(",")}]  ${d.name}`,
    );
  }

  // 특가로 안 잡힌 것 중 이름에 대괄호 태그가 있는지 (판별 로직 누락 점검)
  const missed = items.filter(
    (i) => !i.is_deal && /\[[^\]]+\]/.test(i.name),
  );
  if (missed.length) {
    console.log("\n--- 특가 미판정인데 대괄호 태그가 있는 상품 (regex 보강 검토) ---");
    for (const m of missed) console.log(`   ${m.name}`);
  }
}
