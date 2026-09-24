# iOS 앱 구조

## 1. 기술 선택

| 항목 | 값 | 이유 |
| --- | --- | --- |
| 최소 iOS | **17.0** | SwiftData 와 Observation 이 여기서 시작한다. iOS 18 로 올릴 실익이 없다 |
| UI | SwiftUI | Storyboard 를 버린다. 1.x 의 `Main.storyboard` + xib 5개가 화면 흐름을 감췄다 |
| 저장 | SwiftData | JSON 파일 직접 읽기·쓰기를 대체한다 |
| 상태 | `@Observable` | 1.x 의 static 전역 30여 개를 대체한다 |
| 동시성 | Swift Concurrency | 타이머와 `DispatchQueue.global()` 혼용을 대체한다 |
| 프로젝트 파일 | XcodeGen (`project.yml`) | `.xcodeproj` 를 커밋하지 않는다 |
| 의존성 | SPM only | CocoaPods 를 쓰지 않는다. `Pods/` 를 커밋하지 않는다 |
| 번들 ID | `com.zerolive.cloudRadioN` | 1.x 와 같다. 2.0 업데이트로 올린다 |
| 팀 | XU8HS9JUTS | |

Swift 6 툴체인을 쓰되 **언어 모드는 처음에 5 로 두고** `SWIFT_STRICT_CONCURRENCY = complete` 경고를 켠다. `AVPlayer` 의 KVO 와 SwiftData 모델은 `Sendable` 이 아니라, 6 모드에서 처음부터 막히면 재생 구조를 잡는 M1 이 느려진다. M3 이후 경고가 0 이 되면 6 모드로 올린다. 1.x 의 전역 static 변수가 전부 없어지므로 올리는 데 구조적 장애는 없다.

`FoundationModels` 는 iOS 26 프레임워크다. 최소 iOS 가 17 이므로 `#if canImport(FoundationModels)` 와 `@available(iOS 26, *)` 로 감싸고, iOS 17 기기에서 프레임워크 로드 실패로 앱이 죽지 않는지는 실기기로 확인해야 한다(아직 안 했다).

## 2. 디렉터리

```
zeroplayer/
├ project.yml                  XcodeGen
├ Package.swift 없음           의존성은 project.yml 의 packages 로
├ docs/
└ Sources/
  ├ App/
  │   ZeroPlayerApp.swift       @main, SwiftData 컨테이너 주입
  │   RootView.swift            TabView + 미니 플레이어
  │   AppEnvironment.swift      의존성 조립
  ├ Features/
  │   Recommend/                추천 탭
  │   Discover/                 탐색 탭
  │   Presets/                  프리셋 탭
  │   Stats/                    기록 탭
  │   Settings/                 설정 탭
  │   Player/                   재생 화면 + 미니 플레이어
  │   Alarm/                    알람 설정
  │   Hidden/                   히든 라디오 (해제 전에는 어느 화면에도 안 나온다)
  ├ Core/
  │   Player/
  │     AudioPlayerService.swift   AVPlayer 래퍼. 앱에서 유일한 재생 주체
  │     NowPlayingCenter.swift     잠금화면 정보와 원격 명령
  │     SleepTimer.swift           자동 종료 + 페이드아웃
  │     AudioSessionManager.swift  카테고리 설정과 인터럽트 처리
  │   Networking/
  │     ProxyClient.swift          ai.zerolive.co.kr 전용 클라이언트
  │     DTO/                       서버 응답 구조체
  │   Persistence/
  │     Models/                    SwiftData @Model
  │     Store/                     조회·저장 래퍼
  │   Curation/
  │     Personalizer.swift         청취 기록으로 재정렬 (기기)
  │     OnDeviceReasoner.swift     FoundationModels. iOS 26 에서만 동작
  │   Notifications/
  │     PushRegistrar.swift        APNs 토큰 등록
  │     LocalAlarmScheduler.swift  로컬 알림 백업
  │   Ads/
  │     AdBanner.swift             SwiftUI 래퍼
  │     AdPlacement.swift          화면별 노출 여부를 한 곳에서 판정
  └ Resources/
      Assets.xcassets
      Sounds/                      알람 사운드
```

## 3. 재생 구조 — 여기가 1.x 와 가장 크게 갈린다

1.x 는 `MainViewController`(986줄)가 재생 분기·타이머 3개·알림 수신자 16개를 전부 들고 있었다. 화면끼리는 `Notification.Name` 22개로 통신했다. 컴파일러가 검증해 주는 것이 없었다.

2.0 은 **재생 주체를 하나로** 만든다.

```swift
@MainActor @Observable
final class AudioPlayerService {
    private(set) var state: PlaybackState   // .idle/.loading/.playing/.paused/.failed
    private(set) var current: PlayableItem?
    private(set) var elapsed: TimeInterval

    func play(_ item: PlayableItem) async
    func pause()
    func resume()
    func stop()
    func next() async        // 프리셋의 다음 소스 또는 추천 다음 항목
    func previous() async
}
```

`PlayableItem` 이 라디오·팟캐스트·히든 채널을 하나로 감싼다. 재생 코드는 종류를 구분하지 않는다. 종류별로 다른 것은 **메타데이터를 어디서 받는지**뿐이고, 그건 프록시가 흡수한다.

