> ⚠️ **아카이브 문서** — 작성 시점의 설계 기록입니다. 현재 스펙은 [`docs/product-spec.md`](../../product-spec.md)를 보세요.

# UGC 제품 확장 파이프라인 — 구현 계획 (Phase 1)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 바코드 미등록 제품을 사용자가 사진 3장(전체샷·원재료·영양성분)으로 촬영하면, AI가 멀티이미지로 분석해 결과를 즉시 보여주고, 제보(바코드+사진3장+파싱전체)를 DB에 저장하는 성장 루프를 만든다.

**Architecture:** Gemini 멀티이미지 파싱 로직을 `_shared/parse.ts`로 단일화하고, 신규 `submit-product` Edge Function(service_role)이 파싱→Storage 업로드→`user_submissions` insert→결과 반환을 한 번에 처리한다. 앱은 3단계 가이드 촬영 화면에서 3장을 모아 이 함수를 호출한다. 클라이언트는 service_role/스토리지 정책 없이 동작한다.

**Tech Stack:** Flutter 3.27 + Riverpod 2.5 + supabase_flutter 2.5 / Supabase Edge Functions(Deno) + Gemini 3.1 Flash Lite / image_picker 1.1.

**참조 스펙:** [docs/superpowers/specs/2026-06-16-ugc-product-pipeline-design.md](../specs/2026-06-16-ugc-product-pipeline-design.md)

**전제(다른 컴퓨터에서 시작 시):** `git fetch && git checkout feature/ugc-product-pipeline && flutter pub get`. Edge Function 배포에는 `supabase login` + `supabase link --project-ref aqhfddvvxnakgkdtirem` 1회 필요(또는 Supabase MCP `deploy_edge_function`/`apply_migration` 사용). `GEMINI_API_KEY` 시크릿은 이미 설정돼 있음(기존 `ocr-parse`가 사용 중) — Phase 1에서 새 시크릿 불필요.

---

## 파일 구조 (Phase 1)

신규
- `supabase/migrations/20260616090000_submission_images_bucket.sql` — 비공개 Storage 버킷 생성
- `supabase/functions/_shared/parse.ts` — Gemini 멀티이미지 파싱(단일 진실원천)
- `supabase/functions/_shared/parse_test.ts` — 요청 빌더 순수 단위 테스트(Deno)
- `supabase/functions/submit-product/index.ts` — 파싱+업로드+제보저장+반환
- `lib/features/capture/capture_controller.dart` — 3장 촬영 상태(Riverpod)
- `lib/features/capture/capture_screen.dart` — 3단계 가이드 촬영 UI
- `test/features/capture/capture_controller_test.dart`
- `test/features/ocr/ocr_result_test.dart`

수정
- `supabase/functions/ocr-parse/index.ts` — 내부를 `_shared/parse.ts`로 리팩터(단일 이미지 하위호환)
- `lib/features/ocr/ocr_service.dart` — `OcrResult.fromParsed` 순수 매퍼 추출 + `parseAndSubmit` 추가, 기존 `parseImage` 제거
- `lib/features/scan/scan_screen.dart` — 바텀시트가 `CaptureScreen`으로 진입
- `lib/data/product_repository.dart` — 미사용 `submitOcr` 제거

제거
- `lib/features/ocr/ocr_screen.dart` — `CaptureScreen`으로 대체

---

## Task 1: Storage 버킷 마이그레이션

**Files:**
- Create: `supabase/migrations/20260616090000_submission_images_bucket.sql`

사용자 원본 사진을 담을 비공개 버킷. RLS 정책을 추가하지 않으므로 service_role(Edge Function)만 접근 가능 = 의도된 동작.

- [ ] **Step 1: 마이그레이션 SQL 작성**

```sql
-- 사용자 제보 원본 사진(전체샷/원재료/영양성분) 비공개 버킷.
-- 정책 없음 → service_role(Edge Function)만 읽기/쓰기. 의도된 동작.
insert into storage.buckets (id, name, public)
values ('submission-images', 'submission-images', false)
on conflict (id) do nothing;
```

- [ ] **Step 2: 적용**

Supabase MCP `apply_migration`(name=`submission_images_bucket`, 위 SQL) 또는 CLI:
```bash
supabase db push
```

- [ ] **Step 3: 적용 확인**

SQL 실행 (MCP `execute_sql` 또는 SQL editor):
```sql
select id, public from storage.buckets where id = 'submission-images';
```
Expected: 1행, `public = false`.

- [ ] **Step 4: 커밋**

