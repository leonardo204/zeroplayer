# 작업 인계 메모

다른 세션에서 이 저장소를 처음 열었을 때 읽는 문서다. 지금까지 한 일과 다음에 할 일만 적는다.
기획 배경과 근거는 `docs/` 에 번호순으로 있다. 처음이면 `docs/00-concept.md` 부터 읽는다.

마지막 갱신: 2026-09-24 (M2 완료, 실기기 확인 전)

## 1. 현재 상태

M2 까지 들어갔다. 프록시 Worker 가 돌고 있고, 앱의 탐색 탭이 서버에서 받은 방송국 2,845개를
띄우고 그중 하나를 누르면 재생된다. 앱 소스에 스트림 주소는 한 줄도 없다.
실기기 확인(백그라운드 30분, 전화 인터럽트, 잠금화면 조작, 평문 HTTP)은 아직 안 했다.

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

## 6-2. 다음 할 일 — M3 (프리셋과 타이머)

`docs/07-roadmap.md` 의 M3 을 따른다. 그 전에 실기기 확인 네 줄을 끝내는 편이 낫다 —
평문 HTTP 결과에 따라 목록에 `secure=1` 을 붙일지가 갈린다.

**실기기에서 확인할 것**

- [ ] 화면을 끄고 30분 이상 끊기지 않는지
- [ ] 전화를 받고 끊으면 재생이 이어지는지
- [ ] 잠금화면에서 일시정지·재생이 되는지
- [ ] 평문 HTTP 스트림이 실기기에서도 막히는지

## 7. 정해둔 것과 아직 안 정한 것

**정한 것**

- 최소 iOS 17.0. SwiftUI + SwiftData + `@Observable`
- 의존성은 SPM 만 쓴다. CocoaPods 를 쓰지 않는다
- Swift 6 툴체인을 쓰되 언어 모드는 5 로 시작한다. `AVPlayer` KVO 와 SwiftData 모델이
  `Sendable` 이 아니라 M1 에서 막힌다. M3 이후에 올린다.
  지금 남은 경고는 하나뿐이고(`AVMetadataItem.stringValue` deprecated) 이유는 코드 주석에 적어뒀다
- 프록시 중계를 하지 않는다 — 오디오 대역폭이 전부 Worker 를 거치면 비용이 사용자 수에 비례한다.
  단 평문 HTTP 를 `NSAllowsArbitraryLoadsForMedia` 로 받겠다던 부분은 6번대로 흔들리고 있다
- 서버 LLM 은 분류·정규화를 Workers AI, 추천 문구를 OpenRouter 로 나눈다. 요청마다 부르지 않고
  하루 한 번 배치로 만들어 D1 에 넣어둔다
- 기기 LLM(Foundation Models)은 iOS 26 · A17 Pro 이상에서만 켜지는 덤이다. 없으면 점수 계산만 돌린다

**아직 안 정한 것**

- APNs 인증 키(.p8)를 아직 안 만들었다. App Store Connect 키와 별개다. M6 에서 필요하다
- 방송국을 받아오는 나라는 지금 15개다. 사용자가 실제로 듣는 나라를 보고 넓힌다
  (`server/wrangler.toml` 의 `SYNC_TOP_COUNTRIES`)
- AdMob 광고 단위 ID 를 아직 안 만들었다. M8

## 8. 아직 안 끝난 숙제

**YouTube API 키 폐기.** 1.x 저장소의 `AppDelegate.swift:20` 과
`YoutubePlaylistDownloader.swift:17` 에 `AIzaSy...UC-w` 키가 박혀 있고 이력에 남아 있다.
API 키는 만료가 없으므로 Google Cloud 콘솔에서 직접 지워야 한다. 2.0 은 유튜브를 쓰지 않으니
새 키는 필요 없다. **아직 안 했다.**

서명 인증서(.p12 4개, .cer 1개)는 1.x 저장소에서 삭제했다. 2022-11 에 만료된 것이라 별도
폐기 절차는 밟지 않았다.
