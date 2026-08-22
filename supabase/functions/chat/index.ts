// ZERO DOT 채팅 Edge Function (Deno) — CLOVA Studio HCX-005 (OpenAI 호환 엔드포인트)
// 사용자 질문 + CUBED_v2의 제품 룰북 요약(혈당등급·순탄수·0g함정·대체당)을 주입해 답변 생성.
// "전체 주입" 방식. 비스트리밍(완성 답변 1회 반환).
// ⚠️ 전 제품을 시스템 프롬프트에 주입 → 제품 수가 늘면 prompt 토큰도 커진다(현재 408개 ≈ 4만 토큰).
//    한도에 닿으면 관련 제품만 주입하는 검색형으로 전환 필요.
//
// 배포: supabase functions deploy chat  (project-ref aqhfddvvxnakgkdtirem)
// 비밀키: 이미지 분석과 동일한 CLOVA_API_KEY 시크릿 재사용(앱·코드엔 절대 넣지 않음).

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CHAT_MODEL = Deno.env.get("CHAT_MODEL") ?? "HCX-005";
const CLOVA_API_KEY = Deno.env.get("CLOVA_API_KEY");
const CLOVA_URL = "https://clovastudio.stream.ntruss.com/v1/openai/chat/completions";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SYSTEM_PROMPT = `너는 ZERO DOT의 저당 제품 안내 도우미다.
제공된 제품 데이터(이미 룰북으로 계산된 혈당영향 등급·순탄수·0g 함정 포함)에 있는 제품만 근거로 답한다.
데이터에 없으면 모른다고 솔직히 답한다. 추측하지 말고 데이터의 수치를 인용한다.

원칙:
- 등급은 ZERO DOT 자체 해석이며 의료 조언이 아님을 필요 시 명시한다.
- 당뇨 관련 질문엔 순탄수·당알코올·혈당영향을 우선 설명한다.
- 다이어트 관련 질문엔 칼로리·당류를 우선 설명한다.
- "당 0g인데 왜 주의?" 같은 질문엔 말티톨 등 혈당 올리는 당알코올/순탄수 근거로 설명한다.
- 진단·복약·치료 등 의료 판단을 요구하면 일반 정보만 제공하고 전문의 상담을 권한다.
- 한국어로 간결하고 친절하게 답한다.

제품 데이터 필드: name(이름), brand(브랜드), category(카테고리), grade(혈당영향 등급: 낮음/중간/주의),
per100NetCarb(100단위당 순탄수 g — unit이 ml이면 100ml·g이면 100g 기준), sugar(1회제공량 당류 g),
kcal(1회제공량 열량), unit(ml/g), traps(0g 함정 배열, '없음'이면 함정 없음), sweeteners(대체당 이름 배열).`;

// ───────────────────────── 룰북 (cubed_app/lib/core/rulebook.dart 1:1 포팅) ─────────────────────────
type Grade = "낮음" | "중간" | "주의";
const INV: Grade[] = ["낮음", "중간", "주의"];
const RANK: Record<string, number> = { "낮음": 0, "중간": 1, "주의": 2 };

const T_CARB_LIQ = [2.5, 5];
const T_CARB_SOLID = [10, 20];
const T_CARB_SERVING = [5, 15]; // 1회분 절대 순탄수(g) → +1/+2 단계 (밀도와 max 결합)
const T_KCAL_LIQ = 4;
const T_KCAL_SOLID = 40;
const T_SUGAR_LIQ = 2.5;
const T_SUGAR_SOLID = 5;
const T_SA_MIN = 2;

// 혈당 올리는 당알코올만 (세분형 slug 포함)
const RISKY_SA = new Set([
  "maltitol", "d-maltitol",
  "xylitol",
  "sorbitol", "d-sorbitol-solution",
  "polyglycitol",
]);
// 룰북 혈당등급 계산에서 제외할 class='기타' slug — maltodextrin은 고GI라 반영(제외 금지)
const EXCLUDED_ETC = new Set(["gum-arabic", "monosodium-glutamate"]);

const r2 = (v: number) => Math.round(v * 100) / 100;
const r1 = (v: number) => Math.round(v * 10) / 10;

