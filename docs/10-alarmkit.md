# 10. AlarmKit 알람 — 실기기 측정과 설계

2026-09-25, iPhone 18 Pro Max / iOS 27.0, Xcode 27 에서 직접 재고 쓴 문서다.
측정에 쓴 시험 앱은 `/Users/zerolive/work/alarmkit-probe` 에 있다.

`01-features.md` 5장의 전제 중 둘이 틀렸다는 것을 이 측정으로 확인했다. 그 절은 이 문서를 따라 고친다.

## 10.1 결론

알람 시각에 **탭 한 번**으로 실시간 라디오가 나온다. 앱 화면은 열리지 않는다. 밤새 오디오 세션을 붙들고 있을 필요가 없다.

조건이 하나 있다. 알람 버튼에 물리는 App Intent 가 `LiveActivityIntent` 와 **`AudioPlaybackIntent` 를 함께 채택**해야 한다. 이것이 빠지면 오디오 세션이 열리지 않는다. 애플 문서에 적혀 있지 않고, 재봐야만 알 수 있다.

탭 없는 완전 자동 재생은 여전히 안 된다. 앱 프로세스가 죽어 있으면 `alarmUpdates` 가 오지 않는다.

깨우는 소리는 아직 미결이다. 방송을 알람음으로 넣으면 소리가 난다. 다만 시스템 기본 알람음보다 작게 들리고, 그 원인을 끝까지 가리지 못했다(10.5).

## 10.2 측정 결과

### 되는 것

| 확인한 것 | 결과 |
| --- | --- |
| 앱을 강제 종료(SIGKILL)한 뒤 알람 발화 | 제시간에 울린다 |
| 알람 버튼 탭 → 앱 프로세스 기동 | 화면을 열지 않고 프로세스만 깨어난다 (`appState=background`) |
| 그 프로세스에서 `setActive(true)` | 첫 시도에 0.0초로 성공 |
| 실시간 MP3 스트림 재생 | 40초 관측 구간 내내 끊김 없음 (`keepUp=true`) |
| `perform` 반환 뒤 | 재생이 계속된다 |
| 정지 버튼 · 보조 버튼 | 둘 다 같은 결과 |
| 알람 예약 개수 | 1000건 전부 성공. `maximumLimitReached` 안 남 |
| 예약 뒤 사운드 파일 덮어쓰기 | 덮어쓴 새 소리로 울린다 — 발화 시점에 파일을 읽는다 |
| 무음 모드 · 집중 모드 | AlarmKit 이 뚫는다. Critical Alerts 엔타이틀먼트가 필요 없다 |
| PCM WAV 를 알람음으로 | 소리가 난다. 22.05kHz · 16bit · 모노 · 25초로 확인 |
| 서버에서 방송 앞부분을 받아 알람음으로 | 된다. 받는 데 13~15초, 폰에서 PCM 변환은 0.1초 |

### 안 되는 것

| 확인한 것 | 결과 |
| --- | --- |
| 탭 없이 `alarmUpdates` 로 자동 재생 | 프로세스가 살아 있을 때만 된다. 죽어 있으면 깨어나지 않는다 |
| `AudioPlaybackIntent` 없이 세션 열기 | 20초 동안 40번 연속 거부 |
| 거부된 뒤 `mixWithOthers` 우회 | 세션은 열리지만 `rate=0.0` 으로 재생이 안 붙는다 |
| 커스텀 알람음 반복 | 한 번 울리고 끝난다. 30초 미만이어야 한다 |
| MP3 를 알람음으로 | 알람 화면은 뜨는데 **소리가 안 난다.** 오류도 안 남는다 |
| 시뮬레이터에서 알람 화면 | 상태는 `alerting` 으로 바뀌지만 UI 가 그려지지 않는다. 버튼 시험을 못 한다 |

### 세션이 거부될 때 나오는 오류

```
NSOSStatusErrorDomain code=560557684 ('!int') Session activation failed
```

`AVAudioSessionErrorCodeCannotInterruptOthers` 다. 울리고 있는 알람음을 끊을 수 없다는 뜻이다. `AudioPlaybackIntent` 를 채택하면 이 오류가 사라진다.

