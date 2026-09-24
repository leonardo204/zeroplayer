# App Store 제출 자료

App Store Connect 의 칸에 그대로 붙여 넣을 값이다. 한국어와 영어를 나란히 둔다.
화면 캡처는 저장소의 `Screenshots/` 아래 네 벌(`ko`·`en`·`ipad-ko`·`ipad-en`)에 있다.

## 1. URL 세 개

버전 정보에 딸린 값이라 2.0 을 제출해야 반영된다. 1.7 은 세 칸이 모두 비어 있다.

| 칸 | 값 |
| --- | --- |
| 마케팅 URL | `https://zeroplayer.zerolive.co.kr` |
| 지원 URL | `https://zeroplayer.zerolive.co.kr/support` |
| 개인정보처리방침 URL | `https://zeroplayer.zerolive.co.kr/privacy` |

**마케팅 URL 이 AdMob 앱 인증을 푼다.** AdMob 은 App Store 앱 페이지의 '개발자 웹사이트'
를 읽고 그 도메인 루트에서 `/app-ads.txt` 를 찾는데, 그 값이 곧 마케팅 URL 이다.

세 주소 모두 지금 200 으로 열린다. 한국어가 기본이고 `/en` 에 영어가 있다.

## 2. 프로모션 텍스트 (170자)

심사 없이 언제든 바꿀 수 있는 유일한 칸이다.

**한국어** (78자)

```
취침·운전·공부·작업·기상 가운데 하나만 고르면 지금 시각에 맞는 방송을 골라 틀어 줍니다. 정한 시간이 되면 소리가 서서히 줄며 꺼집니다.
```

**영어** (148자)

```
Pick one moment — sleep, driving, study, work or waking up — and the app picks a station for the hour. It fades out and stops when your timer ends.
```

## 3. 설명 (4000자)

**한국어**

```
무엇을 들을지 고르는 대신, 지금 무엇을 하는지만 고르세요.

취침·운전·공부·작업·기상 가운데 하나를 누르면 그 시각과 요일에 맞는 인터넷 라디오나
팟캐스트를 골라 바로 틀어 줍니다. 목록을 뒤질 필요가 없습니다.


■ 상황을 고르면 방송이 정해집니다

밤 열한 시의 취침과 아침 일곱 시의 기상은 어울리는 방송이 다릅니다. 시각·요일·나라를
함께 보고 고르기 때문에 같은 '취침'이라도 때마다 다른 방송이 나옵니다.

들은 기록이 쌓이면 순서가 내 쪽으로 옮겨 옵니다. 자주 듣던 방송은 위로 올라오고,
삼십 초 안에 넘겨 버린 방송은 아래로 내려갑니다. 이 기록은 기기 안에만 있습니다.


■ 정한 시간이 되면 스스로 꺼집니다

15·30·45·60·90분 가운데 고르거나 직접 분을 적습니다. 끝나기 전 30초 동안 소리가
서서히 줄어들어 뚝 끊기지 않습니다. 잠들고 나서 방송이 밤새 켜져 있는 일이 없습니다.


■ 프리셋 하나로 시작합니다

취침·운전·공부·작업·기상 프리셋이 처음부터 들어 있습니다. 카드를 한 번 누르면
방송이 정해지고, 재생이 시작되고, 타이머까지 함께 걸립니다.

프리셋마다 방송국을 지정해 둘 수도 있고, 그때그때 골라 오게 둘 수도 있습니다.


■ 아침에는 알람으로 깨웁니다

시각과 요일을 정해 두면 그 시각에 알림이 옵니다. 알림을 누르면 그 방송이 바로
시작됩니다. 서버에 닿지 못할 때를 대비해 기기에도 같은 시각으로 알림을 걸어 둡니다.


■ 전 세계 라디오와 팟캐스트

방송국 이천육백여 곳을 나라·장르·언어로 찾고 이름으로 검색합니다. 팟캐스트는 인기
목록과 검색이 있고, 에피소드는 진행 바·15초 되감기·재생 속도가 붙습니다. 듣던 자리에서
이어집니다.

죽은 방송국은 서버가 매일 점검해 목록에서 뺍니다. 같은 방송이 여러 줄로 올라와 있으면
하나로 묶어 대표 한 줄만 보여 줍니다.


■ 화면을 꺼도 이어집니다

잠금화면과 제어센터에서 멈추고 다시 틀 수 있습니다. 지금 나오는 곡 이름과 앨범 그림이
방송국에서 오면 함께 보여 줍니다. 전화를 받고 끊으면 재생이 이어집니다.


■ 기록은 기기 안에만

무엇을 얼마나 들었는지는 이 기기 안에만 남습니다. 서버로 보내지 않고 광고에도 쓰지
않습니다. 월간 리포트에서 이번 달에 몇 시간을 들었고 무엇을 가장 많이 들었는지 봅니다.

한국어와 영어를 지원합니다. 화면 테마를 라이트·다크로 고를 수 있습니다.
```

