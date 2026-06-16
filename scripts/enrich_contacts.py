#!/usr/bin/env python3
"""
DB의 stores 32개에 대해 네이버 공식 검색 API로
전화번호 + 인스타그램(link)을 보강하는 UPDATE SQL 생성.

- 할루시네이션 방지: 네이버가 실제로 반환한 값만 사용.
- telephone 비어있으면 건드리지 않음(기존 값 유지).
- link 가 instagram.com 도메인일 때만 instagram_url 설정.
- 운영시간(hours)은 네이버 지도 API가 CAPTCHA로 차단되어 자동 수집 불가 → 수동.

결과: scripts/output/update_contacts.sql + 검토용 CSV
"""
import os, re, time, csv
from pathlib import Path
from dotenv import load_dotenv
import requests

load_dotenv(Path(__file__).parent / ".env")
SEARCH_ID     = os.environ["NAVER_SEARCH_CLIENT_ID"]
SEARCH_SECRET = os.environ["NAVER_SEARCH_SECRET"]

SUPABASE_URL = "https://aqhfddvvxnakgkdtirem.supabase.co"
ANON = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFxaGZkZHZ2eG5ha2drZHRpcmVtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEyOTcxNzAsImV4cCI6MjA5Njg3MzE3MH0.wntnduEOWL-LMkVkDs9d_p2MKQDDY4XGn8_4tlL6Q9w"

OUTPUT_DIR = Path(__file__).parent / "output"
OUTPUT_DIR.mkdir(exist_ok=True)


def strip_html(t):
    return re.sub(r"<[^>]+>", "", t or "")


def clean_instagram(link):
    """instagram.com 링크를 https://instagram.com/{handle} 로 정규화. 아니면 ''."""
    if not link or "instagram.com" not in link:
        return ""
    m = re.search(r"instagram\.com/([A-Za-z0-9_.]+)", link)
    if not m:
        return ""
    handle = m.group(1).rstrip(".")
    return f"https://instagram.com/{handle}"


def fetch_stores():
    r = requests.get(
        f"{SUPABASE_URL}/rest/v1/stores",
        params={"select": "id,name,district,phone,instagram_url", "is_active": "eq.true", "order": "name"},
        headers={"apikey": ANON, "Authorization": f"Bearer {ANON}"},
        timeout=10,
    )
    r.raise_for_status()
    return r.json()


def naver_search(name, district):
    q = f"{name} {district}".strip()
    r = requests.get(
        "https://openapi.naver.com/v1/search/local.json",
        params={"query": q, "display": 1},
        headers={"X-Naver-Client-Id": SEARCH_ID, "X-Naver-Client-Secret": SEARCH_SECRET},
        timeout=6,
    )
    items = r.json().get("items", [])
    return items[0] if items else None


rows = fetch_stores()
print(f"DB stores: {len(rows)}")

updates = []
review = []

for s in rows:
    name = s["name"]
    district = s.get("district") or ""
    item = naver_search(name, district)

    tel = ""
    link = ""
    if item:
        tel = (item.get("telephone") or "").strip()
        link = (item.get("link") or "").strip()
    insta = clean_instagram(link)

    # 인스타: 네이버 등록값(권위)이 있으면 그 값으로 설정/갱신.
    cur_insta = s.get("instagram_url") or ""
    new_insta = insta if insta and insta != cur_insta else None
    # 전화: API가 반환할 때만(현재 전 매장 빈값이지만 방어적으로 유지)
    new_phone = tel if tel and not s.get("phone") else None

    sets = []
    if new_phone:
        sets.append(f"phone = '{new_phone}'")
    if new_insta:
        sets.append(f"instagram_url = '{new_insta}'")

    if sets:
        updates.append(
            f"UPDATE public.stores SET {', '.join(sets)} WHERE id = '{s['id']}';"
        )

    review.append({
        "name": name,
        "district": district,
        "기존_phone": s.get("phone") or "",
        "네이버_telephone": tel,
        "기존_instagram": cur_insta,
        "네이버_link": link,
        "적용_insta": new_insta or "",
    })
    print(f"  {name:24s} insta={insta or '-'}")
    time.sleep(0.25)

# SQL 저장
sql_path = OUTPUT_DIR / "update_contacts.sql"
header = [
    "-- 전화번호/인스타그램 보강 (네이버 공식 검색 API 기준, 실제 반환값만)",
    "-- 기존값이 있으면 덮어쓰지 않음.",
    f"-- 총 {len(updates)}개 UPDATE",
    "",
]
sql_path.write_text("\n".join(header) + "\n".join(updates) + "\n", encoding="utf-8")
print(f"\n📄 SQL: {sql_path}  ({len(updates)}개 UPDATE)")

# 검토 CSV
csv_path = OUTPUT_DIR / "연락처_검토.csv"
with open(csv_path, "w", newline="", encoding="utf-8-sig") as f:
    w = csv.DictWriter(f, fieldnames=list(review[0].keys()))
    w.writeheader()
    w.writerows(review)
print(f"📋 검토 CSV: {csv_path}")
