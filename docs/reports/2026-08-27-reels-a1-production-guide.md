# 릴스 A-1편 「쿠앤크 샌드 제로」 제작 가이드 — AI 도구 선정 + 프롬프트 (2026-08-27)

> ZERO DOT 인스타그램 마케팅 실행 브리프(v1)의 "이번 주 실행 순서 3번: A-1편 제작"을 위한 실무 문서.
> 2026년 8월 현재 기준 영상 생성 AI 조사 결과와, 실제 투입용 프롬프트 전문을 담는다.

---

## 1. 결론: **Veo 3.1 (Google/Gemini 생태계)** 를 메인으로 추천

사용자가 검토 요청한 "Gemini 사용 방안"이 실제로 현재 최적안이다. 이유:

| 요구사항 (브리프 기준) | Veo 3.1 대응 |
|---|---|
| 한국어 대사 ("저 제로예요") | **한국어 포함 8개 언어 립싱크 네이티브 지원.** 대사·효과음·앰비언스를 영상과 동시 생성 (별도 TTS/립싱크 툴 불필요) |
| 인스타 릴스 세로형 | **9:16 네이티브 생성** (16:9 크롭 아님) |
| 전 편 캐릭터 일관성 ("스타일 프롬프트 1개 확정 후 재사용") | **레퍼런스 이미지 최대 3장** 입력으로 캐릭터 고정. Nano Banana(Gemini 이미지 모델)로 캐릭터 시트 1회 생성 → 8편 내내 재사용 |
| 15~30초 릴스 | 8초/클립 → 3클립 편집 or Flow의 씬 확장(extend) 기능 |
| 제작 단가 | Veo 3.1: $0.40/초(오디오 포함 1080p), Veo 3.1 Fast: $0.10/초(720p 시안용). 8초 클립 1개 ≈ $3.2 → **리테이크 포함 편당 대략 $20~40** |

### 접근 경로 (셋 중 택1)
1. **Google Flow** (flow.google) — Google AI Pro 구독(월 $19.99대)에 포함. 씬 확장·레퍼런스 이미지 UI 제공. **파일럿 8편에는 이걸 추천** (구독 1개로 Nano Banana + Veo 둘 다 커버, 종량 과금 리스크 없음)
2. **Gemini 앱** — 가장 간단하지만 세부 제어(레퍼런스 3장, 씬 확장)가 제한적
3. **Gemini API** (`veo-3.1`) — 나중에 제작을 자동화(스크립트화)할 때

### 차선/보조: Kling 3.0
- 강점: **~$0.10/초로 4~7배 저렴**, 15초 단일 클립(컷 편집 감소), 다국어 립싱크 우수, 모션 사실감 높음
- 용도: 시안 대량 실험(훅 A/B), 예산 절약 모드, Veo 결과 불만족 시 플랜 B
- 이 문서의 프롬프트는 Kling에 그대로 넣어도 동작하도록 작성됨

### 제외
- **Sora 2 (OpenAI)**: 2026-04 앱 서비스 종료, 2026-09 API 종료 예정 — 8주 파일럿의 기반으로 부적합
- **Runway Gen-4.5**: 제어력은 최고지만 가격·복잡도 대비 이 포맷(짧은 캐릭터 릴스)에 과함

---

## 2. 제작 파이프라인 (편당 반나절)

```
[1회만] Nano Banana로 캐릭터 시트 생성 → 확정본 3장 보관 (전 편 공용)
   ↓
Veo 3.1 (Flow): 레퍼런스 이미지 첨부 + 클립 프롬프트 3개 → 8초 × 3클립 생성
   ↓
CapCut(또는 VN): 클립 연결 + 수치 자막 + 타이틀 박스 + 출처 문구 + AI 표기
   ↓
인스타 발행 (화/금 18시)
```