function netCarb(carb: number, fiber: number, sa: number, rare = 0): number {
  const v = carb - fiber - sa - rare;
  return v <= 0 ? 0 : r2(v);
}
function per100NetCarb(serving: number, carb: number, fiber: number, sa: number, rare = 0): number {
  const nc = netCarb(carb, fiber, sa, rare);
  return serving > 0 ? r1((nc * 100) / serving) : 0;
}
function carbSteps(isLiquid: boolean, p100: number, ncServing: number): number {
  const t = isLiquid ? T_CARB_LIQ : T_CARB_SOLID;
  const density = p100 >= t[1] ? 2 : p100 >= t[0] ? 1 : 0;
  const serving = ncServing >= T_CARB_SERVING[1] ? 2 : ncServing >= T_CARB_SERVING[0] ? 1 : 0;
  return Math.max(density, serving);
}
const rulebookSlugs = (slugs: string[]) => slugs.filter((s) => !EXCLUDED_ETC.has(s));

// 열량 정합 상한: 라벨 kcal로 가능한 최대 흡수 탄수는 kcal/4 g (kcal 미상(0)은 클램프 안 함)
function effectiveNetCarb(nc: number, kcal: number): number {
  return kcal > 0 && nc > kcal / 4 ? r1(kcal / 4) : nc;
}

// 감미료 단계(양 감응): 위험 당알코올은 0<SA<2g이면 미량 무시,
// 말토덱스트린은 신뢰 가능한 유효 순탄수 < 2g이면 +1(중간)로 완화
function sweetenerSteps(
  slugs: string[], giMap: Record<string, string>, sa: number, effNc: number, ncReliable: boolean,
): number {
  let worst = 0;
  for (const s of rulebookSlugs(slugs)) {
    let g = RANK[giMap[s] ?? "낮음"] ?? 0;
    if (g === 0) continue;
    if (RISKY_SA.has(s) && sa > 0 && sa < T_SA_MIN) g = 0;
    if (s === "maltodextrin" && ncReliable && effNc < T_SA_MIN && g > 1) g = 1;
    if (g > worst) worst = g;
  }
  return worst;
}

function glycemicGrade(
  isLiquid: boolean, serving: number, kcal: number, carb: number, fiber: number, sa: number,
  rare: number, slugs: string[], giMap: Record<string, string>,
): Grade {
  const ncReliable = carb - fiber - sa - rare >= 0;
  const nc = effectiveNetCarb(netCarb(carb, fiber, sa, rare), kcal);
  const p100 = serving > 0 ? r1((nc * 100) / serving) : 0;
  const sw = sweetenerSteps(slugs, giMap, sa, nc, ncReliable);
  const total = sw + carbSteps(isLiquid, p100, nc);
  return INV[total > 2 ? 2 : total];
}

function traps(
  isLiquid: boolean, serving: number, kcal: number, sugar: number, sa: number,
  carb: number, fiber: number, rare: number, slugs: string[],
): string[] {
  // 함정도 등급과 같은 유효 순탄수(열량 정합 클램프) 기준
  const nc = effectiveNetCarb(netCarb(carb, fiber, sa, rare), kcal);
  const p100 = serving > 0 ? (nc * 100) / serving : 0;
  const per100kcal = serving > 0 ? (kcal * 100) / serving : 0;
  const per100sugar = serving > 0 ? (sugar * 100) / serving : 0;
  const zero = sugar <= 0.5;
  const sugarHigh = per100sugar > (isLiquid ? T_SUGAR_LIQ : T_SUGAR_SOLID);
  const out: string[] = [];
  if (zero && sa >= T_SA_MIN && slugs.some((x) => RISKY_SA.has(x))) out.push("당알코올 함정");
  if (zero && per100kcal >= (isLiquid ? T_KCAL_LIQ : T_KCAL_SOLID)) out.push("칼로리 함정");
  if (sugarHigh) out.push("당류 함정");
  if (!sugarHigh && carbSteps(isLiquid, p100, nc) > 0) out.push("탄수 함정");
  return out.length ? out : ["없음"];
}

// ───────────────────────── 제품 요약 빌더 (warm isolate 캐시, TTL 10분) ─────────────────────────
const TTL_MS = 10 * 60 * 1000;
let cache: { at: number; summary: unknown[] } | null = null;
const num = (v: unknown) => (typeof v === "number" ? v : Number(v)) || 0;

