// ZERO DOT 공유 파싱 모듈 — 멀티이미지 비전으로 영양성분/원재료 추출.
// ocr-parse, submit-product 가 공유한다(단일 진실원천).
// 프로바이더는 OCR_PROVIDER 환경변수로 전환: "clova"(기본) | "gemini".
//   clova → CLOVA HCX-005 단일콜(CLOVA_API_KEY),  gemini → Gemini 멀티이미지(GEMINI_API_KEY).
// 진입점은 parseImages(images) — 프로바이더/키를 env에서 읽어 알아서 분기한다.

export const GEMINI_MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-3.1-flash-lite";

export const SYSTEM = `너는 한국 가공식품 영양성분표·원재료 이미지를 읽어 JSON으로 추출하는 전문가다.
입력은 한 제품에 대한 여러 장의 사진일 수 있다(제품 전체 사진 / 원재료명 / 영양성분표).
- 제품 전체 사진은 name·brand·category 판정에 쓰고, 영양성분표/원재료 사진에서 수치·원재료를 읽는다.
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

const N = { type: "NUMBER", nullable: true };
const S = { type: "STRING", nullable: true };
export const SCHEMA = {
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

export type ParseRole = "full" | "ingredients" | "nutrition" | "single";
export interface ParseImage {
  role: ParseRole;
  base64: string;
  mimeType?: string;
}

const ROLE_TEXT: Record<ParseRole, string> = {
  full: "제품 전체 사진 (제품명·브랜드·카테고리 판정용)",
  ingredients: "원재료명",
  nutrition: "영양성분표",
  single: "영양성분표·원재료",
};

// 네트워크 없는 순수 함수 — 단위 테스트 대상.
export function buildGeminiBody(images: ParseImage[]) {
  const parts: Array<Record<string, unknown>> = [
    { text: "다음은 한 제품의 사진들이다. 각 이미지의 역할을 참고해 스키마대로 추출해줘." },
  ];
  for (const img of images) {
    parts.push({ text: `이미지 역할: ${ROLE_TEXT[img.role]}` });
    parts.push({ inline_data: { mime_type: img.mimeType ?? "image/jpeg", data: img.base64 } });
  }
  return {
    system_instruction: { parts: [{ text: SYSTEM }] },
    contents: [{ parts }],
    generationConfig: {
      responseMimeType: "application/json",
      responseSchema: SCHEMA,
    },
  };
}

// Gemini 호출 → 파싱된 객체 반환. 실패 시 throw.
export async function parseNutrition(images: ParseImage[], apiKey: string): Promise<Record<string, unknown>> {
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`;
  const res = await fetch(url, {
    method: "POST",
    headers: { "x-goog-api-key": apiKey, "content-type": "application/json" },
    body: JSON.stringify(buildGeminiBody(images)),
  });
  if (!res.ok) {
    const t = await res.text();
    throw new Error(`Gemini API ${res.status}: ${t.slice(0, 500)}`);
  }
  const data = await res.json();
  const text = data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "{}";
  return JSON.parse(text);
}

// ───────────────────────────────────────────────────────────────────────────
// CLOVA Studio (HCX-005) — 비전 멀티모달 단일콜. OpenAI 호환 엔드포인트 사용.
// HCX-005는 이미지+Structured Outputs 동시 불가 → 프롬프트로 JSON 유도 후 정규화 파싱.
// 이미지는 "한 턴에 1장"(요청당 최대 5장) 제약 → user 메시지를 이미지별로 나눈다.
export const CLOVA_MODEL = Deno.env.get("CLOVA_MODEL") ?? "HCX-005";
const CLOVA_URL = "https://clovastudio.stream.ntruss.com/v1/openai/chat/completions";

// Gemini SYSTEM 재사용 + CLOVA는 스키마 강제가 없으므로 출력 키를 프롬프트로 명시.
const CLOVA_SYSTEM = `${SYSTEM}
출력은 아래 키를 가진 JSON 객체 하나만 출력한다(코드펜스·설명·주석 금지):
name, brand, category, serving_size, unit("ml"|"g"), kcal, carb, sugar, protein, fat, sodium_mg,
fiber, sugar_alcohol, rare_sugar_g, ingredients_raw, sweeteners:[{slug, amount_g}], unknown_sweeteners:[], notes.
ingredients_raw 는 배열이 아니라 하나의 문자열이어야 한다. 라벨에 없는 수치는 null.`;

