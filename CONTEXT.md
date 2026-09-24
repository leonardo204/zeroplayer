# 작업 인계 메모

다른 세션에서 이 저장소를 처음 열었을 때 읽는 문서다. 지금까지 한 일과 다음에 할 일만 적는다.
기획 배경과 근거는 `docs/` 에 번호순으로 있다. 처음이면 `docs/00-concept.md` 부터 읽는다.

마지막 갱신: 2026-09-24 (M7 완료 + 첫 실기기 확인에서 나온 것 세 가지 수정)

## 1. 현재 상태

M7 까지 들어갔다. 추천 탭에서 상황을 고르면 서버가 밤에 만들어 둔 목록이 나오고, 그 목록이
기기에 쌓인 청취 기록으로 다시 세워진다. 프리셋을 누르면 같은 경로로 고른 방송이 재생되고,
타이머가 끝나면 페이드아웃으로 꺼지고, 그 재생이 기록 탭에 남는다.
탐색 탭에서 팟캐스트를 찾아 에피소드를 재생할 수 있고, 듣던 자리에서 이어진다.
알람을 걸면 서버가 분마다 돌며 그 시각에 푸시를 보내고, 알림을 누르면 그 소스가 재생된다.
서버에 닿지 못할 때를 대비해 같은 시각에 로컬 알림도 함께 걸어 둔다.
설정의 버전 줄을 12번 누르면 탐색 탭에 '지상파' 가 나타나고 한국 지상파 14채널을
지금 방송 중인 프로그램과 함께 들을 수 있다.
실기기 확인(백그라운드 30분, 전화 인터럽트, 잠금화면 조작, 평문 HTTP, 알람 도착)은 아직 안 했다.

```sh
cd /Users/zerolive/work/zeroplayer
export PATH="/opt/homebrew/bin:$PATH"   # xcodegen 이 여기 있다
xcodegen generate
xcodebuild -project zeroPlayer.xcodeproj -scheme zeroPlayer \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

`.xcodeproj` 는 커밋하지 않는다. `project.yml` 로 매번 만든다.

화면을 손으로 누르지 않고 확인하려면 DEBUG 빌드에 넣어둔 통로 두 개를 쓴다.

```sh
xcrun simctl launch booted com.zerolive.cloudRadioN \
  -ZPStartTab discover -ZPAutoPlay "rb:10fbdfdd-2a6f-49fb-a035-8963c57f52e8"
xcrun simctl spawn booted log stream --style compact --level info \
  --predicate 'subsystem == "com.zerolive.cloudRadioN"'
```

`ZPStartTab` 은 처음 열리는 탭, `ZPAutoPlay` 는 바로 재생할 방송국 ID 다.
프리셋과 타이머는 통로가 두 개 더 있다. `ZPAutoPreset` 은 그 이름의 프리셋을 눌러 준 것처럼
실행하고, `ZPTimerSeconds` 는 타이머의 분을 초로 바꿔 준다(45분을 45초로 줄여 확인한다).

```sh
xcrun simctl launch booted com.zerolive.cloudRadioN \
  -ZPStartTab presets -ZPAutoPreset 취침 -ZPTimerSeconds 45
