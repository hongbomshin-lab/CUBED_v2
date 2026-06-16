import { assert, assertEquals } from "jsr:@std/assert@1";
import { buildGeminiBody } from "./parse.ts";

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
