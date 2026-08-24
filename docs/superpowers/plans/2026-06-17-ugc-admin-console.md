> ⚠️ **아카이브 문서** — 작성 시점의 설계 기록입니다. 현재 스펙은 [`docs/product-spec.md`](../../product-spec.md)를 보세요.

# UGC 관리자 검수 콘솔 — 구현 계획 (Phase 2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Phase 1으로 쌓이는 제보(`user_submissions`)를 관리자가 **Flutter Web 콘솔**에서 검수한다. 파싱 결과를 편집하며 **실시간으로 CUBED 등급을 미리보고**, 승인 시 정식 `products`로 승격(전체샷을 대표 이미지로 복사)하거나 거절한다. 기존 408개 제품도 함께 검색·수정·verified 토글한다.

**Architecture:** 모든 권한 작업은 신규 `admin` Edge Function(service_role) 하나로 모은다. 호출자의 JWT에서 이메일을 꺼내 `ADMIN_EMAILS` 화이트리스트와 대조하는 **서버 게이트**가 1차 방어선이고, 웹 UI의 이메일 체크는 UX용 2차일 뿐이다. 제품/제보 테이블은 모두 RLS가 켜져 있어 클라이언트(anon)로는 못 건드리고, 오직 이 함수만 쓴다. 승격(promote)의 DB 쓰기는 **Postgres 함수 `promote_submission`(트랜잭션)** 으로 원자화하고, 이미지 복사는 함수 바깥에서 best-effort로 처리한다. 등급 계산은 앱과 **동일한 `rulebook.dart`/`Interpretation.of`** 를 웹에서 그대로 재사용한다(단일 진실원천).

**Tech Stack:** Flutter 3.44 Web + Riverpod 2.6 + supabase_flutter 2.5 / Supabase Edge Functions(Deno) + Postgres 17(plpgsql). 신규 런타임 의존성 없음.

**참조:** [Phase 1 계획](2026-06-16-ugc-product-pipeline.md) · [설계 스펙](../specs/2026-06-16-ugc-product-pipeline-design.md)

**전제(환경):** `git checkout feature/ugc-product-pipeline && flutter pub get`. Flutter는 `C:\Users\hongb\flutter\bin`에 설치되어 있으나 하네스 셸 PATH에 자동 반영되지 않으므로 **모든 flutter 명령 앞에 `$env:Path = 'C:\Users\hongb\flutter\bin;' + $env:Path;` 를 붙인다**. Supabase는 MCP(`apply_migration`/`deploy_edge_function`/`execute_sql`) 사용, project-ref=`aqhfddvvxnakgkdtirem`. **신규 시크릿 `ADMIN_EMAILS` 1회 설정 필요**(Task 4). `SUPABASE_URL`/`SUPABASE_ANON_KEY`/`SUPABASE_SERVICE_ROLE_KEY`는 Edge 런타임에 자동 주입됨.

---

## 확인된 현실 스키마 (이 계획의 기반)

- `user_submissions`: `id`(bigint identity) · `barcode`(text,null) · `ocr_text`(text,null) · `parsed`(jsonb) · `image_path`(text=uuid 폴더) · `status`(`pending`|`approved`|`rejected`) · `created_at`. **→ Phase 2에서 `promoted_product_id` 추가.**
- `products`: `product_id`(text PK) · name · brand · category(FK→category_meta) · serving_size · unit(`ml`|`g`) · kcal·carb·sugar·protein·fat·sodium_mg·fiber·sugar_alcohol·rare_sugar_g · ingredients_raw · sweetener_summary · sweetener_count · `barcode`(**UNIQUE**,null) · image_file · source_type(기본 `패키지촬영`) · verified(기본 false) · notes · created_at. **408행.**
- `product_sweeteners`: id(bigint) · product_id(FK) · slug(FK→sweeteners) · amount_g · sort_order.
- `sweetener_review`: id · raw_name · product_id(FK) · resolved(기본 false) · created_at. **이미 존재(0행)** → unknown_sweeteners 적재처.
- `sweeteners`(28) · `category_meta`(18, is_liquid) · `combo_rules`(12): anon SELECT 허용(앱이 이미 읽음) → 웹에서 직접 로드.
- Storage 버킷: `product-images`(**public, 존재**) · `submission-images`(private, Phase 1) · 기타 store-*.
- `products.image_file` 규약: `"{product_id}.확장자"`, 표시 URL = `Env.imageBaseUrl + '/' + image_file`.

## 파일 구조 (Phase 2)

신규
- `supabase/migrations/20260617090000_admin_console.sql` — `promoted_product_id` 컬럼 + `promote_submission()` 함수
- `supabase/functions/admin/index.ts` — 관리자 액션 라우터(게이트 포함)
- `supabase/functions/admin/gate_test.ts` — 이메일 게이트 순수 단위 테스트(Deno, 선택)
- `lib/admin/main_admin.dart` — 관리자 웹 진입점(별도 runApp)
- `lib/admin/admin_service.dart` — admin Edge Function 클라이언트 + 모델
- `lib/admin/admin_providers.dart` — 관리자 전용 Riverpod providers
- `lib/admin/admin_gate.dart` — 로그인 + 이메일 게이트 래퍼
- `lib/admin/submission_queue_screen.dart` — 제보 큐(편집 폼 + 실시간 등급 + 승인/거절)
- `lib/admin/parsed_form.dart` — parsed JSON 편집 폼 위젯(공용)
- `lib/admin/product_browser_screen.dart` — 408+승격분 검색·verified 토글·편집
- `test/admin/parsed_form_logic_test.dart` — parsed↔Product 매핑/검증 순수 테스트
- `web/` — `flutter create . --platforms web` 산출물(없으면 Task 8에서 생성)

