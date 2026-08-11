// imweb(아임웹) 쇼핑몰 파서 — 마이노멀(mynormal.shop).
// cafe24.ts 와 동일 계약: (cfg) => Promise<ParsedItem[]>.
//
// 구조(2026-08-11 확인):
//   목록: /?category={code}[&page=N] → 상품 링크 /shop_view/?idx={idx} 나열(가격 없음)
//   상세: /shop_view/?idx={idx} 에 임베드 JS 객체
//         {"prod_id":N,"prod_name":"…","prod_price":할인가,"prod_org_price":원가,"prod_image_url":"…"}
//   → 라라스윗처럼 상세를 타야 함(listHasPricing=false 취급).
import { DOMParser } from "https://deno.land/x/deno_dom@v0.1.45/deno-dom-wasm.ts";
import {
  type BrandConfig,
  classifyCategory,
  DEAL_TITLE_RE,
  PRICE_DIFF_THRESHOLD,
  USER_AGENT,
} from "./config.ts";
import type { ParsedItem } from "./types.ts";

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

async function fetchHtml(url: string): Promise<string> {
  const res = await fetch(url, {
    headers: {
      "User-Agent": USER_AGENT,
      "Accept": "text/html,application/xhtml+xml",
      "Accept-Language": "ko-KR,ko;q=0.9",
    },
    redirect: "follow",
  });
  if (!res.ok) throw new Error(`HTTP ${res.status} on ${url}`);
  return await res.text(); // imweb 은 UTF-8
}

/** 카테고리 페이지에서 상품 idx 수집. 24개/페이지라 새 idx 없을 때까지 페이지 순회. */
async function collectIdxs(
  baseUrl: string,
  code: string | number,
  delayMs: number,
): Promise<string[]> {
  const seen = new Set<string>();
  for (let page = 1; page <= 20; page++) {
    const url = `${baseUrl}/?category=${code}&page=${page}`;
    let html: string;
    try {
      html = await fetchHtml(url);
    } catch (_) {
      break;
    }
    const before = seen.size;
    for (const m of html.matchAll(/shop_view\/\?idx=(\d+)/g)) {
      seen.add(m[1]);
    }
    if (seen.size === before) break; // 새 상품 없으면 마지막 페이지
    await sleep(delayMs);
  }
  return [...seen];
}

/** 상세페이지 임베드 JS 객체 파싱. */
export function parseDetail(
  html: string,
  idx: string,
  baseUrl: string,
): Omit<ParsedItem, "is_deal" | "deal_signals" | "category"> | null {
  // 임베드 객체: {"prod_code":"…","prod_id":524,"prod_name":"…","prod_price":7900,
  //              "prod_org_price":9000,"prod_image_url":"…"}
  // 추천상품 객체와 섞이므로 이 idx 객체를 정확히 지목. 중괄호 없는 구간 통째로 잡아 JSON.parse.
  const re = new RegExp(
    '\\{[^{}]*"prod_id":' + idx + ',[^{}]*"prod_image_url":"(?:[^"\\\\]|\\\\.)*?"\\}',
  );
  const m = re.exec(html);
  if (!m) return null;

  let obj: {
    prod_name?: string;
    prod_price?: number;
    prod_org_price?: number;
    prod_image_url?: string;
  };
  try {
    obj = JSON.parse(m[0]);
  } catch (_) {
    return null;
  }

  const name = (obj.prod_name ?? "").trim();
  const sale = typeof obj.prod_price === "number" ? obj.prod_price : null;
  if (!name || sale == null || sale <= 0) return null;

  const org = typeof obj.prod_org_price === "number" ? obj.prod_org_price : null;
  const listPrice = org != null && org > sale ? org : null;

  // 품절: 구매영역의 품절/일시품절 표기 (리뷰 등 오탐 피해 상단 일부만 검사)
  const doc = new DOMParser().parseFromString(html, "text/html");
  const soldZone =
    doc?.querySelector(".prod_buy, .shop_detail, #product_detail, .btn_buy")
      ?.textContent ?? html.slice(0, 6000);
  const isSoldout = /품절|일시\s*품절|sold\s*out/i.test(soldZone);

  const meta = (p: string) =>
    doc?.querySelector(`meta[property="${p}"]`)?.getAttribute("content") ?? null;
  const summary = meta("og:description")?.trim() || null;

  return {
    external_id: idx,
    name,
    summary: summary && summary.length <= 300 ? summary : null,
    list_price: listPrice,
    sale_price: sale,
    product_url: `${baseUrl}/shop_view/?idx=${idx}`,
    image_url: obj.prod_image_url ? obj.prod_image_url.replace(/\\\//g, "/") : null,
    is_soldout: isSoldout,
  };
}

function judgeDeal(
  item: { name: string; list_price: number | null; sale_price: number },
  inDealCategory: boolean,
): { isDeal: boolean; signals: string[] } {
  const signals: string[] = [];
  if (inDealCategory) signals.push("category");
  if (DEAL_TITLE_RE.test(item.name)) signals.push("title_tag");
  if (
    item.list_price != null &&
    item.list_price > 0 &&
    item.sale_price < item.list_price * (1 - PRICE_DIFF_THRESHOLD)
  ) {
    signals.push("price_diff");
  }
  return { isDeal: signals.length > 0, signals };
}

export async function crawlBrand(cfg: BrandConfig): Promise<ParsedItem[]> {
  const dealSet = new Set<string>();
  const allIdx = new Set<string>();

  const cats = [
    ...cfg.dealCategories.map((c) => ({ code: c, isDeal: true })),
    ...cfg.catalogCategories.map((c) => ({ code: c, isDeal: false })),
  ];

  for (const { code, isDeal } of cats) {
    const idxs = await collectIdxs(cfg.baseUrl, code, cfg.detailDelayMs);
    for (const idx of idxs) {
      if (isDeal) dealSet.add(idx);
      allIdx.add(idx);
    }
    await sleep(cfg.detailDelayMs);
  }

  const items: ParsedItem[] = [];
  for (const idx of allIdx) {
    let base: Omit<ParsedItem, "is_deal" | "deal_signals" | "category"> | null =
      null;
    try {
      const html = await fetchHtml(`${cfg.baseUrl}/shop_view/?idx=${idx}`);
      base = parseDetail(html, idx, cfg.baseUrl);
    } catch (err) {
      console.warn(`[${cfg.slug}] detail ${idx} 실패: ${err}`);
    }
    await sleep(cfg.detailDelayMs);
    if (!base) continue;

    const { isDeal, signals } = judgeDeal(base, dealSet.has(idx));
    items.push({
      ...base,
      category: classifyCategory(base.name),
      is_deal: isDeal,
      deal_signals: signals,
    });
  }

  return items;
}
