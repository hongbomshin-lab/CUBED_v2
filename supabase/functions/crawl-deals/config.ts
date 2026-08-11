// 브랜드별 수집 설정.
// 카테고리 번호는 2026-08-09 기준 실제 확인값. 사이트 개편 시 여기만 고치면 됨.
import type { Platform } from "./types.ts";

export type BrandConfig = {
  slug: string;
  displayName: string;
  /** 파서 디스패치 키. crawlers.ts 의 레지스트리가 이 값으로 파서를 고른다. */
  platform: Platform;
  baseUrl: string;
  /** 특가 전용 카테고리 식별자(cafe24=cate_no 숫자, imweb=category 코드 문자열). 여기 있으면 무조건 is_deal */
  dealCategories: (string | number)[];
  /** 하위가격 수집용 전체 카테고리. 역대최저가 판정에 필요 */
  catalogCategories: (string | number)[];
  /**
   * 목록 페이지만으로 원가/할인가가 다 나오는가?
   * true  → 목록 1~2회 요청으로 끝 (널담)
   * false → 목록에서 product_no만 뽑고 상세페이지를 타야 함 (라라스윗: 커스텀 테마)
   */
  listHasPricing: boolean;
  /** 상세페이지 요청 간 대기(ms). 상용사이트 차단 회피 */
  detailDelayMs: number;
  /** 안전 장치: 직전 파싱 건수 대비 이 비율 미만이면 커밋 중단 */
  minRetainRatio: number;
};

export const BRANDS: BrandConfig[] = [
  {
    slug: "lalasweet",
    displayName: "라라스윗",
    platform: "cafe24",
    baseUrl: "https://lalasweet.kr",
    // 113 = "기간한정 특가"
    dealCategories: [113],
    // 151 인기 / 152 신제품 / 132 아이스크림 / 133 정과 / 143 음료
    // [패밀리인쿠일] 류가 특가 카테고리 밖에 있어서 전체를 타야 함
    catalogCategories: [151, 152, 132, 133, 143],
    listHasPricing: false, // 커스텀 테마 → 목록엔 단일 가격만 노출됨
    detailDelayMs: 400,
    minRetainRatio: 0.5,
  },
  {
    slug: "nuldam",
    displayName: "널담",
    platform: "cafe24",
    baseUrl: "https://nuldam.com",
    // 62 = "일특딜"
    dealCategories: [62],
    // 47 전체상품 / 81 베스트 / 66 고단백·저당 / 55 비건 / 85 음료 / 129 등가
    catalogCategories: [47],
    listHasPricing: true, // 목록에 판매가·할인판매가·할인율 모두 노출
    detailDelayMs: 300,
    minRetainRatio: 0.5,
  },
  {
    slug: "mynormal",
    displayName: "마이노멀",
    platform: "imweb",
    baseUrl: "https://mynormal.shop",
    // imweb 은 전용 특가 카테고리가 없어 price_diff·title_tag 로 판별.
    dealCategories: [],
    // 2026-08-11 확인된 상품 카테고리 코드(각 24개/페이지, 페이지네이션 순회).
    catalogCategories: [
      "s20230201aa551133f0cc2",
      "s20251211abf680715a3ab",
      "s2026013060802d7f678d8",
      "s20240112e1715dc0e1e96",
      "s20240517d24ec71f8d0e0",
    ],
    listHasPricing: false, // 목록엔 가격 없음 → 상세 JS객체 파싱
    detailDelayMs: 400,
    minRetainRatio: 0.5,
  },
];

/**
 * 상품명 기반 특가 판별.
 * 실제 관측 사례: "[최약 특가]", "[패밀리인쿠일]", "[선착순 특가]",
 *                "[무제한 990원]", "[라스틱 990원]", "[1+1]"
 */
export const DEAL_TITLE_RE =
  /\[[^\]]*(특가|세일|SALE|할인|딜|반값|증정|\d\s*\+\s*\d|990원)[^\]]*\]/i;

/** 이 비율 이상 할인이면 가격만으로도 특가로 인정 */
export const PRICE_DIFF_THRESHOLD = 0.05;

/**
 * 상품명 기반 카테고리 분류 (브랜드 무관 — cate_no 매핑보다 브랜드간 통일성 좋음).
 * 통합 라벨: 아이스크림 / 빵 / 디저트 / 과자 / 음료 / 단백바 / 기타
 * 순서 주의: 더 구체적인 것(단백바·아이스크림)을 먼저 검사.
 */
const CATEGORY_RULES: [RegExp, string][] = [
  [/아이스크림|파인트|제로바|셔벗|빙과|월드콘|모나카|스틱바/, '아이스크림'],
  [/단백질\s*바|프로틴\s*바|에너지\s*바/, '단백바'],
  [/쉐이크|에이드|라떼|아메리카노|스무디|드링크|주스|콤부차|음료/, '음료'],
  [/뚱카롱|마카롱|휘낭시에|낭시에|쿠키|케이크|파운드|타르트|브라우니|디저트|초콜릿|초코바|뚱낭시에|푸딩|젤리/, '디저트'],
  [/빵|바게트|깜빠뉴|식빵|모닝빵|베이글|스콘|포카치아|번\b|르방|슬랩|크림빵/, '빵'],
  [/과자|스낵|팝콘|웨하스|칩|콘스낵|시리얼|제과|크래커/, '과자'],
  [/소스|드레싱|마요|케찹|케첩|비빔장|고추장|쌈장|초고추장|굴소스|양념|비빔/, '소스/드레싱'],
  [/알룰로스|시럽|스테비아|감미료|에리스리톨/, '감미료/시럽'],
  [/잼|땅콩버터|스프레드|유자청|무화과청|청$/, '잼/스프레드'],
  // 위 구체 규칙에 안 걸린 "~바"는 라라스윗 아이스크림 바류(듬뿍바·생요거트바·쫀득바 등).
  // 오일류(MCT오일 등)는 별도 카테고리 없이 기타로.
  [/바$/, '아이스크림'],
];

export function classifyCategory(name: string): string {
  for (const [re, label] of CATEGORY_RULES) {
    if (re.test(name)) return label;
  }
  return '기타';
}

// TODO(배포 전 필수): 실제 도메인/이메일로 교체. HTTP 헤더는 ASCII 로마자만.
//   · 배포 후: "jeodangmap-bot/1.0 (+https://<도메인>/bot; bot@<도메인>)"
//   · 배포 전: "jeodangmap-bot/1.0 (contact: bot@<도메인>)"  ← 죽은 URL 박느니 이메일만
// 역할 주소(bot@/crawler@) 사용, 개인·학교 계정 금지, 실제로 읽는 주소일 것.
// 파싱 로직 바꾸면 버전 번호(1.0)를 올릴 것.
export const USER_AGENT =
  "jeodangmap-bot/1.0 (contact: bot@jeodangmap.kr)";
