# 릴스 파일럿 기획 v2 — 레퍼런스 완전 벤치마킹 포맷 (2026-08-28)

> 기존 `2026-08-27-reels-a1-production-guide.md`(취조실 콘셉트)를 **대체**한다.
> 레퍼런스: Unlabel(@ggabalggabal) "대기업이 속인 제품들 TOP 4 (2편)" 실영상을
> 프레임 단위로 분석해 포맷을 역설계했고, 이를 ZERO DOT 버전으로 재구성한다.
> 결정사항(홍범, 2026-08-28): ① 캐릭터는 실제 패키지 그대로 + 얼굴 (상표권
> 리스크 감수, 언라벨 방식) ② 캐릭터가 직접 한국어로 말함.

## 1. 레퍼런스 스타일 공식 (프레임 분석 결과)

| 요소 | 관찰 내용 |
|---|---|
| 캐릭터 | **실제 제품 패키지 그대로**에 만화 얼굴 합성: 크고 광택 있는 눈, 굵은 눈썹, 이빨 보이는 함박웃음(능글/악당톤), 가는 팔 + 흰 장갑, 운동화. 패키지 텍스트·디자인 원본 유지 |
| 배경 | 제품의 "서식지" — 과자 매대, 냉동고 안, 냉장 코너 등 **밝고 현실적인 편의점/마트**, 얕은 심도 |
| 구조 | 제품당 ~8초 × 4제품: ①능글맞은 1인칭 자기소개("난 ○○야!") → ②들킴/자백("나 근데 농축액이라...") |
| 오버레이(전부 편집) | 상단 고정: 흰 배경+빨간 글씨 타이틀 박스 / 중하단: 검은 라운드 필박스+흰 굵은 자막(1인칭) / 제품 전환 시: **앱 스캔 결과 카드**(제품 실사진+이름+브랜드+점수 링) / 자백 비트: **실제 라벨 표시정보 캡처 + 빨간 동그라미** 강조 |
| 효과 | 자백 비트에 설탕가루 파티클(눈처럼 내림), 캐릭터 표정 능글→당황 |
| 엔딩 | 캐릭터가 스마트폰을 들어 앱스토어 화면 노출 + "첨가물 스캐너 앱 ○○!" |
| 오디오 | 캐릭터 육성 대사 (사용자 확인) |

핵심 통찰: **영상 생성 AI가 하는 일은 "패키지+얼굴 캐릭터의 연기" 하나뿐.**
타이틀·자막·스캔카드·라벨캡처·파티클 상당수는 편집 레이어다. 실감의 반은
"실제 패키지"에서, 나머지 반은 "실제 라벨 캡처 인서트"에서 나온다.

## 2. ZERO DOT 버전 차별화

- 스캔 카드 → **ZERO DOT 혈당 신호등 판정 카드** (제품 실사진 + 🔴/🟡 등급 + "자체 룰북 기준" 표기)
- 타이틀 박스 문구 → 비방어 회피: ~~"대기업이 속인"~~ → **「제로라며… 몸은 아니래요 TOP 3 (1편)」** (흰 배경 + 빨간 글씨는 레퍼런스 그대로 — 검증된 어그로 요소)
- 모든 수치는 표시정보 실측(자체 DB) + 「출처: 제품 표시정보」 고정 + AI 생성 표기
- 엔딩: 앱 아이콘("0.")을 마스코트화한 **ZERO DOT 캐릭터 8초 엔딩 클립**(§5-1, §6 클립 4) — 전 편 재사용 브랜드 자산. 앱 미출시이므로 CTA는 "출시 알림은 프로필 링크"

## 3. 제품 3종 선정 (Supabase DB 실측, 2026-08-28 조회)

