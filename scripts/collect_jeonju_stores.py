#!/usr/bin/env python3
"""
전주 지역 저당 매장 14곳 수집 (IR 데모용).

원칙 — 임의값을 만들지 않는다:
  · 매장명·주소·전화·카테고리는 네이버 로컬검색이 반환한 값 그대로.
  · 좌표는 네이버 Geocoding 이 도로명주소로 돌려준 값(로컬검색 좌표는 KATECH 라 부정확).
  · 검색으로 못 찾은 매장은 비워 두고 리포트에만 남긴다. 추측해서 채우지 않는다.

검증:
  · 이름 유사도 — 반환된 상호에 브랜드명과 지점 키워드가 모두 들어가야 한다.
  · 위치 — 전북(위도 35.6~36.1, 경도 126.8~127.4) 밖이면 탈락.

결과:
  scripts/output/jeonju_stores.csv  — 검토용(원본 필드 + 판정 사유 포함)
  scripts/output/jeonju_stores.sql  — 통과분 INSERT
"""
import csv
import html
import os
import re
import sys
import time
from pathlib import Path

import requests


def load_env(path: Path) -> None:
    """.env 를 직접 읽는다 (python-dotenv 의존성 없이)."""
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        os.environ.setdefault(k.strip(), v.strip().strip("'\""))


load_env(Path(__file__).parent / ".env")
SEARCH_ID = os.environ["NAVER_SEARCH_CLIENT_ID"]
SEARCH_SECRET = os.environ["NAVER_SEARCH_SECRET"]
GEO_ID = os.environ["NAVER_GEO_CLIENT_ID"]
GEO_SECRET = os.environ["NAVER_GEO_SECRET"]

OUTPUT_DIR = Path(__file__).parent / "output"
OUTPUT_DIR.mkdir(exist_ok=True)

# (표시할 매장명, 검색어, 이름 검증 키워드들, store_type)
# store_type 은 CHECK 제약: cafe / restaurant / zero_store / delivery
TARGETS = [
    ("디저트39 전주객사점", "디저트39 전주객사점", ["디저트39", "객사"], "cafe"),
    ("디저트39 전주삼천점", "디저트39 전주삼천점", ["디저트39", "삼천"], "cafe"),
    ("디저트39 전주아중점", "디저트39 전주아중점", ["디저트39", "아중"], "cafe"),
    ("디저트39 전북대점", "디저트39 전북대점", ["디저트39", "전북대"], "cafe"),
    ("디저트39 전주만성점", "디저트39 전주만성점", ["디저트39", "만성"], "cafe"),
    ("제로스토어 전북대점", "제로스토어 전북대점", ["제로", "전북대"], "zero_store"),
    ("헬키푸키 전주혁신도시점", "헬키푸키 전주혁신도시점", ["헬키푸키"], "restaurant"),
    ("리얼식단 전북도청점", "리얼식단 전북도청점", ["리얼식단"], "restaurant"),
    ("전주 무가당", "전주 무가당", ["무가당"], "cafe"),
    ("전주 제로초이스", "전주 제로초이스", ["제로초이스"], "zero_store"),
    ("영칼로리포케 전주신시가지점", "영칼로리포케 전주신시가지점", ["영칼로리", "포케"], "restaurant"),
    ("슬로우캘리 전주효자점", "슬로우캘리 전주효자점", ["슬로우캘리"], "restaurant"),
    ("샐러디 전주송천점", "샐러디 전주송천점", ["샐러디", "송천"], "restaurant"),
    ("샐러디 전주혁신도시점", "샐러디 전주혁신도시점", ["샐러디", "혁신"], "restaurant"),
]

# 전북 범위 — 이 밖의 좌표는 동명 타지역 매장을 잘못 잡은 것.
LAT_MIN, LAT_MAX = 35.6, 36.1
LNG_MIN, LNG_MAX = 126.8, 127.4


