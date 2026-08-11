/**
 * 두 브랜드(라라스윗·널담)를 크롤해 특가 정보를 CSV로 저장. DB 불필요.
 *
 *   deno run --allow-net --allow-read --allow-write scripts/deals_to_csv.ts [출력경로]
 *
 * 기본 출력: scripts/output/brand_deals.csv
 */
import { BRANDS } from "../supabase/functions/crawl-deals/config.ts";
import { crawlBrand, type ParsedItem } from "../supabase/functions/crawl-deals/crawlers.ts";

const outPath = Deno.args[0] ??
  new URL("./output/brand_deals.csv", import.meta.url).pathname;

function csvCell(v: unknown): string {
  const s = v == null ? "" : String(v);
  // 콤마·따옴표·개행 포함 시 큰따옴표로 감싸고 내부 따옴표는 이중화
  return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

const HEADER = [
  "brand", "external_id", "name", "list_price", "sale_price",
  "discount_rate", "is_deal", "deal_signals", "is_soldout",
  "summary", "product_url", "image_url",
];

const rows: string[] = [HEADER.join(",")];

for (const cfg of BRANDS) {
  console.error(`크롤 중: ${cfg.displayName} …`);
  let items: ParsedItem[] = [];
  try {
    items = await crawlBrand(cfg);
  } catch (err) {
    console.error(`  실패: ${err}`);
    continue;
  }
  const deals = items.filter((i) => i.is_deal).length;
  console.error(`  ${cfg.displayName}: 총 ${items.length}건 / 특가 ${deals}건`);

  for (const i of items) {
    const rate = i.list_price && i.list_price > 0 && i.sale_price < i.list_price
      ? Math.round((1 - i.sale_price / i.list_price) * 100)
      : "";
    rows.push([
      cfg.displayName,
      i.external_id,
      i.name,
      i.list_price ?? "",
      i.sale_price,
      rate,
      i.is_deal ? "Y" : "N",
      i.deal_signals.join("|"),
      i.is_soldout ? "Y" : "N",
      i.summary ?? "",
      i.product_url,
      i.image_url ?? "",
    ].map(csvCell).join(","));
  }
}

// 엑셀 한글 깨짐 방지용 UTF-8 BOM
await Deno.writeTextFile(outPath, "﻿" + rows.join("\n") + "\n");
console.error(`\n✅ 저장: ${outPath} (${rows.length - 1}행)`);
