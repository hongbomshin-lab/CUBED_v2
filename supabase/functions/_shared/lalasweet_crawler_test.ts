import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  parseDealPage,
  parseSaleList,
  resolveCatalogItem,
} from "./lalasweet_crawler.ts";

Deno.test("할인특가 목록에서 상품 번호와 링크를 읽는다", () => {
  const refs = parseSaleList(`
    <ul class="prd-list">
      <li><a href="/product/detail.html?product_no=252&cate_no=113"></a>
        <p class="name">[골라담기] 라라스윗 이벤트</p></li>
    </ul>
  `);
  assertEquals(refs[0].productNo, "252");
  assertEquals(refs[0].title, "[골라담기] 라라스윗 이벤트");
});

Deno.test("골라담기는 묶음 수와 옵션 개수를 곱한다", () => {
  const offers = parseDealPage(
    {
      productNo: "252",
      title: "[골라담기] 이벤트",
      url: "https://example.com/252",
    },
    `<meta property="product:price:amount" content="26900">
     <ul option_title="묶음 선택"><li title="4가지 골라담기"></li></ul>
     <ul option_title="골라담기 1번">
       <li title="자두 제로바 6개"></li><li title="선택 안함"></li>
     </ul>`,
  );
  assertEquals(offers[0].unitCount, 24);
  assertEquals(offers[0].price, 26900);
  assertEquals(offers[0].offerKind, "standalone_bundle");
});

Deno.test("990원딜은 기본 구매금액과 추가 옵션 가격을 분리한다", () => {
  const offers = parseDealPage(
    {
      productNo: "250",
      title: "[무제한 990딜] 제과",
      url: "https://example.com/250",
    },
    `<meta property="product:price:amount" content="34000">
     <ul option_title="990원딜 1번"><li title="저당 토피넛콘 3개"></li></ul>`,
  );
  assertEquals(offers[0].price, 2970);
  assertEquals(offers[0].minimumOrderAmount, 34000);
  assertEquals(offers[0].offerKind, "conditional_addon");
});

Deno.test("미등록 옵션에는 결정적인 자동 카탈로그 키를 만든다", () => {
  const first = resolveCatalogItem("자두 제로바", [], []);
  const second = resolveCatalogItem("자두 제로바", [], []);
  assertEquals(first.catalogProductKey, second.catalogProductKey);
  assertEquals(first.productId, null);
  assertEquals(first.catalogName, "라라스윗 자두 제로바");
});
