// CUBED 프랜차이즈 메뉴 번역 Edge Function (Deno) — CLOVA HCX-005
// franchise_translation_todo 뷰(아직 번역 안 된 메뉴명×언어)를 읽어 배치 번역 후
// franchise_translations 에 적재한다. 앱은 이 테이블만 읽는다.
//
// 배포: supabase functions deploy translate-franchise --no-verify-jwt
//       (project-ref aqhfddvvxnakgkdtirem)
// 시크릿: CLOVA_API_KEY(기존 재사용) · CRAWL_SECRET(호출 인증, crawl-deals 와 공용)
//
// 호출: POST /functions/v1/translate-franchise?lang=en&limit=200
//   x-crawl-secret 헤더 필수. lang 생략 시 en→ja→zh 순으로 남은 것부터.
//   컴퓨트 한도(WORKER_RESOURCE_LIMIT) 회피를 위해 시간 예산 안에서만 처리하고
//   남은 건수를 응답에 실어 준다. remaining 이 0 이 될 때까지 반복 호출하면 된다.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CLOVA_API_KEY = Deno.env.get("CLOVA_API_KEY");
const CLOVA_URL =
  "https://clovastudio.stream.ntruss.com/v1/openai/chat/completions";
const MODEL = Deno.env.get("TRANSLATE_MODEL") ?? "HCX-005";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

/** 한 번의 LLM 호출에 넣을 메뉴 수. 너무 크면 누락·잘림이 생긴다. */
const BATCH = 15;
/** 이 시간을 넘기면 남은 건 다음 호출로 미룬다(Edge 컴퓨트 한도 회피). */
const TIME_BUDGET_MS = 180_000;

const LANG_LABEL: Record<string, string> = {
  en: "English",
  ja: "Japanese (日本語)",
  zh: "Simplified Chinese (简体中文)",
};

/** 오역이 잦았던 카페 용어 고정 사전 — 프롬프트에 주입해 환각을 막는다. */
const GLOSSARY: Record<string, Record<string, string>> = {
  en: {
    "콜드브루": "Cold Brew", "콜드폼": "Cold Foam", "헤이즐넛": "Hazelnut",
    "플랫치노": "Frappuccino-style blended", "빽스치노": "Bbaksccino",
    "생강차": "Ginger Tea", "헛개": "Oriental Raisin", "막걸리향": "Makgeolli-flavored",
    "흑당": "Brown Sugar", "말차": "Matcha", "쑥": "Mugwort", "유자": "Yuzu",
    "자몽": "Grapefruit", "리치": "Lychee", "곡물": "Grain", "미숫가루": "Misugaru",
    "달고나": "Dalgona", "아인슈페너": "Einspänner", "제로슈가": "Zero Sugar",
    "스무디": "Smoothie", "에이드": "Ade", "디카페인": "Decaf",
  },
  ja: {
    "콜드브루": "コールドブリュー", "콜드폼": "コールドフォーム", "헤이즐넛": "ヘーゼルナッツ",
    "플랫치노": "フラペチーノ風", "빽스치노": "ベクスチーノ",
    "생강차": "生姜茶", "헛개": "ケンポナシ", "막걸리향": "マッコリ風味",
    "흑당": "黒糖", "말차": "抹茶", "쑥": "ヨモギ", "유자": "ゆず",
    "자몽": "グレープフルーツ", "리치": "ライチ", "곡물": "穀物", "미숫가루": "ミスッカル",
    "달고나": "ダルゴナ", "아인슈페너": "アインシュペナー", "제로슈가": "ゼロシュガー",
    "스무디": "スムージー", "에이드": "エード", "디카페인": "デカフェ",
  },
  zh: {
    "콜드브루": "冷萃咖啡", "콜드폼": "冷泡沫", "헤이즐넛": "榛果",
    "플랫치노": "星冰乐风味", "빽스치노": "白斯奇诺",
    "생강차": "生姜茶", "헛개": "枳椇", "막걸리향": "马格利风味",
    "흑당": "黑糖", "말차": "抹茶", "쑥": "艾草", "유자": "柚子",
    "자몽": "西柚", "리치": "荔枝", "곡물": "谷物", "미숫가루": "米谷粉",
    "달고나": "达尔戈纳", "아인슈페너": "维也纳咖啡", "제로슈가": "零糖",
    "스무디": "冰沙", "에이드": "气泡饮", "디카페인": "低因",
  },
};

function systemPrompt(lang: string): string {
  const glossary = Object.entries(GLOSSARY[lang] ?? {})
    .map(([ko, t]) => `  ${ko} = ${t}`)
    .join("\n");
  return `You translate Korean café menu names into ${LANG_LABEL[lang]}.

Output format (STRICT):
- ONLY a JSON array: [{"ko":"<original>","t":"<translation>"}]
- One object per input item, SAME order, and "ko" must be the EXACT input string.
- No explanations, no markdown fences, no extra keys.

Accuracy rules — this is a food menu, a wrong ingredient is a serious error:
- Translate the ACTUAL ingredients. Never substitute a different flavor
  (ginger is NOT cinnamon, chocolate is NOT caramel, strawberry is NOT soda).
- If a token is unfamiliar, transliterate it faithfully rather than guessing
  a similar-sounding product.
- Keep size/count/volume tokens as they are (1L, 500ml, 2개입, BASIC).
- Leading markers stay attached to the translated name if present
  (I-, H-, (HOT), ICED).
- Character/IP names are transliterated, not translated.

Fixed glossary — you MUST use these exact equivalents:
${glossary}`;
}

