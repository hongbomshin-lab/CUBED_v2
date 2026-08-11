// 플랫폼 중립 공통 계약. 모든 사이트 파서는 이 형태로만 출력한다.
// (cafe24 / imweb / 향후 추가 플랫폼이 동일 인터페이스를 구현)

export type Platform = "cafe24" | "imweb";

/** 파서 1건 출력 — apply_crawl_result RPC 가 필드명 그대로 읽는다. */
export type ParsedItem = {
  external_id: string; // 사이트 내 상품 고유 id
  name: string;
  summary: string | null;
  list_price: number | null; // 할인 전(없으면 단일가)
  sale_price: number;
  product_url: string;
  image_url: string | null;
  category: string; // classifyCategory 결과
  is_soldout: boolean;
  is_deal: boolean;
  deal_signals: string[];
};
