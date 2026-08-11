// 카페24(SSR) 쇼핑몰 파서 — 목록/상세/특가판별/브랜드크롤.
// 헤드리스 브라우저 불필요. fetch + HTML 파싱으로 충분.
import { DOMParser, type Element } from "https://deno.land/x/deno_dom@v0.1.45/deno-dom-wasm.ts";
import {
  type BrandConfig,
  classifyCategory,
  DEAL_TITLE_RE,
  PRICE_DIFF_THRESHOLD,
  USER_AGENT,
} from "./config.ts";
import type { ParsedItem } from "./types.ts";

export type { ParsedItem }; // 하위 호환 재수출

// ------------------------------------------------------------------
// 유틸
// ------------------------------------------------------------------

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

  // 카페24 쇼핑몰 중 일부는 EUC-KR. Content-Type 보고 디코딩.
  const ct = res.headers.get("content-type") ?? "";
  const buf = new Uint8Array(await res.arrayBuffer());
  const charset = /charset=([\w-]+)/i.exec(ct)?.[1]?.toLowerCase() ?? "utf-8";
  const enc = charset === "euc-kr" || charset === "ks_c_5601-1987" ? "euc-kr" : "utf-8";
  return new TextDecoder(enc).decode(buf);
}

/** "22,900원" / "26900원" / "₩22,900" → 22900 (순수 숫자열 파싱) */
function toWon(raw: string | null | undefined): number | null {
  if (!raw) return null;
  const digits = raw.replace(/[^\d]/g, "");
  if (!digits) return null;
  const n = parseInt(digits, 10);
  return Number.isFinite(n) && n > 0 ? n : null;
}

/**
 * 노이즈 섞인 텍스트에서 첫 번째 "가격원" 토큰만 뽑는다.
 * 목록 li 는 "할인판매가 20,000원 적립 53원" 처럼 뒤에 적립금 등이 붙어
 * 전체 숫자를 이으면 2000053 같은 값이 나온다 → 첫 금액만 취한다.
 * '원' 표기가 없으면 순수 숫자 파싱으로 폴백.
 */
function firstWon(raw: string | null | undefined): number | null {
  if (!raw) return null;
  const m = /([\d,]+)\s*원/.exec(raw);
  return m ? toWon(m[1]) : toWon(raw);
}

/**
 * 카페24 상품 링크에서 product_no 추출.
 * 두 가지 URL 형태를 모두 지원 → 테마와 무관하게 동작하는 가장 견고한 앵커.
 *   A) /product/detail.html?product_no=239&cate_no=113&display_group=1
 *   B) /product/{slug}/2389/category/62/display/1/
 */
export function extractProductNo(href: string): string | null {
  const a = /[?&]product_no=(\d+)/.exec(href);
  if (a) return a[1];
  const b = /\/product\/[^/]+\/(\d+)\/category\//.exec(href);
  if (b) return b[1];
  return null;
}

function absolute(baseUrl: string, href: string): string {
  try {
    return new URL(href, baseUrl).toString();
  } catch {
    return href;
  }
}

/** 카테고리 파라미터를 뺀 정규 상품 URL (중복 방지) */
function canonicalProductUrl(baseUrl: string, productNo: string): string {
  return `${baseUrl}/product/detail.html?product_no=${productNo}`;
}

// ------------------------------------------------------------------
// 목록 페이지
// ------------------------------------------------------------------

export type ListEntry = {
  productNo: string;
  /** 목록에서 뽑힌 정보 (listHasPricing=true 일 때만 신뢰) */
  name?: string;
  summary?: string;
  listPrice?: number | null;
  salePrice?: number | null;
  imageUrl?: string | null;
};

/**
 * 목록 페이지에서 상품을 뽑는다.
 * 1차: 카페24 표준 링크서(li[id^=anchorBoxId_])
 * 2차: 실패 시 페이지 내 전체 앵커에서 product_no 정규식 스캔 (커스텀 테마 대응)
 */