```

`ZPFakeNowPlaying 1` 은 재생 없이 미니 플레이어만 띄운다. 시뮬레이터는 실제 재생이
죽어서(6-12 참고) 미니 플레이어가 걸린 화면을 볼 방법이 이것뿐이다.

`Logger.info` 는 기본 로그 스트림에 안 나온다. `--level info` 를 빼면 실패 줄만 보인다.

## 2. 저장소 두 곳

| 경로 | 용도 |
| --- | --- |
| `/Users/zerolive/work/zeroplayer` | 2.0 본체. 원격 `github.com/leonardo204/zeroplayer` |
| `/Users/zerolive/work/cloudRadio_ios` | 1.7 원본. 참고용으로만 본다. 원격 `github.com/leonardo204/cloudRadio_ios` |

프록시 Worker 는 같은 저장소의 `server/` 에 있다. 배포와 관리 명령은 `server/README.md` 를 본다.

커밋 identity 는 `leonardo204 / zerolive7@gmail.com` 을 쓴다(1.x 이력과 같게). 전역 설정은
알티미디어 계정이라 저장소마다 따로 지정해야 한다.

## 3. 무엇을 만드는 앱인가

상황(취침·운전·공부·작업·기상)에 맞는 인터넷 라디오와 팟캐스트를 골라주고, 타이머로 끄고
알람으로 켜는 플레이어다. 음원은 부품이고 **켜고 끄는 방식**이 본체다.

- 공개 기능 — 인터넷 라디오(radio-browser) · 팟캐스트(Podcast Index) · 상황 큐레이션 · 프리셋 · 자동 종료 타이머 · 알람 · 청취 기록
- 히든 기능 — 한국 지상파 라디오와 편성표. 버전 라벨 12회 탭으로 열린다
- 광고 — AdMob 배너. 재생 화면·미니 플레이어·히든 화면·알람 직후 화면에는 붙이지 않는다

**유튜브 기능은 전부 뺐다.** 1.7 의 숨긴 웹뷰 재생이 YouTube Developer Policies III.I.9(백그라운드
플레이어 금지)과 III.I.7(오디오 분리 금지)에 어긋나고, 광고를 붙이면 III.G.1.d 까지 걸린다.
숏츠 뷰어와 YouTube Music 을 검토했지만 같은 이유로 접었다. 조항 원문은 `docs/05-ads-policy.md`.

## 4. 코드 구조에서 지켜야 할 것

1.7 은 `MainViewController` 986줄이 재생·타이머·알림을 전부 들고 있었고 화면끼리
`Notification.Name` 22개로 통신했다. 2.0 은 이걸 안 한다.

- 재생 주체는 `Core/Player/AudioPlayerService` 하나다. 화면은 `@Environment` 로 받아 `state` 를 읽는다
- `NotificationCenter` 는 시스템 이벤트(오디오 인터럽트, 앱 생애주기)에만 쓴다
- 전역 `static var` 를 만들지 않는다. 상태는 `@Observable`
- 앱은 `ai.zerolive.co.kr` 한 곳만 부른다. 스트림 주소·방송사 도메인·API 키를 앱에 두지 않는다
- 스트림 URL 은 캐시하지 않고 재생 직전에 프록시에 묻는다

## 5. M1 에서 알아낸 것

**ICY 곡명은 방송국마다 다르다.** Radio Paradise 는 곡명과 앨범 이미지 주소까지 주는데
SomaFM 은 100초를 기다려도 아무것도 안 준다. curl 로는 SomaFM 도 헤더를 내주니 방송국 문제가
아니라 AVPlayer 가 그 스트림에서 못 꺼내는 것이다. 곡명을 앱에서만 얻겠다는 계획은 절반만 된다.
서버가 ICY 를 읽어 내려주는 안은 아직 안 만들었다.

**AVPlayer KVO 는 `change.newValue` 를 믿을 수 없다.** ObjC 열거형이 Swift 열거형으로
안 돌아와 항상 nil 로 들어온다. 관찰 대상에서 직접 읽는다. 이유는 코드 주석에 있다.

## 6. M2 에서 알아낸 것

**평문 HTTP 스트림은 시뮬레이터에서 여전히 막힌다.** 전체 2,845개 중 1,010개(35%)가 평문
HTTP 고 한국도 114개 중 40개로 같은 비율이다. `NSAllowsArbitraryLoadsForMedia` 를 켜도
`-1022` 로 막히고, `AVURLAsset` 의 커스텀 헤더 옵션을 빼도 똑같다(그 옵션은 비공개 키라
지금은 아예 안 쓴다). 실기기에서 다시 재야 확정된다. 서버에는 대비를 해뒀다 — 목록에
`secure=1` 을 붙이면 HTTPS 스트림만 오고, 응답의 `isSecure` 로도 구분할 수 있다.

**Cloudflare 안에서는 IP 주소로 직접 나가는 요청이 막힌다.** 1밀리초 만에 403 이 온다.
그래서 스트림 생사 점검에서 IP 주소로 된 주소는 판정하지 않고 넘긴다. 이걸 실패로 세면
멀쩡한 방송국이 배제된다.

**한국 지상파 HLS 주소는 대부분 죽어 있다.** radio-browser 에 올라온 KBS·MBC·SBS 주소에는
만료된 서명 토큰이 붙어 있어 서버에서도 앱에서도 403·400 이 난다. 점검 120건 중 38건이
실패였고 그 대부분이 이것이다. 히든 기능(M7)에서 서버가 주소를 직접 만들어야 풀린다.

**Workers AI 모델은 폐지된다.** 처음 쓴 `@cf/meta/llama-3.1-8b-instruct` 는 2026-05-30 에
폐지돼 오류만 돌려줬다. 지금은 `@cf/meta/llama-3.3-70b-instruct-fp8-fast` 를 쓴다.
JSON 스키마 강제 출력을 받는 모델이라야 태그 판정이 안정적이다 — 8b 계열은 스키마를 못 받아
장황한 설명을 돌려준다.

**목록 응답은 엣지에 5분 캐시된다.** 서버에서 방송국을 지워도 앱에서 사라지기까지 최대 5분이
걸린다. 바로 확인하려면 쿼리 문자열을 바꿔 부른다.

## 6-1. M2 에서 새로 생긴 것

| 경로 | 하는 일 |
| --- | --- |
| `server/` | Cloudflare Worker `zeroplayer-api`. 배포·관리는 `server/README.md` |
| `Core/Networking/ProxyClient.swift` | `ai.zerolive.co.kr` 전용 클라이언트 |
| `Core/Networking/DTO/StationDTO.swift` | 서버 응답 구조체 |
| `Core/Networking/StreamReporting.swift` | 재생 실패를 서버에 알리는 좁은 통로 |
| `Core/Player/ProxyStreamResolver.swift` | 재생 직전에 주소를 묻는다. `DemoStreamResolver` 를 대신한다 |
| `Core/Persistence/Models/CachedStation.swift` | 목록 캐시(SwiftData). 스트림 주소는 담지 않는다 |
| `Core/Persistence/Store/StationStore.swift` | 목록 조회와 오프라인 폴백 |
| `Core/Config/InstallIdentity.swift` | 설치 UUID. 키체인에 둔다 |
| `Features/Discover/DiscoverModel.swift` | 탐색 탭 상태 |

`DemoStations.swift` 와 `DemoStreamResolver` 는 지웠다.

**M2 완료 기준은 채웠다.** 앱 소스에 스트림 주소가 없고(`zerolive.co.kr` 외 도메인 0건),
프록시에 닿지 못하면 캐시 50건이 그대로 보이며, D1 에서 방송국 한 줄을 지우니 목록에서 사라졌다.

## 6-2. M3 에서 알아낸 것

**프리셋의 자동 선택은 서버 규칙으로 돌린다.** `GET /zp/v1/recommend` 를 M3 에서 만들었다.
LLM 은 아직 안 부른다 — 상황별 태그 규칙과 시간대 가중치만으로 후보를 고르고, `reason` 에는
무엇으로 걸렀는지 그대로 적는다(`source: "rule"`). M4 에서 이 위에 LLM 세트가 얹혔고,
세트가 없을 때 쓰는 폴백으로 그대로 남아 있다.

**시각을 보낼 때 오프셋을 붙이지 않는다.** `at=2026-09-24T23:10:00+09:00` 로 보내면 질의
문자열에서 `+` 가 공백으로 풀려 서버가 시각을 통째로 놓친다(그러면 UTC 현재 시각으로 떨어져
한낮에 새벽 목록이 온다). 그래서 앱은 오프셋 없이 기기 시계만 보내고, 서버는 문자열 앞부분에서
시·요일을 읽는다. 서버는 오프셋이 붙어 와도 읽도록 해뒀다.

**앱이 고르는 자리에서는 HTTPS 스트림만 받는다.** 자동 선택은 사람이 고른 것이 아니라서
평문 HTTP 를 물어 오면 그대로 실패한다. 그래서 `secure=1` 로 요청한다. 탐색 탭은 그대로 둬서
사용자가 직접 고를 수 있다.

**고른 방송이 죽어 있으면 다음 후보로 넘어간다.** 실측에서 첫 후보 KBS Classic FM 이 403 이었고
두 번째 후보로 넘어가 재생됐다. 자동 선택은 최대 세 번까지 시도한다.

**M3 완료 기준은 채웠다.** 취침 프리셋을 실행하니 후보 20개를 받아 두 번째 후보가 재생됐고,
타이머 종료 30초 전에 페이드아웃이 시작됐고, 시간이 되자 재생이 멈췄고, 기록 탭에 50초짜리
세션이 프리셋 이름과 함께 남았다.

## 6-3. M3 에서 새로 생긴 것

| 경로 | 하는 일 |
| --- | --- |
| `server/src/routes/recommend.ts` | 상황별 추천(1단 규칙) |
| `server/src/lib/situations.ts` | 상황 다섯 가지의 태그 규칙과 시간대 구간 |
| `Core/Player/SleepTimer.swift` | 자동 종료와 페이드아웃. 앱에 타이머는 이것 하나뿐이다 |
| `Core/Player/PlaybackOrigin.swift` | 이 재생이 어디서 시작됐는지. 기록에 그대로 들어간다 |
| `Core/Persistence/Models/Preset.swift` | 프리셋. 기본 다섯 개도 여기 있다 |
| `Core/Persistence/Models/Favorite.swift` | 즐겨찾기 |
| `Core/Persistence/Models/ListeningSession.swift` | 청취 기록 |
| `Core/Persistence/Store/ListeningStore.swift` | 기록을 쓰고 읽는다. 30초마다 중간 저장한다 |
| `Core/Persistence/Store/FavoriteStore.swift` | 즐겨찾기 넣고 빼기 |
| `Core/Networking/DTO/RecommendationDTO.swift` | 추천 응답 구조체 |
| `Features/Presets/PresetLauncher.swift` | 프리셋을 누르면 벌어지는 일 전부 |
| `Features/Presets/PresetEditorView.swift` | 프리셋 편집 |
| `Features/Presets/StationPickerView.swift` | 프리셋에 걸 방송국 고르기 |
| `Features/Player/SleepTimerSheet.swift` | 타이머 화면 |
| `Features/Stats/MonthlyReport.swift` | 월간 리포트 계산. 화면과 떼어 뒀다 |

## 6-4. M4 에서 알아낸 것

**기기 안 모델은 "쓸 수 있다"고 답해도 실제로는 못 만들 수 있다.**
`SystemLanguageModel.default.availability` 가 `.available` 인데 첫 생성에서
`ModelManagerError 1026` 이 났다(iPhone 17 Pro 시뮬레이터, iOS 26). 모델 자산이 없어서다.
그래서 가용성을 그대로 믿지 않고 짧은 문장을 한 번 만들어 본 결과까지 보고 상태를 정한다
(`OnDeviceReasoner.warmUp()`). 실기기에서는 다른 결과가 나올 수 있으니 다시 재 본다.

**추천 문구는 Workers AI 하나로 만든다.** `docs/04-curation.md` 는 분류를 Workers AI,
문구를 OpenRouter 로 나눠 뒀지만 OpenRouter 키를 새로 들이지 않고 둘 다
`@cf/meta/llama-3.3-70b-instruct-fp8-fast` 로 돌린다. 한국어 한 줄 품질이 쓸 만하다
("편안한 음악으로 잠을 청합니다", "자연 소리와 음악으로 휴식을 취합니다").
아쉬우면 M8 전에 OpenRouter 로 갈아 끼운다 — 바꿀 자리는 `server/src/lib/recommendSets.ts`
한 곳이다.

**분위기는 태그에서 규칙으로 채우고 모자란 것만 모델에 묻는다.** 방송국 2,845개를 전부
모델에 물으면 30분이 넘는다. 태그가 있는 2,010개는 태그→분위기 표로 즉시 정하고
(`server/src/lib/moods.ts` 의 `MOOD_BY_TAG`), 태그가 하나도 없는 835개만 이름·나라를 보여
모델에게 묻는다. LLM 호출이 '태그 없는 방송국 수' 에만 비례한다.

**D1 은 왕복이 비싸다.** 분위기를 방송국 하나마다 `DB.batch` 로 쓰다가 200초에 1,058건밖에
못 했다. 여러 방송국의 문장을 120개씩 모아 한 번에 보내니 같은 시간에 훨씬 많이 들어간다.
D1 에 줄 단위로 쓰는 코드를 새로 쓸 때는 먼저 묶는다.

**LLM 을 요청마다 부르지 않는다.** 상황 5 × 시간대 6 × 평일·주말 2 × 나라 2 = 120 조합이고,
사용자가 몇 명이든 그대로다. 매일 04:00 KST 배치가 한 번에 24개씩 만들어 `recommendation_sets`
에 넣어 둔다. 한 조합에 약 35초 걸린다. 세트가 없으면 규칙 결과를 즉석에서 만들어 주므로
배치가 밀려도 앱은 목록을 받는다(응답의 `source` 로 구분한다).

## 6-5. M4 에서 새로 생긴 것

| 경로 | 하는 일 |
| --- | --- |
| `server/src/lib/moods.ts` | 분위기 분류. 태그 규칙 + 모자란 것만 Workers AI |
| `server/src/lib/candidates.ts` | 1단 후보 뽑기. 태그·시간대·분위기로 점수를 매긴다 |
| `server/src/lib/recommendSets.ts` | 2단. 조합별 세트를 만들어 D1 에 넣는다 |
| `Core/Curation/Personalizer.swift` | 3단. 청취 기록으로 순서를 다시 세운다 |
| `Core/Curation/OnDeviceReasoner.swift` | 기기 안 모델. 맨 위 한 줄만 다듬는다 |
| `Features/Recommend/RecommendModel.swift` | 추천 탭 상태 |

앱의 `Situation` 과 서버의 `situations.ts` 가 같은 다섯 값을 쓴다. 한쪽만 고치면 400 이 난다.

**3단은 점수식이 순서를 정하고 기기 모델은 문구만 쓴다.** `docs/04-curation.md` 5.3 은
기기 모델에 재정렬까지 맡기라고 적었지만, 3B 모델에 순서를 맡기면 같은 목록에서 매번 다른
답이 나온다. 순서는 `Personalizer` 의 점수식이 정하고(같은 입력에 같은 순서가 나온다),
기기 모델은 맨 위 한 건의 이유 한 줄만 쓴다.

## 6-6. M5 에서 알아낸 것

**iTunes Search 는 Worker 에서 못 쓴다.** 나가는 IP 가 Cloudflare 공용이라 Apple 쪽 한도에
이미 걸려 있다 — `Rate limit has been exceeded for: itunes-apple-com|general|2a06:98c0:3600::103`
로 429 나 403 만 돌아온다. 분당 20회 제한 문제가 아니라 아예 안 열린다(`docs/03-proxy-api.md` 7번의
전제가 틀렸다). 같은 주소가 맥에서는 200 이다. 반면 애플 인기 목록
(`rss.marketingtools.apple.com`)은 Worker 에서도 200 이라 순위는 받을 수 있다. 다만 순위에는
피드 주소가 없다.

**그래서 피드를 주소로 직접 등록한다.** `POST /admin/podcasts/add?feed=<RSS 주소>&id=it:<번호>`
가 RSS 를 읽어 팟캐스트와 에피소드를 넣는다. 지금 들어 있는 48개(한국 25·미국 20 + 확인용)는
맥에서 iTunes lookup 으로 주소를 모아 이 경로로 넣은 것이다. Podcast Index 키가 들어오면
검색·인기 목록이 그쪽으로 바뀌고, 이 경로는 손으로 더하는 용도로 남는다.
키가 없는 동안 `/podcasts/search` 는 이미 받아 둔 것 안에서 찾는다(응답 `source: "local"`).

**팟캐스트 오디오도 평문 HTTP 가 많다.** SBS 계열은 `http://podcastdown.sbs.co.kr/...` 이고
MBC 계열은 HTTPS 다. 방송국과 같은 문제라 에피소드 응답에도 `isSecure` 를 담고,
프리셋 자동 선택처럼 앱이 고르는 자리에서는 `secure=1` 로 HTTPS 만 받는다.

