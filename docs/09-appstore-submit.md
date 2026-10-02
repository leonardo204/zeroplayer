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

심사 없이 언제든 바꿀 수 있는 유일한 칸이다. 그래서 새 기능을 가장 먼저 알리는 자리로 쓴다.

### 2.1.1 — 지금 넣을 것

**한국어** (104자)

```
마음에 안 드는 방송은 '그만 듣기' 를 누르면 바로 다음 방송으로 넘어가고, 다시는 앱이 고를 때 나오지 않습니다. 알람은 무음 모드에서도 울리고 고전 멜로디 스무 곡 가운데 고릅니다.
```

**영어** (168자)

```
Tap "Stop playing this" and the next station starts — it never returns in an automatic pick. Alarms ring through Silent mode, with twenty classical melodies to wake to.
```

### 2.1.0 — 앞 버전에 넣었던 것

**한국어** (104자)

```
알람을 새로 만들었습니다. 무음 모드에서도 울리고, 알람 화면에서 한 번 누르면 앱이 열리지 않은 채 라디오가 나옵니다. 알람음은 바흐·모차르트 등 고전 멜로디 스무 곡 가운데 고릅니다.
```

**영어** (154자)

```
The alarm is rebuilt. It rings through Silent mode, one tap starts live radio without opening the app, and you can wake to any of twenty classical pieces.
```

### 2.0 — 앞 버전에 넣었던 것

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

### 2.1.1 — 지금 넣을 것

**한국어**

```
마음에 안 드는 방송을 뺄 수 있습니다.

• 재생 화면에서 '그만 듣기' 를 누르면 그 방송이 멈추고 바로 다음 방송이 나옵니다.
• 뺀 방송은 추천 목록과 프리셋·알람의 자동 선택에서 다시 나오지 않습니다.
  탐색 탭에서는 그대로 찾아 들을 수 있습니다. 목록에서 감추지는 않습니다.
• 설정 → 그만 듣는 방송 에서 언제든 되돌립니다.
• 30초 안에 넘긴 방송은 다음부터 아래로 내려갑니다. 알람이 고를 때도 그렇게 합니다.
• 미디어 볼륨을 줄여 두면 고른 알람 곡이 들리지 않던 문제를 고쳤습니다. 곡은 처음 한 번 울리고,
  끄지 않으면 2분 뒤부터 알람 볼륨을 따르는 기본음으로 깨웁니다.
```

**영어** (스토어 현지화를 영어까지 늘릴 때만 쓴다)

```
You can now drop a station you don't want to hear.

• Tap "Stop playing this" on the player and the next station starts right away.
• A dropped station no longer appears when the app picks — in recommendations, in a
  preset, or for an alarm. You can still find it and play it from the Browse tab;
  it is not hidden from the list.
• Restore any of them from Settings → Stopped stations.
• Stations you skip within 30 seconds now move down the list, alarms included.
• Fixed alarm melodies going silent when media volume was turned down. The melody plays once,
  then from two minutes later the default sound wakes you at alarm volume.
```

### 2.1.0 — 앞 버전에 넣었던 것

알람을 새로 만든 버전이다. 무엇을 바꿨는지는 `docs/11-post-submit.md` 에 있다.

**한국어**

```
알람을 새로 만들었습니다.

• 무음 모드나 집중 모드를 켜 두어도 알람이 울립니다(iOS 26 이상).
• 알람 화면에서 '방송 켜기' 를 누르면 앱이 열리지 않고 바로 방송이 나옵니다.
• 알람음을 고전 멜로디 스무 곡 가운데 고릅니다. 바흐 무반주 첼로, 그리그 아침,
  모차르트 터키 행진곡처럼 잠을 깨기 좋은 곡을 담았습니다. 음량과 '점점 크게' 도
  따로 맞춥니다.
• 못 듣고 지나치지 않게 2분 간격으로 몇 번 더 울립니다.
• 전화를 받은 뒤 라디오가 다시 이어집니다.
• 즐겨찾기 표시를 한눈에 보이게 바꿨습니다.
```

**영어** (스토어 현지화를 영어까지 늘릴 때만 쓴다)

```
The alarm has been rebuilt.

• Alarms now ring even with Silent mode or a Focus turned on (iOS 26 and later).
• Tap "Play radio" on the alarm screen and the station starts without opening the app.
• Choose from twenty classical pieces — Bach's Cello Suite No. 1, Grieg's Morning,
  Mozart's Turkish March and more. Volume and fade-in are adjustable.
• The alarm repeats every two minutes so you don't sleep through it.
• Radio resumes after a phone call.
• Favourites are easier to spot.
```