**영어**

```
Instead of choosing what to listen to, just choose what you are doing.

Tap one of five moments — sleep, driving, study, work, waking up — and the app picks an
internet radio station or a podcast that fits this hour and this day, then starts it.
No list to dig through.


■ Pick the moment, not the station

Eleven at night and seven in the morning call for different sounds. The pick takes the
hour, the weekday and your country into account, so the same "sleep" gives you something
different from one night to the next.

As you listen, the order moves toward you. Stations you return to rise; stations you
skipped within thirty seconds fall. That history stays on your device.


■ It stops on its own

Choose 15, 30, 45, 60 or 90 minutes, or type your own. Over the last thirty seconds the
volume fades to zero, so nothing cuts off abruptly. Nothing plays all night after you
fall asleep.


■ One tap to start

Sleep, Driving, Study, Work and Wake up presets are there from the first launch. Tap a
card and the station is chosen, playback starts, and the timer is set — all at once.

A preset can hold one station, or leave the choice to the app each time.


■ An alarm that plays radio

Set a time and the weekdays. A notification arrives at that time, and tapping it starts
the station. A local backup notification is scheduled for the same time in case the
server cannot be reached.


■ Radio and podcasts from everywhere

Browse roughly 2,600 stations by country, genre and language, or search by name.
Podcasts come with a popular list and search; episodes have a progress bar, a 15-second
rewind and playback speed, and resume where you left off.

Dead streams are checked daily and dropped from the list. When one station is listed
several times, they are folded into a single row.


■ Keeps playing with the screen off

Pause and resume from the lock screen and Control Center. When a station sends the
current track name and cover art, both are shown. Playback resumes after a phone call.


■ Your history stays here

What you listened to, and for how long, stays on your device. It is never sent to a
server and never used for ads. A monthly report shows the hours and what you played most.

Korean and English. Light and dark appearance.
```

## 4. 키워드 (100자, 쉼표로 나누고 공백을 넣지 않는다)

**한국어** (75자)

```
인터넷라디오,라디오,팟캐스트,수면,취침,자동종료,슬립타이머,알람,백색소음,집중,공부,운전,기상,수면음악,잠잘때,명상,힐링,해외방송,fm
```

**영어** (99자)

```
internet radio,podcast,sleep timer,radio alarm,white noise,focus,study,driving,streaming,fm,live
```

앱 이름에 이미 들어간 말(zeroPlayer)과 카테고리 이름(음악·Music)은 키워드에 넣지 않는다.
검색에서 이름과 키워드가 함께 쓰이므로 같은 말을 두 번 넣으면 자리만 버린다.

## 5. 부제 (30자)

| 언어 | 값 |
| --- | --- |
| 한국어 | `상황에 맞는 라디오와 팟캐스트` |
| 영어 | `Radio and podcasts by moment` |

## 6. 새로운 기능 (릴리스 노트)

1.7 에서 바뀐 것이 많아 그대로 적는다.

**한국어**

```
2.0 에서 앱을 새로 만들었습니다.

• 유튜브 재생목록 기능이 없어졌습니다. 유튜브는 화면을 끈 채 소리만 재생하는 것을
  약관에서 막고 있어, 취침·운전에 쓰는 이 앱과 맞지 않았습니다.
• 대신 전 세계 인터넷 라디오 이천육백여 곳과 팟캐스트가 들어왔습니다.
• 취침·운전·공부·작업·기상 가운데 하나를 고르면 지금 시각에 맞는 방송을 골라 줍니다.
• 자동 종료 타이머에 페이드아웃이 붙었습니다. 뚝 끊기지 않습니다.
• 알람을 정한 시각에 받고, 알림을 누르면 그 방송이 바로 시작됩니다.
• 청취 기록과 월간 리포트가 생겼습니다. 기기 안에만 남습니다.
• 한국어와 영어, 라이트·다크 테마를 지원합니다.

전에 쓰시던 알람과 채널 목록은 그대로 옮겨 뒀습니다.
```

**영어**

```
Version 2.0 is a rebuild.

• The YouTube playlist feature is gone. YouTube's terms do not allow playing only the
  audio with the screen off, which is exactly how this app is used.
• In its place: about 2,600 internet radio stations worldwide, and podcasts.
• Pick sleep, driving, study, work or waking up, and a station is chosen for this hour.
• The sleep timer now fades out instead of cutting off.
• Alarms arrive at the time you set; tapping the notification starts the station.
• Listening history and a monthly report, kept on the device.
• Korean and English, light and dark appearance.

Your old alarms and channel list were carried over.
```

