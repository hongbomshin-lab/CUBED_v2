#!/usr/bin/env python3
"""서울 저당 카페/음식점 대표메뉴 JSON(scratchpad/menus/*.json) → store_menus INSERT SQL.

- 브랜드명이 stores.name 에 부분일치하는 매장(프랜차이즈·제로스토어 제외)에 적용.
- 실제 DB store_id 로만 매칭(임의 이름 생성 방지). 매칭 리포트 출력.
- source_url 필수. ON CONFLICT (store_id,name) DO NOTHING.
"""
import json
import urllib.request
from pathlib import Path

KEY = ("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6"
       "ImFxaGZkZHZ2eG5ha2drZHRpcmVtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEyOTcxNzAs"
       "ImV4cCI6MjA5Njg3MzE3MH0.wntnduEOWL-LMkVkDs9d_p2MKQDDY4XGn8_4tlL6Q9w")
B = "https://aqhfddvvxnakgkdtirem.supabase.co/rest/v1"
HERE = Path(__file__).parent
MENUS = HERE / "data" / "seoul_menus"


def get(path):
    r = urllib.request.Request(B + path)
    r.add_header("apikey", KEY)
    r.add_header("Authorization", "Bearer " + KEY)
    with urllib.request.urlopen(r) as x:
        return json.loads(x.read().decode())


def esc(s):
    return s.replace("'", "''")


def sqlnum(v):
    return "NULL" if v is None else str(v)


def sqltext(v):
    return "NULL" if v in (None, "") else f"'{esc(str(v))}'"


# 1) 스크래치 JSON 로드 (단일 객체 or 배열 혼재)
brands = []
for f in sorted(MENUS.glob("*.json")):
    data = json.loads(f.read_text(encoding="utf-8"))
    brands.extend(data if isinstance(data, list) else [data])

# 2) 비프랜차이즈 매장 로드 (제로스토어 제외)
stores = []
off = 0
while True:
    rows = get(f"/stores?select=id,name,store_type&store_type=neq.franchise"
               f"&offset={off}&limit=1000")
    stores += rows
    if len(rows) < 1000:
        break
    off += 1000
stores = [s for s in stores if s["store_type"] != "zero_store"]

# 3) 매칭 + SQL 생성
values = []
report = []
matched_store_ids = set()
for b in brands:
    brand = b["brand"]
    menus = b.get("menus", [])
    targets = [s for s in stores if brand in s["name"]]
    if not menus:
        report.append(f"  (빈 메뉴) {brand} — 근거 없음, 건너뜀")
        continue
    if not targets:
        report.append(f"  ! 매칭 매장 없음: {brand}")
        continue
    for s in targets:
        matched_store_ids.add(s["id"])
    report.append(f"  ✓ {brand}: 메뉴 {len(menus)}개 × 매장 {len(targets)}곳 "
                  f"({', '.join(t['name'] for t in targets)})")
    for s in targets:
        for i, m in enumerate(menus):
            values.append(
                f"  ('{s['id']}', '{esc(m['name'])}', '{m['kind']}', "
                f"{sqlnum(m.get('sugar_g'))}, {sqlnum(m.get('calories'))}, "
                f"{sqlnum(m.get('price_won'))}, {sqltext(m.get('serving'))}, "
                f"{sqltext(m.get('note'))}, '{esc(m['source_url'])}', "
                f"'{m['confidence']}', {i})")

sql = [
    "-- 서울 저당 카페/음식점 대표메뉴 (build_seoul_menus.py)",
    f"-- 브랜드 {len(brands)}개 · INSERT {len(values)}행",
    "insert into public.store_menus",
    "  (store_id, name, kind, sugar_g, calories, price_won, serving, note, "
    "source_url, confidence, sort_order)",
    "values",
    ",\n".join(values),
    "on conflict (store_id, name) do nothing;",
]
out = HERE / "output" / "seoul_store_menus.sql"
out.write_text("\n".join(sql) + "\n", encoding="utf-8")

print("\n".join(report))
print(f"\n브랜드 {len(brands)}개 · 매칭 매장 {len(matched_store_ids)}곳 · "
      f"INSERT {len(values)}행 → {out}")
# 메뉴 못 붙은 대상 매장(카페/음식점)
uncovered = [s["name"] for s in stores if s["id"] not in matched_store_ids]
print(f"\n메뉴 미부착 매장 {len(uncovered)}곳:")
for n in uncovered:
    print(f"  · {n}")