### 2.0 — 앞 버전에 넣었던 것

1.7 에서 바뀐 것이 많아 그대로 적었다.

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

심사자가 먼저 물을 만한 것을 미리 적어 두는 칸이다. 백그라운드 오디오, 알람이 무음 모드를
뚫는 이유, 번들에 든 음원의 권리, 서버로 무엇이 가는지 — 설명이 없으면 지침 위반으로 보일
수 있는 것들이다.

**지상파(히든) 설명은 2.1.1 에서 뺐다.** 1.7 부터 있던 기능이고 그 뒤 심사를 여러 번
통과했다. 되살리려면 `[Hidden feature — please read]` 블록을 이력에서 꺼내 아래 메모 맨
앞에 붙인다 — 참고용 사본을 여기 두지 않는 이유는, 붙여 넣을 메모 바로 옆에 같은 모양의
블록이 있으면 잘못 복사하기 때문이다.

```sh
git show b4fb88b:docs/09-appstore-submit.md | sed -n '/Hidden feature/,/related to it/p'
```

```
[Background audio]
The app plays internet radio and podcasts with the screen off. That is the core use
(falling asleep, driving), which is why UIBackgroundModes includes audio.

[Alarms - changed in 2.1.0]
On iOS 26 and later the app schedules alarms with AlarmKit, so they are system alarms
and ring through Silent mode and Focus. On iOS 25 and earlier the previous behaviour is
unchanged: a push notification with a local notification scheduled as a backup for the
same time, which the user taps to start playback.

Exactly one of the two paths is active on a device. When AlarmKit authorization is
granted the app cancels its local backup notifications and deletes its APNs token from
our server, so the user is never woken twice for the same alarm.

Because a custom alarm sound plays only once, one alarm is scheduled as four alarms two
minutes apart. Stopping the alarm, or opening the app, cancels the remaining ones.

[Starting playback from the alarm screen]
The AlarmKit alert has two buttons: "Stop" and "Play radio". Both are App Intents that
adopt LiveActivityIntent and AudioPlaybackIntent. When the user taps "Play radio" the
system launches our process without opening the app, and the intent starts the radio
stream. This is the documented purpose of AudioPlaybackIntent — the app is not starting
audio on its own, it is responding to a user tap on a system alarm. Nothing plays until
that button is pressed.

[Alarm sounds - no third-party recordings]
The 20 alarm melodies bundled in the app are our own recordings. The compositions are in
the public domain (Bach, Mozart, Beethoven, Vivaldi, Pachelbel, Haydn, Grieg, Rossini,
Strauss II, Dvorak, Elgar - all more than 70 years after the composer's death) and we
rendered them ourselves from MIDI data using the FluidR3 GM soundfont, which its author
Frank Wen released under the MIT license. No sampled or licensed recordings are
included. Attribution and the full license text are shown in Settings.

[Time Sensitive Notifications]
Still requested for the iOS 25 and earlier path, where alarms are delivered as
notifications and need to appear during Focus. The entitlement is not bundled yet; it
will be added once approved. On iOS 26 and later it is not needed, because AlarmKit
alarms break through Focus on their own.

[Excluding stations - new in 2.1.1]
"Stop playing this" on the player drops the current station and starts the next candidate.
A dropped station is skipped whenever the app picks automatically, but it is still listed
and playable in the Browse tab - it is not hidden from the user.

The list of dropped station ids is stored on the device. It is uploaded to our server only
on iOS 25 and earlier, where the server is the one that decides what an alarm plays; on
iOS 26 and later the app decides, so nothing is uploaded and any earlier copy is deleted.
It holds station ids only - no titles, no listening history, nothing about the person.

[Broadcast content]
Streams are played as the station provides them. Nothing is re-encoded and the
stations' own ads are not removed. Station name, country and homepage link are shown.
Stream URLs are not stored in the app; they are requested from our proxy right before
playback, so a station can be removed server-side at any time.

[Listening history]
What the user listens to stays on the device (SwiftData) and is never sent to a server.
The only values sent are an install UUID (created by the app, kept in the Keychain, used
for alarm registration and rate limiting), the APNs device token, a station ID when a
stream fails to play, and - on iOS 25 and earlier only - the ids of stations the user
dropped, so a server-chosen alarm does not play one of them.

[Ads]
AdMob banners appear on the For You, Browse, Presets and Stats screens only. There are
no ads on the player screen, the mini player, or the screen opened by an alarm.

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
않은 사람이 찾다가 못 찾는다. 2.1.1 부터 심사 메모에도 적지 않는다(7번).

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
