#!/usr/bin/env python3
# 리뷰 안전장치(신고/차단/금칙어/자동숨김/RPC) 코너케이스 검증 — API 레벨.
import json, urllib.request as u, urllib.error, base64

BASE = 'https://aqhfddvvxnakgkdtirem.supabase.co'
ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFxaGZkZHZ2eG5ha2drZHRpcmVtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEyOTcxNzAsImV4cCI6MjA5Njg3MzE3MH0.wntnduEOWL-LMkVkDs9d_p2MKQDDY4XGn8_4tlL6Q9w'
S1 = '0f6eb7fa-8472-448a-acdd-1be87abb1fe1'
S2 = '161b6714-aeb7-43d6-93fd-505c5246e380'
PW = 'Test!2345safety'

def req(method, path, token=None, body=None, prefer=None):
    url = BASE + path
    data = json.dumps(body).encode() if body is not None else None
    r = u.Request(url, data=data, method=method)
    r.add_header('apikey', ANON)
    r.add_header('Authorization', 'Bearer ' + (token or ANON))
    r.add_header('Content-Type', 'application/json')
    if prefer: r.add_header('Prefer', prefer)
    try:
        resp = u.urlopen(r)
        raw = resp.read().decode()
        return resp.status, (json.loads(raw) if raw.strip() else None)
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try: parsed = json.loads(raw)
        except Exception: parsed = raw
        return e.code, parsed

def auth(email):
    # 기존 로그인 시도 → 없으면 회원가입.
    st, b = req('POST', '/auth/v1/token?grant_type=password', body={'email': email, 'password': PW})
    if st != 200:
        req('POST', '/auth/v1/signup', body={'email': email, 'password': PW})
        st, b = req('POST', '/auth/v1/token?grant_type=password', body={'email': email, 'password': PW})
    if st != 200:
        raise SystemExit(f'auth 실패 {email}: {st} {b}')
    tok = b['access_token']
    uid = b['user']['id']
    return tok, uid

A_tok, A = auth('safety_a@zerodot.kr')
B_tok, B = auth('safety_b@zerodot.kr')
C_tok, C = auth('safety_c@zerodot.kr')
D_tok, D = auth('safety_d@zerodot.kr')
print(f'users: A={A[:8]} B={B[:8]} C={C[:8]} D={D[:8]}')

# ---- 사전 정리: 테스트 유저의 기존 리뷰/차단 제거(재실행 안전) ----
for tok, uid in [(A_tok,A),(B_tok,B),(C_tok,C),(D_tok,D)]:
    req('DELETE', f'/rest/v1/store_reviews?user_id=eq.{uid}', tok)
    req('DELETE', f'/rest/v1/user_blocks?blocker_id=eq.{uid}', tok)

results = []
def check(name, cond, extra=''):
    results.append((cond, name))
    print(f"{'✅' if cond else '❌'} {name}" + (f'  [{extra}]' if extra and not cond else ''))

def mkreview(tok, store, content, rec=True):
    return req('POST', '/rest/v1/store_reviews', tok,
               {'store_id': store, 'user_id': None, 'is_recommended': rec, 'content': content},
               prefer='return=representation')

# user_id 는 RLS WITH CHECK(auth.uid()=user_id) 이므로 서버가 검증 — 하지만 컬럼은 명시 필요.
def mkreview2(tok, uid, store, content, rec=True):
    return req('POST', '/rest/v1/store_reviews', tok,
               {'store_id': store, 'user_id': uid, 'is_recommended': rec, 'content': content},
               prefer='return=representation')

# ============================================================
# A. 금칙어 필터 (content guard)
# ============================================================
st,b = mkreview2(A_tok, A, S1, '씨발 최악이다')
check('01 금칙어 리뷰 작성 거부', st >= 400, f'{st}')

st,b = mkreview2(A_tok, A, S1, '씨 발 우회 시도')  # 공백 우회 → 정규화 차단
check('02 공백 우회 금칙어 거부', st >= 400, f'{st}')

st,b = mkreview2(A_tok, A, S1, 'this is fuck bad')
check('03 영문 금칙어 거부', st >= 400, f'{st}')

st,b = mkreview2(A_tok, A, S1, '정말 맛있고 저당이라 좋아요')  # 정상 → RA1
check('04 정상 리뷰 작성 성공', st in (200,201), f'{st} {b}')
RA1 = b[0]['id'] if isinstance(b, list) and b else None

st,b = req('PATCH', f'/rest/v1/store_reviews?id=eq.{RA1}', A_tok,
           {'content': '개새끼 수정'}, prefer='return=representation')
check('05 수정 시 금칙어 거부', st >= 400, f'{st}')

