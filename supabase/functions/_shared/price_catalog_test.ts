import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { buildProductIdentitySet } from "./price_catalog.ts";

Deno.test("가격 카탈로그 미등록 SKU도 인식 후보에 포함한다", () => {
  const result = buildProductIdentitySet(
    [{ product_id: "db-1", name: "등록 제품" }],
    [{
      product_id: null,
      catalog_product_key: "lalasweet:zero-bar:plum",
      catalog_name: "라라스윗 자두 제로바",
      aliases: ["자두맛 제로바"],
    }],
  );

  assertEquals(result.candidates.length, 2);
  assertEquals(
    result.identities.get("lalasweet:zero-bar:plum"),
    {
      candidateId: "lalasweet:zero-bar:plum",
      name: "라라스윗 자두 제로바",
      registeredProductId: null,
      catalogProductKey: "lalasweet:zero-bar:plum",
    },
  );
  assertEquals(
    result.candidates.some((candidate) =>
      candidate.name.includes("자두맛 제로바")
    ),
    true,
  );
});

Deno.test("가격과 연결된 등록 제품은 후보를 중복 생성하지 않는다", () => {
  const result = buildProductIdentitySet(
    [{ product_id: "db-1", name: "라라스윗 포도 제로바" }],
    [
      {
        product_id: "db-1",
        catalog_product_key: "lalasweet:zero-bar:grape",
        catalog_name: "라라스윗 포도 제로바",
        aliases: [],
      },
      {
        product_id: "db-1",
        catalog_product_key: "lalasweet:zero-bar:grape",
        catalog_name: "라라스윗 포도 제로바",
        aliases: ["포도맛 제로바"],
      },
    ],
  );

  assertEquals(result.candidates.length, 1);
  assertEquals(
    result.identities.get("lalasweet:zero-bar:grape")?.registeredProductId,
    "db-1",
  );
});