수정
- 없음(앱 본체는 건드리지 않음 — 관리자 앱은 별도 entrypoint로 완전 분리)

---

## Task 1: 스키마 마이그레이션 + promote 트랜잭션 함수

**Files:** Create `supabase/migrations/20260617090000_admin_console.sql`

`promoted_product_id`로 제보→제품 연결을 추적하고, 승격 DB 쓰기를 한 트랜잭션으로 묶는 `promote_submission()`을 만든다. product_id·image_file은 Edge Function이 만들어 인자로 넘긴다(이미지 복사를 DB 트랜잭션 밖에서 선행하기 위함).

- [ ] **Step 1: 마이그레이션 SQL 작성**

```sql
-- 제보 → 승격된 제품 추적
alter table public.user_submissions
  add column if not exists promoted_product_id text references public.products(product_id);

-- 승격: products insert + product_sweeteners + sweetener_review + 제보 상태전이를 한 트랜잭션으로.
-- product_id / image_file 은 Edge Function(service_role)이 생성해 넘긴다(이미지 복사 선행 때문).
create or replace function public.promote_submission(
  p_submission_id bigint,
  p_product_id text,
  p_image_file text
) returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sub   public.user_submissions%rowtype;
  v_p     jsonb;
  v_sw    jsonb;
  v_i     int := 0;
  v_raw   text;
  v_num   numeric;
begin
  select * into v_sub from public.user_submissions where id = p_submission_id for update;
  if not found then raise exception 'submission % not found', p_submission_id; end if;
  if v_sub.status = 'approved' then raise exception 'submission % already approved', p_submission_id; end if;

  v_p := coalesce(v_sub.parsed, '{}'::jsonb);

  if v_sub.barcode is not null
     and exists (select 1 from public.products where barcode = v_sub.barcode) then
    raise exception 'barcode % already exists in products', v_sub.barcode;
  end if;
  if exists (select 1 from public.products where product_id = p_product_id) then
    raise exception 'product_id % already exists', p_product_id;
  end if;

  insert into public.products (
    product_id, name, brand, category, serving_size, unit,
    kcal, carb, sugar, protein, fat, sodium_mg, fiber, sugar_alcohol, rare_sugar_g,
    ingredients_raw, sweetener_count, barcode, image_file, source_type, verified, notes
  ) values (
    p_product_id,
    coalesce(nullif(v_p->>'name',''), '이름 미상'),
    v_p->>'brand',
    v_p->>'category',
    nullif(v_p->>'serving_size','')::numeric,
    coalesce(nullif(v_p->>'unit',''), 'g'),
    nullif(v_p->>'kcal','')::numeric,
    nullif(v_p->>'carb','')::numeric,
    nullif(v_p->>'sugar','')::numeric,
    nullif(v_p->>'protein','')::numeric,
    nullif(v_p->>'fat','')::numeric,
    nullif(v_p->>'sodium_mg','')::numeric,
    nullif(v_p->>'fiber','')::numeric,
    nullif(v_p->>'sugar_alcohol','')::numeric,
    nullif(v_p->>'rare_sugar_g','')::numeric,
    v_p->>'ingredients_raw',
    coalesce(jsonb_array_length(v_p->'sweeteners'), 0),
    v_sub.barcode,
    p_image_file,
    'OCR제보',
    true,
    v_p->>'notes'
  );

  for v_sw in select * from jsonb_array_elements(coalesce(v_p->'sweeteners', '[]'::jsonb)) loop
    if coalesce(v_sw->>'slug','') <> '' then
      insert into public.product_sweeteners (product_id, slug, amount_g, sort_order)
      values (p_product_id, v_sw->>'slug', nullif(v_sw->>'amount_g','')::numeric, v_i);
      v_i := v_i + 1;
    end if;
  end loop;

  for v_raw in select jsonb_array_elements_text(coalesce(v_p->'unknown_sweeteners', '[]'::jsonb)) loop
    if coalesce(v_raw,'') <> '' then
      insert into public.sweetener_review (raw_name, product_id, resolved) values (v_raw, p_product_id, false);
    end if;
  end loop;

  update public.user_submissions
     set status = 'approved', promoted_product_id = p_product_id
   where id = p_submission_id;

  return p_product_id;
end;
$$;

revoke all on function public.promote_submission(bigint, text, text) from public, anon, authenticated;
```

> 주의: `product_sweeteners.slug`는 `sweeteners`(28종) FK다. 파싱이 목록 밖 slug를 넣으면 insert가 실패→트랜잭션 롤백→promote 에러. 관리자 폼(Task 6)이 slug를 28종 드롭다운으로만 받게 해 사전 차단한다.

