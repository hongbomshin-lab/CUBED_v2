import { assert, assertEquals } from "jsr:@std/assert@1";
import { buildClovaBody, buildGeminiBody, extractJson, normalizeParsed } from "./parse.ts";

Deno.test("멀티이미지 3장 → inline_data 3개 + system instruction 포함", () => {
  const body = buildGeminiBody([
    { role: "full", base64: "AAA" },
    { role: "ingredients", base64: "BBB" },
    { role: "nutrition", base64: "CCC" },
  ]);
  assert(body.system_instruction.parts[0].text.length > 0);
  const parts = body.contents[0].parts as Array<Record<string, unknown>>;
  const inline = parts.filter((p) => "inline_data" in p);
  assertEquals(inline.length, 3);
  assertEquals((inline[0].inline_data as { data: string }).data, "AAA");
  assertEquals(body.generationConfig.responseMimeType, "application/json");
});

Deno.test("단일 이미지 → inline_data 1개", () => {
  const body = buildGeminiBody([{ role: "single", base64: "XYZ" }]);
  const parts = body.contents[0].parts as Array<Record<string, unknown>>;
  assertEquals(parts.filter((p) => "inline_data" in p).length, 1);
});

// ── CLOVA (HCX-005) ──
Deno.test("CLOVA: 이미지 3장 → 이미지별 user 턴 + system + 마무리 = 5 메시지", () => {
  const body = buildClovaBody([
    { role: "full", base64: "AAA" },
    { role: "ingredients", base64: "BBB" },
    { role: "nutrition", base64: "CCC" },
  ]);
  assertEquals(body.model, "HCX-005");
  const msgs = body.messages as Array<Record<string, unknown>>;
  assertEquals(msgs.length, 5); // system + 3 image turns + final
  assertEquals(msgs[0].role, "system");
  const imageTurns = msgs.filter((m) =>
    Array.isArray(m.content) &&
    (m.content as Array<Record<string, unknown>>).some((p) => p.type === "image_url")
  );
  assertEquals(imageTurns.length, 3);
  const first = (msgs[1].content as Array<Record<string, unknown>>)
    .find((p) => p.type === "image_url") as { image_url: { url: string } };
  assert(first.image_url.url.startsWith("data:image/jpeg;base64,AAA"));
});

Deno.test("CLOVA: extractJson 은 코드펜스를 걷어낸다", () => {
  const obj = extractJson("```json\n{\"a\": 1}\n```");
  assertEquals(obj.a, 1);
});

Deno.test("CLOVA: normalizeParsed 는 ingredients_raw 배열을 문자열로, sweeteners를 정리한다", () => {
  const out = normalizeParsed({
    ingredients_raw: ["정제수, 아세설팜칼륨, 수크랄로스"],
    sweeteners: [
      { slug: "acesulfame-potassium", amount_g: 0 },
      { slug: "sucralose" },
      { slug: "", amount_g: 1 }, // 빈 slug 제거
      null,
    ],
    // unknown_sweeteners 누락 → [] 로 보정
  } as Record<string, unknown>);
  assertEquals(typeof out.ingredients_raw, "string");
  assert((out.ingredients_raw as string).includes("아세설팜칼륨"));
  const sw = out.sweeteners as Array<{ slug: string; amount_g: number | null }>;
  assertEquals(sw.length, 2);
  assertEquals(sw[1].amount_g, null); // 누락 amount_g → null
  assertEquals(out.unknown_sweeteners, []);
});