st,b = req('PATCH', f'/rest/v1/store_reviews?id=eq.{RA1}', A_tok,
           {'content': '수정해도 여전히 좋아요'}, prefer='return=representation')
check('06 정상 내용으로 수정 성공', st in (200,201), f'{st}')

st,b = mkreview2(C_tok, C, S1, '')  # 내용 없이 추천만 → RC1 (빈문자→null 저장)
check('07 내용 없는(추천만) 리뷰 성공', st in (200,201), f'{st} {b}')
RC1 = b[0]['id'] if isinstance(b, list) and b else None

st,b = mkreview2(A_tok, A, S2, '여기도 저당 메뉴 많아요')  # RA2 (S2, B가 신고 안함 → 차단 격리용)
check('08 다른 매장에도 리뷰 성공', st in (200,201), f'{st} {b}')
RA2 = b[0]['id'] if isinstance(b, list) and b else None

# ============================================================
# B. 신고 RLS / 제약
# ============================================================
# 본인 리뷰 신고 불가
st,b = req('POST', '/rest/v1/review_reports', A_tok,
           {'review_id': RA1, 'reporter_id': A, 'reason': 'spam'})
check('09 본인 리뷰 신고 거부', st >= 400, f'{st}')

# reporter_id 위조(B가 A인 척)
st,b = req('POST', '/rest/v1/review_reports', B_tok,
           {'review_id': RA1, 'reporter_id': A, 'reason': 'spam'})
check('10 신고자 위조 거부', st >= 400, f'{st}')

# 미로그인 신고
st,b = req('POST', '/rest/v1/review_reports', None,
           {'review_id': RA1, 'reporter_id': B, 'reason': 'spam'})
check('11 미로그인 신고 거부', st >= 400, f'{st}')

# 존재하지 않는 리뷰 신고
st,b = req('POST', '/rest/v1/review_reports', B_tok,
           {'review_id': '00000000-0000-0000-0000-000000000000', 'reporter_id': B, 'reason': 'spam'})
check('12 없는 리뷰 신고 거부', st >= 400, f'{st}')

# 잘못된 사유
st,b = req('POST', '/rest/v1/review_reports', B_tok,
           {'review_id': RA1, 'reporter_id': B, 'reason': 'foo'})
check('13 잘못된 사유 거부', st >= 400, f'{st}')

# detail 500자 초과
st,b = req('POST', '/rest/v1/review_reports', B_tok,
           {'review_id': RA1, 'reporter_id': B, 'reason': 'other', 'detail': 'x'*501})
check('14 detail 500자 초과 거부', st >= 400, f'{st}')

# 정상 신고 + status 위조 → sanitize 로 pending 강제
st,b = req('POST', '/rest/v1/review_reports', B_tok,
           {'review_id': RA1, 'reporter_id': B, 'reason': 'abuse', 'status': 'actioned', 'detail': '   '},
           prefer='return=representation')
ok = st in (200,201) and isinstance(b,list) and b and b[0]['status']=='pending' and b[0]['detail'] is None
check('15 정상 신고+status/detail 새니타이즈', ok, f'{st} {b}')

# 중복 신고 거부
st,b = req('POST', '/rest/v1/review_reports', B_tok,
           {'review_id': RA1, 'reporter_id': B, 'reason': 'spam'})
check('16 중복 신고 거부', st >= 400, f'{st}')

# 남의 신고 조회 불가 — D가 전체 조회 시 자기 것만
req('POST', '/rest/v1/review_reports', D_tok, {'review_id': RA1, 'reporter_id': D, 'reason': 'spam'})
st,b = req('GET', '/rest/v1/review_reports?select=reporter_id', D_tok)
only_d = isinstance(b,list) and all(x['reporter_id']==D for x in b)
check('17 신고는 본인 것만 조회', st==200 and only_d, f'{st} {b}')

# ============================================================
# C. RPC 필터링 — 신고한 리뷰 즉시 숨김
# ============================================================
def visible_ids(tok, store):
    st,b = req('POST', '/rest/v1/rpc/visible_store_reviews', tok,
               {'p_store_id': store, 'p_limit': 50})
    return st, ([x['id'] for x in b] if isinstance(b,list) else [])

st, ids = visible_ids(D_tok, S1)
check('18 신고자에게 신고 리뷰 숨김(D→RA1)', st==200 and RA1 not in ids, f'{st}')

st, ids = visible_ids(B_tok, S1)
check('19 신고자에게 신고 리뷰 숨김(B→RA1)', RA1 not in ids)

st, ids = visible_ids(None, S1)   # 미로그인 → 활성 리뷰 전체
check('20 미로그인은 활성 리뷰 표시(RA1 보임)', RA1 in ids, f'{st}')

