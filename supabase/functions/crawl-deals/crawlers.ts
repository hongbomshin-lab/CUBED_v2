// 플랫폼별 파서 레지스트리 — 사이트별 인터페이스 디스패치.
// 새 사이트 추가 = ① 파서 파일(cafe24.ts 처럼) 작성 ② 아래 REGISTRY 에 한 줄 ③ config 에 platform 지정.
import type { BrandConfig } from "./config.ts";
import type { ParsedItem } from "./types.ts";
import { crawlBrand as crawlCafe24 } from "./cafe24.ts";
import { crawlBrand as crawlImweb } from "./imweb.ts";

export type { ParsedItem };

/** 사이트 파서 공통 인터페이스: config → 표준 ParsedItem 목록 */
export type BrandCrawler = (cfg: BrandConfig) => Promise<ParsedItem[]>;

const REGISTRY: Record<string, BrandCrawler> = {
  cafe24: crawlCafe24,
  imweb: crawlImweb,
};

/** platform 값으로 파서를 골라 실행. */
export function crawlBrand(cfg: BrandConfig): Promise<ParsedItem[]> {
  const fn = REGISTRY[cfg.platform];
  if (!fn) throw new Error(`지원하지 않는 플랫폼: ${cfg.platform} (${cfg.slug})`);
  return fn(cfg);
}
