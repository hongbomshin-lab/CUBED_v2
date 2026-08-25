// ZERO DOT 제보 Edge Function (Deno, service_role).
// 입력: { images:{full,ingredients,nutrition}(base64), barcode? }
//   또는 { quick:true, images:{full} } — 전면 1장 빠른 매칭 (파싱·제보 없음).
// 처리: Gemini 파싱 → submission-images 업로드 → user_submissions insert → 파싱 반환.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { type ParseImage, parseImages } from "../_shared/parse.ts";
import { recognizeWithClova } from "../_shared/recognize.ts";
import {
  buildProductIdentitySet,
  type PriceCatalogRow,
  type RegisteredProductCandidate,
} from "../_shared/price_catalog.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const PRODUCT_COLS =
  "product_id,name,brand,category,serving_size,unit,kcal,carb,sugar,protein,fat," +
  "sodium_mg,fiber,sugar_alcohol,rare_sugar_g,ingredients_raw,sweetener_summary," +
  "sweetener_count,barcode,image_file,source_type,verified,notes," +
  "product_sweeteners(slug,amount_g,sort_order)";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function b64ToBytes(b64: string): Uint8Array {
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  try {
    const { images, barcode, quick } = await req.json();

    // 빠른 매칭 모드: 전면 1장으로 등록 제품/가격 카탈로그 매칭만 시도.
    // 실패는 비치명 — null을 돌려주고 앱은 3장 플로우로 계속한다.
    if (quick) {
      if (!images?.full) return json({ error: "images.full 필요" }, 400);
      const db = createClient(SUPABASE_URL, SERVICE_ROLE);
      try {
        console.log(`quick: 이미지 base64 ${images.full.length}B 수신`);
        const match = await matchRegisteredIdentity(db, images.full);
        console.log(
          `quick: matched_product=${match.matchedProduct ? "있음" : "없음"} price_match=${
            match.priceMatch ? "있음" : "없음"
          }`,
        );
        return json({
          matched_product: match.matchedProduct,
          price_match: match.priceMatch,
        }, 200);
      } catch (e) {
        console.error("submit-product quick 매칭 실패(비치명):", String(e));
        return json({ matched_product: null, price_match: null }, 200);
      }
    }

    if (!images?.full || !images?.ingredients || !images?.nutrition) {
      return json({ error: "images.full/ingredients/nutrition 3장 필요" }, 400);
    }

    const imgs: ParseImage[] = [
      { role: "full", base64: images.full },
      { role: "ingredients", base64: images.ingredients },
      { role: "nutrition", base64: images.nutrition },
    ];
    const parsed = await parseImages(imgs);
    const db = createClient(SUPABASE_URL, SERVICE_ROLE);

    // 영양 분석은 항상 반환하고, 앞면 사진에서 등록 제품 또는 가격 카탈로그 SKU를 찾는다.
    let matchedProduct: Record<string, unknown> | null = null;
    let priceMatch: Record<string, unknown> | null = null;
    try {
      const match = await matchRegisteredIdentity(
        db,
        images.full,
      );
      matchedProduct = match.matchedProduct;
      priceMatch = match.priceMatch;
    } catch (recognitionError) {
      console.error(
        "submit-product 제품 매칭 실패(비치명):",
        String(recognitionError),
      );
    }

    // 제보 영속화(비치명적). 실패해도 파싱 결과는 돌려준다.
    // 성공 시 폴더 uuid를 image_path로 반환 → 앱의 먹은기록 썸네일 재사용 (스펙 §7)
    let imagePath: string | null = null;
    try {
      const folder = crypto.randomUUID();
      const bucket = db.storage.from("submission-images");
      // supabase-js는 API 오류 시 throw하지 않고 { error }를 반환 — 명시 확인 후 throw
      const uploads = await Promise.all([
        bucket.upload(`${folder}/full.jpg`, b64ToBytes(images.full), {
          contentType: "image/jpeg",
        }),
        bucket.upload(
          `${folder}/ingredients.jpg`,
          b64ToBytes(images.ingredients),
          { contentType: "image/jpeg" },
        ),
        bucket.upload(`${folder}/nutrition.jpg`, b64ToBytes(images.nutrition), {
          contentType: "image/jpeg",
        }),
      ]);
      const uploadErr = uploads.find((u) => u.error)?.error;
      if (uploadErr) throw uploadErr;
      const { error: insertErr } = await db.from("user_submissions").insert({
        barcode: barcode ?? null,
        image_path: folder,
        parsed,
        ocr_text: (parsed as { ingredients_raw?: string }).ingredients_raw ??
          null,
        status: "pending",
      });
      if (insertErr) throw insertErr;
      imagePath = folder;
    } catch (persistErr) {
      console.error(
        "submit-product persist 실패(비치명적):",
        String(persistErr),
      );
    }

    return json({
      ...parsed,
      matched_product: matchedProduct,
      price_match: priceMatch,
      image_path: imagePath,
    }, 200);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

// 등록 제품 전체 + 라라스윗 가격 카탈로그(특가 연동용)를 후보로 앞면 사진을 매칭한다.
async function matchRegisteredIdentity(
  db: SupabaseClient,
  imageBase64: string,
): Promise<{
  matchedProduct: Record<string, unknown> | null;
  priceMatch: Record<string, unknown> | null;
}> {
  const [productsResult, pricesResult] = await Promise.all([
    db.from("products").select("product_id,name,brand"),
    db.from("product_prices")
      .select("product_id,catalog_product_key,catalog_name,aliases")
      .eq("brand", "라라스윗")
      .eq("channel", "brand_mall")
      .eq("is_active", true),
  ]);
  if (productsResult.error) throw productsResult.error;
  if (pricesResult.error) throw pricesResult.error;

  // 후보 표시명에 브랜드를 붙여 동명 제품·유사 패키지 오인을 줄인다.
  const products = (productsResult.data ?? []).map(
    (p: { product_id: string; name: string; brand: string | null }) => ({
      product_id: p.product_id,
      name: p.brand ? `${p.brand} ${p.name}` : p.name,
    }),
  );

  const identitySet = buildProductIdentitySet(
    products as RegisteredProductCandidate[],
    (pricesResult.data ?? []) as PriceCatalogRow[],
  );
  if (identitySet.candidates.length === 0) {
    return { matchedProduct: null, priceMatch: null };
  }

  const apiKey = Deno.env.get("CLOVA_API_KEY");
  if (!apiKey) throw new Error("CLOVA_API_KEY 미설정");
  const recognition = await recognizeWithClova(
    identitySet.candidates,
    imageBase64,
    apiKey,
  );
  if (!recognition.matched || !recognition.productId) {
    return { matchedProduct: null, priceMatch: null };
  }

  const identity = identitySet.identities.get(recognition.productId);
  if (!identity) return { matchedProduct: null, priceMatch: null };

  let matchedProduct: Record<string, unknown> | null = null;
  if (identity.registeredProductId) {
    const { data: product, error: productError } = await db
      .from("products")
      .select(PRODUCT_COLS)
      .eq("product_id", identity.registeredProductId)
      .single();
    if (productError) throw productError;
    matchedProduct = product as unknown as Record<string, unknown>;
  }

  const priceMatch = identity.catalogProductKey
    ? {
      catalog_product_key: identity.catalogProductKey,
      catalog_name: identity.name,
      confidence: recognition.confidence,
      reason: recognition.reason,
    }
    : null;
  return { matchedProduct, priceMatch };
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "content-type": "application/json" },
  });
}
