/**
 * 두 브랜드를 크롤해 apply_crawl_result 호출 seed SQL 생성. (crawl-deals 함수 배포 없이
 * SQL Editor 로 brand_deals 를 채워 앱에서 바로 확인용.)
 *
 *   deno run --allow-net --allow-read --allow-write scripts/deals_to_seed.ts
 *
 * 출력: scripts/output/brand_deals_seed.sql
 * ⚠️ 0007_brand_deals.sql (테이블+RPC) 먼저 적용 후 실행.
 */
import { BRANDS } from "../supabase/functions/crawl-deals/config.ts";
import { crawlBrand, type ParsedItem } from "../supabase/functions/crawl-deals/crawlers.ts";

const outPath = new URL("./output/brand_deals_seed.sql", import.meta.url).pathname;

// SQL 문자열 리터럴용: 작은따옴표 이중화
const sqlStr = (s: string) => "'" + s.replace(/'/g, "''") + "'";

const lines: string[] = [
  "-- 자동 생성 (scripts/deals_to_seed.ts). brand_deals 초기 적재용.",
  "-- 0007_brand_deals.sql 먼저 적용 필요. 재실행 가능(apply_crawl_result 는 upsert).",
  "begin;",
];

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

  // ParsedItem[] 를 그대로 jsonb 로 넘긴다 (RPC 가 필드명 그대로 읽음).
  const json = JSON.stringify(items);
  lines.push(
    `select apply_crawl_result(${sqlStr(cfg.slug)}, ${sqlStr(json)}::jsonb);`,
  );
}

lines.push("commit;");
await Deno.writeTextFile(outPath, lines.join("\n") + "\n");
console.error(`\n✅ 저장: ${outPath}`);
