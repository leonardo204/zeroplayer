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
| PCM WAV 를 알람음으로 | 소리가 난다. 44.1kHz · 16bit · 모노 · 23~29초로 확인 |
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

### 알람음 — 기본음과 고전 멜로디 20곡 중에서 고른다

애플이 주는 선택지는 `sound: .default` 아니면 `.named(우리 파일)` 둘뿐이다. 시계 앱의 Radar·Apex 같은 시스템 벨소리는 앱이 읽을 수 없고, **음량을 지정하는 인자도 없다**(iOS 27 SDK 의 `AlertConfiguration.AlertSound` 에 `default` 와 `named(_:)` 만 있다). 알람 전용 벨소리 9종이 `ToneKit.framework/TKAlarmWakeUpRingtones.plist` 에 목록으로 있고 파일은 `ToneLibrary.framework/AlarmWakeUpRingtones/*.m4r` (54~64초)인데, private framework 안이라 샌드박스 밖이고 애플 저작물이라 번들에 넣을 수도 없다.

그래서 편집 화면의 알람음 목록을 이렇게 짰다.

| 고른 것 | 어떻게 울리나 | 음량 |
| --- | --- | --- |
| **기본음**(첫 줄, 기본값) | 끌 때까지 반복한다. 가장 크다 | 기기의 벨소리 볼륨을 따른다. 앱이 못 바꾼다 |
| 고전 멜로디 20곡 | 22.5~29초짜리가 **한 번** 울린다. 2분 간격 연쇄가 이를 메운다 | 슬라이더로 조절한다. 고른 값을 파일에 구워 넣는다 |

확실히 깨워야 하는 사람은 기본음, 기분 좋게 깨고 싶은 사람은 멜로디다.

#### 음원은 우리가 연주해 굽는다

남의 녹음을 쓰면 권리가 걸린다. 오픈소스 알람음 세 곳을 알아봤는데 전부 막혔다.

| 알아본 것 | 결과 |
| --- | --- |
| AOSP `data/sounds/alarms` | Apache 2.0 이 맞다(`Android.bp` 의 `frameworks_alarm_sounds` 에 파일이 명시돼 있다). 다만 전자음 계열이고 중복을 빼면 16종뿐이다 |
| `robbiehanson/AlarmClock` (MIT) | 레포는 MIT 인데 **음원 출처가 지워져 있다.** artist 가 "Sample Alarms" 라는 자체 라벨이고 copyright 태그가 비었고, Credits 에 번역자 18명·디자이너 3명을 적어 두고 사운드만 빠졌다. 자연음 20종이 전부 23.5~23.8초로 균일해 원본을 잘라 쓴 흔적이 남았다. 정규화해도 −17dBFS 로 작다 |
| Freesound CC0 | 라이선스는 깨끗하다(16곡을 페이지에서 직접 대조했다). 그런데 단음이라 멜로디가 안 되고, 자연음은 눌러도 −12~−18dBFS 에 그친다 |

그래서 **저작권이 끝난 고전을 우리가 연주해 굽는다.** 녹음의 권리자가 우리라서 제3자 권리가 걸릴 자리가 없다. 곡은 전부 작곡가 사후 70년이 지난 것이다(파헬벨·비발디·바흐·하이든·모차르트·베토벤·로시니·그리그·슈트라우스 2세·드보르자크·엘가).

음색은 **FluidR3 GM** 사운드폰트다. 원저작자 Frank Wen 이 배포 파일에 직접 적어 둔 문장으로 MIT 를 확인했다 — "I hereby release Fluid under the MIT license, as described in COPYING." 사운드폰트(148MB)는 저장소와 앱에 들어가지 않는다. 구울 때만 받아 쓴다.

도구는 `tools/alarm-tones/` 다. 악보(`melodies.py`, 곡마다 함수 하나), 렌더러(`render.swift`, `AVAudioUnitSampler` 라 외부 도구가 필요 없다), 후처리(`post.py`), 권리 정리(`LICENSE-NOTES.md`)가 들어 있다. 다시 굽는 절차는 그 폴더의 `README.md` 에 있다.

#### 형식과 크기