- [ ] **Step 2: 적용** — MCP `apply_migration`(name=`admin_console`, 위 SQL).
- [ ] **Step 3: 확인** — `execute_sql`:
```sql
select column_name from information_schema.columns
 where table_name='user_submissions' and column_name='promoted_product_id';
select proname from pg_proc where proname='promote_submission';
```
Expected: 각 1행.
- [ ] **Step 4: 커밋** — `git add supabase/migrations/20260617090000_admin_console.sql && git commit -m "feat(db): 관리자 콘솔 스키마 + promote_submission 트랜잭션 함수"`

---

## Task 2: `admin` Edge Function — 게이트 + 제보 조회/편집/거절

**Files:** Create `supabase/functions/admin/index.ts`, `supabase/functions/admin/gate_test.ts`

호출자 JWT→이메일→`ADMIN_EMAILS` 대조 게이트 + 액션 라우터. 이 태스크에선 `list_submissions`/`update_parsed`/`reject`까지. (배포는 Task 4에서 일괄.)

- [ ] **Step 1: 게이트 순수 단위 테스트(선택, Deno)** `supabase/functions/admin/gate_test.ts`
```ts
import { assert, assertEquals } from "jsr:@std/assert@1";
import { isAdminEmail } from "./index.ts";

Deno.test("화이트리스트 대소문자 무시 매칭", () => {
  const list = ["hongbomshin@gmail.com", "ops@cubed.app"];
  assert(isAdminEmail("HongboMShin@Gmail.com", list));
  assert(!isAdminEmail("intruder@evil.com", list));
  assertEquals(isAdminEmail(undefined, list), false);
});
```
(Deno 미설치 시 생략 — Task 4 invoke로 게이트 검증.)

- [ ] **Step 2: `index.ts` 작성**
```ts
// CUBED 관리자 Edge Function (Deno, service_role). ADMIN_EMAILS 게이트.
// 액션: list_submissions, update_parsed, reject, promote, list_products, update_product, set_verified.
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON = Deno.env.get("SUPABASE_ANON_KEY")!;
const ADMIN_EMAILS = (Deno.env.get("ADMIN_EMAILS") ?? "")
  .split(",").map((e) => e.trim().toLowerCase()).filter(Boolean);

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// 순수 함수 — 단위 테스트 대상.
export function isAdminEmail(email: string | undefined, list: string[]): boolean {
  if (!email) return false;
  return list.includes(email.toLowerCase());
}

async function callerEmail(req: Request): Promise<string | undefined> {
  const auth = req.headers.get("Authorization");
  if (!auth) return undefined;
  const userClient = createClient(SUPABASE_URL, ANON, { global: { headers: { Authorization: auth } } });
  const { data } = await userClient.auth.getUser();
  return data.user?.email ?? undefined;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  const email = await callerEmail(req);
  if (!isAdminEmail(email, ADMIN_EMAILS)) return json({ error: "관리자 권한 필요" }, 403);

  const db = createClient(SUPABASE_URL, SERVICE_ROLE);
  try {
    const body = await req.json();
    const action = body?.action as string;
    switch (action) {
      case "list_submissions": return await listSubmissions(db, body);
      case "update_parsed":    return await updateParsed(db, body);
      case "reject":           return await reject(db, body);
      case "promote":          return await promote(db, body);
      case "list_products":    return await listProducts(db, body);
      case "update_product":   return await updateProduct(db, body);
      case "set_verified":     return await setVerified(db, body);
      default: return json({ error: `unknown action: ${action}` }, 400);
    }
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

// ── 제보 ─────────────────────────────────────────────
async function listSubmissions(db: SupabaseClient, b: Record<string, unknown>) {
  const status = (b.status as string) ?? "pending";
  const { data, error } = await db.from("user_submissions")
    .select("id,barcode,parsed,image_path,status,created_at,promoted_product_id")
    .eq("status", status).order("created_at", { ascending: false }).limit(100);
  if (error) throw error;
  return json({ submissions: data }, 200);
}

async function updateParsed(db: SupabaseClient, b: Record<string, unknown>) {
  const id = b.id as number;
  const parsed = b.parsed;
  if (!id || typeof parsed !== "object") return json({ error: "id, parsed 필요" }, 400);
  const { error } = await db.from("user_submissions").update({ parsed }).eq("id", id).eq("status", "pending");
  if (error) throw error;
  return json({ ok: true }, 200);
}

async function reject(db: SupabaseClient, b: Record<string, unknown>) {
  const id = b.id as number;
  if (!id) return json({ error: "id 필요" }, 400);
  const { error } = await db.from("user_submissions").update({ status: "rejected" }).eq("id", id);
  if (error) throw error;
  return json({ ok: true }, 200);
}

// ── promote / 제품 액션은 Task 3에서 추가 ──

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), { status, headers: { ...CORS, "content-type": "application/json" } });
}
```

- [ ] **Step 3: 커밋** — `git add supabase/functions/admin/index.ts supabase/functions/admin/gate_test.ts && git commit -m "feat(fn): admin 게이트 + 제보 조회/편집/거절"`

---

## Task 3: `admin` Edge Function — promote + 제품 액션

**Files:** Modify `supabase/functions/admin/index.ts`

`promote`(이미지 복사 선행 + `promote_submission` RPC) 와 제품 브라우저용 `list_products`/`update_product`/`set_verified` 추가.

