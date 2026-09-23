# 작업 인계 메모

다른 세션에서 이 저장소를 처음 열었을 때 읽는 문서다. 지금까지 한 일과 다음에 할 일만 적는다.
기획 배경과 근거는 `docs/` 에 번호순으로 있다. 처음이면 `docs/00-concept.md` 부터 읽는다.

마지막 갱신: 2026-09-23 (M0 완료 시점)

## 1. 현재 상태

M0 까지 끝났다. 빈 SwiftUI 앱이 시뮬레이터에서 실행되고 탭 5개가 보인다. 재생은 아직 안 된다.

```sh
cd /Users/zerolive/work/zeroplayer
export PATH="/opt/homebrew/bin:$PATH"   # xcodegen 이 여기 있다
xcodegen generate
xcodebuild -project zeroPlayer.xcodeproj -scheme zeroPlayer \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

`.xcodeproj` 는 커밋하지 않는다. `project.yml` 로 매번 만든다.

## 2. 저장소 두 곳

| 경로 | 용도 |
| --- | --- |
| `/Users/zerolive/work/zeroplayer` | 2.0 본체. 원격 `github.com/leonardo204/zeroplayer` |
| `/Users/zerolive/work/cloudRadio_ios` | 1.7 원본. 참고용으로만 본다. 원격 `github.com/leonardo204/cloudRadio_ios` |

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

## 5. 다음 할 일 — M1 (재생)

프록시 없이 하드코딩한 방송국 두세 개로 재생 경로부터 완성한다. 여기가 흔들리면 뒤가 전부 흔들린다.

- [ ] `AudioPlayerService` 에 `AVPlayer` 연결 (지금은 상태 기계만 있다)
- [ ] `AudioSessionManager` — 카테고리 `.playback`, 인터럽트 처리
- [ ] `NowPlayingCenter` — 잠금화면 정보와 원격 명령(재생·일시정지·다음·이전)
- [ ] 미니 플레이어와 전체 재생 화면 실제 동작
- [ ] 스트림 실패 감지 — 15초 안에 첫 오디오가 없으면 실패 처리
- [ ] ICY 메타데이터로 곡명이 오는지 실측 (`AVPlayerItem` 타임드 메타데이터)

**완료 기준** — 화면을 끄고 주머니에 넣어도 30분 이상 끊기지 않는다. 전화를 받고 끊으면 재생이
이어진다. 잠금화면에서 일시정지·재생이 된다.

이후 마일스톤은 `docs/07-roadmap.md` 에 M8 까지 있다. 순서는 M2 프록시·데이터 → M3 프리셋·타이머
→ M4 큐레이션 → M5 팟캐스트 → M6 알람 → M7 히든 라디오 → M8 광고·출시.

## 6. 정해둔 것과 아직 안 정한 것

**정한 것**

- 최소 iOS 17.0. SwiftUI + SwiftData + `@Observable`
- 의존성은 SPM 만 쓴다. CocoaPods 를 쓰지 않는다
- Swift 6 툴체인을 쓰되 언어 모드는 5 로 시작한다. `AVPlayer` KVO 와 SwiftData 모델이
  `Sendable` 이 아니라 M1 에서 막힌다. M3 이후에 올린다
- 평문 HTTP 스트림은 `NSAllowsArbitraryLoadsForMedia` 로 받는다. 프록시 중계를 하지 않는다 —
  오디오 대역폭이 전부 Worker 를 거치면 비용이 사용자 수에 비례한다
- 서버 LLM 은 분류·정규화를 Workers AI, 추천 문구를 OpenRouter 로 나눈다. 요청마다 부르지 않고
  하루 한 번 배치로 만들어 D1 에 넣어둔다
- 기기 LLM(Foundation Models)은 iOS 26 · A17 Pro 이상에서만 켜지는 덤이다. 없으면 점수 계산만 돌린다

**아직 안 정한 것**

- APNs 인증 키(.p8)를 아직 안 만들었다. App Store Connect 키와 별개다. M6 에서 필요하다
- Cloudflare Worker 쪽 코드는 한 줄도 없다. M2 에서 시작한다
- AdMob 광고 단위 ID 를 아직 안 만들었다. M8

## 7. 아직 안 끝난 숙제

**YouTube API 키 폐기.** 1.x 저장소의 `AppDelegate.swift:20` 과
`YoutubePlaylistDownloader.swift:17` 에 `AIzaSy...UC-w` 키가 박혀 있고 이력에 남아 있다.
API 키는 만료가 없으므로 Google Cloud 콘솔에서 직접 지워야 한다. 2.0 은 유튜브를 쓰지 않으니
새 키는 필요 없다. **아직 안 했다.**

서명 인증서(.p12 4개, .cer 1개)는 1.x 저장소에서 삭제했다. 2022-11 에 만료된 것이라 별도
폐기 절차는 밟지 않았다.