**철칙: 숫자·한글 텍스트는 영상 AI에게 맡기지 않는다.**
- AI는 한글 자막을 자주 틀리게 렌더링하고, 수치가 왜곡되면 브리프 8번(리스크 가드레일)의 "표시정보 수치 인용" 방어선이 무너진다.
- 따라서 모든 프롬프트에 "no on-screen text, no subtitles"를 넣고, **수치 자막("말티톨 31g")·타이틀 박스·출처 문구는 전부 후반 편집에서 얹는다.** 앱 팔레트(그린 #0FA678 / 라임 #C9F158 / 딥 잉크)도 편집 단계에서 적용.

**발행 전 체크**: 말티톨 31g / 당류 0g / 탄수 65g 수치는 브리프 값이다. 실제 제품 표시정보 캡처와 대조 후 캡처를 출처 폴더에 보관할 것 (체크리스트 5번 항목).

---

## 3. 제품 인식(실감) 전략 — 캐릭터 혼자 책임지지 않는다 (2026-08-27 v2 수정)

**문제**: 1차 캐릭터 시트가 실제 제품과 너무 달라 "그 제품"이라는 실감이 없음.
원인 진단 — ① 1차 프롬프트가 "아이스크림 샌드"로 잘못 설정됨 (실제 제품은 **검은
코코아 쿠키 샌드 과자**), ② 상표권 가드레일 때문에 캐릭터를 변형하는 이상, 캐릭터
단독으로는 어떤 경우에도 제품 특정이 안 됨. 벤치마크 Unlabel도 캐릭터가 아니라
**자막("난 bhc야!")으로 이름을 박아서** 인식을 해결했다.

**해결: 인식 3겹 구조** — 리스크는 "패키지·로고를 그대로 본뜬 비주얼"과 "비방 단정
표현"에 있지, 제품명을 사실 적시로 부르는 것에 있지 않다 (시리즈 소재표 자체가
실명 기반이고, 출처 표기도 제품 특정을 전제로 함).

| 겹 | 수단 | 리스크 |
|---|---|---|
| ① 텍스트 | 타이틀 박스에 제품명 명시: 「제로의 배신 ①편 \| 쿠앤크 샌드 제로 (롯데)」 — 첫 프레임부터 고정. Unlabel 공식과 동일 | 사실 적시 + 표시정보 인용 → 안전 |
| ② 실물 인서트 | **제품을 직접 구매해 촬영한 실물 컷 1~2초** (영양성분표 클로즈업)를 반전 구간에 삽입. 수치 방어(출처 캡처)와 실감을 동시에 해결 | 정보 제공 목적 실물 촬영 → 통용. 출처 폴더 보관용 캡처와 동일 소스 |
| ③ 캐릭터 근접화 | 캐릭터를 실제 형태(검은 코코아 쿠키 + 흰 크림 샌드)에 가깝게 재설계. 단, 쿠키 표면의 "ZERO" 각인·패키지(크림색 상자)·로고는 금지 — 원형 검은 샌드 쿠키 형태 자체는 여러 브랜드가 공유하는 일반형이라 사용 가능 | 각인·패키지만 피하면 안전 |

## 3-1. 캐릭터 시트 프롬프트 v2 (Nano Banana / Gemini 이미지 — 1회 생성 후 전 편 재사용)

콘셉트: "제로수사대" 취조실에 앉은 **의인화 검은 코코아 샌드 쿠키** 캐릭터.
얼굴은 검은 쿠키 앞면에, 흰 크림이 옆면으로 보이는 구조 — 실제 제품의 쿠키 실물과
같은 형태이되, "ZERO" 각인·로고·패키지는 없음.

```
A character design sheet of a cute 3D-animated anthropomorphized chocolate sandwich
cookie character, shaped exactly like a classic round black cocoa sandwich cookie:
two nearly-black dark cocoa biscuits with a thick layer of smooth white vanilla
cream filling clearly visible between them from the side. The character's face is
on the front black biscuit — oversized nervous glossy eyes and a worried mouth.
The biscuit surface has a subtle generic embossed dot-and-ring pattern (no letters,
no words). Crumbly matte cookie texture. Stubby little cookie arms and legs, tiny
beads of sweat on its forehead. Sitting posture and standing posture, front view,
three-quarter view, and side view showing the white cream layer. Pixar-style soft
3D render, soft studio lighting. Plain deep ink-blue background (#1A2340).
No logos, no brand markings, no packaging, no text anywhere. Character sheet
layout, consistent proportions across all views.
```

- 결과물 중 마음에 드는 **3장(정면/측면/앉은 자세)을 확정본으로 저장** → 이후 모든 Veo 생성에 레퍼런스로 첨부.
- 측면 뷰에서 **흰 크림 층이 뚜렷하게 보이는 컷**을 반드시 포함할 것 — "쿠앤크"임을 시각적으로 말해주는 핵심 단서.
- 이 시트는 A-2편(나랑드 콤부차) 제작 시 "캔 음료 캐릭터" 버전으로 같은 문장 구조만 바꿔 재사용.

---

## 4. Veo 3.1 클립 프롬프트 (8초 × 3클립, 9:16)

공통 설정: 세로 9:16, 오디오 생성 ON, 캐릭터 레퍼런스 이미지 3장 첨부.
프롬프트 본문은 영어(모델 이해도 최적), **대사만 한국어**로 따옴표 안에 지정.

### 클립 1 — 훅 (릴스 0~8초): 억울한 항변 (v3 — 빠른 템포·고양된 목소리)

