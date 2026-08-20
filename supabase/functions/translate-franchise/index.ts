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

/**
 * 재료 정합성 규칙 — 원문에 왼쪽 낱말이 있으면 번역문에 오른쪽 후보 중
 * 하나가 반드시 있어야 한다. 메뉴 번역에서 가장 치명적인 오류가
 * '재료 바꿔치기'(딸기→체리, 바닐라→초콜릿)라 기계적으로 걸러낸다.
 * 검증 실패분은 적재하지 않고 1건씩 재요청한다.
 */
const INGREDIENTS: Array<[string[], string[], string[], string[]]> = [
  [["레몬"], ["lemon"], ["レモン"], ["柠檬"]],
  [["자몽"], ["grapefruit"], ["グレープフルーツ"], ["西柚", "葡萄柚"]],
  [["딸기"], ["strawberry"], ["ストロベリー", "いちご", "イチゴ"], ["草莓"]],
  [["초코", "초콜릿", "쇼콜라"], ["choco"], ["チョコ", "ショコラ"], ["巧克力"]],
  [["망고"], ["mango"], ["マンゴー"], ["芒果"]],
  [["바나나"], ["banana"], ["バナナ"], ["香蕉"]],
  [["복숭아", "피치"], ["peach"], ["ピーチ", "桃"], ["桃"]],
  [["블루베리"], ["blueberry"], ["ブルーベリー"], ["蓝莓"]],
  [["사과", "애플"], ["apple"], ["アップル", "りんご", "リンゴ"], ["苹果"]],
  [["포도", "그레이프"], ["grape"], ["グレープ", "ぶどう"], ["葡萄"]],
  [["유자"], ["yuzu", "citron"], ["ゆず", "ユズ", "柚子"], ["柚子"]],
  [["생강"], ["ginger"], ["生姜", "ジンジャー", "しょうが"], ["生姜", "姜"]],
  [["녹차", "그린티", "말차"], ["green tea", "matcha"], ["抹茶", "緑茶", "グリーンティー"], ["绿茶", "抹茶"]],
  [["홍차", "블랙티"], ["black tea"], ["紅茶", "ブラックティー"], ["红茶"]],
  [["고구마"], ["sweet potato"], ["さつまいも", "スイートポテト"], ["红薯", "地瓜", "番薯"]],
  [["감자"], ["potato"], ["じゃがいも", "ポテト"], ["土豆", "马铃薯"]],
  [["우베", "타로"], ["ube", "taro"], ["ウベ", "タロ"], ["芋", "紫薯"]],
  [["오트", "귀리"], ["oat"], ["オート", "オーツ"], ["燕麦"]],
  [["아몬드"], ["almond"], ["アーモンド"], ["杏仁"]],
  [["땅콩"], ["peanut"], ["ピーナッツ", "落花生"], ["花生"]],
  [["코코넛"], ["coconut"], ["ココナッツ"], ["椰"]],
  [["레드빈", "팥"], ["red bean"], ["あずき", "小豆", "レッドビーン"], ["红豆"]],
  [["옥수수"], ["corn"], ["コーン", "とうもろこし"], ["玉米"]],
  [["흑임자", "검은깨"], ["black sesame"], ["黒ごま", "ブラックセサミ"], ["黑芝麻"]],
  [["수박"], ["watermelon"], ["スイカ", "西瓜"], ["西瓜"]],
  [["파인애플"], ["pineapple"], ["パイナップル"], ["菠萝", "凤梨"]],
  [["오렌지"], ["orange"], ["オレンジ"], ["橙", "橘"]],
  [["라임"], ["lime"], ["ライム"], ["青柠", "莱姆"]],
  [["체리"], ["cherry"], ["チェリー", "さくらんぼ"], ["樱桃"]],
  [["멜론"], ["melon"], ["メロン"], ["蜜瓜", "甜瓜"]],
  [["자두"], ["plum"], ["プラム", "すもも"], ["李", "梅"]],
  [["대추"], ["jujube", "date"], ["なつめ"], ["红枣", "枣"]],
  [["인절미"], ["injeolmi", "rice cake"], ["きなこ", "インジョルミ"], ["黄豆粉", "打糕"]],
  [["카라멜", "캬라멜"], ["caramel"], ["キャラメル", "カラメル"], ["焦糖", "卡拉"]],
  [["바닐라"], ["vanilla"], ["バニラ"], ["香草", "云呢拿"]],
  [["헤이즐넛"], ["hazelnut"], ["ヘーゼルナッツ"], ["榛果", "榛子"]],
  [["민트"], ["mint"], ["ミント"], ["薄荷"]],
  [["복분자"], ["bokbunja", "raspberry"], ["ラズベリー", "ボクブンジャ"], ["覆盆子", "树莓"]],
  [["요거트", "요구르트"], ["yogurt", "yoghurt"], ["ヨーグルト"], ["酸奶", "优格"]],
  [["치즈"], ["cheese"], ["チーズ"], ["奶酪", "芝士"]],
];