- [ ] **Step 1: 함수 추가** — `index.ts`의 `// ── promote / 제품 액션은 Task 3에서 추가 ──` 자리에 삽입(`json` 위):
```ts
// ── 승격 ─────────────────────────────────────────────
async function promote(db: SupabaseClient, b: Record<string, unknown>) {
  const id = b.submission_id as number;
  if (!id) return json({ error: "submission_id 필요" }, 400);
  const { data: sub, error } = await db.from("user_submissions")
    .select("id,barcode,parsed,image_path,status").eq("id", id).single();
  if (error || !sub) return json({ error: "submission 없음" }, 404);
  if (sub.status === "approved") return json({ error: "이미 승격됨" }, 400);

  const barcode = sub.barcode as string | null;
  const pid = (barcode && /^[0-9]{8,14}$/.test(barcode))
    ? `ugc_${barcode}`
    : `ugc_${crypto.randomUUID().replace(/-/g, "").slice(0, 12)}`;
  const imageFile = `${pid}.jpg`;

  // 전체샷 복사(비치명적): submission-images/{path}/full.jpg → product-images/{pid}.jpg
  try {
    const { data: blob } = await db.storage.from("submission-images").download(`${sub.image_path}/full.jpg`);
    if (blob) {
      const bytes = new Uint8Array(await blob.arrayBuffer());
      await db.storage.from("product-images").upload(imageFile, bytes, { contentType: "image/jpeg", upsert: true });
    }
  } catch (imgErr) {
    console.error("promote 이미지 복사 실패(비치명적):", String(imgErr));
  }

  // DB 쓰기(트랜잭션). 실패 시 명확한 에러.
  const { data: newPid, error: rpcErr } = await db.rpc("promote_submission", {
    p_submission_id: id, p_product_id: pid, p_image_file: imageFile,
  });
  if (rpcErr) return json({ error: `승격 실패: ${rpcErr.message}` }, 400);
  return json({ product_id: newPid }, 200);
}

// ── 제품 ─────────────────────────────────────────────
const PRODUCT_COLS =
  "product_id,name,brand,category,serving_size,unit,kcal,carb,sugar,protein,fat," +
  "sodium_mg,fiber,sugar_alcohol,rare_sugar_g,ingredients_raw,sweetener_count," +
  "barcode,image_file,source_type,verified,notes," +
  "product_sweeteners(slug,amount_g,sort_order)";

async function listProducts(db: SupabaseClient, b: Record<string, unknown>) {
  const q = ((b.q as string) ?? "").trim();
  let query = db.from("products").select(PRODUCT_COLS).order("created_at", { ascending: false }).limit(50);
  if (q) query = query.ilike("name", `%${q}%`);
  const { data, error } = await query;
  if (error) throw error;
  return json({ products: data }, 200);
}

async function updateProduct(db: SupabaseClient, b: Record<string, unknown>) {
  const id = b.product_id as string;
  const fields = b.fields as Record<string, unknown>;
  if (!id || typeof fields !== "object") return json({ error: "product_id, fields 필요" }, 400);
  const { error } = await db.from("products").update(fields).eq("product_id", id);
  if (error) throw error;
  return json({ ok: true }, 200);
}

async function setVerified(db: SupabaseClient, b: Record<string, unknown>) {
  const id = b.product_id as string;
  const verified = !!b.verified;
  if (!id) return json({ error: "product_id 필요" }, 400);
  const { error } = await db.from("products").update({ verified }).eq("product_id", id);
  if (error) throw error;
  return json({ ok: true }, 200);
}
```

- [ ] **Step 2: 커밋** — `git add supabase/functions/admin/index.ts && git commit -m "feat(fn): admin promote(RPC+이미지복사) + 제품 list/update/verified"`

---

## Task 4: 시크릿 설정 + 배포 + invoke 스모크

**Files:** 없음(인프라). 오케스트레이터가 MCP/대시보드로 수행.

- [ ] **Step 1: `ADMIN_EMAILS` 시크릿 설정** — Supabase 대시보드 → Edge Functions → Secrets 에 `ADMIN_EMAILS = hongbomshin@gmail.com`(쉼표로 복수 가능) 추가. (MCP엔 시크릿 설정 도구가 없어 수동 또는 `supabase secrets set ADMIN_EMAILS=...`.)
- [ ] **Step 2: 배포** — MCP `deploy_edge_function` slug=`admin`, entrypoint_path=`admin/index.ts`, files=[`admin/index.ts`], verify_jwt=`true`. (`_shared` 의존 없음.)
- [ ] **Step 3: 게이트 스모크** — anon 키(JWT지만 user 아님)로 호출 → **403 "관리자 권한 필요"** 기대(게이트 동작 확인). 관리자 계정으로 로그인해 받은 access_token으로 `{"action":"list_submissions"}` 호출 → 200 + `submissions` 배열 기대.
```bash
curl -s -X POST "https://aqhfddvvxnakgkdtirem.supabase.co/functions/v1/admin" \
  -H "Authorization: Bearer <ADMIN_USER_ACCESS_TOKEN>" -H "content-type: application/json" \
  -d '{"action":"list_submissions","status":"pending"}'
```
Expected: 비관리자→403, 관리자→200.
- [ ] **Step 4: promote 라운드트립 검증(선택)** — pending 제보 1건에 `{"action":"promote","submission_id":<id>}` → 200 `{product_id}`. 이어서 `execute_sql`로 products 1행(verified=true, source_type='OCR제보') + product_sweeteners + user_submissions.status='approved'/promoted_product_id 채워짐 + product-images/{pid}.jpg 존재 확인. (Phase 1 E2E 행 id=4를 테스트로 써도 됨.)

