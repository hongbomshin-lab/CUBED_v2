import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  buildRecognitionBody,
  normalizeRecognition,
  parseRecognitionText,
  validateRecognition,
} from "./recognize.ts";

const candidates = [
  { product_id: "p-choco", name: "라라스윗 저당 초콜릿 초코바" },
  { product_id: "p-vanilla", name: "라라스윗 저당 바닐라 초코바" },
];

Deno.test("인식 요청에 이미지 한 장과 전체 후보를 넣는다", () => {
  const body = buildRecognitionBody(candidates, "ABC");
  const messages = body.messages as Array<Record<string, unknown>>;
  assertEquals(messages.length, 2);
  assert(JSON.stringify(messages).includes("p-choco"));
  assert(JSON.stringify(messages).includes("p-vanilla"));
  assert(JSON.stringify(messages).includes("data:image/jpeg;base64,ABC"));
});

Deno.test("코드펜스와 문자열 confidence를 정규화한다", () => {
  const result = parseRecognitionText(
    '```json\n{"product_id":"p-choco","confidence":"0.91","reason":"초콜릿 표기"}\n```',
  );
  assertEquals(result.productId, "p-choco");
  assertEquals(result.confidence, 0.91);
});

Deno.test("none과 범위를 벗어난 confidence를 보정한다", () => {
  const result = normalizeRecognition({ product_id: "none", confidence: 2 });
  assertEquals(result.productId, null);
  assertEquals(result.confidence, 1);
});

Deno.test("후보 밖 ID와 낮은 confidence를 거부한다", () => {
  assertEquals(
    validateRecognition(
      { productId: "invented", confidence: 0.99, reason: "" },
      candidates,
    ).matched,
    false,
  );
  assertEquals(
    validateRecognition(
      { productId: "p-choco", confidence: 0.69, reason: "" },
      candidates,
    ).matched,
    false,
  );
});

