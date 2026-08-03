import type { RecognitionCandidate } from "./recognize.ts";

export interface RegisteredProductCandidate {
  product_id: string;
  name: string;
}

export interface PriceCatalogRow {
  product_id: string | null;
  catalog_product_key: string;
  catalog_name: string;
  aliases: string[] | null;
}

export interface ProductIdentity {
  candidateId: string;
  name: string;
  registeredProductId: string | null;
  catalogProductKey: string | null;
}

export interface ProductIdentitySet {
  candidates: RecognitionCandidate[];
  identities: Map<string, ProductIdentity>;
}

export function buildProductIdentitySet(
  products: RegisteredProductCandidate[],
  priceRows: PriceCatalogRow[],
): ProductIdentitySet {
  const identities = new Map<string, ProductIdentity>();
  const linkedProductIds = new Set<string>();
  const aliasesByCatalogKey = new Map<string, Set<string>>();

  for (const row of priceRows) {
    const aliases = aliasesByCatalogKey.get(row.catalog_product_key) ??
      new Set<string>();
    for (const alias of row.aliases ?? []) {
      const trimmed = alias.trim();
      if (trimmed && trimmed !== row.catalog_name) aliases.add(trimmed);
    }
    aliasesByCatalogKey.set(row.catalog_product_key, aliases);

    const current = identities.get(row.catalog_product_key);
    identities.set(row.catalog_product_key, {
      candidateId: row.catalog_product_key,
      name: row.catalog_name,
      registeredProductId: row.product_id ?? current?.registeredProductId ??
        null,
      catalogProductKey: row.catalog_product_key,
    });
    if (row.product_id) linkedProductIds.add(row.product_id);
  }

  for (const product of products) {
    if (linkedProductIds.has(product.product_id)) continue;
    identities.set(product.product_id, {
      candidateId: product.product_id,
      name: product.name,
      registeredProductId: product.product_id,
      catalogProductKey: null,
    });
  }

  const candidates = [...identities.values()]
    .sort((a, b) => a.name.localeCompare(b.name, "ko"))
    .map((identity) => {
      const aliases = identity.catalogProductKey
        ? [...(aliasesByCatalogKey.get(identity.catalogProductKey) ?? [])]
        : [];
      return {
        product_id: identity.candidateId,
        name: aliases.length > 0
          ? `${identity.name} (별칭: ${aliases.join(", ")})`
          : identity.name,
      };
    });

  return { candidates, identities };
}
