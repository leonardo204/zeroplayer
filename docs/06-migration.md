# 1.x 에서 옮기는 것과 버리는 것

기준 저장소는 `/Users/zerolive/work/cloudRadio_ios` (커밋 `7dd8f32`). Swift 22개 파일, 5,923줄.

## 1. 먼저 해야 하는 일 — 유출된 비밀

재작성과 무관하게 급하다. 둘 다 원격(`github.com/leonardo204/cloudRadio_ios`)에 올라가 있고 파일만 지워도 이력에 남는다.

**개인키.** 커밋 `cbf472c` 에 `인증서/` 폴더의 `.p12` 4개와 `.cer` 1개가 들어 있었다. `.cer` 는 `cloudradio dist`(배포용) 인증서로 **2022-11-17 에 만료됐다.** 2021~2022년에 함께 쓰던 묶음이라 `.p12` 도 같은 시기 것으로 보고 폐기 절차 없이 넘어가기로 했다. 현재 서명에 쓰는 인증서는 키체인에 따로 있고 저장소에 들어간 적이 없다. `인증서/` 폴더는 2026-09-23 에 저장소에서 삭제했고 `.gitignore` 에 `*.p12`·`*.cer`·`*.p8`·`*.mobileprovision` 을 넣었다. 이력에는 남지만 만료된 키라 그대로 둔다.

**YouTube API 키.** `AppDelegate.swift:20` 과 `YoutubePlaylistDownloader.swift:17` 에 같은 키가 박혀 있다. API 키는 만료가 없으므로 이건 반드시 Google Cloud 콘솔에서 폐기한다. 2.0 은 유튜브를 쓰지 않으므로 새 키가 필요 없다.

저장소는 비공개다(익명 API 조회 404). 공개 유출은 아니지만 비공개 저장소도 협업자나 토큰 유출로 열릴 수 있으니 폐기 원칙은 같다. 둘 다 콘솔에서 직접 해야 한다. 키 폐기가 먼저고 이력 정리는 그다음이다.

## 2. 그대로 옮기는 것

| 자산 | 어디로 |
| --- | --- |
| 번들 ID `com.zerolive.cloudRadioN` | 그대로. 2.0 업데이트로 올린다 |
| 한국 지상파 채널 14개의 이름·`.pls` 주소·채널코드 | 프록시 D1 `stations` 표 (`is_hidden = 1`) |
| 방송사 편성표 파싱 규칙 | 프록시. 아래 3번 |
| CBS 음악FM 편성표 13줄 | 프록시 D1. 시각표는 그대로, 이미지 주소는 갈아끼운다 |
| `Log` 구조체 (`os.log` 래퍼) | `Core/Logging`. `privacy: .public` 기본값과 릴리스 빌드 제외를 고친다 |
| 아이콘·이미지 자산 | `Resources/Assets.xcassets` |

## 3. 프록시로 옮기는 파싱 규칙

`RadioChannelResources.swift`(619줄)에 있는 규칙이다. 로직은 유효하니 서버 코드로 옮긴다.

| 방송사 | 규칙 |
| --- | --- |
| KBS | `onair.kbs.co.kr` 페이지의 `og:image`·`og:description` 메타 태그. 설명 문자열 끝에서 시간 `HH:MM~HH:MM` 을 잘라낸다 |
| MBC | `control.imbc.com/Schedule/PCONAIR?type=radio` JSON. `RadioList` 에서 `TypeTitle` 이 "표준FM"·"FM4U" 인 항목 |
| SBS | `sbs.co.kr/{ko\|en}/live` 의 `__NEXT_DATA__` 스크립트 블록. `props.pageProps.radio` 배열에서 `channelname` 매칭 |
| TBS | `tbs.seoul.kr/player/live.do` HTML 본문. `<span class="time">` 과 `<span class="tit">`, 스크립트의 `posterUrl` |
| CBS | 코드에 박힌 편성표. 웹 파싱 없음 |
| AFN | 고정 이미지 하나. 편성표 없음 |

**옮길 때 반드시 고칠 것.** 원본은 전부 강제 언랩이다. `value.index(of: "...")!` 형태라 방송사가 페이지를 조금만 바꿔도 크래시였다. 서버에서는 실패를 허용하고, 실패하면 프로그램 정보를 비워 응답한다.

SBS·MBC 파싱의 `for i in 0...arrayLength` 는 배열 끝을 한 칸 넘어가는 반복문이다. `0..<` 로 고친다.

`24:00` 을 시각으로 다루는 처리(`CloudRadioUtils`)는 발상은 맞지만 문자열 비교로 분기가 흩어져 있다. 서버에서는 종료 시각을 UTC 타임스탬프로 정규화해 내보낸다.

## 4. 버리는 것

