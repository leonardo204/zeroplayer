# 큐레이션 설계

## 1. 문제

인터넷 라디오의 원래 약점은 후보가 너무 많다는 것이다. radio-browser 에 등록된 방송국은 미국만 8,214개, 독일 6,419개다(2026-09 조회값. 계속 바뀐다). 목록을 국가·장르로 접어 보여주는 앱은 이미 많고, 그 앱들의 공통 문제는 **사용자가 뭘 고를지 모른다**는 점이다.

한국 방송국은 116개뿐이라, 한국 목록만 보여주면 앱이 금방 심심해진다. 전 세계를 열면 고르기 어려워진다. 큐레이션이 이 두 문제를 동시에 푼다.

## 2. 3단 구조

```
1단 규칙       시각·요일·상황으로 후보를 좁힌다      서버, 즉시, LLM 없음
2단 LLM        후보에 순서와 이유를 붙인다            서버, 배치, 하루 한 번
3단 개인화     내 청취 기록으로 다시 정렬한다          기기, 즉시
```

세 단계가 각각 독립적으로 동작한다. LLM 이 실패하면 1단 결과만으로도 목록이 나오고, 기기 LLM 이 없으면 서버 순서를 그대로 쓴다.

## 3. 1단 — 규칙

입력은 상황 · 현재 시각 · 요일 · 국가다.

| 상황 | 좁히는 기준 |
| --- | --- |
| 취침 | `mood ∈ {calm, late-night, ambient}`. 뉴스·토크 제외. 팟캐스트는 타이머 길이 ±10분 |
| 운전 | 토크·뉴스·활기 있는 음악 허용. 끊김이 적은 고비트레이트 우선 |
| 공부 | `mood ∈ {focus, instrumental}`. 가사 있는 채널 순위 하락 |
| 작업 | 공부와 비슷하되 제한이 느슨하다 |
| 기상 | 뉴스·아침 토크·활기 있는 음악. 볼륨이 갑자기 커지는 채널 제외 |

시간대는 여섯 구간으로 나눈다. `06-09`, `09-12`, `12-18`, `18-22`, `22-02`, `02-06`.

`station_health.excluded = 1` 인 채널은 여기서 전부 빠진다. 죽은 채널을 추천하면 앱이 고장난 것처럼 보인다.

## 4. 2단 — 서버 LLM

### 4.1 요청마다 부르지 않는다

이게 비용 설계의 핵심이다. 상황 조합은 유한하다.

```
상황 5 × 시간대 6 × 평일·주말 2 × 국가 N
```

한국만 두면 60가지다. 사용자가 1만 명이 되어도 조합은 60개다. **밤에 한 번 만들어 D1 에 넣어두고 낮에는 꺼내 쓰면** LLM 호출이 사용자 수와 무관해진다.

### 4.2 LLM 이 하는 두 가지 일

**태그 정규화와 분위기 분류.** radio-browser 태그는 지저분하다. `pop`, `POP`, `música pop`, `Pop Music` 이 다 따로 있다. 이걸 한 번 정리하고 분위기 값을 붙여 `station_moods` 에 저장하면 끝난다. 이후에는 새로 들어온 방송국만 처리한다.

**추천 세트 생성.** 1단이 좁힌 후보 중 상위 20개에 순서를 정하고 `reason` 문구를 붙인다. 하루 한 번 돈다.

### 4.3 모델 선택