**RSS 는 정규식으로 읽는다.** Workers 에 `DOMParser` 가 없다(`server/src/lib/rss.ts`).
`itunes:duration` 은 `00:36:26`·`36:26`·`2186` 세 가지가 다 오고, 설명에 HTML 과 CDATA 가
섞인다. 피드 하나가 어긋나도 그 항목만 버리고 넘어간다.

**죽은 피드가 섞여 있다.** 애플 한국 순위 30개 중 2개는 피드가 404 였다(삼프로TV 등).
순위에 있다고 살아 있는 것이 아니다. 등록 실패는 502 `feed_error` 로 구분해 돌려준다.

**에피소드 주소도 앱에 두지 않는다.** `docs/03-proxy-api.md` 3.3 은 목록에 `audioURL` 을
담는다고 적었지만, 방송국과 같은 규칙(4번)을 지켜 목록에서는 빼고 재생 직전에
`GET /episodes/{id}/stream` 으로만 준다. 문서는 고쳐 뒀다.

## 6-7. M5 에서 새로 생긴 것

| 경로 | 하는 일 |
| --- | --- |
| `server/src/lib/rss.ts` | RSS 읽기. 에피소드·길이·발행일 |
| `server/src/lib/itunes.ts` | iTunes 검색·조회와 애플 인기 목록. 검색 쪽은 지금 막혀 있다 |
| `server/src/lib/podcastIndex.ts` | Podcast Index 클라이언트. 시크릿 `PI_KEY`·`PI_SECRET` 이 있으면 켜진다 |
| `server/src/lib/podcasts.ts` | 팟캐스트·에피소드 저장과 배치 |
| `server/src/routes/podcasts.ts` | 검색·인기·에피소드·스트림 |
| `Core/Persistence/Models/PlaybackPosition.swift` | 어디까지 들었는지(에피소드만) |
| `Core/Persistence/Store/PositionStore.swift` | 이어듣기 읽고 쓰기 |
| `Core/Player/PlaybackPositionKeeping.swift` | 재생 코드가 SwiftData 를 모르게 하는 통로 |
| `Features/Podcasts/` | 팟캐스트 목록·에피소드 목록 |

