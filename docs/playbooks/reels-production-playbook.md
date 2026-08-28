# ZERO DOT 릴스 제작 플레이북 v1 (2026-08-28 확정판)

> "제로의 배신" 시리즈 — 패키지 마스코트 자백 포맷.
> 세션·도구와 무관하게 단독으로 재현 가능하도록 작성한 독립 문서.
> 상세 기획 배경: `docs/reports/2026-08-28-reels-pilot-v2-benchmark-format.md`

```
================================================================
ZERO DOT 릴스 제작 플레이북 v1  (2026-08-28 확정판)
"제로의 배신" 시리즈 — 패키지 마스코트 자백 포맷
================================================================

■ 0. 포맷 한 줄 정의
  실제 제품 패키지에 만화 얼굴을 붙인 마스코트가 자기 매대에서
  [잘난척 자기소개 → 들킴/자백] 2비트를 8초간 연기.
  제품 클립 2~3개 + ZERO DOT 엔딩 클립 1개 = 총 24~32초 릴스.

■ 1. 준비물 (편당) — 이미지는 인터넷 수집
  - ① 패키지 정면 이미지 (캐릭터화용):
      우선순위 = 제조사 공식몰/공식 사이트 제품컷 > 편의점몰(CU/GS25 등)
      > 오픈마켓 상세페이지. 조건: 정면 컷, 배경 단순, 가로 1000px 이상,
      워터마크 없는 것 (워터마크가 캐릭터에 그대로 박힘)
  - ② 표시정보 이미지 (영양성분표+원재료명 — 라벨 인서트 컷 + 수치 대조용):
      소스 = 공식몰 상세페이지의 표시정보 캡처, 오픈마켓 상세컷,
      식품안전나라(식약처) 영양성분 DB. 수치가 잘 보이는 캡처로 확보
  - ③ 출처 보관: 사용한 이미지의 URL + 캡처를 편별 폴더에 저장
      (항의·정정 대응용. 온라인 이미지는 촬영자 저작권 이슈가 있을 수 있어
      제조사 공식 이미지를 최우선으로)
  - 제품별 실측 수치 확정 (표시정보 기준. 수치 없이 제작 시작 금지 —
    상세페이지 수치와 DB 수치가 다르면 표시정보 이미지 쪽을 따른다)
  - 도구: Gemini(Nano Banana 이미지) + Google Flow(Veo 3.1) + CapCut
    ※ Flow 팁: 확장(Extend) 메뉴는 "장면에 추가"로 씬빌더에 넣어야 보임.
      단, 확장은 불안정하므로 클립은 전부 독립 생성 후 CapCut에서 이어붙임.

■ 2. 파이프라인 (제품당 ①→②, 마지막에 ③)
  ① Nano Banana: 패키지 사진 첨부 + [템플릿 A] → 마스코트 스틸 생성
     (마음에 들 때까지 재생성. 이미지 단계가 싸므로 여기서 시간 쓸 것)
  ② Veo 3.1 (Flow): 스틸을 "첫 프레임"으로 첨부 + [템플릿 C] → 8초 클립
  ③ 엔딩: ZERO DOT 마스코트 스틸(최초 1회만 [템플릿 B]로 제작, 이후 재사용)
     + [템플릿 D] → 8초 엔딩 클립
  ④ CapCut: 클립 하드컷 연결 + 오버레이 전부 합성 (■7)

  ★ 핵심 원칙 3가지
    1) 한글 텍스트는 절대 AI에게 그리게 하지 않는다.
       패키지 글자 = 실물 사진에서 출발(첫 프레임 방식이라 유지됨).
       자막/수치/타이틀 = 전부 CapCut에서 얹는다.
    2) 구체 수치(31g 등)는 대사에 넣지 않는다. 자막+라벨캡처가 담당.
       (AI 숫자 발음 오류 방지 + 표시정보 인용 원칙)
    3) 폰 화면 등 UI가 나오면 "빛만 나는 상태"로 생성, UI는 편집에서.

■ 3. [템플릿 A] Nano Banana — 패키지 캐릭터화 (패키지 정면 사진 첨부)
  [SETTING]만 제품 매대에 맞게 교체.

----------------------------------------------------------------
Using the attached product package photo, turn this exact package into a cute 3D
mascot character while keeping the package design, colors, proportions and all
printed text EXACTLY as in the photo. Add: two huge glossy cartoon eyes with
thick eyebrows, a wide toothy confident grin, skinny arms with white cartoon
gloves, skinny legs with sneakers. Pixar-style soft 3D render, product-accurate
packaging texture. Place the character standing in [SETTING], bright realistic
lighting, shallow depth of field, 9:16 vertical composition, character centered,
full body visible with headroom for a title box at the top. No extra text, no
watermarks, no other characters.
----------------------------------------------------------------
  [SETTING] 예시:
  - 과자: a Korean convenience store snack aisle with colorful snack bags
    blurred in the background
  - 라면: a Korean convenience store instant noodle aisle with ramyeon
    packages blurred in the background
  - 냉장빵: a Korean convenience store chilled bakery shelf with packaged
    breads blurred in the background
  - 음료: a Korean convenience store drink fridge with bottled drinks
    blurred in the background
  - 아이스크림: inside a Korean convenience store ice cream freezer with
    frosty air and frozen treats blurred in the background
  팁: 끝에 "confident smug expression" / "nervous guilty expression, sweat
  drops"를 붙여 능글/당황 2표정 버전을 뽑아두면 썸네일까지 해결.

■ 4. [템플릿 B] Nano Banana — ZERO DOT 마스코트 (앱 아이콘 첨부, 최초 1회)

----------------------------------------------------------------
Using the attached app icon — a bold dark green number "0" with a small round
green dot at its lower right — turn it into a cute 3D mascot character while
keeping the exact shapes and colors of the icon. The dark green "0" is the body:
add two huge glossy cartoon eyes with confident eyebrows and a bright heroic
smile on the upper front of the "0", skinny arms with white cartoon gloves, and
skinny legs with sneakers (matching the style of product-package mascots). The
small green dot floats next to it like a cute glowing sidekick orb with two tiny
eyes. The mascot holds a smartphone in one hand; the phone screen shows only a
soft glowing green light, no text. Pixar-style soft 3D render. Place the mascot
standing confidently like an inspector in a bright Korean convenience store
snack aisle, shelves blurred in the background, bright realistic lighting,
shallow depth of field, 9:16 vertical composition, full body centered with
headroom at the top. No extra text, no logos other than the icon shapes, no
watermarks.
----------------------------------------------------------------
  확정본은 Flow 캐릭터 자산으로 등록 + 원본 이미지 보관(전 편 재사용).

■ 5. [템플릿 C] Veo 3.1 — 제품 연기 클립 (스틸을 첫 프레임 첨부, 8초, 9:16)
  대괄호만 채워서 사용.

----------------------------------------------------------------
9:16 vertical video, 3D animated mascot, start from the input image and keep the
character's package design and printed text exactly as in the image. IMPORTANT:
absolutely no subtitles, no captions, no added on-screen text, no extra letters
anywhere — dialogue is audio only.

The package mascot stands in [장소, 예: the snack aisle] talking non-stop from
the very first frame. First beat: [잘난척 동작, 예: hands on hips, chest puffed,
grinning], bragging VERY FAST in Korean with a smug energetic voice, saying
"[자랑 대사]" Second beat: [무너지는 동작, 예: its face suddenly falls, eyes dart
sideways, nervous sweat], and it keeps talking fast in a guilty cracking voice,
saying "[자백 대사]"

Camera: static medium-full shot, small punch-in on the brag, slow creep-in on
the confession.

Audio: bright convenience store ambience, a cheerful sting on the brag, record
scratch and tense strings on the confession, the character's voice fast and
expressive with no long pauses.

Remember: NO subtitles, NO captions, NO added text anywhere on screen.
----------------------------------------------------------------

  ● 대사 작성 공식 (이게 품질의 절반)
    - 총 45~55음절 (빠른 발화로 8초 꽉 참. 짧으면 늘여 말해서 느려짐!)
    - 자랑 비트: "난 [제품명]! [제로/저당 자랑]! [건방진 한마디]~!" (2~3문장)
    - 자백 비트: "...근데 사실... [함정 성분/사실]... [멋쩍은 변명]..." (2문장)
    - 제품명은 대사에 넣는다(인식 담당). 수치는 절대 넣지 않는다(자막 담당).
    - 금지어: 속였다/사기/먹지마라 계열. 자백은 항상 "사실 고백" 톤.

  ● 검증된 대사 예시 3종
    쿠앤크 샌드 제로(말티톨 31g):
      자랑 "난 쿠앤크 샌드 제로! 설탕 제로, 당류도 0그램! 다이어트엔 역시 나지~!"
      자백 "...근데 사실... 나 말티톨 범벅이야... 그거 혈당 올리는 당알코올이거든..."
    팔도 비빔면 제로슈거(탄수 67g):
      자랑 "난 팔도 비빔면 제로슈거! 설탕 싹 뺐어! 죄책감 없이 비벼 먹으라구~!"
      자백 "...근데 면은 그대로거든... 탄수화물이 밥 한 공기만큼 있어... 어쩔 수 없잖아..."
    연세 저당 생크림빵(에리스리톨 40g):
      자랑 "난 연세 저당 생크림빵! 당류 확 줄여서 혈당 걱정 없다구~!"
      자백 "...근데 나 에리스리톨 폭탄이라... 많이 먹으면... 화장실 직행일 수도 있어..."

■ 6. [템플릿 D] Veo 3.1 — ZERO DOT 엔딩 클립 (마스코트 스틸 첫 프레임, 8초)

----------------------------------------------------------------
9:16 vertical video, 3D animated mascot, start from the input image and keep the
mascot's dark green "0" body, green dot sidekick, and colors exactly as in the
image. IMPORTANT: absolutely no subtitles, no captions, no added on-screen text,
no extra letters anywhere — dialogue is audio only. The phone screen shows only
a soft glowing green light with no text.

The "0" mascot struts down the convenience store aisle like a confident food
inspector, talking non-stop from the very first frame. First beat: it spins once,
points at the shelves, and says VERY FAST in Korean with a bright heroic
confident voice, saying "라벨은 0이어도, 혈당은 0이 아닐 수 있다구!" Second beat: it
raises the smartphone toward the camera — the phone pulses with a green scanning
glow, the little green dot orb does an excited flip — and the mascot winks and
keeps talking fast, saying "헷갈리면 제로닷! 스캔 한 번이면 3초 만에 끝! 출시 알림
눌러줘~!"

Camera: smooth push-in following the strut, quick punch-in when the phone is
raised toward the camera, ending on a medium close-up of the mascot and the
glowing phone.

Audio: bright store ambience, an upbeat heroic jingle building through the clip,
a satisfying "ding" chime when the phone glows, the mascot's voice fast, cheerful
and confident with no long pauses.

Remember: NO subtitles, NO captions, NO added text anywhere on screen, and no
text on the phone screen.
----------------------------------------------------------------
  ※ 앱 출시 후에는 CTA 대사를 "지금 다운로드해서 찍어봐~!"로 교체.

■ 7. CapCut 합성 스펙 (오버레이는 전부 여기서)
  레이어              내용                                        타이밍
  --------------------------------------------------------------------
  타이틀 박스        흰 배경+빨간 굵은 글씨, 상단 고정            전 구간
                     예: "제로라며… 몸은 아니래요 TOP 3 (N편)"
  필박스 자막        검은 라운드 박스+흰 굵은 글씨, 중하단        대사 싱크
                     자기소개→자백 순서로 교체
  신호등 스캔카드    흰 카드: 제품 실사진+이름/브랜드              제품 시작 1.5초
                     +ZERO DOT 신호등 판정+"자체 룰북 기준"
  라벨 캡처          확보한 표시정보 이미지 + 수치에 빨간 동그라미 자백 비트
  수치 자막          예: "당류 0g / 말티톨 31g"                    자백 비트
  파티클             설탕가루 낙하 등 (CapCut 이펙트)              자백 비트
  엔딩 CTA           판정 카드 + 앱 아이콘                        엔딩 클립
                     + "제로닷 — 출시 알림은 프로필 링크"
  고정 표기          "출처: 제품 표시정보" + AI 생성 콘텐츠 표기   전 구간 하단

■ 8. 트러블슈팅 (실전에서 검증된 순서)
  - 화면에 깨진 자막이 생김 → 프롬프트 수정 말고 같은 프롬프트 재생성 2~3회
    (억제 지시가 앞뒤로 있어도 확률적으로 뚫림. 재생성이 제일 빠름)
  - 말이 느림/처짐 → 대사를 더 길게 (짧은 대사가 원인). 최후엔 CapCut
    1.1~1.15배속(음정 유지 켜기)
  - 한국어 발음 이상 → 재생성 2~3회. 특히 서비스명("제로닷") 확인
  - 대사가 8초에 잘림 → 각 비트의 마지막 문장부터 삭제
  - 캐릭터가 스틸과 달라짐 → 첫 프레임 방식인지 확인(재료 첨부보다 강력),
    프롬프트에 "keep ... exactly as in the image" 유지
  - 모델 선택: 시안은 Veo 3.1 Fast(비용 1/4), 최종만 Quality 재생성.
    Flow @캐릭터 기능이 Quality에서 안 되면 이미지 직접 첨부로 우회

■ 9. 발행 전 체크리스트
  □ 수치가 표시정보 이미지와 일치 (이미지 URL+캡처 출처 폴더 보관)
  □ 대사·자막에 금지어 없음 (속였다/사기/먹지마라 → "라벨은 0, 혈당은 0이
    아니에요" 프레임으로)
  □ 판정 표기에 "자체 룰북 기준" 포함
  □ "출처: 제품 표시정보" + AI 생성 표기 포함
  □ 브랜드 분산 확인 (한 편에 같은 브랜드 몰빵 금지)
  □ 프로필 링크 UTM 확인 (utm_source=instagram&utm_medium=reels&
    utm_campaign=pilot1)
  □ 발행: 화/금 18시. 편별 기록: 3초 유지율/조회수/프로필 방문/링크 클릭
  □ 실험은 한 번에 1변수만 (훅과 썸네일 동시 변경 금지)

■ 10. 리스크 메모
  - 실제 패키지 사용은 상표권 리스크를 인지하고 감수한 결정(2026-08-28).
    완충: 표시정보 실측만 인용, 비방어 금지, 24시간 정정 프로토콜, AI 표기
  - 설사 등 부작용 언급은 라벨 의무 표시 문구("과량 섭취 시 설사를 유발할 수
    있습니다") 인용으로만, 혈당 무해 등 균형 정보 병기
================================================================
```