def store_type_from(category: str, fallback: str) -> tuple[str, str]:
    """네이버 카테고리에서 store_type 을 유도. (타입, 근거) 반환.

    임의 분류를 피하려고 네이버가 실제로 준 분류 문자열을 근거로 삼는다.
    매칭되는 규칙이 없을 때만 TARGETS 의 기본값을 쓰고 그 사실을 근거에 남긴다.
    """
    c = category or ""
    if "식료품" in c or "편의점" in c:
        return "zero_store", f"네이버 분류 '{c}' → 식료품 판매"
    if "카페" in c or "디저트" in c or "베이커리" in c:
        return "cafe", f"네이버 분류 '{c}'"
    if any(k in c for k in ("음식점", "샐러드", "도시락", "분식", "한식", "양식", "포케")):
        return "restaurant", f"네이버 분류 '{c}'"
    return fallback, f"네이버 분류 '{c}' 미매칭 → 기본값 {fallback}"


def strip_html(t: str) -> str:
    """태그 제거 + HTML 엔티티 복원 (네이버는 상호에 &amp; 를 그대로 준다)."""
    return html.unescape(re.sub(r"<[^>]+>", "", t or "")).strip()


def naver_search(query: str, display: int = 5) -> list[dict]:
    r = requests.get(
        "https://openapi.naver.com/v1/search/local.json",
        params={"query": query, "display": display},
        headers={
            "X-Naver-Client-Id": SEARCH_ID,
            "X-Naver-Client-Secret": SEARCH_SECRET,
        },
        timeout=8,
    )
    if r.status_code != 200:
        print(f"    ! 검색 실패 {r.status_code}: {r.text[:120]}", file=sys.stderr)
        return []
    return r.json().get("items", [])


def naver_geocode(address: str):
    """도로명주소 → (lat, lng, 정규화 주소). 실패하면 (None, None, None)."""
    r = requests.get(
        "https://maps.apigw.ntruss.com/map-geocode/v2/geocode",
        params={"query": address},
        headers={
            "X-NCP-APIGW-API-KEY-ID": GEO_ID,
            "X-NCP-APIGW-API-KEY": GEO_SECRET,
        },
        timeout=8,
    )
    if r.status_code != 200:
        print(f"    ! 지오코딩 실패 {r.status_code}: {r.text[:120]}", file=sys.stderr)
        return None, None, None
    addrs = r.json().get("addresses", [])
    if not addrs:
        return None, None, None
    a = addrs[0]
    return float(a["y"]), float(a["x"]), a.get("roadAddress") or a.get("jibunAddress")


def name_matches(title: str, keywords: list[str]) -> bool:
    flat = title.replace(" ", "")
    return all(k.replace(" ", "") in flat for k in keywords)


def pick(items: list[dict], keywords: list[str]):
    """이름 키워드가 모두 맞는 첫 항목. 없으면 None."""
    for it in items:
        if name_matches(strip_html(it.get("title", "")), keywords):
            return it
    return None