`AudioPlayerService` 에 길이·구간 이동·되감기(15초)·건너뛰기(30초)·재생 속도가 붙었다.
속도는 `AVPlayer.defaultRate` 로 둔다 — `play()` 가 속도를 1 로 되돌리기 때문이다.
잠금화면에도 진행 바와 되감기 단추가 나온다(에피소드일 때만 켠다).

**M5 완료 기준은 채웠다.** 취침 프리셋(타이머 45분)을 누르니 45분짜리 에피소드가 골라져
재생됐고, 앱을 끄고 다시 여니 620초 자리에서 이어졌다.

## 6-8. M6 에서 알아낸 것

**APNs 키는 발급할 때 환경 제한을 걸지 않아야 한다.** 처음 만든 키(`J32837LLMM`)는
개발 환경 전용이라 sandbox 는 `400 BadDeviceToken`(인증은 통했고 토큰만 가짜라는 뜻)인데
배포 환경은 `403 BadEnvironmentKeyInToken` 이 왔다. 개발자 포털에서 APNs 키를 만들 때
Sandbox·Production 을 고르는 자리가 있고, Production 으로 다시 받은 키(`HDFVB5T2FZ`)는
두 환경 모두 `400 BadDeviceToken` 이다. **가짜 토큰을 두 환경에 보내 보면 키가 맞는지
기기 없이 확인할 수 있다** — `POST /zp/v1/admin/push/test` 에 `{"token":"<64자>","env":"prod"}`.

**푸시가 와도 앱이 저절로 소리를 내지 못한다.** iOS 제약이라 설계로 받아들였다
(`docs/01-features.md` 5.1). 알림을 눌러야 앱이 열리고 재생이 시작된다. 그래서 본문에
무엇을 틀지 적어 탭할 이유를 만든다.

**권한을 받기 전에 로컬 알림을 걸면 iOS 가 그 자리에서 권한 창을 띄운다.** 앱이 뜨자마자
백업 알림을 걸다가 사용자가 아무것도 안 했는데 창이 떴다. `LocalAlarmScheduler.reschedule`
은 이제 권한 상태를 먼저 보고, 아직 묻지 않았으면 걸지 않는다. 묻는 자리는 두 곳뿐이다 —
알람을 저장할 때와 '알림 허용하기' 를 눌렀을 때.

**같은 알람이 서버에 두 줄 생겼다.** 알람을 만들면 `AlarmStore.add()` 가 서버에 올리는데,
그 사이에 `syncAll()` 이 `needsSync` 인 같은 알람을 한 번 더 올렸다. `AlarmStore` 는 화면마다
새로 만들어 쓰므로 타입 차원의 `inFlight` 집합으로 막았다. 올라가는 중인 알람이 있으면
서버 목록을 내려받지도 않는다 — 기기 쪽에 서버 ID 가 아직 안 적혀 있어 같은 알람을
새로 만들어 버린다.