export function parseListPage(
  html: string,
  baseUrl: string,
  hasPricing: boolean,
): ListEntry[] {
  const doc = new DOMParser().parseFromString(html, "text/html");
  if (!doc) return [];

  const out = new Map<string, ListEntry>();

  // --- 1차: 표준 링크서 ---
  const boxes = Array.from(doc.querySelectorAll('li[id^="anchorBoxId_"]')) as Element[];
  for (const box of boxes) {
    const id = box.getAttribute("id") ?? "";
    const productNo = /anchorBoxId_(\d+)/.exec(id)?.[1];
    if (!productNo) continue;

    const entry: ListEntry = { productNo };

    const nameEl = box.querySelector(".description .name a, .name a, span.title");
    if (nameEl) {
      entry.name = nameEl.textContent.replace(/^\s*상품명\s*:\s*/, "").trim();
    }

    const img = box.querySelector("img");
    const src = img?.getAttribute("src");
    if (src) entry.imageUrl = absolute(baseUrl, src);

    if (hasPricing) {
      // <ul class="spec"><li><strong class="title">판매가</strong><span>22,900원</span></li>...
      for (const li of Array.from(box.querySelectorAll("ul li")) as Element[]) {
        const label = li.querySelector("strong, .title")?.textContent.trim() ?? "";
        const value = li.textContent.replace(label, "").trim();
        // firstWon: 뒤에 붙는 적립금 등 노이즈를 배제하고 첫 금액만.
        if (/^판매가$/.test(label)) entry.listPrice = firstWon(value);
        else if (/할인판매가/.test(label)) entry.salePrice = firstWon(value);
        else if (/^상품요약정보$/.test(label)) entry.summary = value;
        else if (/^소비자가$/.test(label) && entry.listPrice == null) {
          entry.listPrice = firstWon(value);
        }
      }
      // 할인이 없으면 판매가가 곧 결제가
      if (entry.salePrice == null && entry.listPrice != null) {
        entry.salePrice = entry.listPrice;
        entry.listPrice = null;
      }
    }

    out.set(productNo, entry);
  }

  // --- 2차: 커스텀 테마 폴백 (라라스윗처럼 anchorBoxId 가 없는 경우) ---
  if (out.size === 0) {
    for (const a of Array.from(doc.querySelectorAll("a[href]")) as Element[]) {
      const href = a.getAttribute("href") ?? "";
      const productNo = extractProductNo(href);
      if (!productNo || out.has(productNo)) continue;
      out.set(productNo, {
        productNo,
        name: a.textContent.trim() || undefined,
      });
    }
  }

  return Array.from(out.values());
}

/** 페이지네이션: ?page=N 링크에서 최대 페이지 수 */
export function maxPageOf(html: string): number {
  const doc = new DOMParser().parseFromString(html, "text/html");
  if (!doc) return 1;
  let max = 1;
  for (const a of Array.from(doc.querySelectorAll("a[href]")) as Element[]) {
    const n = /[?&]page=(\d+)/.exec(a.getAttribute("href") ?? "")?.[1];
    if (n) max = Math.max(max, parseInt(n, 10));
  }
  return Math.min(max, 20); // 안전 상한
}

// ------------------------------------------------------------------
// 상세 페이지
// ------------------------------------------------------------------

/**
 * 카페24 상세페이지 표준 요소. 테마를 갈아입어도 이 ID들은 대체로 살아남는다.
 *   #span_product_price_custom → 소비자가
 *   #span_product_price_text   → 판매가
 *   #span_product_price_sale   → 할인판매가
 * 없으면 og:* 메타로 폴백.
 */