async function buildSummary(): Promise<unknown[]> {
  if (cache && Date.now() - cache.at < TTL_MS) return cache.summary;

  const sb = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  const [swRes, catRes, prodRes] = await Promise.all([
    sb.from("sweeteners").select("slug,standard_name,glycemic_impact"),
    sb.from("category_meta").select("category,is_liquid"),
    sb.from("products").select(
      "name,brand,category,serving_size,unit,kcal,carb,sugar,fiber,sugar_alcohol,rare_sugar_g," +
        "product_sweeteners(slug,sort_order)",
    ),
  ]);
  if (swRes.error) throw swRes.error;
  if (catRes.error) throw catRes.error;
  if (prodRes.error) throw prodRes.error;

  const giMap: Record<string, string> = {};
  const nameMap: Record<string, string> = {};
  for (const s of swRes.data ?? []) {
    giMap[s.slug] = (s.glycemic_impact as string) ?? "낮음";
    nameMap[s.slug] = (s.standard_name as string) ?? s.slug;
  }
  const liqMap: Record<string, boolean> = {};
  for (const c of catRes.data ?? []) liqMap[c.category as string] = !!c.is_liquid;

  const summary = (prodRes.data ?? []).map((p) => {
    const slugs = ((p.product_sweeteners as { slug: string; sort_order: number }[]) ?? [])
      .slice()
      .sort((a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0))
      .map((x) => x.slug);
    const isLiq = liqMap[p.category as string] ?? false;
    const serving = num(p.serving_size);
    const carb = num(p.carb), fiber = num(p.fiber), sa = num(p.sugar_alcohol), rare = num(p.rare_sugar_g);
    const sugar = num(p.sugar), kcal = num(p.kcal);
    return {
      name: p.name,
      brand: p.brand ?? undefined,
      category: p.category ?? undefined,
      grade: glycemicGrade(isLiq, serving, kcal, carb, fiber, sa, rare, slugs, giMap),
      per100NetCarb: per100NetCarb(serving, carb, fiber, sa, rare),
      sugar,
      kcal,
      unit: (p.unit as string) ?? "g",
      traps: traps(isLiq, serving, kcal, sugar, sa, carb, fiber, rare, slugs),
      sweeteners: slugs.map((s) => nameMap[s] ?? s),
    };
  });

  cache = { at: Date.now(), summary };
  return summary;
}

// ───────────────────────── 핸들러 ─────────────────────────
interface InMsg { role?: string; content?: string }

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (!CLOVA_API_KEY) return json({ error: "CLOVA_API_KEY 미설정" }, 500);

  try {
    const body = await req.json().catch(() => ({}));
    const messages: InMsg[] = Array.isArray(body?.messages) ? body.messages : [];
    if (messages.length === 0) return json({ error: "messages 필요" }, 400);

    const summary = await buildSummary();
    const systemInstruction = `${SYSTEM_PROMPT}\n\n[제품데이터]\n${JSON.stringify(summary)}`;

    // 멀티턴 history → OpenAI 메시지 (system 다음 첫 턴은 user 로 시작)
    const turns = messages.map((m) => ({
      role: m.role === "assistant" ? "assistant" : "user",
      content: String(m.content ?? ""),
    }));
    while (turns.length && turns[0].role !== "user") turns.shift();
    if (turns.length === 0) return json({ error: "user 메시지 필요" }, 400);

    const res = await fetch(CLOVA_URL, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${CLOVA_API_KEY}`,
        "content-type": "application/json",
        "X-NCP-CLOVASTUDIO-REQUEST-ID": crypto.randomUUID(),
      },
      body: JSON.stringify({
        model: CHAT_MODEL,
        messages: [{ role: "system", content: systemInstruction }, ...turns],
        max_tokens: 1024,
        temperature: 0.5,
      }),
    });

    if (!res.ok) {
      const t = await res.text();
      return json({ error: `CLOVA API ${res.status}`, detail: t.slice(0, 500) }, 502);
    }
    const data = await res.json();
    const reply: string = (data?.choices?.[0]?.message?.content ?? "").trim();
    return json({ reply: reply || "죄송해요, 답변을 생성하지 못했어요." }, 200);
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
