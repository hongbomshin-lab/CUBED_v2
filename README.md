# ZERO DOT 앱 (Phase 2)

편의점 저당/제로 제품의 **혈당 영향·0g 마케팅 함정**을 바코드 스캔 한 번으로 직관적으로 보여주는 Flutter 앱.

## 핵심 기능
1. **바코드 스캔 → 해석 UI** — 스캔 시 DB 조회 후 혈당 신호등·대체당 칩·0g 함정 카드·**대체당 조합 맞춤 메시지(combo_rules)**·**"대신 이건 어때요?" 대안 추천**을 표시.
2. **OCR 대체 입력** — 바코드 미등록 시 영양성분표를 촬영하면 Edge Function이 Gemini 비전으로 인식해 동일 포맷으로 해석. (`user_submissions`로 제보 축적 → DB 성장 루프)
3. 이름 검색.
4. **AI 도우미 채팅** — 홈 'AI에게 물어보기' → 전용 채팅 화면. Edge Function `chat`이 전 제품의 룰북 요약(등급·순탄수·0g함정·대체당)을 주입해 Gemini가 **데이터에 있는 제품만 근거로** 답변(비스트리밍, 대화는 메모리만).

## 아키텍처
- **상태관리**: Riverpod (`lib/providers/providers.dart`)
- **해석 엔진**: `lib/core/rulebook.dart` + `lib/core/explain.dart` — 해석값(순탄수·혈당등급·0g함정)은 **DB 미저장, 런타임 계산**(절대 원칙). 채팅 Edge Function도 동일 룰북을 포팅해 등급이 일치.
- **데이터**: `lib/data/` (Supabase 조회, 모델). 기준 데이터(감미료·카테고리·조합규칙)는 앱 시작 시 1회 캐시.
- **도메인**: `lib/domain/interpretation.dart` — 제품 → 해석 ViewModel(등급·함정·칩·combo·대안).
- **화면**: `lib/features/{home,scan,result,ocr,search,chat}/`
- **AI 채팅**: `lib/features/chat/`(chat_screen·chat_controller·chat_service) → Edge Function `supabase/functions/chat/`. LLM 키는 서버에만 두고 앱은 `functions.invoke('chat')`만 호출.

## 실행 준비
1. **설치 & 실행** (Android/iOS 플랫폼 폴더는 저장소에 포함됨)
   ```
   flutter pub get
   flutter run
   ```
2. **카메라 권한** (바코드 스캔·OCR용; 이미 설정돼 있으면 생략)
   - Android: `android/app/src/main/AndroidManifest.xml`의 `<manifest>`에
     `<uses-permission android:name="android.permission.CAMERA"/>`
   - iOS: `ios/Runner/Info.plist`에
     `<key>NSCameraUsageDescription</key><string>바코드 스캔과 영양성분 촬영에 사용됩니다</string>`

## Edge Functions 배포
시크릿은 앱·코드엔 없고 **Edge Functions Secrets에만** 둔다(RLS 보호되는 anon 키로 호출).
```
# Supabase CLI (또는 대시보드 / MCP)
supabase functions deploy ocr-parse      --project-ref aqhfddvvxnakgkdtirem
supabase functions deploy submit-product --project-ref aqhfddvvxnakgkdtirem
supabase functions deploy chat           --project-ref aqhfddvvxnakgkdtirem
# 시크릿 (대시보드 Edge Functions → Secrets 권장)
supabase secrets set CLOVA_API_KEY=nv-... --project-ref aqhfddvvxnakgkdtirem   # 이미지 분석 + chat 공용(현행)
# GEMINI_API_KEY 는 gemini 폴백을 다시 쓸 때만 필요(현재 미설정)
```
- 세 함수 모두 **CLOVA_API_KEY** 시크릿을 공유한다(앱·코드엔 키 없음).
- `ocr-parse`·`submit-product`: 제품 사진 → 구조화 영양정보. 파싱 엔진은 `_shared/parse.ts`가 공유.
  - **프로바이더 전환**: 시크릿 `OCR_PROVIDER`로 선택 — 미설정/`clova`(기본)=CLOVA HCX-005 단일콜, `gemini`=Gemini 멀티이미지. Gemini로 롤백하려면 `GEMINI_API_KEY`를 다시 넣고 `supabase secrets set OCR_PROVIDER=gemini`.
- `chat` (`supabase/functions/chat/`): 전 제품 룰북 요약 주입 → AI 답변(CLOVA HCX-005). 모델 교체는 `supabase secrets set CHAT_MODEL=...`. ⚠️ 전 제품을 프롬프트에 주입하므로 제품 수가 늘면 토큰이 커진다(408개 ≈ 4만 토큰).

## 연결 정보
- Supabase 프로젝트: `CUBED_v2` (ref `aqhfddvvxnakgkdtirem`) — `lib/core/env.dart`
- publishable(anon) 키는 클라이언트 노출이 정상(RLS 보호). service_role 키는 앱에 절대 포함하지 않음.
- ⚠️ `.mcp.json`(Claude Code MCP 설정)은 Supabase 액세스 토큰을 포함하므로 `.gitignore`로 제외됨 — **커밋 금지**.

## 데이터 현황
products 408 · product_sweeteners 896 · sweeteners 28 · category_meta 18 · combo_rules 12. 전부 `verified=false`(사람 검수 전 초안).
