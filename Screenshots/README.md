# App Store 화면 캡처

여덟 장씩 네 벌이다. 기기 크기마다 가장 큰 것 한 벌만 올리면 App Store 가 나머지 크기로
줄여 쓴다.

| 폴더 | 기기 | 크기 |
| --- | --- | --- |
| `ko` · `en` | 아이폰 6.9인치 (iPhone 17 Pro Max) | 1320×2868 |
| `ipad-ko` · `ipad-en` | 아이패드 13인치 (iPad Pro 13-inch M5) | 2064×2752 |

**아이패드 캡처는 빼면 안 된다.** 1.7 이 아이패드를 지원했고 애플은 업데이트에서 지원
기기를 줄이는 것을 막는다. 아이폰 전용으로 올리면 업로드 검증이
`This bundle does not support one or more of the devices supported by the previous app version`
으로 떨어진다. 앱이 아이패드를 지원하는 한 App Store Connect 가 아이패드 캡처를 요구한다.

붙여 넣을 문구는 `docs/09-appstore-submit.md` 에 있다.

## 다시 찍는 법

상태바는 스토어 관례대로 9:41·배터리 가득으로 맞춘다.

```sh
DEV=$(xcrun simctl list devices available | grep "iPhone 17 Pro Max" | head -1 | sed 's/.*(\([0-9A-F-]*\)).*/\1/')
xcrun simctl boot $DEV
xcrun simctl status_bar $DEV override --time "9:41" --batteryState charged --batteryLevel 100 \
  --cellularMode active --cellularBars 4 --wifiMode active --wifiBars 3 --dataNetwork wifi
```

캡처는 DEBUG 빌드의 통로로 화면을 세워 찍는다. 릴리스 빌드에는 들어가지 않는다.

| 인자 | 하는 일 |
| --- | --- |
| `-ZPNoAds 1` | 동의창·추적 허가창을 띄우지 않고 배너도 그리지 않는다 |
| `-ZPFakePushGranted 1` | 알람 화면의 '알림이 꺼져 있습니다' 카드를 감춘다 |
| `-ZPSituation sleep` | 추천 탭의 상황을 고정한다 |
| `-ZPShowTimer 1` | 재생 화면에서 자동 종료 시트를 바로 띄운다 |
| `-ZPSeedHistory 1` | 기록 탭이 비어 보이지 않게 지난 청취 기록을 심는다 |

**기록 탭을 맨 먼저 찍는다.** 씨앗은 청취 기록이 비어 있을 때만 심긴다. 재생 화면을 먼저
찍으면 그 재생이 기록으로 남아 씨앗이 건너뛰어지고, 기록 탭이 '0분' 으로 나온다.

언어는 기기 설정으로 바꾼다. 실행 인자로 주는 방법은 SwiftUI 에서 듣지 않는다.

```sh
xcrun simctl spawn $DEV defaults write -g AppleLanguages -array en-US
xcrun simctl spawn $DEV defaults write -g AppleLocale -string en_US
```

**찍기 전에 시뮬레이터를 `erase` 한다.** 설치 UUID 가 키체인에 남아, 지우고 다시 깔아도
서버에 등록해 둔 알람을 그대로 내려받는다. 그러면 영어 화면에 지난 한국어 알람 이름이
섞인다.

**지상파 화면은 넣지 않는다.** 해제해야 보이는 기능이라 스토어 화면에 올리면 해제하지
않은 사람이 찾다가 못 찾는다. 대신 심사 메모에 여는 방법을 적는다.

## 크기별 벌

App Store Connect 가 6.9인치(1320×2868)를 거부할 때가 있다. 그때는 아래 벌을 올린다.
원본에서 너비를 맞춰 줄이고 가운데를 기준으로 높이를 잘라 만든 것이라 늘어나 보이지 않는다.

| 폴더 | 크기 | 자리 |
| --- | --- | --- |
| `ko` · `en` | 1320×2868 | 아이폰 6.9인치 |
| `ko-6.7` · `en-6.7` | 1284×2778 | 아이폰 6.7인치 |
| `ko-6.5` · `en-6.5` | 1242×2688 | 아이폰 6.5인치 |
| `ipad-ko` · `ipad-en` | 2064×2752 | 아이패드 13인치 |

다시 만들 때는 원본 폴더에서 이렇게 한다(6.7인치 예).

```sh
cd Screenshots && for f in ko/*.png; do
  cp "$f" "ko-6.7/$(basename $f)"
  sips --resampleWidth 1284 "ko-6.7/$(basename $f)"
  sips -c 2778 1284 "ko-6.7/$(basename $f)"
done
```

## 알파 채널을 반드시 걷어낸다

`simctl io screenshot` 이 만드는 PNG 에는 알파 채널이 붙는다. App Store Connect 는
알파가 든 스크린샷을 받지 않는데, **거부 메시지를 내지 않고 '스크린샷 업로드가 진행
중입니다' 에 걸린 채로 둔다.** 썸네일은 목록에 보이지만 심사에 추가가 안 된다.

찍은 뒤 항상 걷어낸다. 도구는 `tools/flatten-screenshots.swift` 다.

```sh
swiftc -O tools/flatten-screenshots.swift -o /tmp/zp_flatten
cd Screenshots && /tmp/zp_flatten */*.png
```

확인하는 법.

```sh
sips -g hasAlpha Screenshots/ko-6.5/01-recommend.png   # hasAlpha: no 여야 한다
```

## 업로드가 '진행 중' 에서 안 끝날 때

App Store Connect 가 자산 하나를 물고 있으면 화면 어디에도 표시가 안 되고
"아직 스크린샷 업로드가 진행 중입니다" 만 남는다. 거부 사유를 따로 알려 주지 않는다.

파일 쪽에서 할 수 있는 것은 다음 셋이고, 여기 있는 캡처는 전부 마쳐 뒀다.

1. **알파 채널을 없앤다.** `simctl` 이 찍는 PNG 에는 알파가 붙는다. `tools/flatten-screenshots.swift`
2. **부가 청크를 걷어낸다.** `sips` 가 `sRGB`·`eXIf` 청크를 남긴다. IHDR·IDAT·IEND 만 남긴다.
3. **JPG 로 바꿔 올린다.** PNG 가 걸릴 때 JPG 는 통과하는 경우가 있다. `jpg-*` 폴더가 그것이다.

크기 칸은 **가장 큰 것 하나만** 채운다. iPhone 은 6.9(1320×2868), iPad 는 13"(2064×2752).
아래 크기는 "6.9 디스플레이 사용" 으로 자동 상속된다 — 그 칸은 흐리게 보이고 '모두 삭제' 가
꺼져 있다. 업로드 중이 아니라 상속된 것이니 건드리지 않는다.