```bash
git add supabase/migrations/20260616090000_submission_images_bucket.sql
git commit -m "feat(db): submission-images 비공개 버킷 마이그레이션"
```

---

## Task 2: 공유 파싱 모듈 `_shared/parse.ts`

**Files:**
- Create: `supabase/functions/_shared/parse.ts`
- Test: `supabase/functions/_shared/parse_test.ts`

Gemini 호출/스키마/프롬프트를 한 곳으로 모은다. `buildGeminiBody`는 네트워크 없는 순수 함수라 단위 테스트 대상.

- [ ] **Step 1: 실패하는 테스트 작성**

`supabase/functions/_shared/parse_test.ts`:
```ts
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
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `deno test --allow-env supabase/functions/_shared/parse_test.ts`
Expected: FAIL — `Module not found "./parse.ts"` 또는 `buildGeminiBody is not exported`.

- [ ] **Step 3: `parse.ts` 구현**

`supabase/functions/_shared/parse.ts`:
```ts
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
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `deno test --allow-env supabase/functions/_shared/parse_test.ts`
Expected: PASS (`ok | 2 passed | 0 failed`).
(Deno 미설치 시: https://deno.land 설치 후 실행. 설치가 어려우면 이 테스트는 건너뛰고 Task 4의 실제 invoke로 검증.)

- [ ] **Step 5: 커밋**

```bash
git add supabase/functions/_shared/parse.ts supabase/functions/_shared/parse_test.ts
git commit -m "feat(fn): Gemini 멀티이미지 공유 파싱 모듈 _shared/parse.ts"
```

---

## Task 3: `ocr-parse`를 공유 모듈로 리팩터 (하위호환)

**Files:**
- Modify: `supabase/functions/ocr-parse/index.ts`

기존 단일 이미지 동작은 유지하되 내부를 `_shared/parse.ts`로 통일(DRY). `images` 멀티이미지도 받게 확장.

- [ ] **Step 1: `index.ts` 전체 교체**

`supabase/functions/ocr-parse/index.ts`:
```ts
// CUBED OCR 파싱 Edge Function (Deno) — 공유 파싱 모듈 사용.
// 단일 image(하위호환) 또는 images:{full,ingredients,nutrition} 멀티이미지 지원.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { parseNutrition, type ParseImage } from "../_shared/parse.ts";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (!GEMINI_API_KEY) return json({ error: "GEMINI_API_KEY 미설정" }, 500);
  try {
    const { image, images, media_type } = await req.json();
    const imgs = toParseImages(image, images, media_type);
    if (imgs.length === 0) return json({ error: "image 또는 images 필요" }, 400);
    const parsed = await parseNutrition(imgs, GEMINI_API_KEY);
    return json(parsed, 200);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

function toParseImages(
  image: string | undefined,
  images: Record<string, string> | undefined,
  mediaType: string | undefined,
): ParseImage[] {
  if (images && typeof images === "object") {
    const out: ParseImage[] = [];
    for (const role of ["full", "ingredients", "nutrition"] as const) {
      if (images[role]) out.push({ role, base64: images[role], mimeType: mediaType });
    }
    return out;
  }
  if (image) return [{ role: "single", base64: image, mimeType: mediaType }];
  return [];
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "content-type": "application/json" },
  });
}
```

- [ ] **Step 2: 배포**

```bash
supabase functions deploy ocr-parse
```
(또는 Supabase MCP `deploy_edge_function` slug=`ocr-parse`, 위 `index.ts` + `_shared/parse.ts` 함께 전송.)
Expected: `Deployed Function ocr-parse`.

- [ ] **Step 3: 단일 이미지 하위호환 invoke 확인**

작은 영양성분표 사진 1장을 base64로 만들어 호출:
```bash
B64=$(base64 -w0 sample_nutrition.jpg)
curl -s -X POST "https://aqhfddvvxnakgkdtirem.supabase.co/functions/v1/ocr-parse" \
  -H "Authorization: Bearer <ANON_KEY>" -H "content-type: application/json" \
  -d "{\"image\":\"$B64\"}" | head -c 400
```
Expected: `{"name":...,"category":...,"sweeteners":[...]}` 형태의 JSON (200). `error` 없음.

- [ ] **Step 4: 커밋**

```bash
git add supabase/functions/ocr-parse/index.ts
git commit -m "refactor(fn): ocr-parse를 _shared/parse.ts 기반으로 통일 + 멀티이미지 수용"
```

---

## Task 4: `submit-product` Edge Function

**Files:**
- Create: `supabase/functions/submit-product/index.ts`

3장 base64 + 바코드 → 파싱 → `submission-images/{uuid}/`에 업로드 → `user_submissions` insert → 파싱 결과 반환. 모두 service_role로 수행(클라이언트 정책 불필요). 업로드/insert 실패는 비치명적(파싱 결과는 반환).

- [ ] **Step 1: `index.ts` 작성**

`supabase/functions/submit-product/index.ts`:
```ts
// CUBED 제보 Edge Function (Deno, service_role).
// 입력: { images:{full,ingredients,nutrition}(base64), barcode? }
// 처리: Gemini 파싱 → submission-images 업로드 → user_submissions insert → 파싱 반환.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { parseNutrition, type ParseImage } from "../_shared/parse.ts";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function b64ToBytes(b64: string): Uint8Array {
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (!GEMINI_API_KEY) return json({ error: "GEMINI_API_KEY 미설정" }, 500);
  try {
    const { images, barcode } = await req.json();
    if (!images?.full || !images?.ingredients || !images?.nutrition) {
      return json({ error: "images.full/ingredients/nutrition 3장 필요" }, 400);
    }

    const imgs: ParseImage[] = [
      { role: "full", base64: images.full },
      { role: "ingredients", base64: images.ingredients },
      { role: "nutrition", base64: images.nutrition },
    ];
    const parsed = await parseNutrition(imgs, GEMINI_API_KEY);

    // 제보 영속화(비치명적). 실패해도 파싱 결과는 돌려준다.
    try {
      const db = createClient(SUPABASE_URL, SERVICE_ROLE);
      const folder = crypto.randomUUID();
      const bucket = db.storage.from("submission-images");
      await Promise.all([
        bucket.upload(`${folder}/full.jpg`, b64ToBytes(images.full), { contentType: "image/jpeg" }),
        bucket.upload(`${folder}/ingredients.jpg`, b64ToBytes(images.ingredients), { contentType: "image/jpeg" }),
        bucket.upload(`${folder}/nutrition.jpg`, b64ToBytes(images.nutrition), { contentType: "image/jpeg" }),
      ]);
      await db.from("user_submissions").insert({
        barcode: barcode ?? null,
        image_path: folder,
        parsed,
        ocr_text: (parsed as { ingredients_raw?: string }).ingredients_raw ?? null,
        status: "pending",
      });
    } catch (persistErr) {
      console.error("submit-product persist 실패(비치명적):", String(persistErr));
    }

    return json(parsed, 200);
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
```

- [ ] **Step 2: 배포**

```bash
supabase functions deploy submit-product
```
(또는 MCP `deploy_edge_function` slug=`submit-product`, `index.ts` + `_shared/parse.ts` 전송. verify_jwt 기본 true 유지.)
Expected: `Deployed Function submit-product`.

- [ ] **Step 3: 실제 invoke로 end-to-end 확인**

전체샷/원재료/영양성분 사진 각 1장을 base64로:
```bash
F=$(base64 -w0 full.jpg); I=$(base64 -w0 ingredients.jpg); N=$(base64 -w0 nutrition.jpg)
curl -s -X POST "https://aqhfddvvxnakgkdtirem.supabase.co/functions/v1/submit-product" \
  -H "Authorization: Bearer <ANON_KEY>" -H "content-type: application/json" \
  -d "{\"barcode\":\"8801234567890\",\"images\":{\"full\":\"$F\",\"ingredients\":\"$I\",\"nutrition\":\"$N\"}}" | head -c 400
```
Expected: 파싱 JSON(200).

- [ ] **Step 4: 제보 저장 확인**

SQL (MCP `execute_sql`):
```sql
select id, barcode, image_path, status, parsed->>'name' as name, parsed->>'category' as category
from public.user_submissions order by created_at desc limit 1;
```
Expected: 방금 제보 1행 — `barcode='8801234567890'`, `image_path`=uuid, `status='pending'`, `name`/`category` 채워짐.

Storage 확인:
```sql
select name from storage.objects where bucket_id='submission-images' order by created_at desc limit 3;
```
Expected: `{uuid}/full.jpg`, `{uuid}/ingredients.jpg`, `{uuid}/nutrition.jpg`.

- [ ] **Step 5: 커밋**

```bash
git add supabase/functions/submit-product/index.ts
git commit -m "feat(fn): submit-product — 멀티이미지 파싱+업로드+제보저장"
```

---

## Task 5: `OcrResult.fromParsed` 순수 매퍼 추출

**Files:**
- Modify: `lib/features/ocr/ocr_service.dart`
- Test: `test/features/ocr/ocr_result_test.dart`

응답 JSON → `Product` 매핑을 순수 함수로 분리해 테스트한다(현재는 `parseImage` 안에 인라인).

- [ ] **Step 1: 실패하는 테스트 작성**

`test/features/ocr/ocr_result_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cubed_app/features/ocr/ocr_service.dart';

void main() {
  test('fromParsed: 파싱맵 → Product + 미지감미료', () {
    final m = <String, dynamic>{
      'name': '제로 콜라',
      'brand': '테스트',
      'category': '탄산음료',
      'serving_size': 355,
      'unit': 'ml',
      'kcal': 0, 'carb': 0, 'sugar': 0, 'protein': 0, 'fat': 0,
      'ingredients_raw': '정제수, 합성착향료, 수크랄로스, 아세설팜칼륨',
      'sweeteners': [
        {'slug': 'sucralose', 'amount_g': null},
        {'slug': 'acesulfame-potassium', 'amount_g': null},
      ],
      'unknown_sweeteners': ['신종감미료X'],
      'notes': null,
    };

    final r = OcrResult.fromParsed(m, barcode: '8801234567890');

    expect(r.product.name, '제로 콜라');
    expect(r.product.category, '탄산음료');
    expect(r.product.unit, 'ml');
    expect(r.product.barcode, '8801234567890');
    expect(r.product.verified, false);
    expect(r.product.sourceType, 'OCR제보');
    expect(r.product.sweeteners.length, 2);
    expect(r.product.sweeteners.first.slug, 'sucralose');
    expect(r.product.sweetenerCount, 2);
    expect(r.unknownSweeteners, ['신종감미료X']);
  });

  test('fromParsed: 누락 필드는 기본값', () {
    final r = OcrResult.fromParsed({'category': '과자/스낵', 'unit': 'g', 'sweeteners': []});
    expect(r.product.name, '촬영한 제품');
    expect(r.product.kcal, 0);
    expect(r.product.sweeteners, isEmpty);
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/features/ocr/ocr_result_test.dart`
Expected: 컴파일 실패 — `The method 'fromParsed' isn't defined for the type 'OcrResult'`.

- [ ] **Step 3: `ocr_service.dart` 수정 — `fromParsed` 추가**

`lib/features/ocr/ocr_service.dart`에서 `OcrResult` 클래스에 팩토리 추가(클래스 본문 내, 기존 생성자 아래):
```dart
  /// 파싱 결과 맵 → OcrResult (순수 변환; 네트워크 무관). ocr-parse/submit-product 응답 공용.
  factory OcrResult.fromParsed(Map<String, dynamic> m, {String? barcode}) {
    double d(dynamic v) => (v as num?)?.toDouble() ?? 0;
    final swList = ((m['sweeteners'] as List?) ?? const [])
        .asMap()
        .entries
        .map((e) => ProductSweetener(
              slug: (e.value as Map)['slug'] as String,
              amountG: ((e.value as Map)['amount_g'] as num?)?.toDouble(),
              sortOrder: e.key,
            ))
        .toList();
    final product = Product(
      productId: 'ocr-temp',
      name: (m['name'] as String?) ?? '촬영한 제품',
      brand: m['brand'] as String?,
      category: m['category'] as String?,
      servingSize: d(m['serving_size']),
      unit: (m['unit'] as String?) ?? 'g',
      kcal: d(m['kcal']),
      carb: d(m['carb']),
      sugar: d(m['sugar']),
      protein: d(m['protein']),
      fat: d(m['fat']),
      sodiumMg: (m['sodium_mg'] as num?)?.toDouble(),
      fiber: d(m['fiber']),
      sugarAlcohol: d(m['sugar_alcohol']),
      rareSugarG: d(m['rare_sugar_g']),
      ingredientsRaw: m['ingredients_raw'] as String?,
      sweetenerCount: swList.length,
      barcode: barcode,
      verified: false,
      sourceType: 'OCR제보',
      notes: m['notes'] as String?,
      sweeteners: swList,
    );
    return OcrResult(
      product: product,
      unknownSweeteners: ((m['unknown_sweeteners'] as List?) ?? const []).cast<String>(),
      rawText: m['ingredients_raw'] as String?,
    );
  }
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/features/ocr/ocr_result_test.dart`
Expected: PASS (`All tests passed!`).

- [ ] **Step 5: 커밋**

```bash
git add lib/features/ocr/ocr_service.dart test/features/ocr/ocr_result_test.dart
git commit -m "refactor(ocr): OcrResult.fromParsed 순수 매퍼 추출 + 테스트"
```

---

## Task 6: `OcrService.parseAndSubmit` + 기존 `parseImage` 제거

**Files:**
- Modify: `lib/features/ocr/ocr_service.dart`

`submit-product`를 호출하고 응답을 `OcrResult.fromParsed`로 매핑. 기존 단일 이미지 `parseImage`는 더 이상 호출처가 없으므로 제거.

- [ ] **Step 1: `OcrService` 본문 교체**

`lib/features/ocr/ocr_service.dart`의 `class OcrService { ... }` 전체를 아래로 교체(파일 상단 import는 그대로 둔다 — `dart:convert`/`supabase_flutter`/`product.dart`/`sweetener.dart` 모두 계속 사용):
```dart
class OcrService {
  OcrService(this._db);
  final SupabaseClient _db;

  /// 3장(전체샷·원재료·영양성분, base64) + 바코드 → submit-product 호출.
  /// Edge Function이 Gemini 멀티이미지로 파싱하고 제보를 저장한 뒤 파싱 결과를 돌려준다.
  Future<OcrResult> parseAndSubmit({
    required String fullB64,
    required String ingredientsB64,
    required String nutritionB64,
    String? barcode,
  }) async {
    final res = await _db.functions.invoke('submit-product', body: {
      'images': {
        'full': fullB64,
        'ingredients': ingredientsB64,
        'nutrition': nutritionB64,
      },
      'barcode': barcode,
    });
    if (res.status != 200 || res.data == null) {
      throw Exception('분석 실패 (status ${res.status})');
    }
    final data = res.data is String ? jsonDecode(res.data as String) : res.data;
    final m = Map<String, dynamic>.from(data as Map);
    if (m['error'] != null) throw Exception('분석 실패: ${m['error']}');
    return OcrResult.fromParsed(m, barcode: barcode);
  }
}
```
(`jsonDecode`를 쓰므로 `import 'dart:convert';`는 유지.)

- [ ] **Step 2: 정적 분석 + 기존 테스트 통과 확인**

Run: `flutter analyze lib/features/ocr/ocr_service.dart && flutter test test/features/ocr/ocr_result_test.dart`
Expected: analyze `No issues found`, 테스트 PASS.
(이 시점에 `ocr_screen.dart`가 아직 `parseImage`/`submitOcr`를 참조하면 analyze 에러가 날 수 있음 — Task 9에서 함께 정리. 단독 파일 analyze로 우선 확인.)

- [ ] **Step 3: 커밋**

```bash
git add lib/features/ocr/ocr_service.dart
git commit -m "feat(ocr): parseAndSubmit(submit-product 호출) 추가, parseImage 제거"
```

---

## Task 7: `CaptureController` (3장 촬영 상태)

**Files:**
- Create: `lib/features/capture/capture_controller.dart`
- Test: `test/features/capture/capture_controller_test.dart`

3개 슬롯(전체샷·원재료·영양성분)의 이미지 바이트를 보관. 순수 상태 로직 → 단위 테스트.

- [ ] **Step 1: 실패하는 테스트 작성**

`test/features/capture/capture_controller_test.dart`:
```dart
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cubed_app/features/capture/capture_controller.dart';

Uint8List _b(int n) => Uint8List.fromList([n]);

// StateNotifier.state는 @protected라 외부에서 직접 읽지 않는다.
// 상태는 provider를 통해 읽고, autoDispose 유지를 위해 리스너를 건다.
ProviderContainer _container() {
  final c = ProviderContainer();
  c.listen(captureControllerProvider, (_, __) {});
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('CaptureState(순수): 3장 다 차야 isComplete', () {
    const empty = CaptureState();
    expect(empty.isComplete, false);
    expect(empty.count, 0);
    final two = empty.copyWith(images: {
      CaptureSlot.full: _b(1),
      CaptureSlot.ingredients: _b(2),
    });
    expect(two.isComplete, false);
    expect(two.count, 2);
    final three = two.copyWith(images: {...two.images, CaptureSlot.nutrition: _b(3)});
    expect(three.isComplete, true);
    expect(three.count, 3);
  });

  test('CaptureController.setImage → 3장이면 isComplete', () {
    final c = _container();
    final ctrl = c.read(captureControllerProvider.notifier);
    ctrl.setImage(CaptureSlot.full, _b(1));
    ctrl.setImage(CaptureSlot.ingredients, _b(2));
    ctrl.setImage(CaptureSlot.nutrition, _b(3));
    expect(c.read(captureControllerProvider).isComplete, true);
  });

  test('removeImage / reset', () {
    final c = _container();
    final ctrl = c.read(captureControllerProvider.notifier);
    ctrl.setImage(CaptureSlot.full, _b(1));
    ctrl.removeImage(CaptureSlot.full);
    expect(c.read(captureControllerProvider).images.containsKey(CaptureSlot.full), false);
    ctrl.setImage(CaptureSlot.full, _b(1));
    ctrl.setError('x');
    ctrl.reset();
    final s = c.read(captureControllerProvider);
    expect(s.count, 0);
    expect(s.error, isNull);
    expect(s.submitting, false);
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/features/capture/capture_controller_test.dart`
Expected: 컴파일 실패 — `Target of URI doesn't exist: '.../capture_controller.dart'`.

- [ ] **Step 3: `capture_controller.dart` 구현**

`lib/features/capture/capture_controller.dart`:
```dart
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 촬영 슬롯 — 순서 = 가이드 단계 순서(전체샷 → 원재료 → 영양성분).
enum CaptureSlot { full, ingredients, nutrition }

extension CaptureSlotLabel on CaptureSlot {
  String get title => switch (this) {
        CaptureSlot.full => '제품 전체 사진',
        CaptureSlot.ingredients => '원재료명',
        CaptureSlot.nutrition => '영양성분표',
      };
  String get hint => switch (this) {
        CaptureSlot.full => '제품 앞면 전체가 보이게 찍어주세요. 카테고리·제품명 판정에 쓰여요.',
        CaptureSlot.ingredients => '원재료명 부분이 또렷하게 보이도록 찍어주세요.',
        CaptureSlot.nutrition => '영양성분표가 정면으로, 숫자가 또렷하게 보이도록 찍어주세요.',
      };
}

@immutable
class CaptureState {
  final Map<CaptureSlot, Uint8List> images;
  final bool submitting;
  final String? error;
  const CaptureState({this.images = const {}, this.submitting = false, this.error});

  bool get isComplete => CaptureSlot.values.every(images.containsKey);
  int get count => images.length;

  CaptureState copyWith({
    Map<CaptureSlot, Uint8List>? images,
    bool? submitting,
    Object? error = _sentinel,
  }) {
    return CaptureState(
      images: images ?? this.images,
      submitting: submitting ?? this.submitting,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }

  static const _sentinel = Object();
}

class CaptureController extends StateNotifier<CaptureState> {
  CaptureController() : super(const CaptureState());

  void setImage(CaptureSlot slot, Uint8List bytes) {
    state = state.copyWith(images: {...state.images, slot: bytes}, error: null);
  }

  void removeImage(CaptureSlot slot) {
    final next = {...state.images}..remove(slot);
    state = state.copyWith(images: next);
  }

  void setSubmitting(bool v) => state = state.copyWith(submitting: v);
  void setError(String? e) => state = state.copyWith(error: e, submitting: false);
  void reset() => state = const CaptureState();
}

/// prefillBarcode마다 독립 인스턴스. autoDispose로 화면 이탈 시 정리.
final captureControllerProvider =
    StateNotifierProvider.autoDispose<CaptureController, CaptureState>(
  (ref) => CaptureController(),
);
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/features/capture/capture_controller_test.dart`
Expected: PASS (`All tests passed!`).

- [ ] **Step 5: 커밋**

```bash
git add lib/features/capture/capture_controller.dart test/features/capture/capture_controller_test.dart
git commit -m "feat(capture): 3장 촬영 상태 CaptureController + 테스트"
```

---

## Task 8: `CaptureScreen` (3단계 가이드 UI)

**Files:**
- Create: `lib/features/capture/capture_screen.dart`

3개 슬롯을 카드로 보여주고, 각 슬롯에 카메라/앨범으로 촬영. 3장 다 차면 "분석·제보" 활성화 → `parseAndSubmit` → `ResultScreen`.

- [ ] **Step 1: `capture_screen.dart` 작성**

`lib/features/capture/capture_screen.dart`:
```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme.dart';
import '../../providers/providers.dart';
import '../ocr/ocr_service.dart';
import '../result/result_screen.dart';
import 'capture_controller.dart';

/// 미등록 제품 제보: 전체샷·원재료·영양성분 3장 가이드 촬영 → 분석.
class CaptureScreen extends ConsumerWidget {
  const CaptureScreen({super.key, this.prefillBarcode});
  final String? prefillBarcode;

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    CaptureSlot slot,
    ImageSource source,
  ) async {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1280,
      imageQuality: 80,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    ref.read(captureControllerProvider.notifier).setImage(slot, bytes);
  }

  Future<void> _submit(BuildContext context, WidgetRef ref) async {
    final ctrl = ref.read(captureControllerProvider.notifier);
    final imgs = ref.read(captureControllerProvider).images;
    ctrl.setSubmitting(true);
    try {
      final service = OcrService(ref.read(supabaseProvider));
      final result = await service.parseAndSubmit(
        fullB64: base64Encode(imgs[CaptureSlot.full]!),
        ingredientsB64: base64Encode(imgs[CaptureSlot.ingredients]!),
        nutritionB64: base64Encode(imgs[CaptureSlot.nutrition]!),
        barcode: prefillBarcode,
      );
      if (!context.mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ResultScreen(product: result.product)),
      );
    } catch (e) {
      ctrl.setError('$e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(captureControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('사진으로 분석 (3장)')),
      body: state.submitting
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: CubedColors.brand),
                  SizedBox(height: 16),
                  Text('AI가 3장을 읽고 분석하고 있어요…',
                      style: TextStyle(color: CubedColors.inkSoft)),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('아래 3장을 모두 촬영하면 분석돼요',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('전체샷으로 카테고리를, 원재료·영양성분으로 대체당과 혈당 영향을 분석해요.',
                    style: TextStyle(color: CubedColors.inkSoft, height: 1.5)),
                const SizedBox(height: 16),
                for (final slot in CaptureSlot.values)
                  _SlotCard(
                    slot: slot,
                    index: slot.index + 1,
                    bytes: state.images[slot],
                    onCamera: () => _pick(context, ref, slot, ImageSource.camera),
                    onGallery: () => _pick(context, ref, slot, ImageSource.gallery),
                    onRemove: () =>
                        ref.read(captureControllerProvider.notifier).removeImage(slot),
                  ),
                if (state.error != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: CubedColors.caution.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(state.error!, style: const TextStyle(color: CubedColors.caution)),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: CubedColors.brand,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: state.isComplete ? () => _submit(context, ref) : null,
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(state.isComplete ? '분석·제보하기' : '3장을 모두 촬영해주세요 (${state.count}/3)'),
                ),
              ],
            ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.slot,
    required this.index,
    required this.bytes,
    required this.onCamera,
    required this.onGallery,
    required this.onRemove,
  });
  final CaptureSlot slot;
  final int index;
  final Uint8List? bytes;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final done = bytes != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CubedColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: done ? CubedColors.brand : CubedColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: done ? CubedColors.brand : CubedColors.line,
                child: done
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : Text('$index', style: const TextStyle(color: CubedColors.ink, fontSize: 13)),
              ),
              const SizedBox(width: 10),
              Text(slot.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 6),
          Text(slot.hint, style: const TextStyle(color: CubedColors.inkSoft, fontSize: 13, height: 1.4)),
          const SizedBox(height: 12),
          if (done)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(bytes!, height: 140, width: double.infinity, fit: BoxFit.cover),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCamera,
                  icon: const Icon(Icons.photo_camera_rounded, size: 18),
                  label: Text(done ? '다시 촬영' : '카메라'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onGallery,
                  icon: const Icon(Icons.photo_library_rounded, size: 18),
                  label: const Text('앨범'),
                ),
              ),
              if (done) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline, color: CubedColors.inkSoft),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: 정적 분석 확인**

Run: `flutter analyze lib/features/capture/`
Expected: `No issues found!`
(`CubedColors`에 `surface/line/ink/inkSoft/brand/caution`가 있는지 확인 — [theme.dart](../../../lib/core/theme.dart)에서 이미 사용 중이므로 존재.)

- [ ] **Step 3: 커밋**

```bash
git add lib/features/capture/capture_screen.dart
git commit -m "feat(capture): 3단계 가이드 촬영 화면 CaptureScreen"
```

---

## Task 9: 진입점 교체 + 구舊 OCR 경로 제거

**Files:**
- Modify: `lib/features/scan/scan_screen.dart:76-84` (바텀시트 버튼)
- Modify: `lib/data/product_repository.dart:97-111` (`submitOcr` 제거)
- Delete: `lib/features/ocr/ocr_screen.dart`

- [ ] **Step 1: `scan_screen.dart` import 교체**

`lib/features/scan/scan_screen.dart` 상단 import에서:
```dart
import '../ocr/ocr_screen.dart';
```
를 아래로 교체:
```dart
import '../capture/capture_screen.dart';
```

- [ ] **Step 2: `scan_screen.dart` 네비게이션 교체**

`_showNotFound` 내 `onPressed`(파일 76–84행 근처)에서:
```dart
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => OcrScreen(prefillBarcode: code)),
                  );