async function translateBatch(
  lang: string,
  names: string[],
): Promise<Map<string, string>> {
  const res = await fetch(CLOVA_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${CLOVA_API_KEY}`,
      "content-type": "application/json",
      "X-NCP-CLOVASTUDIO-REQUEST-ID": crypto.randomUUID(),
    },
    body: JSON.stringify({
      model: MODEL,
      messages: [
        { role: "system", content: systemPrompt(lang) },
        { role: "user", content: JSON.stringify(names) },
      ],
      max_tokens: 2048,
      temperature: 0.1,
    }),
  });
  if (!res.ok) {
    throw new Error(`CLOVA ${res.status}: ${(await res.text()).slice(0, 200)}`);
  }
  const data = await res.json();
  const text: string = data?.choices?.[0]?.message?.content ?? "";
  // 모델이 코드펜스를 붙이는 경우 대비
  const jsonText = text.replace(/^```(?:json)?\s*|\s*```$/g, "").trim();

  let parsed: unknown;
  try {
    parsed = JSON.parse(jsonText);
  } catch {
    const m = /\[[\s\S]*\]/.exec(jsonText);
    if (!m) throw new Error(`JSON 파싱 실패: ${jsonText.slice(0, 150)}`);
    parsed = JSON.parse(m[0]);
  }

  const out = new Map<string, string>();
  if (!Array.isArray(parsed)) return out;
  for (const row of parsed) {
    const ko = (row?.ko ?? "").toString().trim();
    const t = (row?.t ?? "").toString().trim();
    // 원문에 없는 키(환각)는 버린다
    if (ko && t && names.includes(ko)) out.set(ko, t);
  }
  return out;
}

Deno.serve(async (req) => {
  // 인증 — crawl-deals 와 동일한 fail-closed 패턴
  const secret = Deno.env.get("CRAWL_SECRET");
  if (!secret) return new Response("CRAWL_SECRET 미설정", { status: 503 });
  const given = req.headers.get("x-crawl-secret") ?? "";
  if (given.length !== secret.length || given !== secret) {
    return new Response("forbidden", { status: 403 });
  }
  if (!CLOVA_API_KEY) {
    return new Response("CLOVA_API_KEY 미설정", { status: 503 });
  }

  const url = new URL(req.url);
  const onlyLang = url.searchParams.get("lang");
  const limit = Math.min(
    Number(url.searchParams.get("limit") ?? 300) || 300,
    2000,
  );

  const startedAt = Date.now();
  const langs = onlyLang ? [onlyLang] : ["en", "ja", "zh"];
  const result: Record<string, { done: number; failed: number }> = {};
  let processed = 0;
  let timedOut = false;

  for (const lang of langs) {
    if (!LANG_LABEL[lang]) continue;
    result[lang] = { done: 0, failed: 0 };

    while (processed < limit && !timedOut) {
      const { data: todo, error } = await supabase
        .from("franchise_translation_todo")
        .select("source")
        .eq("lang", lang)
        .limit(BATCH);
      if (error) {
        return new Response(JSON.stringify({ error: error.message }), {
          status: 500,
          headers: { "Content-Type": "application/json" },
        });
      }
      const names = (todo ?? []).map((r) => r.source as string);
      if (names.length === 0) break; // 이 언어는 완료

      try {
        const map = await translateBatch(lang, names);
        const rows = [...map.entries()].map(([source, value]) => ({
          kind: "menu",
          source,
          lang,
          value,
          is_reviewed: false,
        }));
        if (rows.length > 0) {
          const { error: upErr } = await supabase
            .from("franchise_translations")
            .upsert(rows, { onConflict: "kind,source,lang" });
          if (upErr) throw upErr;
        }
        result[lang].done += rows.length;
        result[lang].failed += names.length - rows.length;
        // 한 건도 못 얻으면 무한루프가 되므로 중단
        if (rows.length === 0) break;
      } catch (err) {
        console.error(`[${lang}] 배치 실패:`, String(err));
        result[lang].failed += names.length;
        break;
      }

      processed += names.length;
      if (Date.now() - startedAt > TIME_BUDGET_MS) timedOut = true;
    }
  }

  // 남은 작업량
  const { count: remaining } = await supabase
    .from("franchise_translation_todo")
    .select("*", { count: "exact", head: true });

  return new Response(
    JSON.stringify({
      result,
      processed,
      remaining: remaining ?? null,
      timed_out: timedOut,
      duration_ms: Date.now() - startedAt,
    }, null, 2),
    { headers: { "Content-Type": "application/json" } },
  );
});