st, ids = visible_ids(C_tok, S1)  # C는 신고/차단 없음 → RA1 보임
check('21 무관 유저는 리뷰 표시(C→RA1)', RA1 in ids)

# ============================================================
# D. 차단 (user_blocks)
# ============================================================
# 자기 차단 불가
st,b = req('POST', '/rest/v1/user_blocks', B_tok, {'blocker_id': B, 'blocked_id': B})
check('22 자기 자신 차단 거부', st >= 400, f'{st}')

# blocker 위조
st,b = req('POST', '/rest/v1/user_blocks', B_tok, {'blocker_id': A, 'blocked_id': C})
check('23 차단자 위조 거부', st >= 400, f'{st}')

# 정상 차단 B→A
st,b = req('POST', '/rest/v1/user_blocks', B_tok, {'blocker_id': B, 'blocked_id': A})
check('24 사용자 차단 성공(B→A)', st in (200,201), f'{st} {b}')

# 중복 차단(무시)
st,b = req('POST', '/rest/v1/user_blocks', B_tok,
           {'blocker_id': B, 'blocked_id': A}, prefer='resolution=ignore-duplicates')
check('25 중복 차단 무시(에러 아님)', st in (200,201), f'{st}')

# 남의 차단목록 조회 불가 — A는 아무도 차단 안 함
st,b = req('GET', '/rest/v1/user_blocks?select=blocker_id', A_tok)
check('26 차단목록 본인 것만(A는 0건)', st==200 and b==[], f'{st} {b}')

# 차단 후 RPC 필터 — S2의 RA2(신고 안 한 리뷰)가 B에게서 사라짐 → 순수 차단 격리
st, ids = visible_ids(B_tok, S2)
check('27 차단 사용자 리뷰 숨김(B→RA2/S2)', st==200 and RA2 not in ids, f'{st}')

st, ids = visible_ids(None, S2)
check('28 미로그인은 RA2 보임(S2)', RA2 in ids)

# 차단 해제 → RA2 다시 보임
st,b = req('DELETE', f'/rest/v1/user_blocks?blocker_id=eq.{B}&blocked_id=eq.{A}', B_tok)
check('29 차단 해제 성공', st in (200,204), f'{st}')
st, ids = visible_ids(B_tok, S2)
check('30 차단 해제 후 RA2 다시 보임', RA2 in ids)

# ============================================================
# E. 자동 숨김 — 서로 다른 3인 신고 시 리뷰 비활성화 (RC1)
# ============================================================
st, ids = visible_ids(None, S1)
check('31 자동숨김 전 RC1 노출', RC1 in ids)

req('POST', '/rest/v1/review_reports', B_tok, {'review_id': RC1, 'reporter_id': B, 'reason': 'abuse'})  # 1
st, ids = visible_ids(D_tok, S1)   # D는 RC1 신고 안했으니 자동숨김 여부만 봄
check('32 신고 1건은 유지(RC1 노출)', RC1 in ids)

req('POST', '/rest/v1/review_reports', D_tok, {'review_id': RC1, 'reporter_id': D, 'reason': 'abuse'})  # 2
st, ids = visible_ids(A_tok, S1)   # A는 RC1 신고 전 → 아직 보임
check('33 신고 2건은 유지(RC1 노출)', RC1 in ids)

req('POST', '/rest/v1/review_reports', A_tok, {'review_id': RC1, 'reporter_id': A, 'reason': 'abuse'})  # 3 distinct
st, ids = visible_ids(None, S1)    # 미로그인 기준 = 전역 숨김 확인
check('34 신고 3인 누적 시 자동숨김(전역)', RC1 not in ids, f'ids={ids}')

# 중복 신고는 distinct 카운트 안 올림 → RA1(B 1명만)은 여전히 활성
st, ids = visible_ids(C_tok, S1)
check('35 단일 신고 리뷰는 숨김 안됨(RA1 활성)', RA1 in ids)

# ---- 정리 ----
for tok, uid in [(A_tok,A),(C_tok,C)]:
    req('DELETE', f'/rest/v1/store_reviews?user_id=eq.{uid}', tok)  # 리뷰 삭제→신고 cascade
for tok, uid in [(B_tok,B),(D_tok,D)]:
    req('DELETE', f'/rest/v1/user_blocks?blocker_id=eq.{uid}', tok)

passed = sum(1 for ok,_ in results if ok)
print(f'\n===== {passed}/{len(results)} 통과 =====')
if passed != len(results):
    print('실패:', [n for ok,n in results if not ok])
    raise SystemExit(1)
