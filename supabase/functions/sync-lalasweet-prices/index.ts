import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  type ExistingCatalogItem,
  parseDealPage,
  parseSaleList,
  type RegisteredCatalogProduct,
  resolveCatalogItem,
} from "../_shared/lalasweet_crawler.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SYNC_SECRET = Deno.env.get("LALASWEET_SYNC_SECRET") ?? "";
const SALE_LIST_URL = "https://lalasweet.kr/product/list.html?cate_no=113";
const STORE = "라라스윗 공식몰";
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-sync-secret",
};

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: CORS });
  }
  if (request.method !== "POST") return json({ error: "POST only" }, 405);
  if (!SYNC_SECRET || request.headers.get("x-sync-secret") !== SYNC_SECRET) {
    return json({ error: "unauthorized" }, 401);
  }

  try {
    const body = await request.json().catch(() => ({}));
    const dryRun = body?.dry_run === true;
    const db = createClient(SUPABASE_URL, SERVICE_ROLE);

    const listHtml = await fetchHtml(SALE_LIST_URL);
    const pages = parseSaleList(listHtml);
    if (pages.length === 0) {
      throw new Error("할인특가 목록이 비어 있어 갱신을 중단합니다");
    }

    const detailHtml = await Promise.all(
      pages.map((page) => fetchHtml(page.url)),
    );
    const parsedOffers = pages.flatMap((page, index) =>
      parseDealPage(page, detailHtml[index])
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
      const catalog = resolveCatalogItem(
        offer.optionName,
        existingItems,
        products,
      );
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
    const seenOfferKeys = new Set(rows.map((row) => row.offer_key));
    const staleIds = (activeResult.data ?? [])
      .filter((row) => !seenOfferKeys.has(row.offer_key as string))
      .map((row) => row.id as string);

    if (!dryRun) {
      const { error: upsertError } = await db.from("product_prices").upsert(
        rows,
        {
          onConflict: "store,catalog_product_key,offer_key",
        },
      );
      if (upsertError) throw upsertError;
      if (staleIds.length > 0) {
        const { error: staleError } = await db.from("product_prices")
          .update({ is_active: false, fetched_at: fetchedAt })
          .in("id", staleIds);
        if (staleError) throw staleError;
      }
    }

    return json({
      dry_run: dryRun,
      pages_seen: pages.length,
      offers_parsed: parsedOffers.length,
      catalog_products: new Set(rows.map((row) =>
        row.catalog_product_key
      )).size,
      registered_matches: rows.filter((row) => row.product_id != null).length,
      unregistered_matches: rows.filter((row) => row.product_id == null).length,
      upserted: dryRun ? 0 : rows.length,
      deactivated: dryRun ? 0 : staleIds.length,
      offer_keys: [...seenOfferKeys],
    }, 200);
  } catch (error) {
    console.error("sync-lalasweet-prices 실패:", String(error));
    return json({ error: String(error) }, 500);
  }
});

async function fetchHtml(url: string): Promise<string> {
  const response = await fetch(url, {
    headers: { "user-agent": "ZERO-DOT-price-sync/1.0" },
  });
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
      productId: (row.product_id as string | null) ?? current?.productId ??
        null,
      catalogProductKey: key,
      catalogName: row.catalog_name as string,
      aliases: [...aliases],
    });
  }
  return [...items.values()];
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "content-type": "application/json" },
  });
}
