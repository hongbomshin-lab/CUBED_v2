#!/usr/bin/env python3
"""
프랜차이즈 매장명 번역 생성 (en/ja/zh).

191개 매장명을 통째로 쓰지 않는다 — 지점이 늘 때마다 손이 가기 때문.
'브랜드 + 지점명' 으로 쪼갠 뒤, 지점명은 장소 토큰 사전(place_tokens.csv)으로
가장 긴 토큰부터 맞춰 조합한다. 사전에 없는 조각은 로마자로 음차한다
(아파트·건물 브랜드 등). 지어내지 않고, 못 읽은 조각은 리포트에 남긴다.

결과:
  scripts/output/franchise_translations.sql   — 적재 SQL
  scripts/output/franchise_translations.csv   — 검토용 (미매칭 조각 표시)
"""
import csv
import json
import re
from pathlib import Path

import requests

BASE = Path(__file__).parent
OUT = BASE / "output"
OUT.mkdir(exist_ok=True)
LANGS = ("en", "ja", "zh")

SUPABASE_URL = "https://aqhfddvvxnakgkdtirem.supabase.co"
ANON = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9."
    "eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFxaGZkZHZ2eG5ha2drZHRpcmVtIiwicm9sZSI6"
    "ImFub24iLCJpYXQiOjE3ODEyOTcxNzAsImV4cCI6MjA5Njg3MzE3MH0."
    "wntnduEOWL-LMkVkDs9d_p2MKQDDY4XGn8_4tlL6Q9w"
)

# 매장명 앞의 브랜드 — 긴 것부터 맞춰야 '빽다방베이커리'가 '빽다방'에 먹히지 않는다.
BRAND_PREFIX = [
    ("빽다방베이커리", {"en": "PAIK'S COFFEE Bakery", "ja": "ペクタバン ベーカリー", "zh": "白茶坊烘焙"}),
    ("메가MGC커피", {"en": "MEGA COFFEE", "ja": "メガMGCコーヒー", "zh": "MEGA COFFEE"}),
    ("투썸플레이스", {"en": "A TWOSOME PLACE", "ja": "ア・トゥーサムプレイス", "zh": "A TWOSOME PLACE"}),
    ("컴포즈커피", {"en": "COMPOSE COFFEE", "ja": "コンポーズコーヒー", "zh": "COMPOSE COFFEE"}),
    ("이디야커피", {"en": "EDIYA COFFEE", "ja": "イディヤコーヒー", "zh": "EDIYA COFFEE"}),
    ("스타벅스", {"en": "Starbucks", "ja": "スターバックス", "zh": "星巴克"}),
    ("빽다방", {"en": "PAIK'S COFFEE", "ja": "ペクタバン", "zh": "白茶坊"}),
    ("이디야", {"en": "EDIYA COFFEE", "ja": "イディヤコーヒー", "zh": "EDIYA COFFEE"}),
]

# 지점 접미 표기 — 그대로 두거나 언어별로 바꾼다.
SUFFIX = {"en": "", "ja": "店", "zh": "店"}

# 한글 → 로마자 (국어의 로마자 표기법). 사전에 없는 조각의 폴백.
_CHO = ["g","kk","n","d","tt","r","m","b","pp","s","ss","","j","jj","ch","k","t","p","h"]
_JUNG = ["a","ae","ya","yae","eo","e","yeo","ye","o","wa","wae","oe","yo",
         "u","wo","we","wi","yu","eu","ui","i"]
_JONG = ["","k","k","k","n","n","n","t","l","l","l","l","l","l","l","l",
         "m","p","p","t","t","ng","t","t","k","t","p","t"]