## 10.3 그래서 어떻게 만드는가

### 인텐트

```swift
struct WakeRadioIntent: LiveActivityIntent, AudioPlaybackIntent {
    static var title: LocalizedStringResource = "방송 켜기"
    static var isDiscoverable: Bool = false

    @Parameter(title: "알람 ID") var alarmID: String

    func perform() async throws -> some IntentResult {
        // 오디오 세션을 켜고 스트림을 건다. 화면은 열리지 않는다.
        // perform 이 반환돼도 재생은 이어진다.
    }
}
```

`AudioPlaybackIntent` 를 빼면 동작하지 않는다. 지우지 말 것.

### 알람 구성

```swift
let alert = AlarmPresentation.Alert(
    title: "알람",
    // stopButton 을 생략한 초기화는 iOS 26.1 부터다. 26.0 도 받으려면 직접 넘긴다.
    stopButton: AlarmButton(text: "끄기", textColor: .white, systemImageName: "stop.fill"),
    secondaryButton: AlarmButton(text: "방송 켜기", textColor: .white,
                                 systemImageName: "dot.radiowaves.left.and.right"),
    secondaryButtonBehavior: .custom)
```

`Info.plist` 에 `NSAlarmKitUsageDescription` 이 있어야 한다. 값이 비면 알람을 걸 수 없다. 권한 창의 앞 두 문단은 시스템이 쓰고, 우리 문장은 그 아래 한 줄로 붙는다.

### 깨울 때까지 이어가기

커스텀 알람음은 한 번 울리고 끝난다. 그래서 **2분 간격으로 여러 개를 함께 걸고**, 사용자가 끄거나 앱을 열면 남은 것을 전부 취소한다. 개수는 제약이 아니다.

### 알람음 — 시스템 기본음을 쓴다

깨우는 소리는 `sound: .default` 하나다. 방송은 알람 화면의 단추를 누른 뒤부터 나온다.

방송 앞 30초를 알람음으로 넣는 것도 된다. 실제로 되는 것까지 확인했고 아래에 재본 값을 남겨 뒀다. 그런데 커스텀 알람음은 **한 번 울리고 끝나고**(기본음은 1분 넘게 반복된다) **기본음보다 작게 들린다.** 잠을 깨우는 일에 둘 다 불리하다. 그래서 접었다.

접은 자리의 구조는 이렇게 단순해진다.

| 단계 | 언제 | 누가 |
| --- | --- | --- |
| 알람 설정 | 사용자가 설정할 때 | 앱 (서버에는 동기화만) |
| 기본음으로 울림 | 알람 시각 | 시스템 |
| 단추를 누르면 실시간 방송 | 사용자가 깨어난 뒤 | 앱 (인텐트) |

방송을 알람음으로 쓰려면 서버가 조각을 만들어 주고 폰이 받아 두는 단계가 붙는데, 그 단계가 전부 없어진다.

아래는 그 길을 재 본 기록이다. 다시 꺼낼 때를 위해 남긴다. 알람음 파일은 **발화 시점에** `Library/Sounds` 를 읽으므로, 예약을 다시 걸지 않고 앱이 열릴 때마다 최신 조각으로 갈아 끼울 수 있다.

#### 형식

**MP3 는 쓸 수 없다.** 알람 화면은 뜨는데 소리가 나지 않고, 오류도 남지 않는다. 링형 PCM 으로 바꿔야 한다. 22.05kHz · 16bit · 모노 · 25초로 확인했다.

바꾸는 곳은 둘 중 하나다.

| 어디서 | 전송량 | 폰이 하는 일 |
| --- | --- | --- |
| 폰에서 변환 | 401KB (MP3) | `AVAssetReader` 로 0.1초 만에 바꾼다 |
| 서버에서 변환 | 1.1MB (WAV) | 받아서 쓰기만 한다 |

지금 시험은 폰에서 바꿨다. 전송량이 3배 차이 나므로 이쪽이 낫다.

#### 크기

방송 원음은 알람음 기준으로 작다. 올드팝카페를 재보니 피크 −6.4dBFS, RMS −18.7dBFS 였다. 피크만 0dBFS 로 맞추면 6dB 밖에 못 올린다.

