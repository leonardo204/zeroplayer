# App Store 화면 캡처

6.9인치(1320×2868) 여덟 장씩 한국어·영어 두 벌이다. App Store 는 6.9인치 한 벌만
올리면 나머지 크기를 알아서 줄여 쓴다. 아이폰 전용이라 아이패드 캡처는 필요 없다.

붙여 넣을 문구는 `docs/09-appstore-submit.md` 에 있다.

## 다시 찍는 법

시뮬레이터 iPhone 17 Pro Max 를 쓴다. 상태바는 스토어 관례대로 9:41·배터리 가득으로 맞춘다.

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

영어는 앱만 영어로 띄운다. 기기 설정을 바꾸지 않아도 된다.

```sh
xcrun simctl launch $DEV com.zerolive.cloudRadioN -AppleLanguages '(en)' -AppleLocale en_US …
```

**찍기 전에 시뮬레이터를 `erase` 한다.** 설치 UUID 가 키체인에 남아, 지우고 다시 깔아도
서버에 등록해 둔 알람을 그대로 내려받는다. 그러면 영어 화면에 지난 한국어 알람 이름이
섞인다.

**지상파 화면은 넣지 않는다.** 해제해야 보이는 기능이라 스토어 화면에 올리면 해제하지
않은 사람이 찾다가 못 찾는다. 대신 심사 메모에 여는 방법을 적는다.