const LANG_COL: Record<string, number> = { en: 1, ja: 2, zh: 3 };

/** 재료가 뒤바뀌지 않았는지 검사. 문제가 없으면 null, 있으면 기대 후보 목록. */
function ingredientMiss(
  lang: string,
  source: string,
  value: string,
): string[] | null {
  const col = LANG_COL[lang];
  if (!col) return null;
  const low = value.toLowerCase();
  for (const rule of INGREDIENTS) {
    if (!rule[0].some((k) => source.includes(k))) continue;
    const expected = rule[col] as string[];
    if (!expected.some((e) => low.includes(e.toLowerCase()))) return expected;
  }
  return null;
}

function systemPrompt(lang: string): string {
  const glossary = Object.entries(GLOSSARY[lang] ?? {})
    .map(([ko, t]) => `  ${ko} = ${t}`)
    .join("\n");
  return `You translate Korean café menu names into ${LANG_LABEL[lang]}.

Output format (STRICT):
- The input is a numbered list. Output EXACTLY one line per input item.
- Each line: the number, a period, a space, then ONLY the translation.
    1. First translation
    2. Second translation
- Same count, same order. No quotes, no JSON, no markdown, no commentary.

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
        {
          role: "user",
          content: names.map((n, i) => `${i + 1}. ${n}`).join("\n"),
        },
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

  // "1. 번역" 형태를 줄 단위로 파싱.
  // JSON 을 쓰지 않는 이유: 번역문에 따옴표·아포스트로피가 섞이면 모델이 이스케이프를
  // 자주 틀려 배치 전체가 파싱 실패했다(실측). 줄 포맷은 그 문제가 없다.
  const out = new Map<string, string>();
  const numbered = /^\s*(\d+)\s*[.)]\s*(.+?)\s*$/;
  for (const line of text.split("\n")) {
    const m = numbered.exec(line);
    if (!m) continue;
    const idx = parseInt(m[1], 10) - 1;
    const value = m[2].replace(/^["'`]|["'`]$/g, "").trim();
    if (idx >= 0 && idx < names.length && value) out.set(names[idx], value);
  }
  if (out.size === 0) {
    throw new Error(`응답 파싱 실패: ${text.slice(0, 150)}`);
  }
  return out;
}

/**
 * 배치 번역 + 재료 검증. 검증에 걸린 건은 1건씩 다시 물어보고,
 * 그래도 틀리면 결과에서 뺀다(잘못된 번역을 적재하는 것보다 없는 편이 낫다).
 */