```
를 아래로 교체:
```dart
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => CaptureScreen(prefillBarcode: code)),
                  );
```

- [ ] **Step 3: 미사용 `submitOcr` 제거**

`lib/data/product_repository.dart`에서 `submitOcr` 메서드 전체(97–111행: 주석 `/// OCR 제보 ...` 포함)를 삭제. (제보 저장은 이제 `submit-product` Edge Function이 담당.)

- [ ] **Step 4: 구 OCR 화면 삭제**

```bash
git rm lib/features/ocr/ocr_screen.dart
```

- [ ] **Step 5: 전체 정적 분석 + 테스트**

Run: `flutter analyze && flutter test`
Expected: analyze `No issues found!`, 모든 테스트 PASS(`All tests passed!`). 남은 `OcrScreen`/`submitOcr`/`parseImage` 참조가 없어야 함.

- [ ] **Step 6: 실기기/에뮬레이터 end-to-end 수동 검증**

Run: `flutter run`
절차: 홈 → 바코드 스캔 → 등록 안 된 바코드 → "사진으로 분석하기" → 3장 촬영(전체샷/원재료/영양성분) → "분석·제보하기" → ResultScreen에 등급·대체당 표시 확인.
그다음 SQL로 제보 적재 확인:
```sql
select id, barcode, image_path, status, parsed->>'name' as name
from public.user_submissions order by created_at desc limit 1;
```
Expected: 방금 제품의 제보 1행(`status='pending'`, `image_path` uuid).

