// CUBED OCR 파싱 Edge Function (Deno) — Gemini 3.1 Flash Lite
// 영양성분표 사진(base64) → Gemini 비전으로 구조화 영양정보 추출.
// 앱은 이 결과를 rulebook 엔진에 넣어 바코드 스캔과 동일한 해석 UI를 그린다.
//
// 배포: supabase functions deploy ocr-parse  (또는 MCP deploy_edge_function)
// 비밀키: 대시보드 Edge Functions → Secrets 에 GEMINI_API_KEY 추가 (앱·코드엔 절대 넣지 않음)

import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const GEMINI_MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-3.1-flash-lite";
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SYSTEM = `너는 한국 가공식품 영양성분표·원재료 이미지를 읽어 JSON으로 추출하는 전문가다.
규칙:
- 저장기준 = 소비자가 한 번에 먹는 한 단위(1회제공량/1팩/총내용량). 100g·100ml만 있으면 serving_size=100.
- 숫자만(콤마·% 제거). 나트륨은 mg. 당류 '–'는 0. 안 보이면 null(추측 금지).
- fiber/sugar_alcohol/rare_sugar_g는 라벨에 명시될 때만. 알룰로오스→rare_sugar_g, 에리스리톨 등 당알코올→sugar_alcohol.
- 감미료 slug는 다음 28개만 사용(세분형 우선):
  allulose, erythritol, sucralose, aspartame, neotame, acesulfame-potassium, d-maltitol, maltitol,
  d-sorbitol-solution, sorbitol, xylitol, isomalt, lactitol, mannitol, polyglycitol,
  enzyme-treated-stevia, steviol-glycosides, stevia, monk-fruit-extract-powder, monk-fruit,
  sodium-saccharin, saccharin, tagatose, licorice-extract, maltodextrin, gum-arabic, monosodium-glutamate
  매핑: 알룰로오스→allulose, 효소처리스테비아→enzyme-treated-stevia, 스테비올배당체→steviol-glycosides,
  아세설팜칼륨/아세설팜K→acesulfame-potassium, D-말티톨→d-maltitol, D-소르비톨액→d-sorbitol-solution,
  나한과추출분말→monk-fruit-extract-powder, 사카린나트륨→sodium-saccharin.
- category는 다음 18종 중 하나: 탄산음료, 에너지드링크, 스포츠/이온음료, 과일음료, 차/티음료, 커피,
  우유/요거트음료, 두유/식물성음료, 단백질음료, 건강/기능성음료, 아이스크림/빙과, 과자/스낵,
  초콜릿/캔디/껌, 젤리, 빵/디저트, 단백질/에너지바, 간편식/식사, 소스/장류.
- 설탕·과당·물엿 등 일반 당류는 sweeteners에 넣지 않는다(ingredients_raw엔 남김).`;

// Gemini responseSchema (타입 대문자, nullable 사용)
const N = { type: "NUMBER", nullable: true };
const S = { type: "STRING", nullable: true };
const SCHEMA = {
  type: "OBJECT",
  properties: {
    name: { type: "STRING" },
    brand: S,
    category: { type: "STRING" },
    serving_size: N,
    unit: { type: "STRING", enum: ["ml", "g"] },
    kcal: N, carb: N, sugar: N, protein: N, fat: N, sodium_mg: N,
    fiber: N, sugar_alcohol: N, rare_sugar_g: N,
    ingredients_raw: S,
    sweeteners: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: { slug: { type: "STRING" }, amount_g: N },
        required: ["slug"],
      },
    },
    unknown_sweeteners: { type: "ARRAY", items: { type: "STRING" } },
    notes: S,
  },
  required: ["name", "category", "unit", "sweeteners"],
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (!GEMINI_API_KEY) {
    return json({ error: "GEMINI_API_KEY 미설정" }, 500);
  }
  try {
    const { image, media_type } = await req.json();
    if (!image) return json({ error: "image(base64) 필요" }, 400);

    const url =
      `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`;
    const res = await fetch(url, {
      method: "POST",
      headers: {
        "x-goog-api-key": GEMINI_API_KEY,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        system_instruction: { parts: [{ text: SYSTEM }] },
        contents: [{
          parts: [
            { text: "이 영양성분표·원재료를 스키마대로 추출해줘." },
            { inline_data: { mime_type: media_type ?? "image/jpeg", data: image } },
          ],
        }],
        generationConfig: {
          responseMimeType: "application/json",
          responseSchema: SCHEMA,
        },
      }),
    });

    if (!res.ok) {
      const t = await res.text();
      return json({ error: `Gemini API ${res.status}`, detail: t.slice(0, 500) }, 502);
    }
    const data = await res.json();
    const text = data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "{}";
    const parsed = JSON.parse(text);
    return json(parsed, 200);
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
