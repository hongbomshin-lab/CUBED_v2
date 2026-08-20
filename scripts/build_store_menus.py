#!/usr/bin/env python3
"""
브랜드별 대표 메뉴 초안(CSV) → 매장별 store_menus INSERT SQL.

브랜드 단위로 관리하고 매장 단위로 펼친다.
  · 전주 14개 매장이지만 브랜드는 9개다(디저트39 5곳, 샐러디 2곳).
    브랜드로 한 번만 적어 두면 지점이 늘어도 CSV 를 안 고쳐도 된다.
  · 지점별로 메뉴가 다르면 그때 해당 행만 따로 넣으면 된다.

매장 매칭은 DB 의 실제 stores.name 으로 한다(임의 이름 생성 방지).
CSV 에 없는 브랜드는 건너뛰고 리포트에 남긴다.
"""
import csv
import os
import re
from pathlib import Path

import requests

SUPABASE_URL = "https://aqhfddvvxnakgkdtirem.supabase.co"
ANON = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9."
    "eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFxaGZkZHZ2eG5ha2drZHRpcmVtIiwicm9sZSI6"
    "ImFub24iLCJpYXQiOjE3ODEyOTcxNzAsImV4cCI6MjA5Njg3MzE3MH0."
    "wntnduEOWL-LMkVkDs9d_p2MKQDDY4XGn8_4tlL6Q9w"
)

BASE = Path(__file__).parent
OUTPUT_DIR = BASE / "output"
OUTPUT_DIR.mkdir(exist_ok=True)

# CSV 의 브랜드 → stores.name 에서 이 문자열을 포함하는 매장에 적용.
BRAND_MATCH = {
    "디저트39": "디저트39",
    "샐러디": "샐러디",
    "슬로우캘리": "슬로우캘리",
    "영칼로리포케": "영칼로리포케",
    "제로스토어": "제로스토어",
    "제로초이스": "제로초이스",
    "헬키푸키": "헬키푸키",
    "리얼식단": "리얼식단",
    "무가당": "무가당",
}


def fetch_jeonju_stores() -> list[dict]:
    """전북 범위의 매장만 가져온다."""
    r = requests.get(
        f"{SUPABASE_URL}/rest/v1/stores",
        params={
            "select": "id,name,address",
            "lat": "gte.35.6",
            "lng": "gte.126.8",
            "and": "(lat.lte.36.1,lng.lte.127.4)",
        },
        headers={"apikey": ANON, "Authorization": f"Bearer {ANON}"},
        timeout=15,
    )
    r.raise_for_status()
    return r.json()


def sql_escape(s: str) -> str:
    return s.replace("'", "''")


def num(v: str) -> str:
    v = (v or "").strip()
    return v if v else "null"


def text(v: str) -> str:
    v = (v or "").strip()
    return f"'{sql_escape(v)}'" if v else "null"


def main():
    rows = list(csv.DictReader((BASE / "data" / "store_menus_draft.csv").open(encoding="utf-8")))
    stores = fetch_jeonju_stores()
    print(f"전북 매장 {len(stores)}곳 · CSV 메뉴 {len(rows)}건\n")

    by_brand: dict[str, list[dict]] = {}
    for r in rows:
        by_brand.setdefault(r["brand"], []).append(r)

    values: list[str] = []
    covered: set[str] = set()

    for brand, menus in by_brand.items():
        needle = BRAND_MATCH.get(brand, brand)
        targets = [s for s in stores if needle in s["name"]]
        if not targets:
            print(f"  ! {brand}: 매칭되는 매장 없음 — 건너뜀")
            continue
        for s in targets:
            covered.add(s["name"])
            for i, m in enumerate(menus):
                values.append(
                    f"  ('{s['id']}', '{sql_escape(m['name'])}', '{m['kind']}', "
                    f"{num(m['sugar_g'])}, {num(m['calories'])}, {num(m['price_won'])}, "
                    f"{text(m['serving'])}, {text(m['note'])}, "
                    f"'{sql_escape(m['source_url'])}', '{m['confidence']}', {i})"
                )
        print(f"  ✓ {brand}: {len(menus)}개 메뉴 × 매장 {len(targets)}곳")

    missing = [s["name"] for s in stores if s["name"] not in covered]

    lines = [
        "-- 매장 대표 메뉴 (저당 + 시그니처)",
        f"-- 생성: build_store_menus.py · {len(values)}행",
        "-- 출처·신뢰도는 각 행의 source_url/confidence 참고. 당류 미공개는 null.",
        "",
        "-- 테이블이 초안 스키마로 먼저 만들어진 환경을 위해 칼럼을 먼저 맞춘다.",
        "alter table public.store_menus add column if not exists serving text;",
        "alter table public.store_menus"
        " add column if not exists updated_at timestamptz default now();",
        "",
        "insert into public.store_menus",
        "  (store_id, name, kind, sugar_g, calories, price_won, serving, note,"
        " source_url, confidence, sort_order)",
        "values",
        ",\n".join(values),
        "on conflict (store_id, name) do update set",
        "  kind = excluded.kind,",
        "  sugar_g = excluded.sugar_g,",
        "  calories = excluded.calories,",
        "  price_won = excluded.price_won,",
        "  serving = excluded.serving,",
        "  note = excluded.note,",
        "  source_url = excluded.source_url,",
        "  confidence = excluded.confidence,",
        "  sort_order = excluded.sort_order,",
        "  updated_at = now();",
    ]
    out = OUTPUT_DIR / "store_menus.sql"
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")

    print(f"\n총 {len(values)}행 → {out}")
    if missing:
        print(f"\n메뉴가 없는 매장 {len(missing)}곳 (CSV 에 브랜드 미작성):")
        for n in missing:
            print(f"  · {n}")


if __name__ == "__main__":
    main()