| 항목 | 값 |
| --- | --- |
| 번들 형식 | IMA4 압축 CAF, 44.1kHz 모노. 20곡 12MB(곡당 약 600KB) |
| 기기에서 | 링형 PCM WAV 로 풀어 `Library/Sounds` 에 쓴다 |
| 길이 | 22.5 ~ 29.0초 (알람음 한도 30초 미만) |
| 크기(음량 최대) | 피크 98~100%, RMS −8.0 ~ −8.2 dBFS |
| 크기(음량 최소) | RMS −18.5 dBFS. 그래도 들린다 |

**MP3 는 알람음으로 못 쓴다.** 알람 화면은 뜨는데 소리가 나지 않고 오류도 안 남는다. IMA4 CAF 는 `UNNotificationSound` 문서가 허용 형식으로 적어 둔 것이라 안전하고, WAV 대비 4분의 1로 줄어든다.

곡마다 목표 크기(RMS −8.0dBFS)에 닿을 만큼만 눌러 키운다. 눌러야 하는 양이 곡에 따라 0.8~3.2배로 달라서 고정값으로는 맞지 않는다 — `post.py` 가 이분법으로 찾는다.

**표본율을 22.05kHz 로 내리지 않는다.** 처음에는 용량을 줄이려고 내렸는데, 그러면 나이퀴스트가 11.025kHz 라 그 위가 통째로 사라진다. 실측으로 11kHz 위가 −200dB, 즉 아무것도 없었다. 현의 반짝임과 피아노 어택이 거기 있어서 담요를 덮은 소리가 됐다. 44.1kHz 로 구우니 11~16kHz 가 −25~−48dB 로 살아났다. 용량은 5.9MB → 12MB 로 는다.

**눌림 상한은 2.5 배다.** 더 누르면 어택이 뭉개져 다시 막힌 소리가 된다. 목표 크기에 못 닿는 곡은 후처리를 세게 하지 말고 악보에서 고친다 — 세기를 올리거나 이음새를 늘리거나 악기를 바꾼다. 하이든은 반주가 pizzicato 라 거의 안 들렸고, 지속하는 현으로 바꾸니 눌림이 2.5 → 1.7배로 오히려 줄었다. `masterGain` 은 12dB 가 상한이라 그 위를 적으면 조용히 잘린다.

#### 파일을 쓰는 방식

번들의 CAF 를 `AVAudioFile` 로 읽어 압축을 풀고, 음량과 '점점 크게' 를 적용해 링형 PCM WAV 로 `Library/Sounds` 에 쓴다(`Sources/Core/Notifications/AlarmSound.swift`). 파일 이름에 곡 키·음량 단계·점점크게·**번들 음원의 지문**이 들어가 있어 같은 조합이면 여러 알람이 한 파일을 같이 쓰고, 안 쓰는 파일은 예약할 때 치운다(`AlarmSoundStore.prune`).

지문을 붙이는 이유가 있다. `ensure` 는 같은 이름 파일이 있으면 다시 굽지 않는다. 그래서 번들 음원을 44.1kHz 로 다시 구웠을 때 **이미 캐시된 알람은 옛 22.05kHz 소리로 계속 울렸다.** 지문은 번들 파일 크기를 KB 로 줄인 값이라(`AlarmSoundCatalog.sourceTag`) 음원이 바뀌면 이름이 바뀌고 새로 굽는다. 사람이 판 번호를 올려 주는 방식은 쓰지 않는다 — 그 방식이면 잊는다.

WAV 머리말의 표본율도 번들 파일에서 읽은 값을 쓴다. 상수로 박아 두면 음원을 다시 구운 순간 소리가 절반 속도로 늘어진다.

미리듣기는 파일을 다시 굽지 않는다. 번들 CAF 를 `AVAudioPlayer` 로 바로 틀고 `player.volume` 만 맞춘다. 오디오 세션은 카테고리만 건드린다 — 세션을 내리면 듣고 있던 방송까지 끊긴다.

알람음 파일은 **발화 시점에** 읽힌다. 그래서 예약을 다시 걸지 않아도 파일만 바꾸면 다음 알람이 새 소리로 울린다.

곡 키는 저장값이자 파일 이름이다. **한번 정하면 바꾸지 않는다** — 바꾸면 그 곡을 고른 알람이 조용히 기본음으로 떨어진다.

방송 자체를 알람음으로 넣는 길도 재 봤고 되는 것까지 확인했다. 아래에 그 기록을 남긴다 — 다시 꺼낼 때를 위해서다.

#### 방송을 알람음으로 — 접은 길의 기록

