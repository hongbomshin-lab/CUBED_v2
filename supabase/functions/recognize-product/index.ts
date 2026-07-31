import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  recognizeWithClova,
  type RecognitionCandidate,
} from "../_shared/recognize.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const PRODUCT_COLS =
  "product_id,name,brand,category,serving_size,unit,kcal,carb,sugar,protein,fat," +
  "sodium_mg,fiber,sugar_alcohol,rare_sugar_g,ingredients_raw,sweetener_summary," +
  "sweetener_count,barcode,image_file,source_type,verified,notes," +
  "product_sweeteners(slug,amount_g,sort_order)";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: CORS });
  }
  if (request.method !== "POST") return json({ error: "POST only" }, 405);

  try {
    const body = await request.json();
    const image = typeof body.image === "string" ? body.image.trim() : "";
    if (!image) return json({ error: "image base64 필요" }, 400);
    if (image.length > 12_000_000) return json({ error: "image too large" }, 400);

    const db = createClient(SUPABASE_URL, SERVICE_ROLE);
    const { data, error } = await db
      .from("products")
      .select("product_id,name")
      .eq("brand", "라라스윗")
      .order("name");
    if (error) throw error;
    const candidates = (data ?? []) as RecognitionCandidate[];
    if (candidates.length === 0) throw new Error("라라스윗 후보 제품 없음");

    const apiKey = Deno.env.get("CLOVA_API_KEY");
    if (!apiKey) throw new Error("CLOVA_API_KEY 미설정");
    const result = await recognizeWithClova(candidates, image, apiKey);
    if (!result.matched || !result.productId) {
      return json({
        matched: false,
        confidence: result.confidence,
        reason: result.reason,
        product: null,
      }, 200);
    }

    const { data: product, error: productError } = await db
      .from("products")
      .select(PRODUCT_COLS)
      .eq("product_id", result.productId)
      .single();
    if (productError) throw productError;
    return json({
      matched: true,
      confidence: result.confidence,
      reason: result.reason,
      product,
    }, 200);
  } catch (error) {
    console.error("recognize-product 실패:", String(error));
    return json({ error: "제품 인식에 실패했어요" }, 500);
  }
});

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "content-type": "application/json" },
  });
}

