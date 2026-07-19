// CUBED 계정 삭제(회원 탈퇴) Edge Function (Deno)
// 스토어 정책 대응: 로그인 기능이 있는 앱은 앱 내 계정 삭제가 필수
// (Apple 5.1.1(v), Google Play 계정 삭제 정책).
//
// 흐름: 앱에서 사용자 JWT로 호출 → 토큰 검증으로 본인 확인 → service role로 auth 사용자 삭제.
// 사용자 데이터는 FK(ON DELETE CASCADE/SET NULL)로 자동 정리된다
// (store_likes·product_logs는 CASCADE 삭제, store_reports 등은 작성자만 NULL 처리).
//
// 배포: supabase functions deploy delete-account
// 시크릿: SUPABASE_URL/SUPABASE_ANON_KEY/SUPABASE_SERVICE_ROLE_KEY는 Supabase가 자동 주입.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const json = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json(405, { error: "POST only" });

  // 1) 호출자 JWT로 본인 확인 (다른 사용자 삭제 불가)
  const authHeader = req.headers.get("Authorization") ?? "";
  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user }, error: userError } = await userClient.auth.getUser();
  if (userError || !user) return json(401, { error: "인증이 필요합니다" });

  // 2) service role로 auth 사용자 삭제 → FK 캐스케이드로 데이터 정리
  const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  const { error: deleteError } = await adminClient.auth.admin.deleteUser(user.id);
  if (deleteError) {
    console.error("계정 삭제 실패:", deleteError.message);
    return json(500, { error: "계정 삭제에 실패했습니다. 잠시 후 다시 시도해주세요." });
  }

  return json(200, { ok: true });
});
