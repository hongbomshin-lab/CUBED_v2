#!/usr/bin/env python3
"""
전주 프랜차이즈 카페 6개 브랜드 검증·수집 (네이버 플레이스 기준).

입력 CSV(brand, store_name, address, lat, long)를 그대로 믿지 않고 전수 검증한다:
  ① 검증  — CSV 각 행을 네이버 로컬검색으로 조회. 찾으면 네이버 값으로 정정하고
            도로명주소를 다시 지오코딩해 좌표를 얻는다(CSV 좌표도 검증 대상).
  ② 발굴  — 브랜드 × 전주 행정동으로 훑어 CSV 에 없는 매장을 찾는다.
            네이버 로컬검색은 한 번에 최대 5건만 주므로 질의를 잘게 나눈다.
  ③ 대조  — 도로명주소 기준으로 ①과 ②를 합쳐 확인/추가/폐점의심 으로 가른다.

임의값은 만들지 않는다. 네이버가 돌려준 값만 쓰고, 못 찾은 건 '폐점의심'으로
남겨 사람이 판단하게 한다.

결과:
  scripts/output/jeonju_franchise.csv  — 판정 포함 전체 목록(검토용)
  scripts/output/jeonju_franchise.sql  — 확인된 매장 INSERT
"""
import csv
import html
import math
import os
import re
import sys
import time
from pathlib import Path

import requests

BASE = Path(__file__).parent
OUT = BASE / "output"
OUT.mkdir(exist_ok=True)
SRC = Path("/Users/sangin514/Downloads/jeonju_6_cafe_brands (1).csv")


def load_env(path: Path) -> None:
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        os.environ.setdefault(k.strip(), v.strip().strip("'\""))


load_env(BASE / ".env")
SEARCH_H = {
    "X-Naver-Client-Id": os.environ["NAVER_SEARCH_CLIENT_ID"],
    "X-Naver-Client-Secret": os.environ["NAVER_SEARCH_SECRET"],
}
GEO_H = {
    "X-NCP-APIGW-API-KEY-ID": os.environ["NAVER_GEO_CLIENT_ID"],
    "X-NCP-APIGW-API-KEY": os.environ["NAVER_GEO_SECRET"],
}

# CSV 브랜드 → (상호 매칭 키워드, franchise_drinks.brand)
# 매칭 키워드는 지점 표기 흔들림을 흡수할 만큼 짧게 잡는다
# (메가MGC커피 / 메가엠지씨커피 / 메가커피 가 모두 쓰인다).
BRANDS = {
    "스타벅스": ("스타벅스", "스타벅스"),
    "이디야": ("이디야", "이디야"),
    "컴포즈커피": ("컴포즈", "컴포즈커피"),
    "메가MGC커피": ("메가", "메가커피"),
    "투썸플레이스": ("투썸", "투썸플레이스"),
    "빽다방": ("빽다방", "빽다방"),
}

# 전주 범위 — 이 밖은 동명 타지역 매장.
LAT_MIN, LAT_MAX = 35.75, 35.95
LNG_MIN, LNG_MAX = 127.00, 127.25


def strip_html(t: str) -> str:
    return html.unescape(re.sub(r"<[^>]+>", "", t or "")).strip()


def search(query: str, display: int = 5) -> list[dict]:
    for attempt in range(3):
        try:
            r = requests.get(
                "https://openapi.naver.com/v1/search/local.json",
                params={"query": query, "display": display},
                headers=SEARCH_H,
                timeout=8,
            )
            if r.status_code == 200:
                return r.json().get("items", [])
            if r.status_code == 429:
                time.sleep(1.5)
                continue
            return []
        except requests.RequestException:
            time.sleep(0.8)
    return []


def geocode(address: str):
    for attempt in range(3):
        try:
            r = requests.get(
                "https://maps.apigw.ntruss.com/map-geocode/v2/geocode",
                params={"query": address},
                headers=GEO_H,
                timeout=8,
            )
            if r.status_code != 200:
                time.sleep(0.6)
                continue
            addrs = r.json().get("addresses", [])
            if not addrs:
                return None, None, None
            a = addrs[0]
            return float(a["y"]), float(a["x"]), a.get("roadAddress") or address
        except requests.RequestException:
            time.sleep(0.8)
    return None, None, None


def in_jeonju(lat: float, lng: float) -> bool:
    return LAT_MIN <= lat <= LAT_MAX and LNG_MIN <= lng <= LNG_MAX


