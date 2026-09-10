#!/usr/bin/env python3
"""제품 댓글(product_comments) 코너케이스 검증 — 작성/수정/삭제 + RLS 소유권.
마이페이지 '작성한 댓글' 조인 반영까지 API 레벨로 확인."""
import json, urllib.request as u, urllib.error

BASE = 'https://aqhfddvvxnakgkdtirem.supabase.co'
ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFxaGZkZHZ2eG5ha2drZHRpcmVtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEyOTcxNzAsImV4cCI6MjA5Njg3MzE3MH0.wntnduEOWL-LMkVkDs9d_p2MKQDDY4XGn8_4tlL6Q9w'
PW = 'Cmt!2345test'

def req(method, path, token=None, body=None, prefer=None):
    data = json.dumps(body).encode() if body is not None else None
    r = u.Request(BASE + path, data=data, method=method)
    r.add_header('apikey', ANON)
    r.add_header('Authorization', 'Bearer ' + (token or ANON))
    r.add_header('Content-Type', 'application/json')
    if prefer:
        r.add_header('Prefer', prefer)
    try:
        resp = u.urlopen(r); raw = resp.read().decode()
        return resp.status, (json.loads(raw) if raw.strip() else None)
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try: p = json.loads(raw)
        except Exception: p = raw
        return e.code, p

def auth(email):
    st, b = req('POST', '/auth/v1/token?grant_type=password', body={'email': email, 'password': PW})
    if st != 200:
        req('POST', '/auth/v1/signup', body={'email': email, 'password': PW})
        st, b = req('POST', '/auth/v1/token?grant_type=password', body={'email': email, 'password': PW})
    assert st == 200, f'auth {email}: {st} {b}'
    return b['access_token'], b['user']['id']

A_tok, A = auth('comment_a@zerodot.kr')
B_tok, B = auth('comment_b@zerodot.kr')
_, prod = req('GET', '/rest/v1/products?select=product_id&limit=1', A_tok)
PID = prod[0]['product_id']
print(f'A={A[:8]} B={B[:8]} product={PID}')

# 사전 정리
req('DELETE', f'/rest/v1/product_comments?user_id=eq.{A}', A_tok)
req('DELETE', f'/rest/v1/product_comments?user_id=eq.{B}', B_tok)

results = []
def check(name, cond, extra=''):
    results.append((cond, name))
    print(f"{'✅' if cond else '❌'} {name}" + (f'  [{extra}]' if not cond and extra else ''))

def body_of(cid, tok=None):
    st, b = req('GET', f'/rest/v1/product_comments?id=eq.{cid}&select=id,body,user_id', tok or ANON)
    return b[0] if isinstance(b, list) and b else None

# 01 작성(A)
st, c = req('POST', '/rest/v1/product_comments', A_tok,
            {'product_id': PID, 'user_id': A, 'body': 'A의 원본 댓글'}, prefer='return=representation')
CA = c[0]['id'] if st in (200, 201) and isinstance(c, list) else None
check('01 로그인 유저 댓글 작성', st in (200, 201) and CA is not None, f'{st} {c}')

# 02 작성한 댓글이 제품 목록에 노출
st, lst = req('GET', f'/rest/v1/product_comments?product_id=eq.{PID}&select=id', ANON)
check('02 제품 댓글 목록에 노출', any(x['id'] == CA for x in (lst or [])))

# 03 myComments 조인(제품명 포함)에 노출
st, mine = req('GET', f'/rest/v1/product_comments?user_id=eq.{A}&select=id,body,products(name,brand)', A_tok)
row = next((x for x in (mine or []) if x['id'] == CA), None)
check('03 마이 작성한 댓글에 노출 + 제품명 조인', row is not None and 'products' in (row or {}), f'{mine}')

# 04 본인 댓글 수정 → 성공 + 반영
st, r = req('PATCH', f'/rest/v1/product_comments?id=eq.{CA}', A_tok,
            {'body': 'A가 수정한 댓글'}, prefer='return=representation')
check('04 본인 댓글 수정 성공', st == 200 and isinstance(r, list) and r and r[0]['body'] == 'A가 수정한 댓글', f'{st} {r}')

# 05 수정이 재조회에 반영
check('05 수정 내용 재조회 반영', (body_of(CA) or {}).get('body') == 'A가 수정한 댓글')

# 06 남의 댓글 수정 시도(B가 A 댓글) → 변경 안 됨
st, r = req('PATCH', f'/rest/v1/product_comments?id=eq.{CA}', B_tok,
            {'body': 'B가 남의 댓글 변조'}, prefer='return=representation')
unchanged = (body_of(CA) or {}).get('body') == 'A가 수정한 댓글'
check('06 남의 댓글 수정 차단(RLS)', unchanged and (r == [] or st in (403, 401)), f'st={st} r={r}')

# 07 소유권 변조 시도(A가 자기 댓글 user_id를 B로) → owner 안 바뀜
st, r = req('PATCH', f'/rest/v1/product_comments?id=eq.{CA}', A_tok,
            {'user_id': B}, prefer='return=representation')
still_a = (body_of(CA) or {}).get('user_id') == A
check('07 수정으로 소유권 변조 불가', still_a, f'st={st} r={r} owner={(body_of(CA) or {}).get("user_id","?")[:8]}')