그래서 게인을 걸고 `tanh` 로 눌러 포화시킨다. +14dB 를 걸었을 때 폰에서 잰 값이다.

```
정규화 +14dB  피크 0.0->-0.0dBFS  RMS -15.7->-5.6dBFS
```

RMS 가 10dB 올랐는데도 **여전히 기본 알람음보다 작게 들린다.** 0dBFS 순음과 기본음을 나란히 울려 비교하는 시험까지 만들었지만(`./probe.sh devrun loudcmp:25`) 거기서 접었다. 어느 쪽이 원인이든 — 방송이 모자란 것이든 커스텀 알람음 경로가 눌리는 것이든 — 기본음을 쓰면 답이 필요 없어진다.

덧붙여 알람이 울리는 동안 **볼륨 키를 누르면 알람이 멈춘다.** 시계 앱과 같고 우리가 끼어들 자리가 없다.

#### 서버 엔드포인트

`GET /zp/v1/stations/:id/alarm-sound?seconds=25`

방송 앞부분을 잘라 그대로 내려준다. 구현은 `server/src/routes/alarmSound.ts` 다. 응답 헤더로 `x-zp-codec`, `x-zp-station`(퍼센트 인코딩), `x-zp-elapsed-ms` 를 준다.

**배포하지 않았고 경로도 걸지 않았다.** 파일은 남아 있지만 `src/index.ts` 에서 뺐다. 맥에서 `wrangler dev --remote` 로만 시험했다. 다시 열 때는 설치 ID 확인이나 상한을 함께 둔다 — 요청 하나가 방송 서버로 나가는 요청을 부르므로, 공개로 두면 남이 우리 Worker 를 중계기로 쓸 수 있다.

재본 것은 이렇다.

- MP3 방송 4곳 중 3곳에서 22~25초짜리 유효한 MP3 를 받았다
- 한 곳은 20초 타임아웃으로 500 을 냈다. 방송마다 버스트 속도가 달라 상한을 넉넉히 둬야 한다
- 헤더에 한글을 그대로 넣으면 Workers 가 경고한다. 퍼센트 인코딩해서 보낸다
- HLS 방송은 이 방식으로 못 받는다. MP3 방송만 된다

## 10.4 버전 분기

배포 타깃이 iOS 17 이라 두 갈래로 나눈다.

| iOS | 경로 |
| --- | --- |
| 26.0 이상 | AlarmKit. 무음 모드를 뚫고, 버튼 탭으로 스트리밍이 시작된다 |
| 25 이하 | 지금의 `LocalAlarmScheduler` 그대로. 알림을 탭해 앱이 열려야 재생된다 |

## 10.5 주의할 점

- 커스텀 알람음이 기본 알람음보다 작게 들리는 원인은 못 가렸다(방송이 모자란 것인지, 경로가 눌리는 것인지). 기본음을 쓰기로 해서 답이 필요 없어졌다. 다시 커스텀 알람음을 쓸 일이 생기면 시험 앱의 `loudcmp` 명령으로 0dBFS 순음과 기본음을 나란히 울려 가린다.
- 알람이 울리는 중에 볼륨 키를 누르면 소리가 끊긴다. 시계 앱도 같다. 우리 코드가 끼어들 자리는 없다.
- 인텐트 안에서 부른 `AlarmManager.stop(id:)` 이 `com.apple.AlarmKit.Alarm Code=0` 으로 실패한다. 실패해도 시스템이 알람을 정리하므로 동작에는 지장이 없다. 오류를 삼키고 넘어간다.
- 알람 1000건을 한꺼번에 취소한 직후 `AlarmManager.shared.alarms` 를 읽으면 앱이 조용히 죽었다. 실사용에서 그만큼 걸 일은 없지만, 목록을 읽는 곳에 방어를 둔다.
- 시뮬레이터로는 알람 UI 가 안 나온다. 버튼과 관련된 것은 실기기에서만 확인된다.

## 10.6 검토하지 않는 길