**시간대 계산은 발송할 때마다 다시 한다.** 사용자는 '평일 아침 7시' 를 자기 시계로 말하고,
서버는 그것을 UTC 한 시점(`alarms.next_fire_at`)으로 바꿔 둔다. 서머타임이 있는 나라에서는
같은 아침 7시가 계절마다 다른 UTC 시각이라, 보낸 뒤에 다음 시각을 새로 계산한다.
실측으로 확인했다 — 한국 평일 07:00 → 다음 금요일 22:00Z, 뉴욕 07:00 → 같은 날 11:00Z(EDT).

**분마다 도는 Cron 이 실제로 돈다.** `* * * * *` 를 걸어 두고 1분 뒤 울릴 알람을 만들어 두니
`06:01:13` 에 깨어나 `06:01:00` 짜리를 집었다. 조용한 분에는 `sync_state` 를 건드리지 않는다 —
매분 쓰면 기록이 의미를 잃는다.

**시뮬레이터는 탭을 못 보낸다.** 권한 창이 한번 뜨면 재부팅해도, `simctl privacy reset` 을
해도 안 사라진다. 알람 화면 자체는 그 뒤로 정상으로 그려진다. 권한을 허용한 뒤의 흐름은
실기기에서 확인해야 한다.

## 6-9. M6 에서 새로 생긴 것

| 경로 | 하는 일 |
| --- | --- |
| `server/src/lib/apns.ts` | ES256 JWT 서명과 APNs 발송. 토큰은 50분마다 갈아 낀다 |
| `server/src/lib/schedule.ts` | 시간대·요일로 다음 발송 시각을 계산한다 |
| `server/src/lib/alarmDispatch.ts` | 분마다 울릴 알람을 찾아 보내고 다음 시각을 다시 적는다 |
| `server/src/routes/alarms.ts` | 기기 등록과 알람 CRUD |
| `Core/Persistence/Models/AlarmSetting.swift` | 알람 한 건(SwiftData) |
| `Core/Notifications/PushRegistrar.swift` | 알림 권한·APNs 토큰·알림이 눌렸을 때 |
| `Core/Notifications/LocalAlarmScheduler.swift` | 로컬 백업 알림과 스누즈 |
| `Core/Notifications/AlarmStore.swift` | 기기와 서버를 맞춘다 |
| `Features/Alarm/AlarmsView.swift` · `AlarmEditorView.swift` | 알람 목록과 편집 |
| `Sources/App/zeroPlayer.entitlements` | `aps-environment`. Time Sensitive 는 승인 뒤에 넣는다 |

`AppDelegate` 가 처음 생겼다. APNs 토큰은 `UIApplicationDelegate` 로만 오기 때문이고,
`@UIApplicationDelegateAdaptor` 로 SwiftUI 앱에 붙였다. 받은 토큰은 `PushRegistrar` 로 넘긴다.

확인용 디버그 통로가 셋 늘었다(전부 DEBUG 빌드에만 있다).

```sh
xcrun simctl launch booted com.zerolive.cloudRadioN \
  -ZPStartTab settings -ZPOpenAlarms 1 -ZPSeedAlarm "07:00"
# 알림을 누른 상황을 그대로 만든다
xcrun simctl launch booted com.zerolive.cloudRadioN -ZPAlarmPush "rb:<uuid>"
xcrun simctl launch booted com.zerolive.cloudRadioN -ZPAlarmPush "situation:wake"
```

서버 쪽은 관리 경로 둘로 확인한다.

```sh
curl -X POST -H "x-zp-admin: $TOKEN" ".../zp/v1/admin/alarms/dispatch"
curl -X POST -H "x-zp-admin: $TOKEN" -d '{"token":"<64자 16진수>","env":"sandbox"}' \
  ".../zp/v1/admin/push/test"
```

## 6-10. M7 에서 알아낸 것

**.pls 를 저장하지 말고 재생 직전에 푼다.** KBS·MBC·SBS 의 m3u8 주소에는 서명이 붙어 있고
몇 시간이면 만료된다. M2 에서 radio-browser 에 적힌 지상파 주소가 전부 403·400 이던 이유가
이것이다. 1.x 가 쓰던 `serpent0.duckdns.org:8088/*.pls` 는 부를 때마다 새로 서명된 주소를
내주므로, 채널 표에는 `.pls` 주소만 두고 `/hidden/channels/{id}/stream` 에서 그때 푼다.
실측(2026-09-24)에서 여덟 개 `.pls` 가 모두 살아 있었고 받은 m3u8 이 200 으로 재생됐다.

**1.x 의 파싱 규칙은 아직 그대로 통한다.** 방송사 네 곳의 응답 모양이 2021년과 같다.
바뀐 것은 하나뿐이다 — MBC 응답이 `<body><p>` 로 감싸여 오지 않고 순수 JSON 이다.
감싸개가 있으면 벗기고 없으면 그대로 읽게 해 두 경우 모두 받는다.

| 방송사 | 어디서 | 무엇으로 |
| --- | --- | --- |
| KBS | `onair.kbs.co.kr/index.html?…ch_code=<21·22·24·25>` | `og:description` 한 줄. `'2FM 가비의 슈퍼라디오 15:30~16:00'` 모양이라 앞의 채널 약칭과 뒤의 시각을 떼면 프로그램 이름이다 |
| MBC | `control.imbc.com/Schedule/PCONAIR?type=radio` | `RadioList[]` 에서 `TypeTitle` 이 `'FM4U'`·`'표준FM'` 인 줄 |
| SBS | `www.sbs.co.kr/ko/live?div=gnb_pc` | `__NEXT_DATA__` 의 `props.pageProps.radio[]`, `channelname` 이 `'POWER FM'`·`'LOVE FM'` |
| TBS | `tbs.seoul.kr/player/live.do?channelCode=<CH_A·CH_B>` | HTML 의 `class="time"`·`class="tit"`·`posterUrl` |
| CBS | 없음 | 편성표를 내주는 자리가 없어 서버가 표를 들고 있다 |

**1.x 가 들고 있던 주소 중 셋은 죽었다.** AFN The Voice·Joe Radio·Legacy 는 streamtheworld 에서
mount 가 사라졌다 — `.pls` 가 200 을 주지만 `NumberOfEntries=0` 이라 재생할 주소가 없다.
대신 살아 있는 대구(`AFNP_DGU`)를 넣어 두 곳으로 맞췄다. CBS 의 `aac.cbs.co.kr` 도 죽어서
`m-aac.cbs.co.kr` 쪽 https 주소로 바꿨고, 1.x 가 함께 들고 있던 CBS 프로그램 이미지는
개인 서버(`zerolive7.iptime.org`)라 지금 응답이 없어 뺐다.
1.x 는 TBS 의 '재생 페이지 주소' 를 스트림 주소 자리에 넣어 뒀는데, 실제 스트림은
`cdnfm.tbs.seoul.kr`·`cdnefm.tbs.seoul.kr` 이다.