| # | 콘셉트 | 제품 | 실측 수치 (표시정보 기준) | 서사 |
|---|---|---|---|---|
| 1 | 말티톨 함정 | **쿠앤크 샌드 제로** (롯데) | 당류 0g / **D-말티톨 31g** / 탄수 65g (96g) | "당류 0!" → "…말티톨이 좀 많아" |
| 2 | 순탄수 함정 | **팔도 비빔면 제로슈거** (팔도) | 당류 0g / **탄수화물 67g** / 470kcal (120g) | "설탕 다 뺐다!" → "…면은 그대로야" (탄수 67g ≈ 흰밥 한 공기, 환산 표기) |
| 3 | 당알코올 폭탄(설사) | **연세 저당 생크림빵** (연세) | 당류 5g / **에리스리톨 40g** (128g) | "혈당엔 착해!" → "…많이 먹으면 배가 부글부글" |

- 선정 원칙: 콘셉트별 1개 + **브랜드 분산**(롯데/팔도/연세 — 한 브랜드 집중 항의 리스크 회피) + 인지도(비빔면·연세빵은 편의점 히트상품)
- #3 방어 근거: 당알코올 10% 이상 함유 식품은 **"과량 섭취 시 설사를 유발할 수 있습니다" 표시가 라벨에 실제로 있음**(식품 표시기준 의무 문구) → "라벨에도 써 있어요" 프레임으로 비방 아닌 정보 전달. 혈당엔 무해(에리스리톨)라고 명시해 균형톤 확보 = 브리프의 "의외로 무죄" 실험을 겸함
- 예비 후보(리테이크/2편용): 제로 캔디 3종(롯데, 말티톨 28g/봉), 딥앤로우 크림커피바(빙그레, 에리스리톨 30g), PBICK 저당 사브레(당알코올 40.5g, 라벨 경고문구 확인됨), 나랑드 콤부차(동아, 말티톨 26g)
- **발행 전 필수**: 3개 제품의 패키지 정면·표시정보 이미지를 온라인에서 확보(공식몰 우선) → 수치 대조 + 이미지 URL·캡처 출처 폴더 보관 (2026-08-28 변경: 실물 구매 대신 온라인 수집)

## 4. 제작 파이프라인 (제품당 반복)

```
[준비] 온라인 이미지 수집 → ① 패키지 정면 컷(공식몰 우선) ② 표시정보 캡처(영양+원재료)
  ↓
Nano Banana(Gemini 이미지): 패키지 사진 첨부 + 캐릭터화 프롬프트(§5)
  → 매대 배경 + 얼굴·팔다리 붙은 캐릭터 스틸 생성 (마음에 들 때까지, 저비용)
  ↓
Flow / Veo 3.1: 캐릭터 스틸을 "첫 프레임"(프레임→동영상) 또는 재료로 첨부
  + 연기 프롬프트(§6) → 8초 클립 생성
  ↓
CapCut 합성(§7): 타이틀 박스 / 필박스 자막 / 신호등 스캔카드 / 라벨 캡처+빨간 원
  / 파티클 / 엔딩 CTA / 출처·AI 표기
```

왜 이미지 먼저인가: **패키지의 한글 텍스트를 Veo가 프롬프트만으로 그리면 반드시
깨진다.** 실제 패키지 사진을 Nano Banana로 캐릭터화(원본 픽셀 유지·변형)하고,
그 결과 이미지를 Veo의 시작 프레임으로 주면 텍스트가 원본에서 이어져 유지된다.
자막 억제 원칙(무자막 생성 + 편집에서 얹기)은 그대로.

## 5. Nano Banana 캐릭터화 프롬프트 (패키지 사진 첨부 후)

공용 템플릿 — [SETTING]만 제품별 교체:

```
Using the attached product package photo, turn this exact package into a cute 3D
mascot character while keeping the package design, colors, proportions and all
printed text EXACTLY as in the photo. Add: two huge glossy cartoon eyes with
thick eyebrows, a wide toothy confident grin, skinny arms with white cartoon
gloves, skinny legs with sneakers. Pixar-style soft 3D render, product-accurate
packaging texture. Place the character standing in [SETTING], bright realistic
lighting, shallow depth of field, 9:16 vertical composition, character centered,
full body visible with headroom for a title box at the top. No extra text, no
watermarks, no other characters.
```