| 대상 | 이유 |
| --- | --- |
| `Youtube/` 전체 (614줄) | 유튜브 기능 제거 |
| `YoutubeKit`, `Alamofire` | 위와 함께. HTTP 는 `URLSession` |
| `Kanna`, `SwiftyJSON` | 파싱이 서버로 옮겨간다 |
| `QuickTableViewController`, `MarqueeLabel` | SwiftUI 로 대체 |
| CocoaPods 전체 (`Pods/` 198파일, `Pods_local_bk/` 133파일) | SPM only |
| `Main.storyboard`, xib 5개 | SwiftUI |
| `CloudRadioShareValues` (static var 30여 개) | `@Observable` 상태 객체. UI 요소(`UILabel?`·`UISlider?`)를 전역에 담던 부분이 특히 문제였다 |
| `Notification.Name` 22개 | 화면 간 통신을 타입 있는 인터페이스로 바꾼다 |
| `MainViewController` (986줄) | `RootView` + `AudioPlayerService` 로 쪼갠다 |
| `AlarmCell.swift` (798줄, 코드로 만든 오토레이아웃) | SwiftUI 알람 화면 |
| `exit(0)` 강제 종료 | 애플 금지 |
| `NSAllowsArbitraryLoads = true` | 프록시는 HTTPS. 평문 스트림은 `NSAllowsArbitraryLoadsForMedia` 로만 연다 |
| `UIFileSharingEnabled`, `LSSupportsOpeningDocumentsInPlace` | Documents 폴더를 파일 앱에 노출하던 설정. SwiftData 라 필요 없다 |
| `release/` 폴더 (6MB, 2021년 사설 배포 기록) | 쓰지 않는다 |
| `download.html` (Dropbox manifest 배포 페이지) | 쓰지 않는다 |
| `getKBSFMAddressByChannelCode`, `startKBSRadio` | 이미 죽은 코드. 2023-07-24 주석에 따라 KBS 도 `.pls` 로 전환됐다 |
| `AppDelegate` 의 알림 델리게이트 확장 | 실제 델리게이트는 `MainViewController` 였다. 죽은 코드 |
| 화면잠금 감지 주석 블록 | 심사 반려 이력이 주석으로 남아 있다 |

## 5. 고쳐야 할 버그 — 재작성해도 같은 실수를 반복하지 않기 위해 기록한다

**타이머 유효성 검사가 항상 참이다.**

```swift
if ( self.mainRadioTimer?.isValid ) != nil {   // 잘못됨
```

`isValid` 값을 보는 게 아니라 옵셔널이 nil 인지 보고 있다. 타이머가 이미 멈췄어도 참이다. 1.x 코드 여러 곳에 같은 형태가 있다.

**조건문 안에서 부수효과를 일으킨다.**

```swift
// TimerTableViewCell.swift
if ( CloudRadioShareValues.drawRadioTimeTimer?.invalidate() ) != nil {
```

조건을 평가하면서 `invalidate()` 를 호출한다. `Void?` 를 비교하는 꼴이다.

2.0 은 타이머를 `SleepTimer` 하나로 모으고 `Task` 와 `AsyncTimerSequence` 를 쓴다. 1.x 의 타이머 7개가 서로를 무효화하는 순서 문제가 근본 원인이었다.

**배열 경계를 넘는 반복문.** 3번에 적었다.

## 6. 사용자 데이터 이관

1.x 는 `Documents/` 에 JSON 두 개를 쓴다.

- `CRSettings.json` — 히든 해제 여부, 랜덤/연속 재생, 알람 설정
- `CRChannels.json` — 사용자가 구성한 채널 목록 (라디오 + 유튜브 재생목록)

2.0 첫 실행 때 이 파일이 있으면 읽어 옮긴다.

| 1.x 값 | 2.0 |
| --- | --- |
| `isUnlocked: true` | 히든 기능 해제 상태 유지. 서버에서 히든 토큰을 받아 키체인에 저장 |
| 알람 설정 (시·분·요일·프로그램) | `alarmProgram`(채널 제목)을 히든 채널 ID 로 매핑해 `AlarmSetting(sourceKind: .station)` 으로 옮기고 서버에 등록. 매핑이 안 되면 `.auto` + `wake` 로 둔다 |
| 채널 목록 중 `type: 0` (라디오) | 히든 즐겨찾기로 옮긴다 |
| 채널 목록 중 `type: 1` (유튜브 재생목록) | **버린다.** 마이그레이션 완료 안내에 "유튜브 재생목록 기능이 없어졌다"를 한 줄 적는다 |
| `isShuffle`, `isRepeat` | 유튜브 전용이었다. 버린다 |

이관 후 원본 JSON 은 지우지 않고 남겨 둔다. 되돌릴 수 있게.

**유튜브 재생목록을 쓰던 사용자에게는 안내가 필요하다.** 앱 첫 실행 시 한 번만 뜨는 화면에 이유를 짧게 적는다. 약관 조항을 인용할 필요는 없다. "유튜브 재생목록 재생 기능이 없어졌고, 대신 전 세계 인터넷 라디오와 팟캐스트가 들어왔다" 정도면 된다.

## 7. 저장소 정리

새 저장소 `/Users/zerolive/work/zeroplayer` 에 처음부터 짓는다. 지금 저장소는 참고물로 남긴다.

`.gitignore` 에 넣을 것.

```
*.xcodeproj/
*.xcworkspace/
!*.xcworkspace/contents.xcworkspacedata
.build/
DerivedData/
xcuserdata/
.DS_Store
Secrets.xcconfig
```

XcodeGen 을 쓰므로 `.xcodeproj` 를 커밋하지 않는다. 인증서와 키는 어떤 형태로도 저장소에 넣지 않는다.