**편성표가 실패해도 재생은 된다.** 1.x 는 강제 언랩으로 잘라서 방송사가 페이지를 바꾸면
앱이 죽었다. 서버는 못 읽으면 `programName` 을 비워 200 을 주고, 예전에 읽어 둔 값이 있으면
그쪽을 먼저 쓴다. 잘못된 채널 이름을 넣어 일부러 실패시켜 확인했다 — `now` 는 전부 null 이고
`stream` 은 그대로 주소를 줬다.

## 6-11. M7 에서 새로 생긴 것

| 경로 | 하는 일 |
| --- | --- |
| `server/src/routes/hidden.ts` | 해제·잠금·채널 목록·주소·편성표 |
| `server/src/lib/hiddenSchedule.ts` | 방송사별 편성표 파서와 `.pls` 해석, 5분 캐시 |
| `server/migrations/0005_hidden.sql` | `hidden_channels`·`hidden_now_cache`, `devices` 에 토큰 두 칸 |
| `server/migrations/0006_hidden_afn.sql` | 죽은 AFN 세 곳을 빼고 대구를 넣는다 |
| `Core/Config/HiddenAccess.swift` | 해제 상태와 토큰(키체인) |
| `Core/Networking/DTO/HiddenDTO.swift` | 채널·편성표 구조체 |
| `Core/Ads/AdPlacement.swift` | 화면별 배너 노출 판정. 배너 자체는 M8 |
| `Features/Hidden/HiddenModel.swift` | 채널 목록과 편성표 상태. 캐시하지 않는다 |
| `Features/Hidden/HiddenRadioContent.swift` | 방송사별로 묶은 채널 목록 |

**해제는 설정의 버전 줄을 12번 누르면 된다.** 1.x 는 40번이었고 해제 직후 `exit(0)` 으로
앱을 껐다 — 애플이 금지하는 동작이다. 2.0 은 앱을 끄지 않고 탐색 탭의 갈래 고르개에
'지상파' 가 하나 늘어난다. 여섯 번째 탭으로 두지 않는다(`TabView` 가 다섯 개를 넘으면
'더 보기' 로 접는다). 설정에서 '목록에서 숨기기' 를 누르면 되돌아간다.

**앱에는 방송사 이름도 주소도 없다.** 채널 이름·방송사·주소가 전부 서버에서 온다.
`Sources/` 안에 `KBS`·`MBC`·`serpent0` 같은 문자열이 한 건도 없다(주석과 화면 문구의
'지상파' 라는 말은 남는다 — 이건 문턱이지 자물쇠가 아니다).

**시뮬레이터에서 확인한 것** — 해제 전에는 탐색 탭에 라디오·팟캐스트 둘뿐이고, 해제하면
앱을 끄지 않고 '지상파' 가 나타난다. 채널 14개가 방송사별로 묶여 나오고 지금 방송 중인
프로그램과 시각이 함께 뜬다. KBS 쿨FM 을 눌러 실제로 소리가 났다.

## 6-12. 첫 실기기 확인에서 나온 것

실기기에서 앱을 돌려 보고 세 가지를 고쳤다.

**푸시 등록이 실패했다.** `registerForRemoteNotifications` 가
`NSCocoaErrorDomain 3000 — aps-environment 인타이틀먼트를 찾을 수 없습니다` 로 떨어졌다.
엔타이틀먼트 파일을 만들어 두기만 하고 안이 비어 있었다. `aps-environment` 는 Time Sensitive
와 다른 것이라 승인을 기다릴 필요가 없다 — 번들 ID 에 Push Notifications 를 켜 뒀으면 바로
쓴다. 개발과 배포의 값이 달라서 파일을 둘로 나누고 `project.yml` 에서 빌드 설정별로 지정한다.

| 빌드 | 파일 | aps-environment |
| --- | --- | --- |
| Debug | `Sources/App/zeroPlayer.entitlements` | `development` |
| Release | `Sources/App/zeroPlayerRelease.entitlements` | `production` |

시뮬레이터 빌드로는 확인할 수 없다. 서명할 때 이 값을 떼어 내기 때문에
`codesign -d --entitlements` 가 빈 사전을 보여준다. 실기기에서만 붙는다.

**KBS Classic FM 이 403 으로 재생되지 않았다.** radio-browser 에 올라온 주소에 CloudFront
서명이 붙어 있었고 그 서명이 하루 전에 만료돼 있었다. 등록된 날에는 살아 있으니 스트림 생사
점검으로는 영영 안 걸러진다 — 점검이 성공한 다음 날 만료되기 때문이다. 주소 모양으로 가려야
한다(`Policy`+`Signature`, `Key-Pair-Id`, `token=eyJ`, `_lsu_sa_`, Akamai `hdnts`).
3,012줄 가운데 33줄이고 전부 KBS·MBC·SBS·CPBC 다. 이 방송들은 히든 채널 표에 `.pls` 로
들어 있어 거기서는 재생 직전에 새 서명을 받아 멀쩡히 나온다.

**같은 방송이 목록에 여러 줄 보였다.** 'Listen.moe Kpop' 과 'Listen.moe Kpop (MP3)' 는
코덱만 다른 같은 방송이고, 'KBS Classic FM' 은 올린 사람만 다른 줄이 열여섯 개였다.
`dedupe_key`(`나라|정규화한 이름`)로 묶고 묶음마다 `is_primary` 를 하나만 세운다.
3,012줄이 2,644묶음이 됐다.

정규화는 **코덱과 비트레이트 표기만** 뗀다. 'no pub'(광고 없음)·'hifi'·'original' 처럼
내용이 갈리는 말은 남긴다 — 'FIP' 와 'FIP (no pub)' 을 합치면 사용자가 찾던 쪽이 사라진다.
이름 **앞**에 붙은 짧은 괄호만 예외로 뗀다. 거기 오는 건 올린 사람 표기다('(BSOD) KBS...').

대표를 `is_primary` 로 미리 정해 두는 이유는 목록과 추천이 같은 줄을 보게 하려는 것이다.
목록은 묶음 질의로, 추천은 먼저 나온 줄로 대표를 고르면 화면마다 다른 이름이 나온다.