---

## Task 5: Flutter Web 진입점 + 관리자 게이트 + 서비스/프로바이더

**Files:** Create `lib/admin/main_admin.dart`, `lib/admin/admin_service.dart`, `lib/admin/admin_providers.dart`, `lib/admin/admin_gate.dart`

앱 본체와 완전 분리된 별도 `runApp`. 로그인(기존 `AuthRepository` 재사용) 후 이메일이 관리자가 아니면 차단 화면, 맞으면 콘솔.

- [ ] **Step 1: `admin_service.dart`** — admin Edge Function 호출 래퍼.
```dart
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 제보 큐 항목 (parsed는 편집 대상이라 Map 그대로 보관).
class Submission {
  final int id;
  final String? barcode;
  final Map<String, dynamic> parsed;
  final String imagePath;
  final String status;
  const Submission({required this.id, this.barcode, required this.parsed, required this.imagePath, required this.status});
  factory Submission.fromMap(Map<String, dynamic> m) => Submission(
        id: m['id'] as int,
        barcode: m['barcode'] as String?,
        parsed: Map<String, dynamic>.from((m['parsed'] as Map?) ?? const {}),
        imagePath: (m['image_path'] as String?) ?? '',
        status: (m['status'] as String?) ?? 'pending',
      );
}

class AdminService {
  AdminService(this._db);
  final SupabaseClient _db;

  Future<Map<String, dynamic>> _call(String action, [Map<String, dynamic> args = const {}]) async {
    final res = await _db.functions.invoke('admin', body: {'action': action, ...args});
    final data = res.data is String ? jsonDecode(res.data as String) : res.data;
    final m = Map<String, dynamic>.from(data as Map);
    if (res.status != 200 || m['error'] != null) {
      throw Exception(m['error'] ?? '요청 실패 (status ${res.status})');
    }
    return m;
  }

  Future<List<Submission>> listSubmissions({String status = 'pending'}) async {
    final m = await _call('list_submissions', {'status': status});
    return ((m['submissions'] as List?) ?? const [])
        .map((e) => Submission.fromMap(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> updateParsed(int id, Map<String, dynamic> parsed) => _call('update_parsed', {'id': id, 'parsed': parsed});
  Future<void> reject(int id) => _call('reject', {'id': id});
  Future<String> promote(int submissionId) async =>
      (await _call('promote', {'submission_id': submissionId}))['product_id'] as String;

  Future<List<Map<String, dynamic>>> listProducts({String q = ''}) async {
    final m = await _call('list_products', {'q': q});
    return ((m['products'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> updateProduct(String productId, Map<String, dynamic> fields) =>
      _call('update_product', {'product_id': productId, 'fields': fields});
  Future<void> setVerified(String productId, bool verified) =>
      _call('set_verified', {'product_id': productId, 'verified': verified});
}
```

- [ ] **Step 2: `admin_providers.dart`** — supabase·서비스·기준데이터·세션·관리자여부. 기준데이터/등급계산은 앱 코드 재사용.
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/product_repository.dart'; // ReferenceData.loadReference 재사용
import 'admin_service.dart';

final adminSupabaseProvider = Provider<SupabaseClient>((_) => Supabase.instance.client);
final adminServiceProvider = Provider<AdminService>((ref) => AdminService(ref.watch(adminSupabaseProvider)));

/// 기준데이터(감미료/카테고리/조합) — 앱과 동일 경로(anon read).
final adminReferenceProvider = FutureProvider<ReferenceData>(
  (ref) => ProductRepository(ref.watch(adminSupabaseProvider)).loadReference(),
);

final adminAuthStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(adminSupabaseProvider).auth.onAuthStateChange,
);

/// 현재 사용자 이메일(없으면 null). 게이트/표시는 서버가 최종 결정 — 여긴 UX용.
final adminEmailProvider = Provider<String?>((ref) {
  ref.watch(adminAuthStateProvider);
  return ref.watch(adminSupabaseProvider).auth.currentUser?.email;
});

final pendingSubmissionsProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(adminServiceProvider).listSubmissions(status: 'pending'),
);
final productSearchProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
  (ref, q) => ref.watch(adminServiceProvider).listProducts(q: q),
);
```

- [ ] **Step 3: `admin_gate.dart`** — 로그인 폼 + 비관리자 차단. (서버가 최종 게이트이므로 여긴 UX. 관리자 판정은 "함수 호출이 403이 아니면 통과"로 단순화: 로그인되면 콘솔 진입을 허용하되, 첫 `list_submissions` 403 시 차단 메시지.)
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme.dart';
import 'admin_providers.dart';
import 'submission_queue_screen.dart';

class AdminGate extends ConsumerWidget {
  const AdminGate({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(adminEmailProvider);
    if (email == null) return const _LoginScreen();
    return const AdminHome();
  }
}

class _LoginScreen extends ConsumerStatefulWidget {
  const _LoginScreen();
  @override
  ConsumerState<_LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<_LoginScreen> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  String? _err; bool _busy = false;

  Future<void> _login() async {
    setState(() { _busy = true; _err = null; });
    try {
      await ref.read(adminSupabaseProvider).auth.signInWithPassword(
        email: _email.text.trim(), password: _pw.text);
    } on AuthException catch (e) {
      setState(() => _err = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('CUBED 관리자', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
              TextField(controller: _email, decoration: const InputDecoration(labelText: '이메일')),
              const SizedBox(height: 12),
              TextField(controller: _pw, obscureText: true, decoration: const InputDecoration(labelText: '비밀번호')),
              if (_err != null) Padding(padding: const EdgeInsets.only(top: 12),
                child: Text(_err!, style: const TextStyle(color: CubedColors.caution))),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: CubedColors.brand, padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: _busy ? null : _login,
                child: Text(_busy ? '로그인 중…' : '로그인'))),
            ]),
          ),
        ),
      ),
    );
  }
}

/// 탭 2개(제보 큐 / 제품 브라우저).
class AdminHome extends ConsumerWidget {
  const AdminHome({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('CUBED 검수 콘솔'),
          bottom: const TabBar(tabs: [Tab(text: '제보 큐'), Tab(text: '제품')]),
          actions: [
            TextButton(onPressed: () => ref.read(adminSupabaseProvider).auth.signOut(),
              child: const Text('로그아웃')),
          ],
        ),
        body: const TabBarView(children: [SubmissionQueueScreen(), ProductBrowserScreen()]),
      ),
    );
  }
}
```
(`ProductBrowserScreen`/`SubmissionQueueScreen`은 Task 6·7. import는 그때 추가.)

- [ ] **Step 4: `main_admin.dart`** — 별도 진입점.
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/env.dart';
import 'core/theme.dart';
import 'admin/admin_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnonKey);
  runApp(const ProviderScope(child: AdminApp()));
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'CUBED Admin', debugShowCheckedModeBanner: false,
        theme: buildCubedTheme(), home: const AdminGate());
}
```
> `import 'core/env.dart'` 는 `lib/admin/main_admin.dart` 기준 상대경로가 `../core/env.dart`다. 빌드 시 `--target lib/admin/main_admin.dart`로 지정하므로 import는 패키지 루트 기준이 아님에 유의 — 실제로는 `import '../core/env.dart';`/`import '../core/theme.dart';`로 작성한다.

- [ ] **Step 5: analyze** — `flutter analyze lib/admin/` (Task 6·7 화면 미작성 상태면 미해결 import 에러가 정상; 이 태스크 단독 검증은 `admin_service.dart`/`admin_providers.dart`/`main_admin.dart` 개별 파일 analyze로 한정).
- [ ] **Step 6: 커밋** — `git add lib/admin/ && git commit -m "feat(admin): 웹 진입점 + 게이트 + AdminService/providers"`

---

## Task 6: 제보 큐 화면 + parsed 편집 폼 (실시간 등급 미리보기)

**Files:** Create `lib/admin/submission_queue_screen.dart`, `lib/admin/parsed_form.dart`, `test/admin/parsed_form_logic_test.dart`

핵심 화면. 좌측 제보 목록(바코드·썸네일·name) → 선택 시 우측에 **parsed 편집 폼**. 폼은 `OcrResult.fromParsed(editedMap)`로 Product를 만들고 `Interpretation.of(product, ref)`로 **등급/순탄수/함정을 실시간 표시**. 승인(promote)/거절.

> **알룰로오스 케이스 대비:** 편집 폼은 `rare_sugar_g`·`sugar_alcohol`·`fiber`를 숫자 필드로 직접 노출한다. Phase 1에서 Gemini가 알룰로오스를 `sweeteners`에만 넣고 `rare_sugar_g`를 비운 사례처럼, 관리자가 `rare_sugar_g=3.3`을 채우면 순탄수·등급 미리보기가 즉시 갱신돼 올바른 값으로 승격된다.

- [ ] **Step 1: parsed↔Product 매핑 순수 테스트** `test/admin/parsed_form_logic_test.dart` — 폼이 쓰는 변환이 `OcrResult.fromParsed`와 일치하고, 숫자 편집이 미리보기에 반영되는지.
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cubed_app/features/ocr/ocr_service.dart';

void main() {
  test('parsed map 편집 → Product 반영(순수)', () {
    final m = {'name': '테스트 음료', 'category': '과일음료', 'unit': 'ml',
      'serving_size': 500, 'carb': 6, 'rare_sugar_g': 3.3,
      'sweeteners': [{'slug': 'allulose', 'amount_g': 3.3}], 'unknown_sweeteners': []};
    final r = OcrResult.fromParsed(m);
    expect(r.product.rareSugarG, 3.3);
    expect(r.product.carb, 6);
    expect(r.product.sweeteners.single.slug, 'allulose');
  });
}
```
Run: `flutter test test/admin/parsed_form_logic_test.dart` → PASS (기존 `OcrResult.fromParsed` 재사용이라 별도 구현 없이 통과).

