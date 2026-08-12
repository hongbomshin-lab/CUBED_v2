# 스토어 출시 체크리스트 — 사용자 직접 작업

코드 작업은 완료된 상태(2026-07-17 기준). 아래는 계정·콘솔 등록 등 직접 해야 하는 일들입니다.
순서대로 진행하면 됩니다.

## A. 지금 바로 (코드 마무리에 필요)

### A-1. Android 업로드 키스토어 생성 ⚠️ 최우선
```powershell
keytool -genkey -v -keystore $env:USERPROFILE\cubed-upload-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
- 비밀번호는 안전한 곳(비밀번호 관리자)에 보관. **분실 시 앱 업데이트 불가**
- `android\key.properties.example`을 `android\key.properties`로 복사해 실제 값 입력
- 확인: `flutter build appbundle --release` 성공하면 완료

### A-2. delete-account Edge Function 배포
```powershell
supabase functions deploy delete-account
```
(또는 Claude에게 "delete-account 함수 배포해줘"라고 요청 — 권한 승인 필요)

### A-3. 패키지 ID 변경에 따른 외부 서비스 재등록
- **네이버 클라우드 콘솔** (지도): Application → Mobile Dynamic Map → Android 앱 패키지 이름에 `com.cubed.app` 추가, iOS Bundle ID에 `com.cubed.app` 추가
- **카카오 개발자 콘솔**: 플랫폼 설정 → Android 패키지명 `com.cubed.app` + 키 해시 재등록, iOS 번들 ID `com.cubed.app`
  - 릴리즈 키 해시 추출: 키스토어 생성 후
    ```powershell
    keytool -exportcert -alias upload -keystore $env:USERPROFILE\cubed-upload-key.jks | openssl sha1 -binary | openssl base64
    ```
- **Supabase**: Redirect URL(`cubed://login-callback`)은 패키지와 무관하므로 그대로 OK

### A-4. 개인정보처리방침 호스팅
- GitHub 저장소(CUBED_v2) → Settings → Pages → Source: `main` 브랜치 `/docs` 폴더 선택
- 게시 URL 확인: `https://hongbomshin-lab.github.io/CUBED_v2/privacy-policy`
- URL이 다르면 `lib/features/home/home_screen.dart`의 `kPrivacyPolicyUrl` 수정 요청

### A-5. 앱 아이콘 제작
- 1024×1024 PNG 1장 준비 (ZERO DOT 브랜드 아이콘)
- 준비되면 Claude에게 전달 → `flutter_launcher_icons`로 전 해상도 자동 생성 + 스플래시 적용

## B. 개발자 계정 등록 (심사 대기시간이 기니 빨리 시작)

### B-1. Google Play Console — $25 (1회)
- https://play.google.com/console 에서 개인 또는 조직 계정 생성
- 본인 확인(신분증) 필요, 승인까지 며칠 걸릴 수 있음
- ⚠️ **개인 계정은 정식 출시 전 "비공개 테스트 12명 유지 × 14일" 요건** 있음
  → 테스터 12명(지인 gmail 주소) 미리 모집해두기
- 사업자로 등록하면 이 요건 면제 (사업자등록증 필요)

### B-2. Apple Developer Program — $99/년
- https://developer.apple.com/programs/ 등록 (Apple ID 필요)
- 승인 후 해야 할 것:
  1. Certificates → App ID 등록 (`com.cubed.app`) + **Sign in with Apple** capability 체크
  2. App Store Connect에서 앱 생성
  3. Supabase 대시보드 → Authentication → Providers → **Apple 활성화** (Client ID = `com.cubed.app`)

### B-3. iOS 빌드 환경 (Windows에서는 불가)
- 추천: **Codemagic** (https://codemagic.io) — Flutter 특화 CI, 무료 500분/월
  - GitHub 저장소 연결 → Apple Developer 계정 연동 → 자동 빌드·TestFlight 업로드
- 대안: 맥 대여/클라우드 맥(MacinCloud), 지인 맥 빌드

## C. 스토어 등록 정보 준비

### C-1. 공통 자산
- [ ] 앱 설명 (짧은 설명 80자 / 긴 설명 4000자)
- [ ] 스크린샷: Android 폰 (최소 2장), iPhone 6.7" (필수), 6.5" (권장)
- [ ] Play 그래픽 이미지 1024×500
- [ ] 지원 이메일: hongbomshin@gmail.com
- [ ] 개인정보처리방침 URL (A-4에서 확보)

### C-2. Play Console 신고 항목
- [ ] 데이터 보안 섹션: 위치(수집 안 함·기기 내 사용), 이메일/이름(계정), 사진(제품 등록)
- [ ] 위치 권한 선언 폼 (`ACCESS_FINE_LOCATION` 사용 사유: 주변 매장 지도)
- [ ] 콘텐츠 등급 설문
- [ ] 계정 삭제 안내 URL (개인정보처리방침 내 회원 탈퇴 항목으로 대응 가능)

### C-3. App Store Connect 신고 항목
- [ ] 앱 개인정보 보호 (Privacy Nutrition Label): 이메일·이름·위치(정확한 위치, 앱 기능용)·사진
- [ ] 심사 메모에 테스트 계정(이메일/비번) 제공
- [ ] 건강 관련 앱 아님 + "의학적 조언 아님" 면책이 앱 내 있음을 언급하면 심사에 유리

## D. 출시 순서 요약

1. A-1 ~ A-5 완료 → `flutter build appbundle --release`
2. Play Console 등록 → 비공개 테스트 트랙 업로드 → 테스터 12명 × 14일 (개인 계정인 경우)
3. 그 사이 B-2, B-3 진행 → TestFlight 업로드 → 내부 테스트
4. 양쪽 심사 제출 (Play: 보통 1~3일, Apple: 1~2일)