방송 스트림은 MP3 라 그대로는 못 쓴다(위와 같다). 링형 PCM 으로 바꿔야 한다. 22.05kHz · 16bit · 모노 · 25초로 확인했다(그때는 알람음도 22.05k 였다).

바꾸는 곳은 둘 중 하나다.

| 어디서 | 전송량 | 폰이 하는 일 |
| --- | --- | --- |
| 폰에서 변환 | 401KB (MP3) | `AVAssetReader` 로 0.1초 만에 바꾼다 |
| 서버에서 변환 | 1.1MB (WAV) | 받아서 쓰기만 한다 |

지금 시험은 폰에서 바꿨다. 전송량이 3배 차이 나므로 이쪽이 낫다.

#### 방송 소리의 크기

방송 원음은 알람음 기준으로 작다. 올드팝카페를 재보니 피크 −6.4dBFS, RMS −18.7dBFS 였다. 피크만 0dBFS 로 맞추면 6dB 밖에 못 올린다.

그래서 게인을 걸고 `tanh` 로 눌러 포화시킨다. +14dB 를 걸었을 때 폰에서 잰 값이다.

```
정규화 +14dB  피크 0.0->-0.0dBFS  RMS -15.7->-5.6dBFS
```

RMS 가 10dB 올랐는데도 **여전히 기본 알람음보다 작게 들린다.** 0dBFS 순음과 기본음을 나란히 울려 비교하는 시험까지 만들었지만(`./probe.sh devrun loudcmp:25`) 결과를 확인하지 못했다. 방송이 모자란 것인지 커스텀 알람음 경로가 눌리는 것인지 아직 갈리지 않았다. 그래서 목록의 첫 줄을 기본음으로 두고 기본값으로 삼았다 — 어느 쪽이 원인이든 기본음은 영향을 받지 않는다.

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
| `Sources/Core/Notifications/AlarmSound.swift` | 알람음 목록, 번들 CAF 를 풀어 `Library/Sounds` 에 쓰기, 안 쓰는 파일 치우기 |
| `Sources/Features/Alarm/AlarmSoundSection.swift` | 알람음 고르는 화면·음량 슬라이더·미리듣기 |
| `Sources/Resources/AlarmTones/zptone-*.caf` | 음원 20곡. IMA4 CAF 44.1kHz, 12MB |
| `tools/alarm-tones/` | 음원을 굽는 도구. 악보·렌더러·후처리·권리 정리 |
| `Sources/Core/Notifications/PushRegistrar.swift` | AlarmKit 로 가면 APNs 등록을 건너뛰고 올려 둔 토큰을 지운다 |
| `project.yml` | `NSAlarmKitUsageDescription`, `NSSupportsLiveActivities` |

### 두 길을 가르는 규칙

iOS 26 이상에서 AlarmKit 권한을 받았으면 AlarmKit 하나만 쓴다. 그때 서버 푸시 토큰을 지우고(`PushRegistrar.dropTokenForAlarmKit`) 로컬 백업 알림도 걸지 않는다. 권한을 못 받았거나 iOS 25 이하면 지금까지의 길 — 서버 푸시 + 로컬 백업 알림 — 그대로다.

알람 목록·편집 화면은 `push.isAlarmReady` 와 `push.alarmPermission` 을 본다. 기기에 따라 묻는 권한이 다르기 때문이다.

### 연쇄 알람의 식별자

`AlarmManager.shared.alarms` 는 우리가 넘긴 메타데이터를 돌려주지 않는다. 그래서 어느 묶음인지 ID 로만 알 수 있다. `AlarmSetting.localID` 의 마지막 바이트를 연쇄 번호와 XOR 해서 되짚는다(`AlarmKitScheduler.chainID`).

### 남은 것

- 알람이 울리고 단추로 방송이 나오는 것까지는 실기기에서 확인했다.
- **44.1kHz 로 바꾼 음원을 실기기에서 아직 울려 보지 못했다.** 굽는 경로는 맥에서 같은 `AVAudioFile` 로 검증했다(표본율 44100, 길이·크기 일치). 기기에서는 `-ZPBakeTones 1` 로 20곡을 구워 파일 크기가 곡당 2.3MB 대(22.05k 시절 1.1MB 의 두 배)인지 보면 된다.
- 자정을 넘는 연쇄(23:54 이후 알람)는 요일까지 밀어야 해서 지금은 건너뛴다.
