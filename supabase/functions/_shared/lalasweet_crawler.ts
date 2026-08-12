import { DOMParser } from "npm:linkedom@0.18.12";

export interface SalePageRef {
  productNo: string;
  title: string;
  url: string;
}

export interface ParsedStoreOffer {
  optionName: string;
  price: number;
  unitCount: number;
  promoType: "sale" | "bundle";
  offerKind: "standalone_bundle" | "conditional_addon";
  minimumOrderAmount: number | null;
  offerKey: string;
  offerTitle: string;
  offerNote: string;
  linkUrl: string;
}

export interface ExistingCatalogItem {
  productId: string | null;
  catalogProductKey: string;
  catalogName: string;
  aliases: string[];
}

export interface RegisteredCatalogProduct {
  productId: string;
  name: string;
}

export interface ResolvedCatalogItem extends ExistingCatalogItem {}

const BASE_URL = "https://lalasweet.kr";

export function parseSaleList(html: string): SalePageRef[] {
  const document = new DOMParser().parseFromString(html, "text/html");
  const refs = new Map<string, SalePageRef>();
  for (const item of document.querySelectorAll(".prd-list > li")) {
    const anchor = item.querySelector("a[href*='product_no=']");
    if (!anchor) continue;
    const href = anchor.getAttribute("href") ?? "";
    const productNo = new URL(href, BASE_URL).searchParams.get("product_no");
    const title = item.querySelector(".name")?.textContent.trim() ?? "";
    if (!productNo || !title) continue;
    refs.set(productNo, {
      productNo,
      title: collapseWhitespace(title),
      url: new URL(href, BASE_URL).toString(),
    });
  }
  return [...refs.values()];
}

export function parseDealPage(
  ref: SalePageRef,
  html: string,
): ParsedStoreOffer[] {
  const document = new DOMParser().parseFromString(html, "text/html");
  const priceText =
    document.querySelector("meta[property='product:price:amount']")
      ?.getAttribute("content") ?? "";
  const basePrice = Number(priceText.replace(/[^0-9]/g, ""));
  if (!Number.isFinite(basePrice) || basePrice <= 0) {
    throw new Error(`product_no=${ref.productNo} 가격 파싱 실패`);
  }

  const groups = [...document.querySelectorAll("ul[option_title]")].map((
    element,
  ) => ({
    title: collapseWhitespace(element.getAttribute("option_title") ?? ""),
    options: [...element.querySelectorAll("li[title]")]
      .map((option) => collapseWhitespace(option.getAttribute("title") ?? ""))
      .filter(isProductOption),
  }));
  const conditionalGroups = groups.filter((group) =>
    group.title.includes("990원딜")
  );
  const conditional = conditionalGroups.length > 0;
  const productGroup = conditional
    ? conditionalGroups[0]
    : groups.find((group) =>
      group.title !== "묶음 선택" && group.options.length > 0
    );
  if (!productGroup || productGroup.options.length === 0) {
    throw new Error(`product_no=${ref.productNo} 옵션 파싱 실패`);
  }

  const bundleLabel =
    groups.find((group) => group.title === "묶음 선택")?.options[0] ?? "1";
  const bundleMultiplier = conditional
    ? 1
    : firstPositiveInteger(bundleLabel) ?? 1;
  const conditionalUnitPrice = conditional
    ? firstPositiveInteger(ref.title.match(/([0-9,]+)\s*원?딜/)?.[1] ?? "")
    : null;
  if (conditional && conditionalUnitPrice == null) {
    throw new Error(`product_no=${ref.productNo} 조건부 단가 파싱 실패`);
  }

  const offerKey = `lalasweet-${ref.productNo}${conditional ? "-addon" : ""}`;
  const offers = new Map<string, ParsedStoreOffer>();
  for (const rawOption of productGroup.options) {
    const count = optionUnitCount(rawOption);
    const optionName = cleanOptionName(rawOption);
    if (!optionName || count == null) continue;
    const unitCount = count * bundleMultiplier;
    offers.set(normalizeCatalogName(optionName), {
      optionName,
      price: conditional ? conditionalUnitPrice! * unitCount : basePrice,
      unitCount,
      promoType: conditional ? "sale" : "bundle",
      offerKind: conditional ? "conditional_addon" : "standalone_bundle",
      minimumOrderAmount: conditional ? basePrice : null,
      offerKey,
      offerTitle: ref.title.replace(/^\[[^\]]+\]\s*/, ""),
      offerNote: conditional
        ? `기본 구성 ${formatWon(basePrice)} 구매 후 추가 옵션 선택 시 · 개당 ${
          formatWon(conditionalUnitPrice!)
        }`
        : `${bundleLabel} 선택 시 · 총 ${unitCount}개`,
      linkUrl: ref.url,
    });
  }
  if (offers.size === 0) {
    throw new Error(`product_no=${ref.productNo} 유효 옵션 없음`);
  }
  return [...offers.values()];
}

export function resolveCatalogItem(
  optionName: string,
  existingItems: ExistingCatalogItem[],
  products: RegisteredCatalogProduct[],
): ResolvedCatalogItem {
  const normalized = normalizeCatalogName(optionName);
  const existing = existingItems.find((item) =>
    normalizeCatalogName(item.catalogName) === normalized ||
    item.aliases.some((alias) => normalizeCatalogName(alias) === normalized)
  );
  if (existing) {
    const aliases = new Set(existing.aliases);
    aliases.add(optionName);
    return { ...existing, aliases: [...aliases] };
  }

  const product = products.find((item) =>
    normalizeCatalogName(item.name) === normalized
  );
  return {
    productId: product?.productId ?? null,
    catalogProductKey: `lalasweet:auto:${fnv1a(normalized)}`,
    catalogName: optionName.startsWith("라라스윗")
      ? optionName
      : `라라스윗 ${optionName}`,
    aliases: [optionName],
  };
}

export function normalizeCatalogName(value: string): string {
  return value.normalize("NFKC")
    .toLocaleLowerCase("ko")
    .replace(/라라스윗/g, "")
    .replace(/[0-9]+\s*개(?:입)?/g, "")
    .replace(/[^\p{L}\p{N}]/gu, "");
}

function cleanOptionName(value: string): string {
  return collapseWhitespace(value.replace(/[0-9]+\s*개(?:입)?/g, "")).trim();
}

function optionUnitCount(value: string): number | null {
  const match = value.match(/([0-9]+)\s*개(?:입)?/);
  return match ? Number(match[1]) : value.includes("파인트") ? 1 : null;
}

function isProductOption(value: string): boolean {
  return value.length > 0 && !value.includes("선택 안함") &&
    !value.includes("추가 안 함");
}

function firstPositiveInteger(value: string): number | null {
  const number = Number(value.replace(/[^0-9]/g, ""));
  return Number.isInteger(number) && number > 0 ? number : null;
}

function collapseWhitespace(value: string): string {
  return value.replace(/\s+/g, " ").trim();
}

function formatWon(value: number): string {
  return `${value.toLocaleString("ko-KR")}원`;
}

function fnv1a(value: string): string {
  let hash = 0x811c9dc5;
  for (let i = 0; i < value.length; i++) {
    hash ^= value.charCodeAt(i);
    hash = Math.imul(hash, 0x01000193);
  }
  return (hash >>> 0).toString(16).padStart(8, "0");
}