export function parseDetailPage(
  html: string,
  baseUrl: string,
  productNo: string,
): Omit<ParsedItem, "is_deal" | "deal_signals" | "category"> | null {
  const doc = new DOMParser().parseFromString(html, "text/html");
  if (!doc) return null;

  const meta = (prop: string) =>
    doc.querySelector(`meta[property="${prop}"]`)?.getAttribute("content") ?? null;

  const name =
    doc.querySelector("#span_product_name, .headingArea h2, .infoArea .name")
      ?.textContent.trim() ||
    meta("og:title")?.replace(/\s*-\s*[^-]*$/, "").trim() ||
    "";

  if (!name) return null;

  // 표준 테마: 스팬에 가격이 들어있음. 커스텀 테마(라라스윗): 스팬이 비고 og 메타에 있음.
  const custom = firstWon(doc.querySelector("#span_product_price_custom")?.textContent);
  const text = firstWon(doc.querySelector("#span_product_price_text")?.textContent);
  const sale = firstWon(doc.querySelector("#span_product_price_sale")?.textContent);
  const ogList = toWon(meta("product:price:amount"));       // 판매가(할인 전)
  const ogSale = toWon(meta("product:sale_price:amount"));  // 할인판매가

  // 결제가 우선순위: 할인판매가span > og sale > 판매가span > og price
  const salePrice = sale ?? ogSale ?? text ?? ogList;
  if (salePrice == null) return null;

  // 할인 전 가격: 할인이 있으면 판매가(text/og) 우선, 없으면 소비자가.
  // 스팬이 비면 og price 로 폴백. sale 보다 높아야 원가로 인정.
  let listPrice: number | null =
    sale != null || ogSale != null ? (text ?? ogList ?? custom) : (custom ?? ogList);
  if (listPrice != null && listPrice <= salePrice) listPrice = null;

  const bodyText = doc.querySelector("body")?.textContent ?? "";
  const isSoldout =
    /품절|SOLD\s*OUT/i.test(
      doc.querySelector(".headingArea, .infoArea, #contents")?.textContent ?? bodyText.slice(0, 4000),
    );

  const image = meta("og:image") ?? doc.querySelector(".keyImg img, #zoom1")?.getAttribute("src");

  const summary =
    doc.querySelector("#span_product_name + .summary, .infoArea .summary")?.textContent.trim() ||
    meta("og:description")?.trim() ||
    null;

  return {
    external_id: productNo,
    name,
    summary: summary && summary.length <= 300 ? summary : null,
    list_price: listPrice,
    sale_price: salePrice,
    product_url: canonicalProductUrl(baseUrl, productNo),
    image_url: image ? absolute(baseUrl, image) : null,
    is_soldout: isSoldout,
  };
}

// ------------------------------------------------------------------
// 특가 판별
// ------------------------------------------------------------------

export function judgeDeal(
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

// ------------------------------------------------------------------
// 브랜드 단위 수집
// ------------------------------------------------------------------

export async function crawlBrand(cfg: BrandConfig): Promise<ParsedItem[]> {
  const dealSet = new Set<string>();
  const entries = new Map<string, ListEntry>();

  const categories = [
    ...cfg.dealCategories.map((c) => ({ cateNo: c, isDeal: true })),
    ...cfg.catalogCategories.map((c) => ({ cateNo: c, isDeal: false })),
  ];

  for (const { cateNo, isDeal } of categories) {
    const first = `${cfg.baseUrl}/product/list.html?cate_no=${cateNo}`;
    const html = await fetchHtml(first);
    const pages = maxPageOf(html);

    for (let p = 1; p <= pages; p++) {
      const pageHtml =
        p === 1 ? html : await fetchHtml(`${first}&page=${p}`);
      for (const e of parseListPage(pageHtml, cfg.baseUrl, cfg.listHasPricing)) {
        if (isDeal) dealSet.add(e.productNo);
        const prev = entries.get(e.productNo);
        // 특가 카테고리 쪽 정보를 우선 (가격이 더 정확)
        entries.set(e.productNo, prev && !isDeal ? prev : { ...prev, ...e });
      }
      if (p < pages) await sleep(cfg.detailDelayMs);
    }
    await sleep(cfg.detailDelayMs);
  }

  const items: ParsedItem[] = [];

  for (const e of entries.values()) {
    let base: Omit<ParsedItem, "is_deal" | "deal_signals" | "category"> | null = null;

    if (cfg.listHasPricing && e.name && e.salePrice != null) {
      // fast-path: 목록에 가격이 다 있음 (널담)
      base = {
        external_id: e.productNo,
        name: e.name,
        summary: e.summary ?? null,
        list_price: e.listPrice ?? null,
        sale_price: e.salePrice,
        product_url: canonicalProductUrl(cfg.baseUrl, e.productNo),
        image_url: e.imageUrl ?? null,
        is_soldout: false,
      };
    } else {
      // slow-path: 상세페이지 타야 함 (라라스윗)
      try {
        const html = await fetchHtml(canonicalProductUrl(cfg.baseUrl, e.productNo));
        base = parseDetailPage(html, cfg.baseUrl, e.productNo);
      } catch (err) {
        console.warn(`[${cfg.slug}] detail ${e.productNo} 실패: ${err}`);
      }
      await sleep(cfg.detailDelayMs);
    }

    if (!base) continue;

    const { isDeal, signals } = judgeDeal(base, dealSet.has(e.productNo));
    items.push({
      ...base,
      category: classifyCategory(base.name),
      is_deal: isDeal,
      deal_signals: signals,
    });
  }

  return items;
}
