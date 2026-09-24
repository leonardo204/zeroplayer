# zeroPlayer 2.0

상황에 맞는 인터넷 라디오와 팟캐스트를 골라주고, 타이머로 끄고 알람으로 켜는 iOS 플레이어.

App Store 의 [zeroPlayer](https://apps.apple.com/kr/app/zeroplayer/id1610259595) (번들 ID `com.zerolive.cloudRadioN`) 를 전면 재작성한 것이다. 1.x 저장소는 `/Users/zerolive/work/cloudRadio_ios` 에 참고물로 남아 있다.

## 구성

| 항목 | 값 |
| --- | --- |
| 최소 iOS | 17.0 |
| UI | SwiftUI |
| 저장 | SwiftData |
| 의존성 | SPM only (CocoaPods 없음) |
| 프로젝트 파일 | XcodeGen (`project.yml`). `.xcodeproj` 는 커밋하지 않는다 |
| 서버 | `ai.zerolive.co.kr` (Cloudflare Workers + D1) |

## 기능

**공개** — 인터넷 라디오(radio-browser), 팟캐스트(Podcast Index), 상황별 큐레이션, 상황 프리셋, 자동 종료 타이머, 알람, 청취 기록.

**히든** — 한국 지상파 라디오와 편성표.

유튜브 관련 기능은 없다. 이유는 `docs/05-ads-policy.md`.

## 문서

작업을 이어받는 사람은 `CONTEXT.md` 를 먼저 읽는다. 지금까지 한 일과 다음에 할 일이 적혀 있다.

기획은 `docs/` 에 번호순으로 있다. 배경부터 보려면 `docs/00-concept.md` 부터 읽는다.

## 빌드

```sh
brew install xcodegen      # 이미 있으면 건너뛴다
xcodegen generate
open zeroPlayer.xcodeproj
```

`.xcodeproj` 와 `Sources/App/Info.plist` 는 XcodeGen 이 만들므로 커밋하지 않는다. `project.yml` 을 고치면 `xcodegen generate` 를 다시 돌린다.

빌드 설정은 `Configs/` 에 있다. 두 빌드가 함께 쓰는 값은 `Base.xcconfig`, 광고 ID 처럼 빌드마다 다른 값은 `Debug.xcconfig`(구글 테스트 ID)와 `Release.xcconfig`(실제 광고 단위)에 나눠 둔다. 프록시 주소를 로컬이나 스테이징으로 돌릴 때만 루트에 `Secrets.xcconfig` 를 만든다(`Secrets.xcconfig.example` 참고). 없어도 빌드된다. 인증서와 키는 어떤 형태로도 저장소에 넣지 않는다.

## 진행 상황

마일스톤은 `docs/07-roadmap.md`. 지금은 **M0** 가 끝났다 — 탭 5개 껍데기와 `AudioPlayerService` 상태 기계까지 있고, 실제 재생은 M1 에서 붙인다.