| 방법 | 왜 안 쓰는가 |
| --- | --- |
| 밤새 무음 오디오로 세션 유지 | 심사지침 2.5.4 로 리젝된다. "Background audio intended for setting and playing alarms is inappropriate because it can be replicated with Local Notifications" 가 실제 리젝 통보 문구다 |
| 무음 푸시로 알람 시각에 깨우기 | 앱을 스위처에서 밀어 끄면 배달되지 않고, 배달돼도 시점이 밀린다 |
| 단축어 자동화 | 앱이 개인 자동화를 대신 만들 수 없다. 미디어 볼륨으로 나고 스누즈가 없다. 실패해도 우리가 못 고친다 |

## 10.7 근거

- [App Store Review Guidelines 2.5.4](https://developer.apple.com/app-store/review/guidelines/) — "Multitasking apps may only use background services for their intended purposes"
- [Scheduling an alarm with AlarmKit](https://developer.apple.com/documentation/AlarmKit/scheduling-an-alarm-with-alarmkit) — "It overrides both a device's focus and silent mode, if necessary."
- WWDC25 세션 230 — 사운드 파일은 "app's main bundle or Library/Sounds folder of your app's data container"
- [AlarmKit play sound only once](https://developer.apple.com/forums/thread/797172) — 애플 엔지니어: 30초 미만, 반복은 미지원
- [gdelataillade/alarm discussion 87](https://github.com/gdelataillade/alarm/discussions/87) — 2.5.4 리젝 통보 원문 3건
- iOS 27.0 SDK `AppIntents.swiftinterface` — `AudioPlaybackIntent` 선언

## 10.8 구현된 곳

| 파일 | 하는 일 |
| --- | --- |
| `Sources/Core/Notifications/AlarmDelivery.swift` | 어느 길로 갈지 정한다. 두 길이 함께 돌면 두 번 울린다 |
| `Sources/Core/Notifications/AlarmKitScheduler.swift` | 알람을 연쇄로 걸고 치운다. 권한도 여기서 묻는다 |
| `Sources/Core/Notifications/AlarmIntents.swift` | 알람 화면의 두 단추. `AudioPlaybackIntent` 를 지우면 소리가 안 난다 |
| `Sources/Core/Notifications/AlarmPlaybackBridge.swift` | 화면 없이 재생기를 부르는 통로. 자동 선택 알람이 무엇을 틀지도 여기서 고른다 |
| `Sources/Core/Notifications/AlarmStore.swift` | `reschedule()` 에서 두 길을 가른다 |
| `Sources/Core/Notifications/PushRegistrar.swift` | AlarmKit 로 가면 APNs 등록을 건너뛰고 올려 둔 토큰을 지운다 |
| `project.yml` | `NSAlarmKitUsageDescription`, `NSSupportsLiveActivities` |

### 두 길을 가르는 규칙

iOS 26 이상에서 AlarmKit 권한을 받았으면 AlarmKit 하나만 쓴다. 그때 서버 푸시 토큰을 지우고(`PushRegistrar.dropTokenForAlarmKit`) 로컬 백업 알림도 걸지 않는다. 권한을 못 받았거나 iOS 25 이하면 지금까지의 길 — 서버 푸시 + 로컬 백업 알림 — 그대로다.

알람 목록·편집 화면은 `push.isAlarmReady` 와 `push.alarmPermission` 을 본다. 기기에 따라 묻는 권한이 다르기 때문이다.

### 연쇄 알람의 식별자

`AlarmManager.shared.alarms` 는 우리가 넘긴 메타데이터를 돌려주지 않는다. 그래서 어느 묶음인지 ID 로만 알 수 있다. `AlarmSetting.localID` 의 마지막 바이트를 연쇄 번호와 XOR 해서 되짚는다(`AlarmKitScheduler.chainID`).

### 남은 것

- 실기기에서 알람을 걸고 단추를 눌러 방송이 나오는 것까지는 시험 앱으로 확인했다. **zeroPlayer 본체로 같은 것을 다시 확인해야 한다.**
- 자정을 넘는 연쇄(23:54 이후 알람)는 요일까지 밀어야 해서 지금은 건너뛴다.