화면은 `AudioPlayerService` 를 `@Environment` 로 받아 `state` 를 읽는다. `NotificationCenter` 는 시스템 이벤트(오디오 인터럽트, 앱 생애주기)에만 쓴다.

## 4. SwiftData 모델

```swift
@Model final class Preset {
    var name: String
    var symbolName: String
    var sourceKind: SourceKind      // .station / .podcast / .auto
    var sourceID: String?
    var timerMinutes: Int?
    var fadeOutSeconds: Int
    var order: Int
}

@Model final class CachedStation {         // 프록시 응답 캐시. 오프라인 대비
    @Attribute(.unique) var id: String
    var name: String
    var countryCode: String
    var tags: [String]
    var moods: [String]
    var homepage: URL?
    var faviconURL: URL?
    var fetchedAt: Date
}

@Model final class Favorite {
    var itemID: String
    var kind: SourceKind
    var title: String
    var addedAt: Date
}

@Model final class ListeningSession {
    var itemID: String
    var kind: SourceKind
    var title: String
    var startedAt: Date
    var duration: TimeInterval
    var presetName: String?
    var fromRecommendation: Bool
    var skippedEarly: Bool          // 30초 안에 넘겼는지
}

@Model final class AlarmSetting {
    var isEnabled: Bool
    var hour: Int
    var minute: Int
    var weekdays: Set<Int>          // 1=일 ... 7=토
    var sourceKind: SourceKind      // .station / .podcast / .auto  (03 의 alarms.source 와 같다)
    var sourceID: String?
    var situation: String?          // sourceKind == .auto 일 때 'wake' 등
    var serverAlarmID: String?      // 서버에 등록된 알람 ID
}
```

스트림 URL 은 캐시하지 않는다. 재생 직전에 프록시에 물어 받는다. 방송국이 주소를 바꿔도 앱을 고칠 필요가 없게 하려는 것이다.

## 5. 네트워크

앱은 `ai.zerolive.co.kr` 한 곳만 부른다. radio-browser, Podcast Index, 방송사 페이지에 직접 접근하지 않는다.

```swift
protocol ProxyClienting {
    func recommendations(context: SituationContext) async throws -> [Recommendation]
    func stations(query: StationQuery) async throws -> [Station]
    func streamURL(stationID: String) async throws -> URL
    func podcastEpisodes(feedID: String) async throws -> [Episode]
    func hiddenChannels() async throws -> [HiddenChannel]
    func nowPlaying(hiddenChannelID: String) async throws -> ProgramInfo
    func registerAlarm(_ setting: AlarmSetting, pushToken: String) async throws -> String
    func reportDeadStream(stationID: String) async throws
}
```

`URLSession` 을 그대로 쓴다. Alamofire 를 넣지 않는다.

**ATS 를 정상으로 돌린다.** 1.x 는 `NSAllowsArbitraryLoads = true` 였다. 프록시가 HTTPS 이므로 필요 없다. 다만 인터넷 라디오 스트림 중 상당수가 평문 HTTP 다. 도메인이 수천 개라 `NSExceptionDomains` 로 하나씩 열 수는 없다. 기본안은 **`NSAllowsArbitraryLoadsForMedia`** 다. AVFoundation 이 여는 미디어 로드에만 예외를 주는 키라 용도가 정확히 맞고, 심사 설명도 '인터넷 라디오 스트림 재생' 한 줄이면 된다. 프록시가 오디오를 HTTPS 로 중계하는 안은 쓰지 않는다. 장시간 연결과 대역폭이 전부 Worker 를 거치게 되어 비용과 제한이 사용자 수에 비례한다. M2 에서 스트림을 실측해 HTTP 비율이 무시할 만큼 적으면 그때 예외를 뺀다.

## 6. 오프라인

- 방송국 목록과 최근 추천은 SwiftData 에 캐시한다. 네트워크가 없으면 캐시를 보여준다.
- 스트림 URL 은 캐시하지 않으므로 오프라인에서는 재생이 안 된다. 이건 어쩔 수 없다.
- 프리셋·즐겨찾기·청취 기록은 전부 로컬이라 항상 열린다.

## 7. 로깅

1.x 의 `Log` 구조체(`os.log` 래퍼)는 쓸 만하다. 가져오되 두 가지를 고친다.

- `privacy: .public` 을 기본으로 두지 않는다. 채널 이름 같은 값은 사용자 취향 정보다.
- 릴리스 빌드에서 디버그 레벨을 컴파일 시점에 뺀다. 1.x 는 `//#if LOG` 가 주석 처리돼 있어 전부 살아 있었다.

## 8. 테스트

전체 커버리지를 목표로 하지 않는다. 깨지면 조용히 아픈 곳만 잡는다.

- 타이머와 페이드아웃 — 시각을 주입 가능하게 만들고 단위 테스트를 쓴다.
- 추천 재정렬 로직 — 청취 기록을 넣고 순서가 기대대로 나오는지 본다.
- 프록시 DTO 디코딩 — 실제 응답 샘플을 픽스처로 둔다.
- 알람 요일 계산 — 1.x 에서 버그가 나기 쉬웠던 부분이다.
