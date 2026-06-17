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
      case "signed_urls":      return await signedUrls(db, body);
      case "update_product_sweeteners": return await updateProductSweeteners(db, body);
      case "replace_product_image": return await replaceProductImage(db, body);
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

  // 승격 후 상세 사진 2장(원재료/영양성분)은 불필요 → submission-images에서 삭제(용량 절약, 비치명적).
  // 메인(full)은 product-images로 이미 복사됨.
  try {
    await db.storage.from("submission-images").remove([
      `${sub.image_path}/ingredients.jpg`,
      `${sub.image_path}/nutrition.jpg`,
    ]);
  } catch (delErr) {
    console.error("승격 후 상세 사진 삭제 실패(비치명적):", String(delErr));
  }

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

// 제보 원본 사진 3장의 서명 URL(비공개 버킷). image_path = user_submissions.image_path(uuid 폴더).
async function signedUrls(db: SupabaseClient, b: Record<string, unknown>) {
  const path = b.image_path as string;
  if (!path) return json({ error: "image_path 필요" }, 400);
  const bucket = db.storage.from("submission-images");
  const out: Record<string, string | null> = {};
  for (const n of ["full", "ingredients", "nutrition"]) {
    const { data } = await bucket.createSignedUrl(`${path}/${n}.jpg`, 3600);
    out[n] = data?.signedUrl ?? null;
  }
  return json({ urls: out }, 200);
}

// 제품 감미료 행 전체 교체(삭제 후 재삽입) + sweetener_count 동기화.
async function updateProductSweeteners(db: SupabaseClient, b: Record<string, unknown>) {
  const id = b.product_id as string;
  const list = (b.sweeteners as Array<{ slug?: string; amount_g?: number | null }>) ?? [];
  if (!id) return json({ error: "product_id 필요" }, 400);
  const clean = list.filter((s) => s.slug && s.slug.trim() !== "");
  const del = await db.from("product_sweeteners").delete().eq("product_id", id);
  if (del.error) throw del.error;
  if (clean.length > 0) {
    const rows = clean.map((s, i) => ({
      product_id: id, slug: s.slug, amount_g: s.amount_g ?? null, sort_order: i,
    }));
    const ins = await db.from("product_sweeteners").insert(rows);
    if (ins.error) throw ins.error;
  }
  await db.from("products").update({ sweetener_count: clean.length }).eq("product_id", id);
  return json({ ok: true }, 200);
}

function b64ToBytes(b64: string): Uint8Array {
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

// 제품 대표 이미지 교체: 새 사진 업로드(캐시버스트 파일명) + products.image_file 갱신 + 기존 파일 삭제.
async function replaceProductImage(db: SupabaseClient, b: Record<string, unknown>) {
  const id = b.product_id as string;
  const b64 = b.image_base64 as string;
  if (!id || !b64) return json({ error: "product_id, image_base64 필요" }, 400);
  const { data: prod } = await db.from("products").select("image_file").eq("product_id", id).single();
  const oldFile = (prod?.image_file as string | null) ?? null;
  const newFile = `${id}-${crypto.randomUUID().slice(0, 8)}.jpg`;
  const up = await db.storage.from("product-images")
    .upload(newFile, b64ToBytes(b64), { contentType: "image/jpeg", upsert: true });
  if (up.error) throw up.error;
  const { error } = await db.from("products").update({ image_file: newFile }).eq("product_id", id);
  if (error) throw error;
  if (oldFile && oldFile !== newFile) {
    try { await db.storage.from("product-images").remove([oldFile]); } catch (_) { /* 비치명적 */ }
  }
  return json({ image_file: newFile }, 200);
}

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), { status, headers: { ...CORS, "content-type": "application/json" } });
}
