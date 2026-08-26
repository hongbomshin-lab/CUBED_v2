#!/usr/bin/env python3
"""
미션 정의 CSV → 앱 에셋(JSON) + 적재 SQL.

미션을 코드에 박지 않기 위한 파이프라인이다.
  · 지금  — 앱이 assets/missions.json 을 읽는다.
  · 나중  — 같은 모양의 missions 테이블을 읽는다(리포지토리만 교체).
어느 쪽이든 미션 추가는 CSV 한 줄이고, 앱 로직은 안 건드린다.

condition 은 이벤트에 딸려온 값과 대조하는 조건이다.
  예) grade=low        → 저당 등급 기록만 인정
      brand=스타벅스   → 그 브랜드만 인정
  비어 있으면 무조건 통과.
"""
import csv
import json
from pathlib import Path

BASE = Path(__file__).parent
ASSET = BASE.parent / "assets" / "missions.json"
OUT = BASE / "output"
OUT.mkdir(exist_ok=True)

VALID_TRIGGERS = {
    "checkin",            # 앱 실행 (출석)
    "product_log",        # 오늘 이거 먹었어요
    "store_review",       # 매장 리뷰
    "store_favorite",     # 매장 즐겨찾기
    "menu_board_report",  # 메뉴판 제보
    "store_report",       # 매장 제보
    "product_comment",    # 제품 댓글
}
VALID_PERIODS = {"once", "daily", "weekly", "streak"}


def parse_condition(raw: str) -> dict:
    """'grade=low;brand=스타벅스' → {'grade':'low','brand':'스타벅스'}"""
    out = {}
    for part in (raw or "").split(";"):
        part = part.strip()
        if "=" in part:
            k, v = part.split("=", 1)
            out[k.strip()] = v.strip()
    return out


def main():
    rows = list(csv.DictReader((BASE / "data" / "missions.csv").open(encoding="utf-8")))

    missions = []
    for r in rows:
        if r["trigger"] not in VALID_TRIGGERS:
            raise SystemExit(f"알 수 없는 trigger: {r['trigger']} ({r['code']})")
        if r["period"] not in VALID_PERIODS:
            raise SystemExit(f"알 수 없는 period: {r['period']} ({r['code']})")
        missions.append({
            "code": r["code"],
            "title": r["title"],
            "description": r["description"],
            "icon": r["icon"],
            "trigger": r["trigger"],
            "condition": parse_condition(r["condition"]),
            "period": r["period"],
            "target": int(r["target"]),
            "reward": int(r["reward"]),
            "sort": int(r["sort"]),
            "active": r["active"].strip().lower() == "true",
        })
    missions.sort(key=lambda m: m["sort"])

    ASSET.parent.mkdir(exist_ok=True)
    ASSET.write_text(
        json.dumps(missions, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    # 나중에 DB 로 옮길 때 그대로 쓸 SQL. 지금은 참고용.
    def esc(s):
        return str(s).replace("'", "''")

    values = ",\n".join(
        f"  ('{esc(m['code'])}', '{esc(m['title'])}', '{esc(m['description'])}', "
        f"'{esc(m['icon'])}', '{m['trigger']}', "
        f"'{esc(json.dumps(m['condition'], ensure_ascii=False))}'::jsonb, "
        f"'{m['period']}', {m['target']}, {m['reward']}, {m['sort']}, {str(m['active']).lower()})"
        for m in missions
    )
    (OUT / "missions.sql").write_text(
        "-- 미션 정의. 미션 추가는 이 표에 한 줄 넣는 것으로 끝난다(앱 배포 불필요).\n"
        f"-- 생성: build_missions.py · {len(missions)}개\n\n"
        "insert into public.missions\n"
        "  (code, title, description, icon, trigger, condition, period,"
        " target, reward, sort_order, is_active)\nvalues\n"
        f"{values}\n"
        "on conflict (code) do update set\n"
        "  title = excluded.title, description = excluded.description,\n"
        "  icon = excluded.icon, trigger = excluded.trigger,\n"
        "  condition = excluded.condition, period = excluded.period,\n"
        "  target = excluded.target, reward = excluded.reward,\n"
        "  sort_order = excluded.sort_order, is_active = excluded.is_active;\n",
        encoding="utf-8",
    )

    print(f"미션 {len(missions)}개")
    for m in missions:
        cond = f" [{m['condition']}]" if m["condition"] else ""
        print(f"  {m['period']:<7} {m['code']:<16} 목표 {m['target']:>2} → {m['reward']:>3}P{cond}")
    print(f"\n에셋: {ASSET}\nSQL : {OUT / 'missions.sql'}")


if __name__ == "__main__":
    main()