- [ ] **Step 7: 커밋**

```bash
git add lib/features/scan/scan_screen.dart lib/data/product_repository.dart
git commit -m "feat(scan): 미등록 제품 진입을 CaptureScreen으로 교체, 구 OCR 경로 제거"
```

---

## Phase 1 완료 기준 (Definition of Done)

- [ ] 바코드 미등록 시 3장 가이드 촬영 → AI 분석 결과 즉시 표시
- [ ] 제보가 `user_submissions`에 [barcode + image_path(uuid) + parsed 전체 + status=pending]로 저장
- [ ] 원본 3장이 비공개 `submission-images/{uuid}/`에 저장
- [ ] `flutter analyze` 무경고 + `flutter test` 전체 통과
- [ ] 모든 변경이 `feature/ugc-product-pipeline`에 커밋됨

---

## Phase 2 로드맵 (관리자 콘솔 — 다음 계획서에서 bite-sized로 상세화)

> 아래는 실행용 bite-sized 태스크가 **아니라** 다음 계획서로 옮길 범위 메모다. Phase 1을 실기기에서 검증해 실제 제보 데이터가 쌓인 뒤(파싱 품질·필드 분포 확인 후) `docs/superpowers/plans/<date>-ugc-admin-console.md`로 상세화한다. 그래야 폼 필드·검증 규칙을 실데이터에 맞출 수 있다.

