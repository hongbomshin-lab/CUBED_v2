// 라라스윗 가격 카탈로그 동기화 — 결과화면 가격비교(product_prices)용.
// 구 sync-lalasweet-prices Edge Function 을 crawl-deals 로 흡수한 것(크롤러 통합 리팩토링).
// 특가 목록(cate 113)의 상세 페이지에서 옵션 단위 오퍼(개당가·1+1·최소주문)를 뽑아
// 등록 제품(products)과 이름 매칭 후 product_prices 에 upsert 한다.
// 파싱·매칭 로직은 검증된 ../_shared/lalasweet_crawler.ts 를 그대로 재사용.
import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  type ExistingCatalogItem,
  parseDealPage,
  parseSaleList,
  type RegisteredCatalogProduct,
  resolveCatalogItem,
} from "../_shared/lalasweet_crawler.ts";
import { USER_AGENT } from "./config.ts";

const SALE_LIST_URL = "https://lalasweet.kr/product/list.html?cate_no=113";
const STORE = "라라스윗 공식몰";

export interface PriceCatalogStats {
  pages_seen: number;
  offers_parsed: number;
  upserted: number;
  deactivated: number;
}

/** 라라스윗 특가 오퍼를 product_prices 에 동기화. 실패 시 throw(호출부에서 격리). */
export async function syncLalasweetPriceCatalog(
  db: SupabaseClient,
): Promise<PriceCatalogStats> {
  const listHtml = await fetchHtml(SALE_LIST_URL);
  const pages = parseSaleList(listHtml);
  if (pages.length === 0) {
    throw new Error("할인특가 목록이 비어 있어 가격 카탈로그 갱신을 중단합니다");
  }

  const detailHtml = await Promise.all(pages.map((p) => fetchHtml(p.url)));
  const parsedOffers = pages.flatMap((page, i) =>
    parseDealPage(page, detailHtml[i])
  );

  const [catalogResult, productsResult, activeResult] = await Promise.all([
    db.from("product_prices")
      .select("product_id,catalog_product_key,catalog_name,aliases")
      .eq("brand", "라라스윗")
      .eq("channel", "brand_mall"),
    db.from("products").select("product_id,name").eq("brand", "라라스윗"),
    db.from("product_prices")
      .select("id,offer_key")
      .eq("brand", "라라스윗")
      .eq("channel", "brand_mall")
      .eq("is_active", true)
      .neq("promo_type", "regular"),
  ]);
  if (catalogResult.error) throw catalogResult.error;
  if (productsResult.error) throw productsResult.error;
  if (activeResult.error) throw activeResult.error;

  const existingItems = dedupeCatalogItems(
    (catalogResult.data ?? []) as Array<Record<string, unknown>>,
  );
  const products = (productsResult.data ?? []).map((row) => ({
    productId: row.product_id as string,
    name: row.name as string,
  })) as RegisteredCatalogProduct[];

  const fetchedAt = new Date().toISOString();
  const rows = parsedOffers.map((offer) => {
    const catalog = resolveCatalogItem(offer.optionName, existingItems, products);
    return {
      product_id: catalog.productId,
      catalog_product_key: catalog.catalogProductKey,
      catalog_name: catalog.catalogName,
      brand: "라라스윗",
      aliases: catalog.aliases,
      channel: "brand_mall",
      store: STORE,
      price: offer.price,
      unit_count: offer.unitCount,
      promo_type: offer.promoType,
      offer_kind: offer.offerKind,
      minimum_order_amount: offer.minimumOrderAmount,
      offer_key: offer.offerKey,
      offer_title: offer.offerTitle,
      offer_note: offer.offerNote,
      link_url: offer.linkUrl,
      fetched_at: fetchedAt,
      is_active: true,
    };
  });

  const seenOfferKeys = new Set(rows.map((r) => r.offer_key));
  const staleIds = (activeResult.data ?? [])
    .filter((row) => !seenOfferKeys.has(row.offer_key as string))
    .map((row) => row.id as string);

  const { error: upsertError } = await db.from("product_prices").upsert(rows, {
    onConflict: "store,catalog_product_key,offer_key",
  });
  if (upsertError) throw upsertError;

  if (staleIds.length > 0) {
    const { error: staleError } = await db.from("product_prices")
      .update({ is_active: false, fetched_at: fetchedAt })
      .in("id", staleIds);
    if (staleError) throw staleError;
  }

  return {
    pages_seen: pages.length,
    offers_parsed: parsedOffers.length,
    upserted: rows.length,
    deactivated: staleIds.length,
  };
}

async function fetchHtml(url: string): Promise<string> {
  const response = await fetch(url, { headers: { "user-agent": USER_AGENT } });
  if (!response.ok) throw new Error(`${url} HTTP ${response.status}`);
  return await response.text();
}

function dedupeCatalogItems(
  rows: Array<Record<string, unknown>>,
): ExistingCatalogItem[] {
  const items = new Map<string, ExistingCatalogItem>();
  for (const row of rows) {
    const key = row.catalog_product_key as string;
    const current = items.get(key);
    const aliases = new Set(current?.aliases ?? []);
    for (const alias of (row.aliases as string[] | null) ?? []) {
      aliases.add(alias);
    }
    items.set(key, {
      productId: (row.product_id as string | null) ?? current?.productId ?? null,
      catalogProductKey: key,
      catalogName: row.catalog_name as string,
      aliases: [...aliases],
    });
  }
  return [...items.values()];
}