> v2까지의 "겁먹은 소곤 자백" 톤은 시네마틱하나 3초 훅이 약해 폐기.
> 연기 방향 = **"억울해서 따지는 항변"**: 템포·성량이 올라가고 클립 2 반전이 세짐.
> Veo 템포 3원칙: ① 대사를 길고 잘게 쪼갠 문장으로(짧으면 8초에 맞춰 늘여 말해 느려짐)
> ② 말하기 지시 대문자 강조(VERY FAST) ③ "영상이 대사 중간부터 즉시 시작" 명시.

```
9:16 vertical video. Pixar-style soft 3D animation. A dim police interrogation
room with a single harsh overhead lamp, deep ink-blue walls, subtle green rim
light. A cute anthropomorphized black cocoa sandwich cookie character (match the
reference images exactly). The video starts INSTANTLY mid-argument — no slow
build-up, no pause before speaking. The character slams its stubby arms on the
metal table, leans in toward the camera, worked up and indignant, and speaks
VERY FAST in Korean with a raised, defensive, almost shouting voice, words
tumbling out: "아니, 저 진짜 제로라니까요?! 라벨 보세요, 라벨! 당류 0그램! 빵이에요 빵!
뭐가 문제냐고요!"

Camera: fast snap zoom-in to a close-up as it slams the table, slight handheld
shake, punchy high-energy cuts.

Audio: a loud slam of hands on the metal table at the very first frame, a punchy
dramatic hit, fast tense percussion driving underneath, the character's voice
loud, rapid, agitated and slightly squeaky.

No on-screen text, no subtitles, no captions, no logos, no real product packaging.
```

> Flow에서는 캐릭터 묘사 문장 대신 `@쿠앤크` 태그 사용.