**이미 만들어 둔 추천 세트는 옛 목록을 들고 있다.** 세트는 하루에 한 번만 다시 만들어서
그 사이에 빠진 방송국이 그대로 남는다. `loadSet` 이 꺼낼 때 지금 목록에 없는 방송국을
걸러 낸다. 규칙을 크게 바꿨을 때는 `DELETE FROM recommendation_sets` 로 비우고 다시 만든다.

**시뮬레이터에서 재생이 안 된다.** `-ZPAutoPlay` 로 띄우면 앱이 2초 안에 조용히 죽는다.
크래시 리포트도 로그도 남지 않는다. 기기를 바꿔도, M7 커밋 상태로 되돌려 빌드해도 같으므로
앱 코드 회귀가 아니고, 같은 빌드가 실기기에서는 잘 재생된다. 맥의 오디오 쪽 문제로 보인다.
재생을 확인할 일이 있으면 실기기를 쓴다. 목록·추천·화면은 시뮬레이터로 그대로 확인된다.

## 6-13. 썸네일

미니 플레이어와 재생 화면이 늘 회색 파형만 보여 주던 것을 고쳤다. 한 자리에서 그린다 —
`Core/UI/ArtworkView.swift`. 목록·추천·지상파 줄도 같은 뷰를 쓴다.

**썸네일이 오는 곳은 셋이고 뒤로 갈수록 이긴다.**

1. 목록이 준 주소(`PlayableItem.artworkURL`)
2. 방송국을 목록 없이 튼 경우(프리셋·알람) 재생 주체가 `GET /stations/{id}` 로 한 번 더 묻는다
3. 재생이 붙은 뒤 오는 것 — ICY 가 주는 곡 이미지, 지상파 편성표가 주는 프로그램 이미지

셋을 `AudioPlayerService.artworkURL` 하나로 모았다. 화면은 `current?.artworkURL` 이 아니라
**이 값을 본다.** 잠금화면(`NowPlayingCenter`)도 같은 값으로 그림을 올린다.

**없으면 이름 첫 글자로 타일을 그린다.** 색은 이름을 해시해 정한다 — `hashValue` 는 실행할
때마다 달라져서 쓰지 않는다. 껐다 켤 때마다 방송국 색이 바뀌면 다른 목록처럼 보인다.

**서버가 메우는 부분.** radio-browser 의 favicon 칸은 절반 넘게 비어 있다. 이름에 방송사가
드러나는 한국 방송국은 손으로 모은 로고로 메운다(`server/src/lib/logos.ts`). KR 목록 기준
썸네일이 20건에서 37건으로 늘었다. 지상파 14채널에는 `hidden_channels.logo_url` 을 채웠고,
AFN 두 곳은 방송사 사이트가 외부 요청을 막아 못 구했다 — 이름 타일로 나간다.

**평문 HTTP 썸네일은 HTTPS 로 올려 보낸다.** `AsyncImage` 는 `URLSession` 을 타기 때문에
ATS 가 막는다(`NSAllowsArbitraryLoadsForMedia` 는 AVFoundation 이 여는 오디오에만 해당한다).
전 세계 목록 200건 기준 21건이 평문이었고 18건이 HTTPS 로도 같은 그림을 준다. 나머지 셋은
실패하고 이름 타일이 대신 나온다.

**저장된 추천 세트는 만들 때의 썸네일을 박제하고 있다.** 로고 표를 고쳐도 다음 배치 전까지
반영되지 않아서 `GET /recommend` 가 내보낼 때 한 번 더 메운다.

**덤으로 고친 것.** `GET /stations?limit=200` 이 500 이었다. 태그를 묻는 `IN` 절에 값을
200개 넣는데 D1 은 한 문장에 100개까지다. 90개씩 잘라 묻는다. 앱은 50 씩 받으니 닿지 않던
자리였다.

**실기기에서 확인할 것** — 시뮬레이터는 재생이 죽어서 못 봤다.

- [ ] Radio Paradise 처럼 ICY 로 곡 이미지를 주는 방송국에서 썸네일이 곡마다 바뀌는지
- [ ] 지상파를 틀면 프로그램 이미지와 프로그램 이름이 재생 화면에 올라오는지
- [ ] 잠금화면과 제어센터에 그림이 뜨는지

## 6-14. 다음 할 일 — M8 (광고와 출시)

`docs/07-roadmap.md` 의 M8 을 따른다. AdMob 앱 인증이 먼저다(6-13 참고).
`Core/Ads/AdPlacement.swift` 에 어느 화면에 붙일지 판정이 이미 있으니 배너만 얹는다.
알람 커스텀 사운드(30초 `.caf`)도 이 단계에서 넣는다.

**실기기에서 확인할 것** — M1 부터 밀린 것이다.

- [ ] 화면을 끄고 30분 이상 끊기지 않는지
- [ ] 전화를 받고 끊으면 재생이 이어지는지
- [ ] 잠금화면에서 일시정지·재생이 되는지
- [ ] 평문 HTTP 스트림이 실기기에서도 막히는지
- [ ] 기기 안 모델이 실기기(A17 Pro 이상)에서는 실제로 문구를 만드는지
- [ ] 알림 권한을 허용하면 APNs 토큰이 잡히고 서버에 등록되는지 (엔타이틀먼트를 고쳤으니 다시 재 본다)
- [ ] 앱을 완전히 종료한 상태에서 알람 시각에 알림이 오고, 탭하면 재생되는지
- [ ] 비행기 모드에서 로컬 백업 알림이 울리는지
- [ ] 잠금화면 알림의 '재생'·'5분 뒤 다시' 단추

**손으로 눌러 봐야 하는 것** — 시뮬레이터에서 자동으로 확인하지 못했다.

- [ ] 프리셋 편집(이름·아이콘·방송국 고르기·타이머)이 저장되는지
- [ ] 탐색 탭에서 줄을 밀어 즐겨찾기에 넣고 빼는 동작
- [ ] 재생 화면의 하트와 자동 종료 단추
- [ ] 추천 탭에서 상황을 바꿔 가며 목록이 바뀌는지
- [ ] 팟캐스트 검색·에피소드 목록·이어듣기 줄을 눌러 여는 동작
- [ ] 재생 화면의 진행 바를 끌어 옮기기와 재생 속도 바꾸기
- [ ] 알람 만들기·고치기·요일 고르기·켜고 끄기
- [ ] 설정의 버전 줄을 실제로 12번 눌러 지상파가 열리는지, '목록에서 숨기기' 로 되돌아가는지

