#!/usr/bin/env python3
"""프랜차이즈 음료 CSV 6종 → franchise_drinks 적재용 SQL seed 생성.

- 컬럼 스키마가 브랜드마다 조금씩 다르므로(DictReader로) 이름 기준 매핑, 없는 컬럼은 NULL.
- 전처리: name_clean 생성
    · 이디야: 메뉴명 앞 괄호토큰 `(L)`,`(EX)` 등을 분리 → name_clean=순수명, size=토큰
    · 그 외 브랜드: name_clean = name
- 재실행 가능(idempotent): 각 행의 원본 id(uuid)를 PK로 쓰고 ON CONFLICT DO UPDATE.

사용:
    python3 scripts/build_franchise_seed.py [CSV_DIR]
CSV_DIR 미지정 시 ~/Downloads.
출력: scripts/output/franchise_drinks_seed.sql
"""
from __future__ import annotations

import csv
import os
import re
import sys
from pathlib import Path

# 파일명 → 브랜드는 CSV 안 brand 컬럼을 신뢰(파일명 매핑 불필요).
CSV_FILES = [
    "starbucks_drinks.csv",
    "megacoffee_drinks.csv",
    "compose_drinks.csv",
    "paik_all.csv",
    "ediya_all.csv",
    "twosome_all.csv",
]

# franchise_drinks 목표 컬럼(생성컬럼 sugar_cubes 제외).
NUMERIC_COLS = {
    "volume_ml", "calories", "sugar_g", "carbs_g",
    "protein_g", "fat_g", "sodium_mg", "caffeine_mg",
}
INT_COLS = {"volume_ml"}
OUT_COLS = [
    "id", "brand", "category", "name", "name_clean", "size", "volume_ml",
    "calories", "sugar_g", "carbs_g", "protein_g", "fat_g", "sodium_mg",
    "caffeine_mg", "has_zero_option", "alt_sweetener", "confidence", "source_url",
]

# 이디야 앞괄호 토큰 분리: "(L) 얼박사 코코 에이드" → ("L", "얼박사 코코 에이드")
PAREN_PREFIX = re.compile(r"^\((.+?)\)\s*(.+)$")


def clean_name(brand: str, name: str, size: str) -> tuple[str, str]:
    """(name_clean, size) 반환. 이디야만 괄호토큰 분리."""
    name = (name or "").strip()
    size = (size or "").strip()
    if brand == "이디야":
        m = PAREN_PREFIX.match(name)
        if m:
            token, pure = m.group(1).strip(), m.group(2).strip()
            # size가 비어 있으면 토큰을 size로 승격(있으면 기존 값 유지).
            return pure, (size or token)
    return name, size


def sql_str(v) -> str:
    if v is None:
        return "NULL"
    return "'" + str(v).replace("'", "''") + "'"


def sql_bool(v) -> str:
    s = str(v).strip().lower()
    if s in ("true", "1", "yes", "y", "t"):
        return "true"
    if s in ("false", "0", "no", "n", "f", ""):
        return "false"
    return "false"


def to_num(col: str, raw) -> str:
    if raw is None or str(raw).strip() == "":
        return "NULL"
    try:
        f = float(raw)
    except ValueError:
        return "NULL"
    return str(int(f)) if col in INT_COLS else repr(f)


def build_row(r: dict) -> list[str] | None:
    brand = (r.get("brand") or "").strip()
    name = (r.get("name") or "").strip()
    if not brand or not name:
        return None  # 이름/브랜드 없는 행은 스킵
    name_clean, size = clean_name(brand, name, r.get("size", ""))

    vals: list[str] = []
    for col in OUT_COLS:
        if col == "name_clean":
            vals.append(sql_str(name_clean))
        elif col == "size":
            vals.append(sql_str(size or None))
        elif col == "has_zero_option":
            vals.append(sql_bool(r.get("has_zero_option")))
        elif col in NUMERIC_COLS:
            vals.append(to_num(col, r.get(col)))
        else:  # id, brand, category, name, alt_sweetener, confidence, source_url
            raw = r.get(col)
            raw = raw.strip() if isinstance(raw, str) else raw
            vals.append(sql_str(raw if raw else None))
    return vals


def main() -> None:
    csv_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.home() / "Downloads"
    out_path = Path(__file__).resolve().parent / "output" / "franchise_drinks_seed.sql"
    out_path.parent.mkdir(parents=True, exist_ok=True)

    all_rows: list[list[str]] = []
    per_brand: dict[str, int] = {}
    ediya_examples: list[str] = []

    for fname in CSV_FILES:
        fpath = csv_dir / fname
        if not fpath.exists():
            print(f"⚠️  누락: {fpath}", file=sys.stderr)
            continue
        with open(fpath, encoding="utf-8-sig", newline="") as f:
            for r in csv.DictReader(f):
                row = build_row(r)
                if row is None:
                    continue
                all_rows.append(row)
                brand = (r.get("brand") or "").strip()
                per_brand[brand] = per_brand.get(brand, 0) + 1
                if brand == "이디야" and len(ediya_examples) < 5:
                    ediya_examples.append(f"  {r.get('name')!r} → name_clean={row[4]}, size={row[5]}")

    if not all_rows:
        print("❌ 적재할 행이 없습니다. CSV 경로를 확인하세요.", file=sys.stderr)
        sys.exit(1)

    cols = ", ".join(OUT_COLS)
    update_set = ", ".join(
        f"{c} = EXCLUDED.{c}" for c in OUT_COLS if c != "id"
    )

    lines = [
        "-- 자동 생성 파일 (scripts/build_franchise_seed.py). 직접 수정하지 말 것.",
        "-- franchise_drinks 데이터 적재. 0006_franchise_drinks.sql (테이블) 먼저 실행.",
        "-- 재실행 가능: 원본 id 기준 upsert.",
        "BEGIN;",
    ]
    # 500행씩 배치 INSERT.
    BATCH = 500
    for i in range(0, len(all_rows), BATCH):
        chunk = all_rows[i:i + BATCH]
        lines.append(f"INSERT INTO public.franchise_drinks ({cols}) VALUES")
        value_lines = [f"  ({', '.join(v)})" for v in chunk]
        lines.append(",\n".join(value_lines))
        lines.append(f"ON CONFLICT (id) DO UPDATE SET {update_set};")
    lines.append("COMMIT;")

    out_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    print(f"✅ {len(all_rows)}행 → {out_path}")
    for b, n in per_brand.items():
        print(f"   {b}: {n}")
    if ediya_examples:
        print("이디야 name_clean 분리 예시:")
        print("\n".join(ediya_examples))


if __name__ == "__main__":
    main()