def norm_addr(a: str) -> str:
    """도로명주소 대조용 정규화 — 건물명·괄호·층호를 떼고 '도로명 번호'만 남긴다."""
    a = re.sub(r"\(.*?\)", " ", a or "")
    m = re.search(r"(전북특별자치도|전라북도)\s*(\S+시)\s*(\S+구)?\s*(\S+(?:로|길))\s*([\d-]+)", a)
    if m:
        return f"{m.group(2)}|{m.group(4)}|{m.group(5)}"
    return re.sub(r"\s+", " ", a).strip()[:40]


def item_to_row(brand: str, it: dict) -> dict | None:
    """네이버 검색 결과 1건 → 표준 행. 브랜드가 안 맞거나 전주가 아니면 None."""
    keyword, _ = BRANDS[brand]
    title = strip_html(it.get("title", ""))
    if keyword.replace(" ", "") not in title.replace(" ", ""):
        return None
    road = strip_html(it.get("roadAddress", ""))
    jibun = strip_html(it.get("address", ""))
    if "전주" not in (road + jibun):
        return None
    return {
        "brand": brand,
        "naver_name": title,
        "road": road,
        "jibun": jibun,
        "category": strip_html(it.get("category", "")),
        "link": it.get("link", ""),
    }


def verify_csv(rows: list[dict]) -> dict[str, dict]:
    """CSV 각 행을 네이버로 확인. 키는 정규화 도로명주소."""
    found: dict[str, dict] = {}
    missing: list[dict] = []
    for i, r in enumerate(rows, 1):
        brand = r["brand"]
        if brand not in BRANDS:
            continue
        hit = None
        for q in (r["store_name"], f"{r['store_name']} 전주"):
            for it in search(q):
                hit = item_to_row(brand, it)
                if hit:
                    break
            time.sleep(0.25)
            if hit:
                break
        if hit:
            hit["csv_name"] = r["store_name"]
            found[norm_addr(hit["road"])] = hit
        else:
            missing.append(r)
        if i % 20 == 0:
            print(f"    검증 {i}/{len(rows)} · 확인 {len(found)} · 미확인 {len(missing)}")
    return found, missing


def dongs_from(rows: list[dict]) -> list[str]:
    """CSV 주소 괄호 안의 법정동을 뽑아 발굴 질의어로 쓴다(실제 존재하는 동만)."""
    s = set()
    for r in rows:
        for m in re.finditer(r"\(([^)]*)\)", r["address"]):
            for part in m.group(1).split(","):
                part = part.strip()
                if part.endswith(("동", "가", "면", "리")) and len(part) <= 8:
                    s.add(re.sub(r"\d+가$", "", part))
    return sorted(s)


def discover(dongs: list[str]) -> dict[str, dict]:
    """브랜드 × 동네로 훑어 CSV 에 없는 매장까지 수집."""
    # 동네 + 전주에서 흔히 쓰이는 상권 키워드.
    spots = dongs + [
        "전북대", "신시가지", "서부신시가지", "에코시티", "혁신도시",
        "한옥마을", "객사", "고사동", "전주역", "아중리", "만성동",
        "효자동", "송천동", "평화동", "삼천동", "인후동", "우아동",
    ]
    found: dict[str, dict] = {}
    total = len(BRANDS) * len(spots)
    n = 0
    for brand in BRANDS:
        for spot in spots:
            n += 1
            for it in search(f"{brand} 전주 {spot}"):
                row = item_to_row(brand, it)
                if row:
                    found.setdefault(norm_addr(row["road"]), row)
            time.sleep(0.25)
            if n % 40 == 0:
                print(f"    발굴 {n}/{total} · 누적 {len(found)}")
    return found


def retry_by_address(rows: list[dict], known: set[str]) -> tuple[dict[str, dict], list[dict]]:
    """이름 검색이 실패한 건을 도로명·법정동으로 다시 찾는다.

    지점 표기가 CSV 와 다른 경우가 많아(메가엠지씨커피 ↔ 메가MGC커피)
    상호 검색만으로는 살아 있는 매장을 폐점으로 오판한다.
    """
    found: dict[str, dict] = {}
    still: list[dict] = []
    for r in rows:
        brand = r["brand"]
        if brand not in BRANDS:
            continue
        key = norm_addr(r["address"])
        if key in known:      # 발굴 단계에서 이미 잡힌 매장 — 중복 기록 방지
            continue
        keyword = BRANDS[brand][0]
        rm = re.search(r"(\S+(?:로|길))\s*([\d-]+)", r["address"])
        dm = re.search(r"\(([^),]+)", r["address"])
        queries = []
        if rm:
            queries.append(f"{brand} {rm.group(1)}")
            queries.append(f"{keyword} {rm.group(1)} {rm.group(2)}")
        if dm:
            queries.append(f"{brand} 전주 {dm.group(1)}")
        hit = None
        for q in queries:
            for it in search(q):
                row = item_to_row(brand, it)
                if row and norm_addr(row["road"]) == key:
                    hit = row
                    break
            time.sleep(0.25)
            if hit:
                break
        if hit:
            hit["csv_name"] = r["store_name"]
            found[key] = hit
        else:
            still.append(r)
    return found, still


