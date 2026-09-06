#!/usr/bin/env python3
"""비비드키친(동원) 제품 수집 파이프라인 — Step 1(리스트) + Step 2(사진 저장).

동원몰 브랜드관(SSR)에서 SKU 코드를 뽑고, 각 상세페이지 og:title/og:image 로
상품명과 대표사진을 얻어 파일로 저장한다. (이미지는 URL 저장이 아니라 파일 다운로드)

산출물:
  scripts/output/vivid_products_list.csv   (productId, name, image_file, detail_url)
  scripts/output/vivid_images/{productId}.jpg

영양성분·원재료명(Step 3)은 식품안전나라 API 로 별도 수집(collect_vivid_nutrition.py).
최종 적재(Step 6)는 관리자 콘솔에서 수동 등록.
"""
import urllib.request as u, re, html as H, os, csv

UA = ('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120 Safari/537.36')
BRAND_PLAN = 'https://www.dongwonmall.com/display/plan.do?seq=00000104936'
OUTDIR = 'scripts/output/vivid_images'
LIST_CSV = 'scripts/output/vivid_products_list.csv'


def get(url, binary=False):
    r = u.Request(url, headers={'User-Agent': UA, 'Accept-Language': 'ko',
                                'Referer': 'https://www.dongwonmall.com/'})
    with u.urlopen(r, timeout=25) as x:
        return (x.read() if binary else x.read().decode('utf-8', 'replace')), x.status


def discover_ids():
    """브랜드관 페이지 임베디드에서 실제 상품코드(003######) 추출."""
    doc, _ = get(BRAND_PLAN)
    ids = []
    for i in re.findall(r'003[06]\d{5}', doc):
        if i not in ids:
            ids.append(i)
    return ids


def main():
    os.makedirs(OUTDIR, exist_ok=True)
    ids = discover_ids()
    print(f'발견 SKU: {len(ids)}개')
    rows = []
    for pid in ids:
        doc, _ = get(f'https://www.dongwonmall.com/product/detail.do?productId={pid}')
        mt = re.search(r'<meta property="og:title" content="([^"]+)"', doc) \
            or re.search(r'<title>([^<]+)</title>', doc)
        name = H.unescape(mt.group(1)).strip() if mt else '(이름없음)'
        name = re.sub(r'\s*[-|_]\s*동원몰.*$', '', name).strip()
        mi = re.search(r'<meta property="og:image" content="([^"]+)"', doc)
        img = H.unescape(mi.group(1)) if mi else None
        if img and img.startswith('//'):
            img = 'https:' + img
        if img:
            img = re.sub(r'\?.*$', '', img)
        saved = ''
        if img:
            try:
                b, st = get(img, binary=True)
                if st == 200 and len(b) > 2000:
                    open(f'{OUTDIR}/{pid}.jpg', 'wb').write(b)
                    saved = f'{pid}.jpg'
            except Exception:
                pass
        rows.append({'productId': pid, 'name': name, 'image_file': saved,
                     'detail_url': f'https://www.dongwonmall.com/product/detail.do?productId={pid}'})
        print(f'  {pid} | {name[:55]:55} | {saved or "이미지실패"}')
    with open(LIST_CSV, 'w', encoding='utf-8-sig', newline='') as f:
        w = csv.DictWriter(f, fieldnames=['productId', 'name', 'image_file', 'detail_url'])
        w.writeheader()
        w.writerows(rows)
    print(f'\n리스트 → {LIST_CSV} ({len(rows)}개)')
    print(f'이미지 → {OUTDIR}/ ({sum(1 for r in rows if r["image_file"])}개)')


if __name__ == '__main__':
    main()
