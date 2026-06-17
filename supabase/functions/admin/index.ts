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