- [ ] **Step 2: `parsed_form.dart`** — parsed Map을 받아 텍스트/숫자/감미료 필드를 그리고, 변경 시 `onChanged(updatedMap)` 콜백. 핵심 필드: name·brand·category(드롭다운=category_meta 18종)·unit(ml/g)·serving_size·kcal·carb·sugar·protein·fat·sodium_mg·fiber·sugar_alcohol·rare_sugar_g·ingredients_raw·sweeteners(slug 드롭다운=28종 + amount_g)·unknown_sweeteners(읽기전용 표시). 구현은 `Map`을 복제→필드 수정→콜백 패턴. (상세 위젯 코드는 구현 시 `CubedColors`/기존 입력 스타일 따름.)

- [ ] **Step 3: `submission_queue_screen.dart`** — 목록 + 선택 + 폼 + 실시간 미리보기 + 액션.
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/env.dart';
import '../core/theme.dart';
import '../domain/interpretation.dart';
import '../features/ocr/ocr_service.dart';
import 'admin_providers.dart';
import 'parsed_form.dart';

class SubmissionQueueScreen extends ConsumerStatefulWidget {
  const SubmissionQueueScreen({super.key});
  @override
  ConsumerState<SubmissionQueueScreen> createState() => _SubmissionQueueScreenState();
}