# 08 user_id 위조 작성(B 토큰으로 user_id=A) → 차단
st, r = req('POST', '/rest/v1/product_comments', B_tok,
            {'product_id': PID, 'user_id': A, 'body': '위조 작성'}, prefer='return=representation')
check('08 작성자 위조 차단', st >= 400, f'{st} {r}')

# 09 미로그인 작성 → 차단
st, r = req('POST', '/rest/v1/product_comments', None,
            {'product_id': PID, 'user_id': A, 'body': '익명 작성'}, prefer='return=representation')
check('09 미로그인 작성 차단', st >= 400, f'{st}')

# 10 남의 댓글은 조회 가능(공개 읽기) — B가 A 댓글 조회
st, r = req('GET', f'/rest/v1/product_comments?id=eq.{CA}&select=id,body', B_tok)
check('10 공개 읽기(남의 댓글 조회)', st == 200 and isinstance(r, list) and len(r) == 1)

# 11 myComments는 본인 것만 — B 작성 후 A 목록엔 B것 없음
st, cb = req('POST', '/rest/v1/product_comments', B_tok,
             {'product_id': PID, 'user_id': B, 'body': 'B의 댓글'}, prefer='return=representation')
CB = cb[0]['id'] if isinstance(cb, list) and cb else None
st, aList = req('GET', f'/rest/v1/product_comments?user_id=eq.{A}&select=id', A_tok)
check('11 마이 목록은 본인 것만', CB is not None and all(x['id'] != CB for x in (aList or [])))

# 12 남의 댓글 삭제 시도(A가 B 댓글) → 여전히 존재
req('DELETE', f'/rest/v1/product_comments?id=eq.{CB}', A_tok)
check('12 남의 댓글 삭제 차단', body_of(CB) is not None)

# 13 본인 댓글 삭제 → 사라짐 (B가 자기 것)
req('DELETE', f'/rest/v1/product_comments?id=eq.{CB}', B_tok)
check('13 본인 댓글 삭제 성공', body_of(CB) is None)

# 14 존재하지 않는 댓글 수정 → 변화 없음(에러 아님/빈 결과)
st, r = req('PATCH', '/rest/v1/product_comments?id=eq.999999999', A_tok,
            {'body': 'x'}, prefer='return=representation')
check('14 없는 댓글 수정은 무영향', st in (200, 204) and (r == [] or r is None), f'{st} {r}')

# 15 빈 body 수정은 서버가 거부(DB CHECK) + 원본 유지 — UI(공백→null)와 이중 방어
st, r = req('PATCH', f'/rest/v1/product_comments?id=eq.{CA}', A_tok,
            {'body': ''}, prefer='return=representation')
unchanged = (body_of(CA) or {}).get('body') == 'A가 수정한 댓글'
check('15 빈 body 수정 서버 거부 + 원본 유지', st >= 400 and unchanged, f'{st} {r}')

# ── 마이페이지 수정/삭제 → 제품 상세 목록 동기화(교차 반영) ──
def in_product_list(cid, body=None):
    st, l = req('GET', f'/rest/v1/product_comments?product_id=eq.{PID}&select=id,body', ANON)
    row = next((x for x in (l or []) if x['id'] == cid), None)
    return row is not None and (body is None or row['body'] == body)

def in_my_list(cid, tok, uid, body=None):
    st, l = req('GET', f'/rest/v1/product_comments?user_id=eq.{uid}&select=id,body', tok)
    row = next((x for x in (l or []) if x['id'] == cid), None)
    return row is not None and (body is None or row['body'] == body)

# 16 마이페이지 수정 → 제품 댓글 목록에 새 내용 반영
req('PATCH', f'/rest/v1/product_comments?id=eq.{CA}', A_tok, {'body': '동기화된 수정본'})
check('16 수정이 제품 댓글 목록에 반영', in_product_list(CA, '동기화된 수정본'))

# 17 마이페이지 수정 → 마이 목록에도 새 내용 반영
check('17 수정이 마이 목록에 반영', in_my_list(CA, A_tok, A, '동기화된 수정본'))

# 18 마이페이지 삭제 → 제품 목록 + 마이 목록 양쪽에서 제거
req('DELETE', f'/rest/v1/product_comments?id=eq.{CA}', A_tok)
check('18 삭제가 양쪽 목록에서 제거',
      not in_product_list(CA) and not in_my_list(CA, A_tok, A))

# 19 products에 없는 product_id(예: OCR draft 'ocr-temp') 댓글 → FK 위반 거부
#    → 앱은 draft 제품에 커뮤니티 섹션을 숨겨야 함(버그4 수정의 근거)
st, r = req('POST', '/rest/v1/product_comments', A_tok,
            {'product_id': 'ocr-temp', 'user_id': A, 'body': 'draft 댓글'},
            prefer='return=representation')
is_fk = st >= 400 and (isinstance(r, dict) and str(r.get('code')) == '23503' or st in (409, 400))
check('19 미등록 제품(draft) 댓글 FK 거부', is_fk, f'{st} {r}')

# 정리
req('DELETE', f'/rest/v1/product_comments?user_id=eq.{A}', A_tok)
req('DELETE', f'/rest/v1/product_comments?user_id=eq.{B}', B_tok)

passed = sum(1 for ok, _ in results if ok)
print(f'\n===== {passed}/{len(results)} 통과 =====')
if passed != len(results):
    print('실패:', [n for ok, n in results if not ok])
    raise SystemExit(1)