- #1 쿠앤크: `[SETTING]` = "a Korean convenience store snack aisle with colorful snack bags blurred in the background"
- #2 비빔면: `[SETTING]` = "a Korean convenience store instant noodle aisle with ramyeon packages blurred in the background"
- #3 생크림빵: `[SETTING]` = "a Korean convenience store chilled bakery shelf with packaged breads blurred in the background"
- 표정 변형: 같은 프롬프트 끝에 "confident smug expression" / "nervous guilty expression, sweat drops" 두 버전을 뽑아두면 Veo 연기 유도와 썸네일에 모두 사용 가능

### 5-1. ZERO DOT 마스코트화 (엔딩용, 앱 아이콘 이미지 첨부 — 전 편 엔딩 재사용 자산)

아이콘 사진은 Veo에 직접 넣지 않고 이 단계에 넣는다(브랜드 색·형태 픽셀 유지).
폰 화면은 "초록 빛만"으로 생성 — UI 텍스트는 AI가 깨뜨리므로 편집에서 판정 카드를 얹는다.

```
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
```

## 6. Veo 3.1 연기 프롬프트 (캐릭터 스틸을 첫 프레임으로 첨부, 각 8초, 9:16)

> **대사 밀도 (v2.1)**: 레퍼런스는 8초 내내 쉼 없이 떠드는 구성 + Veo는 대사가
> 짧으면 늘여 말해 느려짐 → 대사를 8초 꽉 차게(빠른 발화 기준 45~55음절) 작성하고
> "talking non-stop from the very first frame / no long pauses"로 강제.
> 안 붙으면 각 비트 마지막 문장부터 삭제. 수치는 여전히 대사 금지(자막 담당).

공통 앞머리(자막 억제) — 세 클립 모두 동일:

```
9:16 vertical video, 3D animated mascot, start from the input image and keep the
character's package design and printed text exactly as in the image. IMPORTANT:
absolutely no subtitles, no captions, no added on-screen text, no extra letters
anywhere — dialogue is audio only.
```

### 클립 1 — 쿠앤크 샌드 제로 (말티톨)

```
[공통 앞머리]

The package mascot stands in the snack aisle talking non-stop from the very
first frame. First beat: hands on hips, chest puffed, grinning, bragging VERY
FAST in Korean with a smug energetic voice, saying "난 쿠앤크 샌드 제로! 설탕 제로,
당류도 0그램! 다이어트엔 역시 나지~!" Second beat: its face suddenly falls, eyes
dart sideways, nervous sweat, shoulders shrinking, and it keeps talking fast in
a guilty cracking voice, saying "...근데 사실... 나 말티톨 범벅이야... 그거 혈당
올리는 당알코올이거든..."

Camera: static medium-full shot, small punch-in when the bragging line lands,
slight handheld feel.

Audio: bright convenience store ambience, a cheerful sting on the brag, record
scratch and tense strings on the confession, the character's voice fast and
expressive.

Remember: NO subtitles, NO captions, NO added text anywhere on screen.
```

### 클립 2 — 팔도 비빔면 제로슈거 (순탄수)

```
[공통 앞머리]

The package mascot stands in the instant noodle aisle talking non-stop from the
very first frame. First beat: arms crossed like a tough guy, smirking, then
flexing, shouting VERY FAST in Korean with a proud punchy voice, saying "난 팔도
비빔면 제로슈거! 설탕 싹 뺐어! 죄책감 없이 비벼 먹으라구~!" Second beat: it freezes,
eyes widen, glances left and right, and keeps talking fast in a deflating
embarrassed voice, saying "...근데 면은 그대로거든... 탄수화물이 밥 한 공기만큼
있어... 어쩔 수 없잖아..."

Camera: static medium-full shot, quick punch-in on the flex, slight handheld
feel.

Audio: bright store ambience, a confident brass sting on the brag, awkward
silence beat then tense strings on the confession, the character's voice fast
and expressive.

Remember: NO subtitles, NO captions, NO added text anywhere on screen.
```

### 클립 3 — 연세 저당 생크림빵 (당알코올·설사)