## 6-15. 랜딩 페이지와 광고 준비

앱 소개와 광고 게시자 선언을 맡는 Worker 가 `worker/` 에 따로 있다. 앱이 부르는 API
(`server/`, `ai.zerolive.co.kr/zp/v1`)와 다른 Worker 다. 둘을 섞지 않는다.

| 이름 | 값 |
| --- | --- |
| Worker | `zeroplayer-landing` |
| 주소 | `https://zeroplayer.zerolive.co.kr` (custom domain) |
| 배포 | `cd worker && npm install --include=dev && npx wrangler deploy` |
| 경로 | `/` `/en` `/privacy` `/en/privacy` `/support` `/en/support` `/app-ads.txt` `/robots.txt` `/sitemap.xml` `/llms.txt` |

랜딩 본문은 2.0 기준으로 썼다. 스토어에 올라가 있는 것은 아직 1.7(유튜브 재생)이다.

**app-ads.txt 는 도메인이 전부다.** 파일 내용은 모든 zerolive 앱이 같다
(`google.com, pub-4410880415888380, DIRECT, f08c47fec0942fa0`). AdMob 은 **App Store 앱
페이지의 '개발자 웹사이트'** 를 보고 그 도메인의 루트에서 이 파일을 찾는다. 그 값은
App Store Connect 의 **마케팅 URL** 이다. 지금 zeroPlayer(id1610259595)에는 마케팅 URL 이
비어 있어서 AdMob 이 크롤할 곳이 없다 — 앱 인증이 막힌 원인이 이것이다.
`https://zeroplayer.zerolive.co.kr` 를 마케팅 URL 로 넣은 뒤 AdMob 에서 다시 확인해야 한다.
스토어 페이지에 반영되기까지 하루 정도 걸리고, AdMob 크롤도 하루 안팎 기다려야 한다.

바닥글 상호 링크는 `worker/src/render.ts` 의 `SIBLINGS` 에 있다. 다른 랜딩(lnhud·md-editor·
golf·wander·hamzzi-diet)의 바닥글과 live-translate 의 `llms.txt` 에도 zeroplayer 를 넣어
배포했고, zerolive-root 의 `robots.txt` 사이트맵 줄에도 있다. 포트폴리오(me.zerolive.co.kr)
쪽은 코드가 아니라 데이터다 — 홈 서버 PostgreSQL 의 `portfolio_projects.live_url` 에
랜딩 주소를 넣으면 앱 카드에 '소개 페이지' 단추가 생긴다(id=29 에 넣어 뒀다).

## 7. 정해둔 것과 아직 안 정한 것

**정한 것**

- 최소 iOS 17.0. SwiftUI + SwiftData + `@Observable`
- 의존성은 SPM 만 쓴다. CocoaPods 를 쓰지 않는다
- Swift 6 툴체인을 쓰되 언어 모드는 5 로 시작한다. `AVPlayer` KVO 와 SwiftData 모델이
  `Sendable` 이 아니라 막힌다. 지금 남은 경고는 `AVMetadataItem.stringValue` deprecated 하나와
  SwiftData `#Predicate` 의 KeyPath 경고들이다. 뒤엣것은 SwiftData 쪽이라 우리가 못 고친다.
  언어 모드는 M5 이후에 다시 본다
- 프록시 중계를 하지 않는다 — 오디오 대역폭이 전부 Worker 를 거치면 비용이 사용자 수에 비례한다.
  단 평문 HTTP 를 `NSAllowsArbitraryLoadsForMedia` 로 받겠다던 부분은 6번대로 흔들리고 있다.
  앱이 방송을 고르는 자리(프리셋 자동 선택)는 이미 `secure=1` 로 HTTPS 만 받는다
- 서버 LLM 은 분류·정규화를 Workers AI, 추천 문구를 OpenRouter 로 나눈다. 요청마다 부르지 않고
  하루 한 번 배치로 만들어 D1 에 넣어둔다. M3 의 추천은 아직 LLM 없이 규칙만 돈다
- 청취 기록·즐겨찾기·프리셋은 전부 기기 안(SwiftData)에만 둔다. 서버로 보내지 않는다
- 기기 LLM(Foundation Models)은 iOS 26 · A17 Pro 이상에서만 켜지는 덤이다. 없으면 점수 계산만 돌린다

**아직 안 정한 것**

- Podcast Index 키를 받아 Worker 시크릿 `PI_KEY`·`PI_SECRET` 에 넣었다. 검색과 인기 목록이
  Podcast Index 로 돈다(`/zp/v1/health` 의 `podcastIndexKeys` 로 확인한다)
- APNs 인증 키를 받았다. **Key ID `HDFVB5T2FZ`**(Production), Team `XU8HS9JUTS`.
  sandbox·배포 두 환경 모두 통한다(가짜 토큰에 양쪽 다 `400 BadDeviceToken`). 파일은
  `AuthKey_HDFVB5T2FZ.p8` 이고 저장소 맨 위에 두되 `.gitignore` 의 `*.p8` 로 막혀 있다.
  **재다운로드가 안 되는 유일본이다** — 집 서버 `~/work/backup/certs/` 와 R2 에 사본을 둔다.
  먼저 만든 `J32837LLMM` 은 개발 환경 전용이라 더 쓰지 않는다(포털에서 지워도 된다).
  번들 ID `com.zerolive.cloudRadioN` 에 Push Notifications 를 켰고 Time Sensitive 는 신청했다
- 방송국을 받아오는 나라는 지금 15개다. 사용자가 실제로 듣는 나라를 보고 넓힌다
  (`server/wrangler.toml` 의 `SYNC_TOP_COUNTRIES`)
- AdMob 앱 등록이 앱 인증에서 막혀 있다. 원인과 푸는 법은 6-15 절. 광고 단위 ID 는 M8

## 8. 아직 안 끝난 숙제

**YouTube API 키 폐기.** 1.x 저장소의 `AppDelegate.swift:20` 과
`YoutubePlaylistDownloader.swift:17` 에 `AIzaSy...UC-w` 키가 박혀 있고 이력에 남아 있다.
API 키는 만료가 없으므로 Google Cloud 콘솔에서 직접 지워야 한다. 2.0 은 유튜브를 쓰지 않으니
새 키는 필요 없다. **아직 안 했다.**

서명 인증서(.p12 4개, .cer 1개)는 1.x 저장소에서 삭제했다. 2022-11 에 만료된 것이라 별도
폐기 절차는 밟지 않았다.