def romanize(text: str) -> str:
    out = []
    for ch in text:
        code = ord(ch) - 0xAC00
        if 0 <= code < 11172:
            out.append(_CHO[code // 588] + _JUNG[(code % 588) // 28] + _JONG[code % 28])
        else:
            out.append(ch)
    s = "".join(out)
    return s[:1].upper() + s[1:] if s else s


def load_tokens() -> list[tuple[str, dict]]:
    rows = list(csv.DictReader((BASE / "data" / "place_tokens.csv").open(encoding="utf-8")))
    # 긴 토큰부터 맞춰야 '전북도청' 이 '전북'+'도청' 으로 쪼개지지 않는다.
    return sorted(
        ((r["ko"], {l: r[l] for l in LANGS}) for r in rows),
        key=lambda t: -len(t[0]),
    )


def split_branch(branch: str, tokens) -> tuple[list[dict], list[str]]:
    """지점명을 토큰으로 분해. (조각들, 사전에 없던 조각들)

    왼쪽부터 가장 긴 토큰을 무는 그리디는 틀린다 —
    '전주대자인병원' 이 '전주대'(전주대학교) + '자인병원' 으로 잘린다.
    남는 글자가 가장 적은 분절을 고르도록 DP 로 푼다.
    """
    tok = {ko: tr for ko, tr in tokens}
    n = len(branch)
    # best[i] = (미매칭 글자 수, 조각 수, 조각 리스트) — i 위치부터 끝까지의 최적
    best: dict[int, tuple[int, int, list]] = {n: (0, 0, [])}

    def solve(i: int):
        if i in best:
            return best[i]
        cand = []
        for ko, tr in tokens:            # 토큰으로 진행
            if branch.startswith(ko, i):
                u, c, rest = solve(i + len(ko))
                cand.append((u, c + 1, [("tok", tr)] + rest))
        # 한 글자를 미매칭으로 흘려보내는 선택지 (항상 가능해야 종료된다)
        u, c, rest = solve(i + 1)
        cand.append((u + 1, c + 1, [("raw", branch[i])] + rest))
        best[i] = min(cand)
        return best[i]

    _, _, seq = solve(0)

    # 연속된 미매칭 글자를 한 덩어리로 묶어 음차한다.
    parts, unknown, buf = [], [], ""

    def flush():
        nonlocal buf
        if not buf:
            return
        if re.fullmatch(r"[A-Za-z0-9 ]+", buf):    # DT, CGV, LH, IC 등은 그대로
            parts.append({l: buf for l in LANGS})
        else:
            unknown.append(buf)
            rom = romanize(buf)
            parts.append({l: rom for l in LANGS})
        buf = ""

    for kind, val in seq:
        if kind == "raw":
            buf += val
        else:
            flush()
            parts.append(val)
    flush()
    return parts, unknown


def translate(name: str, tokens) -> tuple[dict, list[str]]:
    for ko, tr in BRAND_PREFIX:
        if name.startswith(ko):
            brand_tr, branch = tr, name[len(ko):].strip()
            break
    else:
        brand_tr, branch = {l: name for l in LANGS}, ""

    branch = re.sub(r"점$", "", branch).strip()
    parts, unknown = split_branch(branch, tokens) if branch else ([], [])

    out = {}
    for l in LANGS:
        seg = "".join(p[l] for p in parts) if l != "en" else " ".join(
            p[l] for p in parts if p[l]
        )
        seg = re.sub(r"\s+", " ", seg).strip()
        if not seg:
            out[l] = brand_tr[l]
        elif l == "en":
            out[l] = f"{brand_tr[l]} {seg}"
        else:
            out[l] = f"{brand_tr[l]} {seg}{SUFFIX[l]}"
    return out, unknown


def main():
    tokens = load_tokens()
    rows = requests.get(
        f"{SUPABASE_URL}/rest/v1/stores",
        params={"select": "name,brand", "store_type": "eq.franchise", "limit": "300"},
        headers={"apikey": ANON, "Authorization": f"Bearer {ANON}"},
        timeout=15,
    ).json()
    print(f"프랜차이즈 매장 {len(rows)}곳")

    out_rows, all_unknown = [], []
    for r in rows:
        tr, unknown = translate(r["name"], tokens)
        all_unknown += unknown
        out_rows.append({"ko": r["name"], **tr, "미매칭": " / ".join(unknown)})

    values = []
    for r in out_rows:
        for l in LANGS:
            v = r[l].replace("'", "''")
            src = r["ko"].replace("'", "''")
            values.append(f"  ('store', '{src}', '{l}', '{v}', true)")

    sql = f"""-- 프랜차이즈 매장명 번역 (en/ja/zh)
-- 생성: build_franchise_i18n.py · {len(values)}행 ({len(rows)}곳 × 3언어)
-- 브랜드는 공식 표기, 지점명은 장소 토큰 사전으로 조합.
-- 사전에 없는 조각(아파트·건물명 등)은 국어의 로마자 표기법으로 음차.

insert into public.franchise_translations (kind, source, lang, value, is_reviewed)
values
{",".join(chr(10) + v for v in values)}
on conflict (kind, source, lang) do update
  set value = excluded.value, is_reviewed = excluded.is_reviewed, updated_at = now();
"""
    (OUT / "franchise_translations.sql").write_text(sql, encoding="utf-8")

    with (OUT / "franchise_translations.csv").open("w", newline="", encoding="utf-8-sig") as f:
        w = csv.DictWriter(f, fieldnames=["ko", "en", "ja", "zh", "미매칭"])
        w.writeheader()
        w.writerows(out_rows)

    from collections import Counter
    print(f"번역 {len(values)}행 생성")
    if all_unknown:
        print(f"\n사전에 없어 음차한 조각 {len(set(all_unknown))}종:")
        for t, c in Counter(all_unknown).most_common(30):
            print(f"   {c}회  {t}")
    print(f"\nSQL: {OUT / 'franchise_translations.sql'}")
    print(f"CSV: {OUT / 'franchise_translations.csv'}")


if __name__ == "__main__":
    main()