```
[공통 앞머리]

The soft bread package mascot stands by the chilled bakery shelf talking
non-stop from the very first frame. First beat: doing a cute proud little dance,
smiling sweetly, saying VERY FAST in Korean with an adorable confident voice,
"난 연세 저당 생크림빵! 당류 확 줄여서 혈당 걱정 없다구~!" Second beat: it abruptly
stops dancing, clutches its belly with both gloved hands, cheeks puffed, eyes
darting in panic, and keeps talking fast in an embarrassed whisper, saying
"...근데 나 에리스리톨 폭탄이라... 많이 먹으면... 화장실 직행일 수도 있어..."

Camera: static medium-full shot, gentle bounce with the dance, quick punch-in
when it clutches its belly.

Audio: bright store ambience, cute playful jingle on the intro, comedic bubbling
stomach gurgle sound and a record scratch on the confession, the character's
voice fast and expressive.

Remember: NO subtitles, NO captions, NO added text anywhere on screen.
```

### 클립 4 — ZERO DOT 엔딩 (해결사 등장, 유일하게 무너지지 않는 캐릭터)

```
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
```

- 구조 의도: 앞 3클립은 "능글→자백"으로 무너지고, 엔딩만 무너지지 않는 해결사
  (우리 마스코트) — 대비로 마무리. 시그니처 서사를 마스코트 첫 대사에 배치
- "제로닷" 발음이 이상하면 해당 컷만 2~3회 재생성

## 7. CapCut 합성 스펙 (레퍼런스 오버레이 재현)

| 레이어 | 스펙 | 타이밍 |
|---|---|---|
| 타이틀 박스 | 흰 배경 + 빨간 굵은 글씨, 상단 고정: 「제로라며… 몸은 아니래요 TOP 3 (1편)」 | 전 구간 |
| 필박스 자막 | 검은 라운드 박스 + 흰 굵은 글씨, 중하단. 자기소개("난 쿠앤크 샌드 제로야!") → 자백("근데 말티톨 31g…") 순서로 교체 | 대사 싱크 |
| 신호등 스캔카드 | 흰 카드: 제품 실사진 + 이름/브랜드 + ZERO DOT 신호등(🔴 주의 등) + "자체 룰북 기준" 소문구 | 각 제품 시작 1.5초 |
| 라벨 캡처 | 직접 촬영한 표시정보 캡처 + 해당 수치에 빨간 동그라미 (쿠앤크: 당알코올 31g / 비빔면: 탄수 67g / 연세빵: 에리스리톨 40g + "과량 섭취 시 설사" 문구) | 각 자백 비트 |
| 수치 자막 | 「당류 0g / 말티톨 31g」「당류 0g / 탄수 67g ≈ 흰밥 한 공기」「에리스리톨 40g / 혈당엔 무해」 | 자백 비트 |
| 파티클 | 설탕가루 낙하 효과 (CapCut 이펙트) | 자백 비트 |
| 엔딩 CTA | 클립 4 위에: 폰 상승 순간 신호등 판정 카드(쿠앤크 🔴 재사용) + 마지막 2초 앱 아이콘·「제로닷 — 출시 알림은 프로필 링크」 라임 박스 | 클립 4 |
| 고정 표기 | 「출처: 제품 표시정보」 + AI 생성 콘텐츠 표기 | 전 구간 하단 |

## 8. 리스크 기록 (v2 결정 반영)

- **패키지 그대로 사용은 상표권(트레이드 드레스) 리스크를 인지하고 감수하는 결정**(2026-08-28, 홍범). 완충 장치: 수치는 표시정보 실측만 인용, 비방 단정어("속인/사기") 미사용, 판정은 "자체 룰북 기준" 명시, 브랜드 항의 시 24시간 정정 프로토콜, 브랜드 분산(롯데/팔도/연세), AI 생성 표기
- #3 설사 언급은 라벨 의무 표시 문구 인용으로만 — "라벨에도 써 있어요" + 혈당 무해 병기(균형)

## 9. 다음 액션

- [ ] 3개 제품 실물 구매 + 패키지 정면·표시정보 접사 촬영
- [ ] Nano Banana 캐릭터화 (제품당 능글/당황 2표정)
- [ ] Veo 클립 3개 생성 (§6)
- [ ] ZERO DOT 신호등 스캔카드 목업 3장 제작
- [ ] CapCut 합성 → 발행 (화/금 18시), 지표 4개 기록