| 일 | 경로 | 이유 |
| --- | --- | --- |
| 태그 정규화, 분위기 분류 | **Cloudflare Workers AI** | 프록시가 이미 Workers 위에 있어 붙일 것이 없다. 하루 10,000 뉴런까지 무료 [[S4]](#s4). 분류는 작은 모델로 충분하다 |
| `reason` 문구 생성 | **OpenRouter** | 문장 품질이 필요하다. 프록시에 이미 깔려 있다 |

Workers AI 는 무료 구간을 넘으면 1,000 뉴런당 $0.011 이다. 참고로 Llama 3.2 1B 기준 출력 100만 토큰이 18,252 뉴런, 약 $0.20 이다. 분류 작업 규모에서는 무료 구간을 거의 벗어나지 않는다.

OpenRouter 로는 문구만 만든다. 방송국 3,000개에 문구를 한 번 붙이고, 이후에는 새 방송국만 처리한다.

**벤더를 직접 부르지 않는다.** 키 관리가 늘 뿐 지금은 얻을 것이 없다.

### 4.4 폴백

LLM 이 실패하면 1단 결과를 인기순(`votes + clicks`)으로 정렬해 내보낸다. `reason` 은 비운다. 앱은 `reason` 이 없으면 태그를 대신 보여준다.

## 5. 3단 — 기기 개인화

### 5.1 여기서만 개인 데이터를 다룬다

청취 기록은 서버로 보내지 않는다. 재정렬을 기기에서 하기 때문에 보낼 이유가 없다.

### 5.2 점수

```
score = (limit - serverRank)              // 서버 순위. 1위가 가장 큰 값이 되게 뒤집는다
      + 0.8 × log(그 채널 누적 청취 시간 + 1)
      + 0.5 × (같은 상황에서 들었던 횟수)
      - 1.2 × (30초 안에 넘긴 횟수)
      - 0.3 × (최근 3일 안에 들었음)      // 같은 것만 나오지 않게
```

가중치는 출발값이고, 실제 사용 로그를 보며 조정한다. 마지막 항이 없으면 매일 같은 채널만 위에 뜬다.

### 5.3 기기 LLM — Apple Foundation Models

iOS 26 부터 기기 안의 약 30억 파라미터 모델을 쓸 수 있다 [[S2]](#s2). 무료고 오프라인에서 돌고 한국어를 지원한다.

**그런데 애플이 문서에 직접 적어 둔 제약이 있다.**

> "It is not designed to be a chatbot for general world knowledge." [[S1]](#s1)

브라질 보사노바 채널이 밤에 어울리는지 판단하는 것은 세상 지식이다. 3B 모델이 이름과 태그만 보고 할 수 있는 일이 아니다. 그래서 세상 지식이 필요한 판단은 서버에 남긴다.

제약이 둘 더 있다.

- **컨텍스트가 좁다.** 커뮤니티에서 보고된 값은 4,096 토큰이다(애플 공식 문서에서는 확인하지 못했다) [[S5]](#s5). 방송국 하나를 이름·태그·국가로 설명하는 데 40토큰쯤 쓰면 한 번에 넣을 수 있는 후보가 50~80개다. 전 세계 목록을 통째로 주고 고르게 하는 방식은 불가능하다.
- **기기가 가린다.** Apple Intelligence 는 **A17 Pro 이상**이다 [[S3]](#s3). 아이폰 15 Pro 와 16 이후만 된다. 일반 아이폰 15, 14, 13 은 전부 빠진다.

**그래서 기기 LLM 은 두 가지만 맡는다.**

1. 서버가 보낸 상위 10~20개를 내 청취 기록에 맞춰 재정렬하고, 그 이유를 한 줄로 쓴다.
2. 프리셋 "자동 선택" 에서 지금 틀 것 하나를 고르고 이유를 한 줄로 쓴다.

둘 다 짧은 문장 생성이라 3B 로 충분하고, 후보 수가 20개 이하라 4,096 토큰에 들어간다.

### 5.4 기기 LLM 이 없으면

`SystemLanguageModel.default.availability` 를 확인하고, 사용할 수 없으면 5.2 의 점수 계산만 돌린다. 문구는 서버가 보낸 `reason` 을 쓴다. 기능은 전부 돌아가고 개인화 문구만 없어진다.

가용성 확인 사유는 기기 미지원 · Apple Intelligence 꺼짐 · 모델 다운로드 중 세 가지다. 세 경우 모두 조용히 폴백한다. 사용자에게 알리지 않는다.

## 6. 추천 품질을 어떻게 확인하는가

지표는 두 개만 본다.

- **30초 이탈률.** 추천에서 시작한 재생 중 30초 안에 끝난 비율. 낮을수록 좋다.
- **추천 경유 재생 비율.** 전체 재생 중 추천 목록에서 시작한 비율. 높을수록 큐레이션이 일하고 있다는 뜻이다.

둘 다 기기에 쌓인다. 서버로 보내지 않으므로 전체 통계는 볼 수 없다. 개발 중에는 디버그 화면에서 본인 기기 값만 확인한다.

## 7. 출처

- <a id="s1"></a>**[S1]** [Updates to Apple's On-Device and Server Foundation Language Models — Apple Machine Learning Research](https://machinelearning.apple.com/research/apple-foundation-models-2025-updates)
- <a id="s2"></a>**[S2]** [Foundation Models — Apple Developer Documentation](https://developer.apple.com/documentation/foundationmodels)
- <a id="s3"></a>**[S3]** [Apple Intelligence Compatible Devices — iClarified](https://www.iclarified.com/101137/apple-intelligence-compatible-devices-full-list-for-iphone-ipad-mac-vision-pro-and-apple-watch)
- <a id="s4"></a>**[S4]** [Workers AI Pricing — Cloudflare Docs](https://developers.cloudflare.com/workers-ai/platform/pricing/)
- <a id="s5"></a>**[S5]** [Putting Apple Foundation Models in a real app — Vadim Drobinin](https://drobinin.com/consulting/foundation-models-apple-intelligence/putting-apple-foundation-models-in-a-real-app/)
