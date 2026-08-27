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

## 3. 캐릭터 시트 프롬프트 (Nano Banana / Gemini 이미지 — 1회 생성 후 전 편 재사용)

콘셉트: "제로수사대" 취조실에 앉은 **의인화 쿠키앤크림 아이스크림 샌드** 캐릭터.
상표권 가드레일: 실제 패키지·로고·브랜드 폰트를 일절 묘사하지 않은 일반형(generic) 디자인.

```
A character design sheet of a cute 3D-animated anthropomorphized cookies-and-cream
ice cream sandwich character. Round vanilla ice cream disc pressed between two dark
chocolate cookie wafers, the white cream visibly speckled with cookie crumbs. Stubby
little arms and legs, oversized nervous glossy eyes, tiny beads of melting sweat on
its forehead. Sitting posture and standing posture, front view, three-quarter view,
and side view. Pixar-style soft 3D render, rounded shapes, soft studio lighting.
Plain deep ink-blue background (#1A2340). No logos, no brand markings, no packaging,
no text anywhere. Character sheet layout, consistent proportions across all views.
```

- 결과물 중 마음에 드는 **3장(정면/측면/앉은 자세)을 확정본으로 저장** → 이후 모든 Veo 생성에 레퍼런스로 첨부.
- 이 시트는 A-2편(나랑드 콤부차) 제작 시 "캔 음료 캐릭터" 버전으로 같은 문장 구조만 바꿔 재사용.

---

## 4. Veo 3.1 클립 프롬프트 (8초 × 3클립, 9:16)

공통 설정: 세로 9:16, 오디오 생성 ON, 캐릭터 레퍼런스 이미지 3장 첨부.
프롬프트 본문은 영어(모델 이해도 최적), **대사만 한국어**로 따옴표 안에 지정.

### 클립 1 — 훅 (릴스 0~8초): "저 제로예요"

```
9:16 vertical video. Pixar-style soft 3D animation. A dim police interrogation room
with a single harsh overhead lamp, deep ink-blue walls, subtle green rim light.
A cute anthropomorphized cookies-and-cream ice cream sandwich character (match the
reference images exactly: round vanilla ice cream between two dark chocolate cookie
wafers, cream speckled with cookie crumbs, stubby arms, big nervous eyes) sits alone
on a metal chair at a metal table, fidgeting nervously, a bead of melty sweat
rolling down its wafer.

Camera: slow push-in from a low angle toward the character's face, shallow depth
of field.

The character looks up at the camera, forces an innocent smile, and says in Korean,
in a squeaky nervous voice: "안녕하세요... 저, 제로예요. 라벨 보세요, 당류 0이에요."

Audio: tense quiet room tone, faint hum of the fluorescent lamp, one soft
suspenseful piano note at the end.

No on-screen text, no subtitles, no captions, no logos, no real product packaging.
```

### 클립 2 — 반전·자백 (릴스 8~16초): 수치 자막이 얹힐 구간

```
9:16 vertical video. Pixar-style soft 3D animation. Same dim interrogation room,
same cute anthropomorphized cookies-and-cream ice cream sandwich character sitting
at the metal table (match the reference images exactly). The overhead lamp swings
slightly. A manila document folder slides across the table into frame from
off-screen. The character stares at the folder, gulps, eyes darting left and right,
sweating more heavily now.

Camera: quick dramatic zoom from medium shot to close-up on the character's guilty
face, slight dutch angle.

The character breaks down and blurts out in Korean, voice cracking: "...근데요,
사실은... 저 안에 말티톨이 잔뜩 들어있어요!" then covers its face with its stubby arms.

Audio: dramatic orchestral sting when the folder lands, tense strings underneath,
the character's voice nervous and cracking.

No on-screen text, no subtitles, no captions, no logos, no real product packaging.
```

> 편집 단계: 이 클립 위에 큰 자막 **「당류 0g / 말티톨 31g / 탄수화물 65g」** + 「출처: 제품 표시정보」 고정 표기.

### 클립 3 — 해설 + CTA (릴스 16~24초)

```
9:16 vertical video. Pixar-style soft 3D animation. Same interrogation room, now
slightly brighter and calmer. The cute cookies-and-cream ice cream sandwich
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
5. A-2편(나랑드 콤부차)은 이 프롬프트 3개에서 캐릭터 묘사와 대사만 교체 — 브리프의 "1변수 원칙(훅 문구만 변경)" 유지

## 6. 이번 주 남은 작업과의 연결

- [ ] Nano Banana 캐릭터 시트 생성 → 확정 3장 보관 (체크리스트 "캐릭터 스타일 프롬프트 확정" 충족)
- [ ] Veo 3.1로 클립 1~3 생성 (본 문서 §4)
- [ ] 표시정보 캡처 확보·대조 (말티톨 31g) → 출처 폴더 보관
- [ ] CapCut 합성: 수치 자막·타이틀 박스(팔레트)·출처 문구·AI 표기
- [ ] 발행 전 A-2편 훅 변형 준비
