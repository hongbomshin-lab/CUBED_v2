#!/usr/bin/env python3
"""
전주 매장 번역: 원본 CSV → ① 적재 SQL  ② 검토용 CSV(매장×메뉴×언어).

두 산출물을 한 원본에서 만들어 서로 어긋나지 않게 한다.
번역은 사람이 작성한 store_translations.csv 가 유일한 출처다
(HCX-005 자동 번역은 재료 오역이 확인돼 매장 데이터에는 쓰지 않는다).
"""
import csv
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
OUT = BASE / "output"
OUT.mkdir(exist_ok=True)
LANGS = ("en", "ja", "zh")


def esc(s: str) -> str:
    return s.replace("'", "''")


def load_translations() -> list[dict]:
    path = BASE / "data" / "store_translations.csv"
    return list(csv.DictReader(path.open(encoding="utf-8")))


# 브랜드 → stores.name 매칭 (build_store_menus.py 와 동일 규칙)
BRAND_MATCH = {
    "디저트39": "디저트39", "샐러디": "샐러디", "슬로우캘리": "슬로우캘리",
    "영칼로리포케": "영칼로리포케", "제로스토어": "제로스토어",
    "제로초이스": "제로초이스", "헬키푸키": "헬키푸키",
    "리얼식단": "리얼식단", "무가당": "무가당",
}


def fetch_jeonju() -> tuple[list[dict], list[dict]]:
    """전북 매장 목록 + 초안 CSV 를 매장별로 펼친 메뉴.

    store_menus 테이블이 아니라 로컬 초안에서 만든다 —
    DB 시드 전에도 검토용 CSV 를 뽑을 수 있어야 하고,
    시드 SQL 과 같은 원본을 써야 값이 어긋나지 않는다.
    """
    h = {"apikey": ANON, "Authorization": f"Bearer {ANON}"}
    stores = requests.get(
        f"{SUPABASE_URL}/rest/v1/stores",
        params={
            "select": "id,name,address,store_type",
            "lat": "gte.35.6",
            "and": "(lat.lte.36.1,lng.gte.126.8,lng.lte.127.4)",
        },
        headers=h,
        timeout=15,
    )
    stores.raise_for_status()
    stores = stores.json()

    draft = list(csv.DictReader(
        (BASE / "data" / "store_menus_draft.csv").open(encoding="utf-8")))
    menus = []
    for m in draft:
        needle = BRAND_MATCH.get(m["brand"], m["brand"])
        for st in stores:
            if needle in st["name"]:
                menus.append({**m, "store_id": st["id"]})
    return stores, menus


def write_sql(rows: list[dict]) -> Path:
    values = []
    for r in rows:
        for lang in LANGS:
            v = (r[lang] or "").strip()
            if not v:
                continue
            values.append(
                f"  ('{r['kind']}', '{esc(r['source'])}', '{lang}', '{esc(v)}', true)"
            )

    joined = ",\n".join(values)
    sql = f"""-- 전주 매장 이름·메뉴 번역 (en/ja/zh)
-- 생성: build_store_i18n.py · {len(values)}행
-- 사람이 작성한 scripts/data/store_translations.csv 가 원본.
-- is_reviewed = true — 자동 번역이 아니라 검수된 값이라는 뜻.

-- kind 에 매장/메뉴 종류를 추가한다. (테이블 구조는 원래 kind|source|lang 로 범용)
alter table public.franchise_translations
  drop constraint if exists franchise_translations_kind_check;
alter table public.franchise_translations
  add constraint franchise_translations_kind_check
  check (kind in ('menu', 'brand', 'size', 'category',
                  'store', 'store_menu', 'menu_note', 'serving', 'store_addr'));

insert into public.franchise_translations (kind, source, lang, value, is_reviewed)
values
{joined}
on conflict (kind, source, lang) do update
  set value = excluded.value,
      is_reviewed = excluded.is_reviewed,
      updated_at = now();
"""
    p = OUT / "store_translations.sql"
    p.write_text(sql, encoding="utf-8")
    return p


def write_review_csv(stores, menus, rows) -> Path:
    """매장별 대표 메뉴 5개 + 언어별 번역 (검토·전달용)."""
    tr = {(r["kind"], r["source"]): r for r in rows}

    def t(kind: str, source: str, lang: str) -> str:
        r = tr.get((kind, source))
        return (r[lang].strip() if r and r[lang].strip() else "")

    by_store = {}
    for m in menus:
        by_store.setdefault(m["store_id"], []).append(m)

    out = []
    for s in stores:
        for m in sorted(by_store.get(s["id"], []), key=lambda x: x["kind"]):
            out.append({
                "매장(한국어)": s["name"],
                "매장(EN)": t("store", s["name"], "en"),
                "매장(JA)": t("store", s["name"], "ja"),
                "매장(ZH)": t("store", s["name"], "zh"),
                "구분": "저당" if m["kind"] == "low_sugar" else "시그니처",
                "메뉴(한국어)": m["name"],
                "메뉴(EN)": t("store_menu", m["name"], "en"),
                "메뉴(JA)": t("store_menu", m["name"], "ja"),
                "메뉴(ZH)": t("store_menu", m["name"], "zh"),
                "당류(g)": m.get("sugar_g") or "",
                "칼로리": m.get("calories") or "",
                "가격(원)": m.get("price_won") or "",
                "기준량": m.get("serving") or "",
                "비고(한국어)": m.get("note") or "",
                "비고(EN)": t("menu_note", m.get("note") or "", "en"),
                "비고(JA)": t("menu_note", m.get("note") or "", "ja"),
                "비고(ZH)": t("menu_note", m.get("note") or "", "zh"),
                "신뢰도": m["confidence"],
                "출처": m["source_url"],
            })

    p = OUT / "jeonju_store_menus_i18n.csv"
    if out:
        with p.open("w", newline="", encoding="utf-8-sig") as f:
            w = csv.DictWriter(f, fieldnames=list(out[0].keys()))
            w.writeheader()
            w.writerows(out)
    return p


def main():
    rows = load_translations()
    stores, menus = fetch_jeonju()
    print(f"번역 원본 {len(rows)}건 · 전북 매장 {len(stores)}곳 · 메뉴 {len(menus)}건")

    # 번역 누락 점검 — 매장명·메뉴명·비고가 CSV 에 다 있는지.
    have = {(r["kind"], r["source"]) for r in rows}
    missing = []
    for s in stores:
        if ("store", s["name"]) not in have:
            missing.append(f"store: {s['name']}")
    for m in menus:
        if ("store_menu", m["name"]) not in have:
            missing.append(f"store_menu: {m['name']}")
        if m.get("note") and ("menu_note", m["note"]) not in have:
            missing.append(f"menu_note: {m['note']}")
    for x in sorted(set(missing)):
        print(f"  ! 번역 없음 — {x}")

    sql = write_sql(rows)
    csv_path = write_review_csv(stores, menus, rows)
    print(f"\nSQL: {sql}\nCSV: {csv_path}")


if __name__ == "__main__":
    main()