**스키마 추가 (Phase 2 마이그레이션):**
```sql
alter table public.user_submissions
  add column if not exists promoted_product_id text references public.products(product_id);
```

**`admin` Edge Function (service_role, ADMIN_EMAILS 게이트):** 액션 `list_submissions` / `update_parsed` / `promote` / `reject` / `list_products` / `update_product` / `set_verified`. 새 시크릿 `ADMIN_EMAILS`(예: `hongbomshin@gmail.com`) 설정 필요. `promote`는 product_id 생성(`ugc_{barcode|nanoid}`) → products insert(verified=true, source_type='OCR제보') → product_sweeteners insert → 전체샷을 `product-images/{product_id}.jpg` 복사 → submission status='approved'+promoted_product_id, 모두 원자적. unknown_sweeteners는 `sweetener_review`에 적재.

**Flutter Web 관리자 앱:** 진입점 `lib/admin/main_admin.dart`(별도 runApp), `data/models`·`domain/interpretation.dart`·`core/rulebook.dart` 재사용. 화면 ① 제보 큐(바코드+썸네일+파싱폼 편집+`Interpretation.of` 실시간 등급 미리보기+승인/거절) ② 제품 브라우저(408+승격분 검색·verified 토글). 빌드 `flutter build web --target lib/admin/main_admin.dart` → Netlify/Vercel/GitHub Pages. 비관리자 이메일은 UI 숨김 + 서버 게이트 이중 차단.

**예상 태스크 수:** ~9 (마이그레이션 / admin 함수 5개 액션 / web 진입점·라우팅 / 제보 큐 화면 / 제품 브라우저 / 배포).
