#!/usr/bin/env python3
"""
제로 전문 편의점 프랜차이즈(제로연구소·제로플러스·제로초이스) 지점 수집.

- 제로랩 → 제로연구소 리브랜딩: 기존 좌표와 일치하면 이름만 UPDATE.
- 신규 지점은 INSERT.
- 네이버 로컬검색(브랜드×자치구) → 도로명주소 dedupe → Geocoding 정밀좌표.
- 할루시네이션 방지: 네이버가 실제 반환한 지점만.

결과: scripts/output/zero_stores.sql (UPDATE + INSERT), 검토 CSV
"""
import os, re, time, csv
from pathlib import Path
from dotenv import load_dotenv
import requests

load_dotenv(Path(__file__).parent / ".env")
SEARCH_ID     = os.environ["NAVER_SEARCH_CLIENT_ID"]
SEARCH_SECRET = os.environ["NAVER_SEARCH_SECRET"]
GEO_ID        = os.environ["NAVER_GEO_CLIENT_ID"]
GEO_SECRET    = os.environ["NAVER_GEO_SECRET"]

SUPABASE_URL = "https://aqhfddvvxnakgkdtirem.supabase.co"
ANON = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFxaGZkZHZ2eG5ha2drZHRpcmVtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEyOTcxNzAsImV4cCI6MjA5Njg3MzE3MH0.wntnduEOWL-LMkVkDs9d_p2MKQDDY4XGn8_4tlL6Q9w"

OUTPUT_DIR = Path(__file__).parent / "output"
OUTPUT_DIR.mkdir(exist_ok=True)

BRANDS = ["제로연구소", "제로플러스", "제로초이스"]
DISTRICTS = [
    "종로구", "중구", "용산구", "성동구", "광진구", "동대문구", "중랑구",
    "성북구", "강북구", "도봉구", "노원구", "은평구", "서대문구", "마포구",
    "양천구", "강서구", "구로구", "금천구", "영등포구", "동작구", "관악구",
    "서초구", "강남구", "송파구", "강동구",
]

GU_SET = {d[:-1] for d in DISTRICTS}  # 종로, 중, 용산 ...


def strip_html(t):
    return re.sub(r"<[^>]+>", "", t or "")


def naver_search(q):
    r = requests.get(
        "https://openapi.naver.com/v1/search/local.json",
        params={"query": q, "display": 5},
        headers={"X-Naver-Client-Id": SEARCH_ID, "X-Naver-Client-Secret": SEARCH_SECRET},
        timeout=6,
    )
    return r.json().get("items", [])


def naver_geocode(address):
    r = requests.get(
        "https://maps.apigw.ntruss.com/map-geocode/v2/geocode",
        params={"query": address},
        headers={"X-NCP-APIGW-API-KEY-ID": GEO_ID, "X-NCP-APIGW-API-KEY": GEO_SECRET},
        timeout=6,
    )
    addrs = r.json().get("addresses", [])
    if addrs:
        a = addrs[0]
        return float(a["y"]), float(a["x"]), a.get("roadAddress", address)
    return None, None, address


def district_of(road_addr):
    m = re.search(r"서울특별시 (\S+?구)", road_addr)
    return m.group(1) if m else ""


def fetch_existing():
    r = requests.get(
        f"{SUPABASE_URL}/rest/v1/stores",
        params={"select": "id,name,lat,lng,store_type", "is_active": "eq.true"},
        headers={"apikey": ANON, "Authorization": f"Bearer {ANON}"},
        timeout=10,
    )
    r.raise_for_status()
    return r.json()


def near(lat1, lng1, lat2, lng2, tol=0.0004):
    """약 ±40m 이내면 동일 지점으로 간주."""
    return abs(lat1 - lat2) < tol and abs(lng1 - lng2) < tol


# 1) 브랜드 × 자치구 검색 → 도로명주소 dedupe
seen_addr = set()
found = []  # (brand, name, road_addr)

for brand in BRANDS:
    for gu in DISTRICTS:
        for it in naver_search(f"{brand} {gu}"):
            name = strip_html(it.get("title", ""))
            road = it.get("roadAddress") or ""
            # 브랜드명이 실제 매장명에 포함 + 서울 + 식료품 카테고리만
            if brand not in name:
                continue
            if "서울특별시" not in road:
                continue
            cat = it.get("category", "")
            if "식료품" not in cat and "유통" not in cat:
                continue
            key = road.split("(")[0].strip()
            if key in seen_addr:
                continue
            seen_addr.add(key)
            found.append((brand, name, road))
        time.sleep(0.15)

print(f"수집된 고유 지점: {len(found)}")

# 2) Geocoding
existing = fetch_existing()
print(f"기존 DB 매장: {len(existing)}")

updates, inserts, review = [], [], []

for brand, name, road in found:
    lat, lng, road2 = naver_geocode(road)
    if not lat:
        review.append({"brand": brand, "name": name, "road": road,
                       "lat": "", "lng": "", "action": "❌ 좌표실패"})
        time.sleep(0.2)
        continue

    gu = district_of(road2) or district_of(road)

    # 기존 매장과 좌표 매칭 → 리브랜딩 UPDATE
    matched = None
    for e in existing:
        if near(lat, lng, e["lat"], e["lng"]):
            matched = e
            break

    if matched:
        if matched["name"] != name:
            updates.append(
                f"UPDATE public.stores SET name = '{name}' WHERE id = '{matched['id']}';"
            )
            review.append({"brand": brand, "name": name, "road": road2,
                           "lat": lat, "lng": lng,
                           "action": f"🔄 이름변경: {matched['name']} → {name}"})
        else:
            review.append({"brand": brand, "name": name, "road": road2,
                           "lat": lat, "lng": lng, "action": "✓ 이미존재(동일)"})
    else:
        inserts.append(
            f"  ('{name}','{road2}',{lat},{lng},'','','zero_store','{gu}',true)"
        )
        review.append({"brand": brand, "name": name, "road": road2,
                       "lat": lat, "lng": lng, "action": "🆕 신규INSERT"})
    time.sleep(0.25)

# 3) SQL 출력
lines = ["-- 제로 전문 편의점 수집 (제로연구소/제로플러스/제로초이스)",
         "-- 제로랩 → 제로연구소 리브랜딩 이름변경 + 신규 지점 추가", ""]
if updates:
    lines.append(f"-- 이름변경(리브랜딩) {len(updates)}건")
    lines += updates
    lines.append("")
if inserts:
    lines.append(f"-- 신규 INSERT {len(inserts)}건")
    lines.append("INSERT INTO public.stores")
    lines.append("  (name, address, lat, lng, phone, instagram_url, store_type, district, is_active)")
    lines.append("VALUES")
    lines.append(",\n".join(inserts) + ";")

sql_path = OUTPUT_DIR / "zero_stores.sql"
sql_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

# 검토 CSV
csv_path = OUTPUT_DIR / "제로편의점_검토.csv"
with open(csv_path, "w", newline="", encoding="utf-8-sig") as f:
    w = csv.DictWriter(f, fieldnames=["brand", "name", "road", "lat", "lng", "action"])
    w.writeheader()
    w.writerows(review)

print(f"\n🔄 이름변경: {len(updates)}  🆕 신규: {len(inserts)}")
print(f"📄 SQL: {sql_path}")
print(f"📋 CSV: {csv_path}")
for r in review:
    print(f"  [{r['action']}] {r['name']} | {r['road']}")
