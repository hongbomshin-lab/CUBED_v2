import { CLOVA_MODEL, extractJson } from "./parse.ts";

const CLOVA_URL = "https://clovastudio.stream.ntruss.com/v1/openai/chat/completions";

export interface RecognitionCandidate {
  product_id: string;
  name: string;
}

export interface RecognitionOutput {
  productId: string | null;
  confidence: number;
  reason: string;
}

export interface ValidatedRecognition extends RecognitionOutput {
  matched: boolean;
}

export function buildRecognitionBody(
  candidates: RecognitionCandidate[],
  imageBase64: string,
) {
  const choices = candidates.map((candidate) =>
    `${candidate.product_id}\t${candidate.name}`
  ).join("\n");
  const system = `너는 한국 식품 패키지 앞면을 보고 제품을 식별하는 분류기다.
아래 등록 제품 후보 중 사진과 정확히 같은 SKU 하나만 고른다.
브랜드, 맛, 제품 형태, 제품명 표기가 모두 일치하지 않거나 후보에 없는 제품이면 product_id를 null로 둔다.
추측하지 말고 확신도를 0~1 숫자로 반환한다.
출력은 코드펜스 없이 JSON 객체 하나만 쓴다:
{"product_id":"후보 ID 또는 null","confidence":0.0,"reason":"짧은 한국어 근거"}

후보(product_id<TAB>name):
${choices}`;

  return {
    model: CLOVA_MODEL,
    messages: [
      { role: "system", content: system },
      {
        role: "user",
        content: [
          { type: "text", text: "이 제품 앞면 사진을 후보 중 하나로 분류해줘." },
          {
            type: "image_url",
            image_url: { url: `data:image/jpeg;base64,${imageBase64}` },
          },
        ],
      },
    ],
    // 500이면 모델이 근거 서술을 먼저 쓸 때 JSON이 잘려 "JSON 객체를 찾지 못함"이 난다
    max_tokens: 800,
    temperature: 0,
  };
}

export function normalizeRecognition(
  raw: Record<string, unknown>,
): RecognitionOutput {
  const rawId = raw.product_id;
  const textId = typeof rawId === "string" ? rawId.trim() : "";
  const productId = !textId || textId.toLowerCase() === "none" ||
      textId.toLowerCase() === "null"
    ? null
    : textId;
  const parsedConfidence = typeof raw.confidence === "number"
    ? raw.confidence
    : Number(raw.confidence);
  const confidence = Number.isFinite(parsedConfidence)
    ? Math.max(0, Math.min(1, parsedConfidence))
    : 0;
  return {
    productId,
    confidence,
    reason: typeof raw.reason === "string" ? raw.reason.trim() : "",
  };
}

export function parseRecognitionText(text: string): RecognitionOutput {
  return normalizeRecognition(extractJson(text));
}

export function validateRecognition(
  output: RecognitionOutput,
  candidates: RecognitionCandidate[],
  minConfidence = 0.7,
): ValidatedRecognition {
  const candidateIds = new Set(candidates.map((candidate) => candidate.product_id));
  const matched = output.productId != null &&
    candidateIds.has(output.productId) &&
    output.confidence >= minConfidence;
  return { ...output, matched, productId: matched ? output.productId : null };
}

export async function recognizeWithClova(
  candidates: RecognitionCandidate[],
  imageBase64: string,
  apiKey: string,
): Promise<ValidatedRecognition> {
  const response = await fetch(CLOVA_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "content-type": "application/json",
      "X-NCP-CLOVASTUDIO-REQUEST-ID": crypto.randomUUID(),
    },
    body: JSON.stringify(buildRecognitionBody(candidates, imageBase64)),
  });
  if (!response.ok) {
    const text = await response.text();
    throw new Error(`CLOVA API ${response.status}: ${text.slice(0, 500)}`);
  }
  const data = await response.json();
  const text = data?.choices?.[0]?.message?.content ?? "{}";
  // 단계별 진단 로그: 어떤 단계에서 매칭이 틀어지는지 function_logs로 추적.
  let output: RecognitionOutput;
  try {
    output = parseRecognitionText(text);
  } catch (e) {
    console.error(
      `recognize: JSON 파싱 실패 (finish=${data?.choices?.[0]?.finish_reason}) raw=${
        String(text).slice(0, 300)
      }`,
    );
    throw e;
  }
  const validated = validateRecognition(output, candidates);
  console.log(
    `recognize: 후보 ${candidates.length}개 → id=${output.productId} conf=${output.confidence} ` +
      `matched=${validated.matched} reason=${output.reason.slice(0, 80)}`,
  );
  if (output.productId && !validated.matched) {
    const inSet = candidates.some((c) => c.product_id === output.productId);
    console.error(
      inSet
        ? `recognize: 확신도 미달(${output.confidence} < 0.7)로 기각 — id=${output.productId}`
        : `recognize: 모델이 후보에 없는 id 반환(오타 가능) — id=${output.productId}`,
    );
  }
  return validated;
}