## 7. 심사 메모 (App Review Information → Notes)

**지상파 라디오를 반드시 적는다.** 심사 지침 2.3.1 이 숨겨진 기능과 문서화되지 않은
기능을 금지한다. 여는 방법을 적어 두면 '숨긴 기능' 이 아니라 '설명된 기능' 이 된다.

```
[Hidden feature — please read]
Tapping the version number on the Settings screen 12 times reveals a "Terrestrial"
segment in the Browse tab. It lists Korean terrestrial radio channels (KBS, MBC, SBS,
CBS, TBS, AFN). This is not a hidden or undocumented feature in the sense of guideline
2.3.1 — it is carried over from version 1.7, where the same feature existed, and it is
documented here so the reviewer can reach it. It can be turned off again from Settings.
No ads are shown on any screen related to it.

[Background audio]
The app plays internet radio and podcasts with the screen off. That is the core use
(falling asleep, driving), which is why UIBackgroundModes includes audio.

[Alarms]
Alarms are delivered as notifications. iOS does not allow an app to start audio by
itself when a push arrives, so the user taps the notification and playback then starts.
The app does not try to work around this. A local notification is scheduled as a backup
for the same time in case the server cannot be reached.

[Time Sensitive Notifications]
Requested so alarms appear during Focus. The entitlement is not bundled yet; it will be
added once approved.

[Broadcast content]
Streams are played as the station provides them. Nothing is re-encoded and the
stations' own ads are not removed. Station name, country and homepage link are shown.
Stream URLs are not stored in the app; they are requested from our proxy right before
playback, so a station can be removed server-side at any time.

[Listening history]
What the user listens to stays on the device (SwiftData) and is never sent to a server.
The only values sent are an install UUID (created by the app, kept in the Keychain, used
for alarm registration and rate limiting), the APNs device token, and a station ID when
a stream fails to play.

[Ads]
AdMob banners appear on the For You, Browse, Presets and Stats screens only. There are
no ads on the player screen, the mini player, any terrestrial radio screen, or the
screen opened by an alarm.

[Test account]
Not needed. No sign-in anywhere in the app.
```

## 8. 화면 캡처

여덟 장씩 네 벌이다. 기기 크기마다 가장 큰 것 한 벌만 올리면 App Store 가 나머지
크기로 줄여 쓴다.

| 폴더 | 기기 | 크기 |
| --- | --- | --- |
| `Screenshots/ko` · `Screenshots/en` | 아이폰 6.9인치 | 1320×2868 |
| `Screenshots/ipad-ko` · `Screenshots/ipad-en` | 아이패드 13인치 | 2064×2752 |

**아이패드 캡처가 필수다.** 앱이 아이패드를 지원하는 한 App Store Connect 가 요구하고,
지원을 줄이는 것은 애플이 막는다(아래 9번).

| 파일 | 담은 화면 |
| --- | --- |
| `01-recommend` | 추천 — 상황 다섯 개와 골라 온 목록, 고른 이유 |
| `02-player` | 재생 화면 — 앨범 그림, 곡 이름 |
| `03-timer` | 자동 종료 — 시간 고르기와 페이드아웃 |
| `04-presets` | 프리셋 다섯 개 |
| `05-discover` | 탐색 — 방송국 목록과 장르 |
| `06-stats` | 기록 — 월간 리포트 |
| `07-podcasts` | 탐색 — 팟캐스트 인기 목록 |
| `08-alarm` | 알람 |

**지상파 화면은 넣지 않았다.** 해제해야 보이는 기능이라 스토어 화면에 올리면 해제하지
않은 사람이 찾다가 못 찾는다. 심사 메모에는 적는다(7번).

올리는 순서는 파일 이름 순서 그대로 둔다. 첫 석 장이 검색 결과에서 먼저 보이므로
상황 고르기·재생·타이머가 앞에 오게 했다.

## 9. 그 밖의 칸

| 칸 | 값 |
| --- | --- |
| 카테고리 | 음악 (기본), 엔터테인먼트 (보조) |
| 연령 등급 | 4+ |
| 저작권 | `2026 YONGSUB LEE` |
| 가격 | 무료 |
| 지원 언어 | 한국어, 영어 |
| 기기 | iPhone·iPad (iOS 17.0 이상) |

**App Privacy 표기는 `docs/08-release.md` 2번에 있다.** 앱이 보내는 것 넷과 AdMob 이
가져가는 것을 나눠 적어 뒀다.
