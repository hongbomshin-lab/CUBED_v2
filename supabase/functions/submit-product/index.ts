// ZERO DOT 제보 Edge Function (Deno, service_role).
// 입력: { images:{full,ingredients,nutrition}(base64), barcode? }
// 처리: Gemini 파싱 → submission-images 업로드 → user_submissions insert → 파싱 반환.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { parseImages, type ParseImage } from "../_shared/parse.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
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
    const { images, barcode } = await req.json();
    if (!images?.full || !images?.ingredients || !images?.nutrition) {
      return json({ error: "images.full/ingredients/nutrition 3장 필요" }, 400);
    }

    const imgs: ParseImage[] = [
      { role: "full", base64: images.full },
      { role: "ingredients", base64: images.ingredients },
      { role: "nutrition", base64: images.nutrition },
    ];
    const parsed = await parseImages(imgs);

    // 제보 영속화(비치명적). 실패해도 파싱 결과는 돌려준다.
    // 성공 시 폴더 uuid를 image_path로 반환 → 앱의 먹은기록 썸네일 재사용 (스펙 §7)
    let imagePath: string | null = null;
    try {
      const db = createClient(SUPABASE_URL, SERVICE_ROLE);
      const folder = crypto.randomUUID();
      const bucket = db.storage.from("submission-images");
      // supabase-js는 API 오류 시 throw하지 않고 { error }를 반환 — 명시 확인 후 throw
      const uploads = await Promise.all([
        bucket.upload(`${folder}/full.jpg`, b64ToBytes(images.full), { contentType: "image/jpeg" }),
        bucket.upload(`${folder}/ingredients.jpg`, b64ToBytes(images.ingredients), { contentType: "image/jpeg" }),
        bucket.upload(`${folder}/nutrition.jpg`, b64ToBytes(images.nutrition), { contentType: "image/jpeg" }),
      ]);
      const uploadErr = uploads.find((u) => u.error)?.error;
      if (uploadErr) throw uploadErr;
      const { error: insertErr } = await db.from("user_submissions").insert({
        barcode: barcode ?? null,
        image_path: folder,
        parsed,
        ocr_text: (parsed as { ingredients_raw?: string }).ingredients_raw ?? null,
        status: "pending",
      });
      if (insertErr) throw insertErr;
      imagePath = folder;
    } catch (persistErr) {
      console.error("submit-product persist 실패(비치명적):", String(persistErr));
    }

    return json({ ...parsed, image_path: imagePath }, 200);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "content-type": "application/json" },
  });
}