> 편집 단계: **첫 프레임부터** 상단 타이틀 박스(그린 #0FA678) 고정 —
> 「제로의 배신 ①편 | 쿠앤크 샌드 제로 (롯데)」. 제품 인식은 이 텍스트가 책임진다 (§3 ①겹).

### 클립 2 — 반전·자백 (릴스 8~16초): 실물 인서트 + 수치 자막이 얹힐 구간

```
9:16 vertical video. Pixar-style soft 3D animation. Same dim interrogation room,
same cute anthropomorphized black cocoa sandwich cookie character (match the
reference images exactly). The character is still riled up, arms crossed
defiantly — then a manila document folder is SLAMMED onto the table from
off-screen. The character flinches hard, freezes for half a second, eyes darting,
then breaks down and blurts out VERY FAST in Korean, voice cracking from defiant
to panicked, almost wailing: "아니 그게... 그러니까 그게요... 말티톨! 말티톨이 잔뜩
들어있긴 한데... 그래도 당류는 0이잖아요!!"

Camera: quick dramatic whip-zoom to a tight close-up on the character's panicking
face, slight dutch angle, handheld shake.

Audio: a sharp slam when the folder hits the table, dramatic sting, fast tense
strings, the character's voice rapid, high-pitched and cracking.

No on-screen text, no subtitles, no captions, no logos, no real product packaging.
```

> 편집 단계 (인식 ②겹의 핵심):
> 1. 자백 대사 직후, **직접 구매해 촬영한 실물 영양성분표 클로즈업 컷 1~2초 삽입**
>    (말티톨 31g 표기 부분을 라임 #C9F158 박스로 강조). "그 제품"이라는 실감과
>    수치 방어(출처 캡처)를 이 한 컷이 동시에 해결한다.
> 2. 실물 컷과 캐릭터 컷 위에 큰 자막 **「당류 0g / 말티톨 31g / 탄수화물 65g」**
>    + 「출처: 제품 표시정보」 고정 표기.

### 클립 3 — 해설 + CTA (릴스 16~24초)

```
9:16 vertical video. Pixar-style soft 3D animation. Same interrogation room, now
slightly brighter and calmer. The cute black cocoa sandwich cookie
character (match the reference images exactly) sits with its head hung low in
resignation. A rubber stamp comes down from off-screen onto the document folder
on the table with a satisfying thunk. The character sighs and shrugs at the camera
as if to say "sorry".

Camera: static medium shot, then a gentle slow zoom toward the stamped folder.

A calm, confident male detective voice narrates off-screen in Korean: "말티톨은
혈당을 올리는 당알코올이에요. 라벨은 0이어도, 혈당은 0이 아닐 수 있어요."

Audio: the thunk of the stamp, papers shuffling, light minimal background music
turning from tense to resolved.

No on-screen text, no subtitles, no captions, no logos, no real product packaging.
```

> 편집 단계: 마지막 2~3초에 CTA 자막 **「스캔하면 3초 만에 알려드려요 — 출시 알림은 프로필 링크」** + 라임(#C9F158) 타이틀 박스. AI 생성 콘텐츠 표기 포함.

### 대사 설계 노트 (가드레일 반영)
- 캐릭터 자백은 "말티톨이 들어있어요"까지만 — **구체 수치(31g)는 검증된 자막으로만 표기** (AI 음성이 숫자를 잘못 발음하는 리스크 차단 + 표시정보 인용 원칙 유지)
- "속였다/사기" 계열 표현 없음. 프레임은 시그니처 서사 "라벨은 0, 혈당은 0이 아니에요" 그대로 (클립 3 내레이션에 삽입)
- 캐릭터는 일반형 쿠키앤크림 샌드 — 특정 패키지 식별 불가 수준 유지

---

## 5. 생성 팁 (리테이크 절약)

1. **클립 1부터 확정하고 진행** — 캐릭터 톤이 맘에 들면 그 결과의 마지막 프레임을 클립 2의 시작 이미지(first frame)로 넣으면 연속성이 더 좋아짐 (Flow의 extend 기능이 이걸 자동으로 해줌)
2. 시안은 **Veo 3.1 Fast**($0.10/초)로 3~4개 뽑아 훅 연기 톤을 고른 뒤, 확정 프롬프트만 **Veo 3.1 표준**으로 재생성
3. 대사가 8초에 안 붙으면 대사를 한 문장으로 줄이는 게 정답 (말 빠르기 조절 지시는 잘 안 먹음)
4. 한국어 발음이 어색한 컷이 나오면: 같은 프롬프트 재생성 2~3회가 프롬프트 수정보다 빠름
5. **템포가 느릴 때** (v3 반영): ① 같은 프롬프트 재생성 2~3회(연기 편차 큼) →
   ② 대사를 더 길게 쪼개기(대사가 길수록 말이 빨라짐) → ③ 최후 수단: CapCut에서
   1.1~1.15배속(음정 유지 옵션 필수). 클립 3 내레이션은 의도적으로 차분하게 유지 —
   앞의 소란과 톤 대비로 핵심 문장("라벨은 0이어도...")이 더 박힘
5. A-2편(나랑드 콤부차)은 이 프롬프트 3개에서 캐릭터 묘사와 대사만 교체 — 브리프의 "1변수 원칙(훅 문구만 변경)" 유지

## 5-1. Google Flow 실행 순서 (2026-08-28 추가 — 캐릭터 등록 완료 상태 기준)

1. **생성 설정**: 입력창 설정(슬라이더 아이콘) → 모델 시안은 Veo 3.1 Fast /
   최종본만 Quality, **화면비 9:16으로 변경(기본 16:9 주의)**, 출력 개수 2
2. **캐릭터 연결**: 프롬프트에 `@쿠앤크` 태그 (등록된 캐릭터 자산 호출 = 레퍼런스
   첨부). @태그를 쓰면 프롬프트의 캐릭터 외형 묘사 문장은 생략
3. **클립 1 생성** (§4 프롬프트, 캐릭터 묘사 대신 @쿠앤크) → 2안 비교, 한국어
   발음 어색하면 같은 프롬프트 재생성 2~3회 → Fast로 톤 확정 후 Quality 재생성
4. **클립 2·3**: 확정 클립의 "확장(Extend)"으로 이어받기 (조명·위치 연속성 유지).
   확장이 어색하면 @쿠앤크 + 새 생성도 무방. 클립 1 마지막 프레임을 이미지로
   저장해 클립 2의 첫 프레임으로 지정하면 연속성 최상
5. **씬빌더**: 클립 1→2→3 타임라인 배열·미리보기만 (정밀 편집은 CapCut)
6. **1080p 다운로드** → CapCut 합성 (§4 편집 단계 지시 참조)
- 크레딧: 오른쪽 조수 패널에 "생성 비용에 대해 알려 줘"로 구독 크레딧 소모율
  먼저 확인. 대사는 따옴표 안에 클립당 한 문장만.

## 6. 이번 주 남은 작업과의 연결

- [ ] Nano Banana 캐릭터 시트 v2 생성 (§3-1) → 확정 3장 보관 (체크리스트 "캐릭터 스타일 프롬프트 확정" 충족)
- [ ] **제품 실물 구매 + 영양성분표 접사 촬영** (인서트 컷 겸 출처 캡처, 말티톨 31g 수치 대조)
- [ ] Veo 3.1로 클립 1~3 생성 (본 문서 §4)
- [ ] CapCut 합성: 수치 자막·타이틀 박스(팔레트)·출처 문구·AI 표기
- [ ] 발행 전 A-2편 훅 변형 준비
