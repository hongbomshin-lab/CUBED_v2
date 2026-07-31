# ZERO DOT 관리자 콘솔 — 배포·운영 노트

Flutter Web 기반 관리자 검수 콘솔(`lib/admin/main_admin.dart`)의 빌드·배포·운영 가이드. 앱 본체와 별도 entrypoint로 완전 분리돼 있다.

## 빌드

```bash
flutter build web --target lib/admin/main_admin.dart --no-tree-shake-icons
# 산출물: build/web
```

- `--no-tree-shake-icons`: 동적으로 쓰는 Material 아이콘이 빌드에서 누락되지 않도록.
- 로컬 미리보기: `flutter run -d chrome --target lib/admin/main_admin.dart`

## 배포 (Vercel)

정적 사이트로 `build/web`를 올린다.

1. Vercel 프로젝트 생성 → 이 레포 연결(또는 `build/web`만 별도 배포).
2. **Build Command**: `flutter build web --target lib/admin/main_admin.dart --no-tree-shake-icons`
   - Vercel 빌드 환경에 Flutter가 없으면, 로컬에서 빌드한 `build/web`를 직접 올리거나(Output only), Flutter 설치 스텝을 추가한다.
3. **Output Directory**: `build/web`
4. **SPA 라우팅**: 단일 페이지라 별도 rewrite 없이도 동작하지만, 새로고침 404 방지를 위해 `vercel.json`에 모든 경로를 `/index.html`로 rewrite 권장:
   ```json
   { "rewrites": [{ "source": "/(.*)", "destination": "/index.html" }] }
   ```

> 앱 본체(소비자용)는 별도 빌드(`flutter build web` 기본 target 또는 모바일)다. 이 배포는 **관리자 전용**이며 URL이 공개돼도 아래 게이트가 데이터를 막는다.

## 접근 통제 (이중 방어)

- **1차(서버, 최종 결정)**: `admin` Edge Function이 호출자 JWT→이메일을 `ADMIN_EMAILS` 시크릿과 대조. 불일치 시 모든 액션 **403**. 비관리자는 콘솔 URL에 접근해 로그인해도 데이터가 전혀 안 보인다.
- **2차(클라이언트, UX)**: 로그인 화면 + 로그아웃. (클라이언트 체크는 편의일 뿐, 신뢰 경계 아님.)

### `ADMIN_EMAILS` 관리

- Supabase 대시보드 → **Edge Functions → Secrets** 에서 설정.
- 형식: 쉼표 구분 이메일. 예: `hongbomshin@gmail.com,ops@cubed.app`
- 추가/제거는 시크릿 값만 수정하면 즉시 반영(함수 재배포 불필요). 대소문자 무시.
- 관리자 계정은 일반 사용자와 동일한 Supabase Auth(이메일/비밀번호)로 가입돼 있어야 한다.

## promote(승격) 롤백

잘못 승격한 제보를 되돌리려면(트랜잭션 함수가 만든 것들을 역순으로 제거):

```sql
-- p_product_id = 잘못 만들어진 product_id (예: 'ugc_8801...')
delete from public.product_sweeteners where product_id = '<pid>';
delete from public.sweetener_review where product_id = '<pid>';
delete from public.products where product_id = '<pid>';
update public.user_submissions
   set status = 'pending', promoted_product_id = null
 where promoted_product_id = '<pid>';
-- 대표 이미지도 지우려면 Storage product-images/<pid>.jpg 삭제.
```

## 데이터 흐름 요약

```
[앱] 바코드 미등록 → 3장 촬영 → submit-product
        → Gemini 파싱 → submission-images/{uuid}/ 업로드 → user_submissions(status=pending)

[관리자 콘솔] 제보 큐 → parsed 편집(실시간 등급 미리보기) →
        승인: admin/promote → promote_submission(트랜잭션)
              → products(verified=true, source_type='OCR제보') + product_sweeteners
              + product-images/{pid}.jpg 복사 + sweetener_review(unknown)
              + user_submissions(status=approved, promoted_product_id)
        거절: status=rejected
```

## 알려진 개선 여지 (Phase 3 후보)

- 제보 썸네일: `submission-images`가 private이라 콘솔에서 직접 표시 불가 → `admin` 함수에 `signed_url` 액션 추가 시 이미지 미리보기 가능.
- 파싱 프롬프트: 알룰로오스를 `sweeteners`에만 넣고 `rare_sugar_g`를 비우는 경향 → 현재는 편집 폼에서 수동 교정. 프롬프트 규칙 강화로 자동화 가능.
- 관리자 활동 감사 로그, 제보 일괄 승인/거절.