async function translateChecked(
  lang: string,
  names: string[],
): Promise<{ ok: Map<string, string>; rejected: string[]; notes: string[] }> {
  const notes: string[] = [];
  const first = await translateBatch(lang, names);
  const ok = new Map<string, string>();
  const suspect: string[] = [];

  // 배치 응답에서 아예 빠진 항목도 재시도 대상.
  for (const n of names) if (!first.has(n)) suspect.push(n);

  for (const [source, value] of first) {
    if (ingredientMiss(lang, source, value)) suspect.push(source);
    else ok.set(source, value);
  }

  const rejected: string[] = [];
  for (const source of suspect) {
    try {
      // 1건만 주면 배치 내 위치 밀림·재료 혼선이 사라져 대부분 바로잡힌다.
      const retry = await translateBatch(lang, [source]);
      const value = retry.get(source);
      if (value && !ingredientMiss(lang, source, value)) {
        ok.set(source, value);
      } else {
        rejected.push(source);
        // 왜 탈락했는지 몇 건만 남긴다 — 모델 문제인지 규칙 문제인지 구분용.
        if (notes.length < 8) {
          const miss = value ? ingredientMiss(lang, source, value) : null;
          notes.push(
            value
              ? `${source} → ${value} (기대: ${miss?.join("/") ?? "?"})`
              : `${source} → (응답 없음)`,
          );
        }
      }
    } catch (err) {
      rejected.push(source);
      if (notes.length < 8) notes.push(`${source} → 호출실패: ${String(err).slice(0, 120)}`);
    }
  }
  return { ok, rejected, notes };
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
  let processed = 0;
  let timedOut = false;

  // ── 보수 모드: 이미 적재된 번역 중 재료가 어긋난 것만 다시 번역해 덮어쓴다.
  //    (초기 대량 번역분에 딸기→체리, 바닐라→초콜릿 같은 재료 바꿔치기가 섞였다)
  if (url.searchParams.get("mode") === "repair") {
    const repaired: Record<string, unknown> = {};
    for (const lang of langs) {
      if (!LANG_LABEL[lang]) continue;

      // 언어별 전체를 받아 규칙 위반분만 추린다(언어당 1,000건 미만).
      const rows: Array<{ source: string; value: string }> = [];
      for (let from = 0; ; from += 1000) {
        const { data, error } = await supabase
          .from("franchise_translations")
          .select("source, value")
          .eq("kind", "menu")
          .eq("lang", lang)
          .range(from, from + 999);
        if (error) {
          return new Response(JSON.stringify({ error: error.message }), {
            status: 500,
            headers: { "Content-Type": "application/json" },
          });
        }
        rows.push(...(data ?? []));
        if ((data?.length ?? 0) < 1000) break;
      }

      const broken = rows
        .filter((r) => ingredientMiss(lang, r.source, r.value))
        .map((r) => r.source);

      let fixed = 0;
      let stillBad = 0;
      const notes: string[] = [];
      for (let i = 0; i < broken.length; i += BATCH) {
        if (Date.now() - startedAt > TIME_BUDGET_MS) {
          timedOut = true;
          break;
        }
        const slice = broken.slice(i, i + BATCH);
        try {
          const { ok, rejected, notes: n } = await translateChecked(lang, slice);
          stillBad += rejected.length;
          for (const x of n) if (notes.length < 12) notes.push(x);
          const upserts = [...ok.entries()].map(([source, value]) => ({
            kind: "menu",
            source,
            lang,
            value,
            is_reviewed: false,
          }));
          if (upserts.length > 0) {
            const { error: upErr } = await supabase
              .from("franchise_translations")
              .upsert(upserts, { onConflict: "kind,source,lang" });
            if (upErr) throw upErr;
            fixed += upserts.length;
          }
        } catch (err) {
          console.error(`[${lang}] 보수 배치 실패:`, String(err));
          stillBad += slice.length;
          if (notes.length < 12) notes.push(`배치실패: ${String(err).slice(0, 160)}`);
        }
        processed += slice.length;
      }
      repaired[lang] = {
        detected: broken.length,
        fixed,
        still_bad: stillBad,
        notes,
      };
      if (timedOut) break;
    }
    return new Response(
      JSON.stringify(
        { mode: "repair", repaired, processed, timed_out: timedOut, duration_ms: Date.now() - startedAt },
        null,
        2,
      ),
      { headers: { "Content-Type": "application/json" } },
    );
  }
  const result: Record<
    string,
    { done: number; failed: number; rejected: number; errors: string[] }
  > = {};

  for (const lang of langs) {
    if (!LANG_LABEL[lang]) continue;
    result[lang] = { done: 0, failed: 0, rejected: 0, errors: [] };

    // 실패한 배치를 건너뛰기 위한 오프셋.
    // 성공분은 todo 뷰에서 빠지므로 정상 흐름에선 0 유지.
    let offset = 0;

    while (processed < limit && !timedOut) {
      const { data: todo, error } = await supabase
        .from("franchise_translation_todo")
        .select("source")
        .eq("lang", lang)
        .range(offset, offset + BATCH - 1);
      if (error) {
        return new Response(JSON.stringify({ error: error.message }), {
          status: 500,
          headers: { "Content-Type": "application/json" },
        });
      }
      const names = (todo ?? []).map((r) => r.source as string);
      if (names.length === 0) break; // 이 언어는 완료

      try {
        const { ok: map, rejected } = await translateChecked(lang, names);
        if (rejected.length > 0) {
          result[lang].rejected += rejected.length;
          console.warn(`[${lang}] 재료 검증 탈락 ${rejected.length}건:`, rejected.join(", "));
        }
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
        // 검증 탈락분은 todo 에 남아 무한 재시도가 되므로 건너뛴다.
        offset += rejected.length;
        // 한 건도 못 얻은 배치는 건너뛴다(같은 배치 무한 재시도 방지)
        if (rows.length === 0) {
          if (result[lang].errors.length < 3) result[lang].errors.push("매칭 0건(모델 응답 형식 확인 필요)");
          offset += BATCH;
        }
      } catch (err) {
        // 배치 하나가 죽어도 전체를 멈추지 않는다 — 다음 배치로 진행
        console.error(`[${lang}] 배치 실패(건너뜀 offset=${offset}):`, String(err));
        if (result[lang].errors.length < 3) result[lang].errors.push(String(err).slice(0, 300));
        result[lang].failed += names.length;
        offset += BATCH;
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
