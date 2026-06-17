// CUBED 공유 파싱 모듈 — Gemini 멀티이미지 비전으로 영양성분/원재료 추출.
// ocr-parse, submit-product 가 공유한다(단일 진실원천).

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