def collect():
    rows = []
    for display_name, query, keywords, store_type in TARGETS:
        print(f"▶ {display_name}")
        row = {
            "입력명": display_name,
            "검색어": query,
            "네이버상호": "",
            "도로명주소": "",
            "지번주소": "",
            "전화": "",
            "카테고리": "",
            "네이버링크": "",
            "lat": "",
            "lng": "",
            "store_type": store_type,
            "분류근거": "",
            "판정": "",
        }

        items = naver_search(query)
        hit = pick(items, keywords)

        # 지점명으로 못 찾으면 브랜드 + '전주' 로 한 번 더 (지점 표기가 다른 경우).
        if hit is None:
            alt = f"{keywords[0]} 전주"
            print(f"    · 재시도: {alt}")
            time.sleep(0.3)
            items = naver_search(alt, display=10)
            hit = pick(items, keywords)

        if hit is None:
            row["판정"] = "검색결과 없음 — 수동 확인 필요"
            print("    ✗ 못 찾음")
            rows.append(row)
            time.sleep(0.3)
            continue

        title = strip_html(hit.get("title", ""))
        road = strip_html(hit.get("roadAddress", ""))
        jibun = strip_html(hit.get("address", ""))
        row.update({
            "네이버상호": title,
            "도로명주소": road,
            "지번주소": jibun,
            "전화": strip_html(hit.get("telephone", "")),
            "카테고리": strip_html(hit.get("category", "")),
            "네이버링크": hit.get("link", ""),
        })
        st, why = store_type_from(row["카테고리"], store_type)
        row["store_type"], row["분류근거"] = st, why

        time.sleep(0.3)
        lat, lng, norm = naver_geocode(road or jibun)
        if lat is None:
            row["판정"] = "지오코딩 실패 — 좌표 없음"
            print(f"    ✗ 좌표 실패 ({road or jibun})")
        elif not (LAT_MIN <= lat <= LAT_MAX and LNG_MIN <= lng <= LNG_MAX):
            row["lat"], row["lng"] = lat, lng
            row["판정"] = f"전북 범위 밖 ({lat:.4f},{lng:.4f}) — 동명 타지역 의심"
            print(f"    ✗ 범위 밖 {lat:.4f},{lng:.4f}")
        else:
            row["lat"], row["lng"] = lat, lng
            if norm:
                row["도로명주소"] = norm
            row["판정"] = "OK"
            print(f"    ✓ {title} / {row['도로명주소']} / {lat:.5f},{lng:.5f}")

        rows.append(row)
        time.sleep(0.3)
    return rows


def sql_escape(s: str) -> str:
    return s.replace("'", "''")


def write_outputs(rows):
    csv_path = OUTPUT_DIR / "jeonju_stores.csv"
    with csv_path.open("w", newline="", encoding="utf-8-sig") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)

    ok = [r for r in rows if r["판정"] == "OK"]
    lines = [
        "-- 전주 지역 저당 매장 (네이버 플레이스 로컬검색 + Geocoding 결과 그대로)",
        f"-- 생성: collect_jeonju_stores.py · 통과 {len(ok)}/{len(rows)}건",
        "-- 좌표·주소·전화는 네이버 반환값. 임의 입력 없음.",
        "",
        "insert into public.stores (name, address, lat, lng, phone, instagram_url,"
        " store_type, district, is_active) values",
    ]
    values = []
    for r in ok:
        phone = f"'{sql_escape(r['전화'])}'" if r["전화"] else "null"
        # 로컬검색의 link 는 '매장 홈페이지/인스타'다 — 네이버 플레이스 URL 이 아니다.
        # 인스타그램이면 instagram_url 에 넣고, 그 외 홈페이지는 넣을 칸이 없어 CSV 에만 남긴다.
        url = r["네이버링크"] or ""
        insta = f"'{sql_escape(url)}'" if "instagram.com" in url else "null"
        # district: 도로명주소에서 시/군 단위 추출 (예: 전주시 완산구)
        m = re.search(r"(전주시\s*\S+구|\S+시|\S+군)", r["도로명주소"])
        district = f"'{sql_escape(m.group(1))}'" if m else "null"
        values.append(
            f"  ('{sql_escape(r['네이버상호'])}', '{sql_escape(r['도로명주소'])}', "
            f"{r['lat']}, {r['lng']}, {phone}, {insta}, "
            f"'{r['store_type']}', {district}, true)"
        )
    lines.append(",\n".join(values) + "\non conflict do nothing;")

    sql_path = OUTPUT_DIR / "jeonju_stores.sql"
    sql_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return csv_path, sql_path, ok


if __name__ == "__main__":
    rows = collect()
    csv_path, sql_path, ok = write_outputs(rows)
    print(f"\n통과 {len(ok)}/{len(rows)}")
    for r in rows:
        if r["판정"] != "OK":
            print(f"  ✗ {r['입력명']}: {r['판정']}")
    print(f"\nCSV: {csv_path}\nSQL: {sql_path}")
