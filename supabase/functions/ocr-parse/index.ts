// CUBED OCR 파싱 Edge Function (Deno) — 공유 파싱 모듈 사용.
// 단일 image(하위호환) 또는 images:{full,ingredients,nutrition} 멀티이미지 지원.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { parseImages, type ParseImage } from "../_shared/parse.ts";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  try {
    const { image, images, media_type } = await req.json();
    const imgs = toParseImages(image, images, media_type);
    if (imgs.length === 0) return json({ error: "image 또는 images 필요" }, 400);
    const parsed = await parseImages(imgs);
    return json(parsed, 200);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

function toParseImages(
  image: string | undefined,
  images: Record<string, string> | undefined,
  mediaType: string | undefined,
): ParseImage[] {
  if (images && typeof images === "object") {
    const out: ParseImage[] = [];
    for (const role of ["full", "ingredients", "nutrition"] as const) {
      if (images[role]) out.push({ role, base64: images[role], mimeType: mediaType });
    }
    return out;
  }
  if (image) return [{ role: "single", base64: image, mimeType: mediaType }];
  return [];
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "content-type": "application/json" },
  });
}
