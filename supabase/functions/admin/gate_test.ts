import { assert, assertEquals } from "jsr:@std/assert@1";
import { isAdminEmail } from "./index.ts";

Deno.test("화이트리스트 대소문자 무시 매칭", () => {
  const list = ["hongbomshin@gmail.com", "ops@cubed.app"];
  assert(isAdminEmail("HongboMShin@Gmail.com", list));
  assert(!isAdminEmail("intruder@evil.com", list));
  assertEquals(isAdminEmail(undefined, list), false);
});