class _SubmissionQueueScreenState extends ConsumerState<SubmissionQueueScreen> {
  int? _selectedId;
  Map<String, dynamic>? _draft; // 편집 중 parsed
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final subs = ref.watch(pendingSubmissionsProvider);
    final refData = ref.watch(adminReferenceProvider);
    return Row(children: [
      // ── 좌: 목록
      SizedBox(width: 320, child: subs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (_, i) {
            final s = list[i];
            return ListTile(
              selected: s.id == _selectedId,
              title: Text((s.parsed['name'] as String?) ?? '(이름 없음)'),
              subtitle: Text('${s.barcode ?? '바코드 없음'} · #${s.id}'),
              onTap: () => setState(() { _selectedId = s.id; _draft = Map.of(s.parsed); }),
            );
          },
        ),
      )),
      const VerticalDivider(width: 1),
      // ── 우: 편집 + 미리보기
      Expanded(child: (_selectedId == null || _draft == null)
        ? const Center(child: Text('제보를 선택하세요'))
        : refData.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (ref0) {
              final preview = OcrResult.fromParsed(_draft!).product;
              final interp = Interpretation.of(preview, ref0);
              return ListView(padding: const EdgeInsets.all(16), children: [
                _GradePreview(interp: interp),
                const SizedBox(height: 12),
                ParsedForm(parsed: _draft!, onChanged: (m) => setState(() => _draft = m)),
                const SizedBox(height: 16),
                Row(children: [
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: CubedColors.brand),
                    onPressed: _busy ? null : _approve,
                    child: const Text('승인 → 제품 승격')),
                  const SizedBox(width: 12),
                  OutlinedButton(onPressed: _busy ? null : _reject, child: const Text('거절')),
                ]),
              ]);
            },
          ),
      ),
    ]);
  }

  Future<void> _approve() async {
    final id = _selectedId!;
    setState(() => _busy = true);
    try {
      final svc = ref.read(adminServiceProvider);
      await svc.updateParsed(id, _draft!);      // 편집본 저장 후
      await svc.promote(id);                    // 승격
      ref.invalidate(pendingSubmissionsProvider);
      setState(() { _selectedId = null; _draft = null; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('승격 완료')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final id = _selectedId!;
    setState(() => _busy = true);
    try {
      await ref.read(adminServiceProvider).reject(id);
      ref.invalidate(pendingSubmissionsProvider);
      setState(() { _selectedId = null; _draft = null; });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _GradePreview extends StatelessWidget {
  const _GradePreview({required this.interp});
  final Interpretation interp;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CubedColors.grade(interp.grade).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Text('등급 ${interp.grade.ko}', style: TextStyle(
          fontWeight: FontWeight.w800, fontSize: 18, color: CubedColors.grade(interp.grade))),
        const SizedBox(width: 16),
        Text('순탄수 ${interp.netCarb}g · 100당 ${interp.per100NetCarb}g'),
        const SizedBox(width: 16),
        Expanded(child: Text('함정: ${interp.trapCodes.join(", ")}', overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}
```
> 썸네일: private 버킷이라 직접 URL 불가. 필요 시 admin 함수에 `signed_url` 액션을 추가하거나(권장), 1차 버전은 텍스트만. (Storage signed URL 생성은 service_role 필요 → 함수 경유.)

- [ ] **Step 4: analyze + test** — `flutter analyze lib/admin/ test/admin/` + `flutter test test/admin/parsed_form_logic_test.dart` → 그린.
- [ ] **Step 5: 커밋** — `git add lib/admin/parsed_form.dart lib/admin/submission_queue_screen.dart test/admin/ && git commit -m "feat(admin): 제보 큐 + parsed 편집 폼 + 실시간 등급 미리보기"`

---

## Task 7: 제품 브라우저 화면

**Files:** Create `lib/admin/product_browser_screen.dart`

408+승격분 검색, verified 토글, 핵심 필드 편집(`update_product`). `ParsedForm`/`Interpretation` 재사용 가능.

- [ ] **Step 1: `product_browser_screen.dart`** — 검색창 + 결과 리스트(name·brand·category·verified 스위치). 행의 verified 스위치 → `setVerified`. 상세 편집은 제보 큐와 같은 `ParsedForm`을 products row(Map)로 띄워 `update_product(fields)` 호출.
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import 'admin_providers.dart';

class ProductBrowserScreen extends ConsumerStatefulWidget {
  const ProductBrowserScreen({super.key});
  @override
  ConsumerState<ProductBrowserScreen> createState() => _ProductBrowserScreenState();
}

class _ProductBrowserScreenState extends ConsumerState<ProductBrowserScreen> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final results = ref.watch(productSearchProvider(_q));
    return Column(children: [
      Padding(padding: const EdgeInsets.all(12),
        child: TextField(
          decoration: const InputDecoration(hintText: '제품명 검색', prefixIcon: Icon(Icons.search)),
          onSubmitted: (v) => setState(() => _q = v.trim()))),
      Expanded(child: results.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final p = list[i];
            final verified = (p['verified'] as bool?) ?? false;
            return ListTile(
              title: Text((p['name'] as String?) ?? ''),
              subtitle: Text('${p['brand'] ?? ''} · ${p['category'] ?? ''} · ${p['source_type'] ?? ''}'),
              trailing: Switch(
                value: verified,
                activeColor: CubedColors.brand,
                onChanged: (v) async {
                  await ref.read(adminServiceProvider).setVerified(p['product_id'] as String, v);
                  ref.invalidate(productSearchProvider(_q));
                }),
            );
          },
        ),
      )),
    ]);
  }
}
```

- [ ] **Step 2: 게이트 import 연결** — `admin_gate.dart`의 `AdminHome`이 `ProductBrowserScreen`을 import하도록 추가.
- [ ] **Step 3: analyze** — `flutter analyze lib/admin/` → `No issues found!`(이 시점엔 모든 화면이 갖춰져 전체 그린).
- [ ] **Step 4: 커밋** — `git add lib/admin/product_browser_screen.dart lib/admin/admin_gate.dart && git commit -m "feat(admin): 제품 브라우저 + verified 토글"`

---

## Task 8: 웹 빌드 설정 + 전체 검증

**Files:** `web/`(생성), 가능 시 `.gitignore` 확인

- [ ] **Step 1: 웹 플랫폼 활성화** — `web/`가 없으면 `flutter create . --platforms web`(기존 파일 보존). 산출된 `web/index.html` title 등 정리.
- [ ] **Step 2: 디버그 빌드 확인** — `flutter build web --target lib/admin/main_admin.dart --no-tree-shake-icons` → `build/web` 생성 성공.
- [ ] **Step 3: 전체 analyze + test** — `flutter analyze` 무이슈 + `flutter test` 전체 통과(앱 본체 + admin 테스트). 관리자 앱이 앱 본체를 망가뜨리지 않았는지 확인.
- [ ] **Step 4: 커밋** — `git add web/ pubspec.yaml && git commit -m "build(admin): Flutter Web 빌드 타깃 + web 스캐폴드"`

---

## Task 9: 배포 + 운영 노트

**Files:** Create `docs/admin-deploy.md`(선택)

- [ ] **Step 1: 호스팅 배포** — `build/web`를 정적 호스팅에 올린다. 권장: GitHub Pages(`gh-pages` 브랜치 또는 Actions) 또는 Netlify/Vercel(빌드 커맨드 `flutter build web --target lib/admin/main_admin.dart`, 퍼블리시 `build/web`). SPA 라우팅 위해 200.html/리다이렉트 설정.
- [ ] **Step 2: 접근 통제 확인** — 배포 URL이 공개돼도 **서버 게이트(`ADMIN_EMAILS`)가 최종 방어**임을 확인: 비관리자 로그인 → 콘솔 진입돼도 `list_submissions`가 403 → 데이터 안 보임. (원하면 `admin_gate`에 "첫 호출 403이면 접근 거부 화면" 추가.)
- [ ] **Step 3: 운영 메모** — `docs/admin-deploy.md`에 배포 절차·`ADMIN_EMAILS` 관리·promote 롤백(잘못 승격 시 products/product_sweeteners 삭제 + 제보 status 되돌리기) 기록.
- [ ] **Step 4: 커밋 + 푸시** — `git add docs/admin-deploy.md && git commit -m "docs(admin): 배포·운영 노트"` 후 `git push`.

---

## Phase 2 완료 기준 (Definition of Done)

- [ ] 관리자 이메일로만 콘솔 데이터 접근(서버 게이트 403 검증)
- [ ] 제보 큐에서 parsed 편집 시 CUBED 등급/순탄수/함정이 **실시간** 갱신
- [ ] 승인 → `products`(verified=true, source_type='OCR제보') + `product_sweeteners` + 전체샷 `product-images/{pid}.jpg` + 제보 `status='approved'`/`promoted_product_id` (트랜잭션)
- [ ] unknown_sweeteners → `sweetener_review` 적재
- [ ] 거절 → `status='rejected'`
- [ ] 제품 브라우저에서 검색·verified 토글·편집
- [ ] `flutter analyze` 무경고 + `flutter test` 전체 통과 + `flutter build web` 성공
- [ ] 정적 호스팅 배포 완료, 모든 변경 커밋·푸시

## 향후(Phase 3 메모, 비실행)
- 썸네일 signed URL 액션, 제보 일괄 처리, 파싱 프롬프트 자동 개선 루프(알룰로오스→rare_sugar_g 규칙 강화), products 감미료 행 편집 UI, 관리자 활동 감사 로그.