// 네트워크 없는 순수 함수 — 단위 테스트 대상.
export function buildClovaBody(images: ParseImage[]) {
  const messages: Array<Record<string, unknown>> = [
    { role: "system", content: CLOVA_SYSTEM },
  ];
  for (const img of images) {
    messages.push({
      role: "user",
      content: [
        { type: "text", text: `이미지 역할: ${ROLE_TEXT[img.role]}` },
        { type: "image_url", image_url: { url: `data:${img.mimeType ?? "image/jpeg"};base64,${img.base64}` } },
      ],
    });
  }
  messages.push({ role: "user", content: "위 사진들을 종합해 스키마대로 JSON 하나만 출력해." });
  return { model: CLOVA_MODEL, messages, max_tokens: 3000, temperature: 0.1 };
}

// CLOVA 응답 텍스트 → JSON 객체. 코드펜스/앞뒤 잡텍스트를 걷어낸다.
export function extractJson(s: string): Record<string, unknown> {
  const fence = s.match(/```(?:json)?\s*([\s\S]*?)```/);
  const raw = fence ? fence[1] : s;
  const a = raw.indexOf("{");
  const b = raw.lastIndexOf("}");
  if (a < 0 || b < 0) throw new Error("CLOVA 응답에서 JSON 객체를 찾지 못함");
  return JSON.parse(raw.slice(a, b + 1)) as Record<string, unknown>;
}

// CLOVA 출력 편차 보정 → Gemini 스키마와 동일한 형태로 맞춘다(OcrResult.fromParsed 호환).
// 관측된 편차: ingredients_raw 를 배열로 반환, sweeteners 누락/형식 변형.
export function normalizeParsed(m: Record<string, unknown>): Record<string, unknown> {
  const out: Record<string, unknown> = { ...m };
  if (Array.isArray(out.ingredients_raw)) {
    out.ingredients_raw = (out.ingredients_raw as unknown[]).map((x) => String(x)).join(", ");
  }
  const sw = Array.isArray(out.sweeteners) ? (out.sweeteners as unknown[]) : [];
  out.sweeteners = sw
    .filter((s): s is Record<string, unknown> => !!s && typeof s === "object")
    .map((s) => ({
      slug: typeof s.slug === "string" ? s.slug : String(s.slug ?? ""),
      amount_g: typeof s.amount_g === "number" ? s.amount_g : null,
    }))
    .filter((s) => s.slug.length > 0 && s.slug !== "undefined");
  out.unknown_sweeteners = Array.isArray(out.unknown_sweeteners)
    ? (out.unknown_sweeteners as unknown[]).map((x) => String(x))
    : [];
  return out;
}

// CLOVA 호출 → 정규화된 파싱 객체 반환. 실패 시 throw.
export async function parseWithClova(
  images: ParseImage[],
  apiKey: string,
): Promise<Record<string, unknown>> {
  const res = await fetch(CLOVA_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "content-type": "application/json",
      "X-NCP-CLOVASTUDIO-REQUEST-ID": crypto.randomUUID(),
    },
    body: JSON.stringify(buildClovaBody(images)),
  });
  if (!res.ok) {
    const t = await res.text();
    throw new Error(`CLOVA API ${res.status}: ${t.slice(0, 500)}`);
  }
  const data = await res.json();
  const text = data?.choices?.[0]?.message?.content ?? "{}";
  return normalizeParsed(extractJson(text));
}

// ───────────────────────────────────────────────────────────────────────────
// 프로바이더 진입점 — OCR_PROVIDER(기본 clova)에 따라 분기하고 키를 env에서 읽는다.
export async function parseImages(images: ParseImage[]): Promise<Record<string, unknown>> {
  const provider = (Deno.env.get("OCR_PROVIDER") ?? "clova").toLowerCase();
  if (provider === "gemini") {
    const key = Deno.env.get("GEMINI_API_KEY");
    if (!key) throw new Error("GEMINI_API_KEY 미설정");
    return parseNutrition(images, key);
  }
  const key = Deno.env.get("CLOVA_API_KEY");
  if (!key) throw new Error("CLOVA_API_KEY 미설정 (OCR_PROVIDER=clova)");
  return parseWithClova(images, key);
}
