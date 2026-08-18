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
const BATCH = 25;
/** 이 시간을 넘기면 남은 건 다음 호출로 미룬다(Edge 컴퓨트 한도 회피). */
const TIME_BUDGET_MS = 180_000;

const LANG_LABEL: Record<string, string> = {
  en: "English",
  ja: "Japanese (日本語)",
  zh: "Simplified Chinese (简体中文)",
};

function systemPrompt(lang: string): string {
  return `You translate Korean café menu names into ${LANG_LABEL[lang]}.

Rules:
- Output ONLY a JSON array of objects: [{"ko":"<original>","t":"<translation>"}]
- Keep the SAME number of items and the EXACT original Korean string in "ko".
- These are beverage/dessert menu items from Korean coffee chains.
- Translate meaning, not sound, when the word is a common food term
  (아메리카노 → Americano, 자몽 → Grapefruit, 흑당 → Brown Sugar, 라떼 → Latte).
- Keep brand/product proper nouns recognizable; romanize only when there is no
  common equivalent (헛개 → Oriental Raisin).
- Keep size/count tokens as-is when present (1L, 500ml, 2개입).
- No explanations, no markdown fences, no extra keys.`;
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