def main():
    rows = [r for r in csv.DictReader(SRC.open(encoding="utf-8-sig"))]
    print(f"입력 {len(rows)}행\n")

    print("① CSV 검증")
    verified, unverified = verify_csv(rows)
    print(f"   확인 {len(verified)} · 미확인 {len(unverified)}\n")

    print("② 누락 매장 발굴")
    discovered = discover(dongs_from(rows))
    print(f"   수집 {len(discovered)}\n")

    print("③ 이름으로 못 찾은 건 도로명·법정동으로 재검색")
    known = set(verified) | set(discovered)
    retried, unverified = retry_by_address(unverified, known)
    verified.update(retried)
    print(f"   추가 확인 {len(retried)} · 여전히 미확인 {len(unverified)}\n")

    print("④ 대조 + 좌표")
    merged: dict[str, dict] = {}
    for key, r in verified.items():
        merged[key] = {**r, "판정": "확인"}
    for key, r in discovered.items():
        if key in merged:
            continue
        merged[key] = {**r, "csv_name": "", "판정": "추가(CSV에 없음)"}

    out_rows = []
    for i, (key, r) in enumerate(sorted(merged.items()), 1):
        lat, lng, norm = geocode(r["road"] or r["jibun"])
        time.sleep(0.2)
        if lat is None:
            r["판정"] = "지오코딩 실패"
        elif not in_jeonju(lat, lng):
            r["판정"] = f"전주 범위 밖({lat:.4f},{lng:.4f})"
        else:
            r["road"] = norm or r["road"]
        r["lat"], r["lng"] = (lat or ""), (lng or "")
        out_rows.append(r)
        if i % 30 == 0:
            print(f"    좌표 {i}/{len(merged)}")

    for r in unverified:
        out_rows.append({
            "brand": r["brand"], "naver_name": "", "csv_name": r["store_name"],
            "road": r["address"], "jibun": "", "category": "", "link": "",
            "lat": r["lat"], "lng": r["long"],
            "판정": "폐점의심(네이버 검색결과 없음)",
        })

    fields = ["brand", "csv_name", "naver_name", "road", "jibun",
              "category", "lat", "lng", "link", "판정"]
    csv_path = OUT / "jeonju_franchise.csv"
    with csv_path.open("w", newline="", encoding="utf-8-sig") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        for r in out_rows:
            w.writerow({k: r.get(k, "") for k in fields})

    ok = [r for r in out_rows if r["판정"] in ("확인", "추가(CSV에 없음)")]
    values = []
    for r in ok:
        db_brand = BRANDS[r["brand"]][1]
        m = re.search(r"(전주시\s*\S+구|\S+시|\S+군)", r["road"])
        district = f"'{m.group(1)}'" if m else "null"
        link = r.get("link") or ""
        insta = f"'{link}'" if "instagram.com" in link else "null"
        values.append(
            f"  ('{r['naver_name'].replace(chr(39), chr(39)*2)}', "
            f"'{r['road'].replace(chr(39), chr(39)*2)}', {r['lat']}, {r['lng']}, "
            f"null, {insta}, 'franchise', '{db_brand}', {district}, true)"
        )

    sql = f"""-- 전주 프랜차이즈 카페 (네이버 플레이스 검증 결과)
-- 생성: collect_jeonju_franchise.py · {len(values)}곳
-- 상호·주소·좌표는 네이버 반환값. 임의 입력 없음.

insert into public.stores
  (name, address, lat, lng, phone, instagram_url, store_type, brand, district, is_active)
values
{",".join(chr(10) + v for v in values)}
on conflict do nothing;
"""
    sql_path = OUT / "jeonju_franchise.sql"
    sql_path.write_text(sql, encoding="utf-8")

    from collections import Counter
    print("\n판정 요약:", dict(Counter(r["판정"] for r in out_rows)))
    print("브랜드별 확정:", dict(Counter(r["brand"] for r in ok)))
    print(f"\nCSV: {csv_path}\nSQL: {sql_path}")


if __name__ == "__main__":
    main()
