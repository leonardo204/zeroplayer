# 광고와 약관

## 1. 왜 유튜브를 뺐는가

조항 원문으로 정리한다. 세 개가 각각 다른 곳을 막는다.

**백그라운드 재생 금지** — Developer Policies III.I.9

> "create, include, or promote features that play content, including audio or video components, from a **background player**, meaning a player that is not displayed in the page, tab, or screen that the user is viewing" [[S1]](#s1)

1.x 는 `videoView.isHidden = true` 로 플레이어를 숨기고 소리만 썼다. 정확히 이 금지 대상이다. 그리고 이 앱의 사용 형태(취침·운전 중 청취)는 화면을 끈 채 소리가 나야 하므로, 이 조항을 지키면서 기능을 유지할 방법이 없다.

**오디오 분리 금지** — III.I.7

> "separate, isolate, or modify the **audio or video components** of any YouTube audiovisual content" [[S1]](#s1)

**광고 조건** — III.G.1

| 항목 | 내용 |
| --- | --- |
| III.G.1.c | 플레이어 위나 안에 광고 — 사전 서면 승인 없이는 금지 |
| III.G.1.d | 같은 화면 광고 — 유튜브에서 받지 않은 콘텐츠가 함께 있고, **그것이 유튜브 데이터를 빼도 독립적으로 가치가 있어야** 허용 |

플레이어 높이를 제한하고 그 아래에 배너를 두면 `c` 는 피한다. 그러나 `d` 의 조건은 광고 **위치**가 아니라 **화면에 무엇이 같이 있는지**다. 판정 기준은 "그 화면에서 유튜브 것을 전부 지웠을 때 남은 것만으로 광고를 팔 만한가" 다. 유튜브 영상·제목·채널명·썸네일이 전부인 화면은 높이를 어떻게 잡아도 이 기준을 통과하지 못한다.

**공식 API 외 접근 금지** — III.I.14

> "use **any technology other than YouTube API Services** to access or retrieve API Data" [[S1]](#s1)

OpenRouter 나 비공식 라이브러리(`ytmusicapi` 등)로 유튜브 데이터를 받는 것은 이 조항에 직접 해당한다. 재생에 임베드 플레이어를 쓰는 순간 API Client 가 되므로 정책 전체가 적용된다. 데이터만 다른 길로 받는 것은 회피가 아니라 위반을 하나 더 얹는 쪽이다.

**추가로** 화면 설계까지 제약이 있다. Required Minimum Functionality 는 플레이어 최소 크기 200×200px, 절반 이상 노출 전 자동 재생 금지, **플레이어 위 오버레이 금지**를 요구한다 [[S2]](#s2). 틱톡식으로 영상 위에 제목·버튼을 겹치는 배치는 쓸 수 없다.

## 2. 숏츠 뷰어를 넣지 않는 이유

**숏츠를 API 로 골라낼 방법이 없다.** YouTube Data API v3 의 Video 리소스에 숏츠를 표시하는 필드가 없다. 숏츠는 일반 영상과 똑같이 내려온다. 구글 이슈 트래커에 요청이 올라와 있지만 반영되지 않았다 [[S3]](#s3).

실무 우회는 `contentDetails.duration ≤ 60초` 로 추정하거나 `youtube.com/shorts/{id}` 응답을 확인하는 것뿐이다. 전자는 짧은 일반 영상이 섞이고, 후자는 영상 하나당 요청 한 번이 든다.

**할당량이 막는다.**

| 항목 | 기본 할당량 |
| --- | --- |
| `search.list` | **하루 100회** (별도 통) |
| 그 외 전체 합산 | 하루 10,000 units |
| `playlistItems.list` · `videos.list` | 1회당 1 unit |

숏츠 뷰어는 새 영상을 계속 찾아야 하는데 그 검색이 하루 100회다. 사용자 한 명이 아니라 앱 전체가 100회다 [[S4]](#s4). 감사를 받아 증액할 수 있지만 위 1번의 위반 상태로는 통과가 어렵다.

**자동 넘김이 III.F.3 과 충돌한다.**

> "playback integrity is contingent on a **user choosing to watch a video**" [[S1]](#s1)

## 3. 다른 음원 소스를 검토한 결과

| 소스 | 전곡 재생 조건 | 백그라운드 | 광고 | 큐레이션 데이터 |
| --- | --- | --- | --- | --- |
| YouTube Music | **공개 API 없음** | 금지 | — | 불가 |
| YouTube Data API | 플레이어 노출 필수 | 금지 | 조건부 | 검색 하루 100회 |
| Apple Music (MusicKit) | 사용자 구독 | 가능 | **금지** | 좋음 |
| Spotify | Premium + 앱 설치 | 가능 | 제약 | **추천 API 폐기** |
| 인터넷 라디오 (radio-browser) | 없음 | 가능 | **자유** | 태그·인기도 |
| 팟캐스트 (Podcast Index) | 없음 | 가능 | 조건부 | 카테고리·길이 |

**YouTube Music** 은 구글이 공개 API 를 제공하지 않는다. 있는 것은 웹 클라이언트 요청을 흉내 내고 사용자 쿠키로 인증하는 비공식 라이브러리뿐이고, III.I.14 에 해당한다 [[S5]](#s5).

**Apple Music** 은 개발자 계약이 광고를 직접 금지한다.

> "you agree **not to require payment for or indirectly monetize access to the Apple Music service** (e.g. in-app purchase, **advertising**, requesting user info) through your use of the MusicKit APIs" [[S6]](#s6)

**Spotify** 는 2024-11-27 부로 신규 앱의 `/recommendations` 와 `/artists/{id}/related-artists`, 음향 특성 분석 접근을 닫았다 [[S7]](#s7). 큐레이션을 하려는데 큐레이션용 엔드포인트가 없는 셈이다.

그래서 **인터넷 라디오와 팟캐스트**가 남는다.

## 4. 인터넷 라디오·팟캐스트에 광고를 붙일 수 있는 근거

인터넷 라디오와 팟캐스트에는 유튜브의 III.G.1.d 같은 별도 약관이 없다. AdMob 정책만 만족하면 된다.

Google Publisher Policies 의 관련 조항이다.

> "with embedded or copied content from others **without additional commentary, curation, or otherwise adding value** to that content" [[S8]](#s8)

금지 대상은 "부가가치 없이 남의 콘텐츠를 그대로 나열하는 것"이다. 조항이 허용 조건으로 **curation 을 직접 지목한다.** 이 앱이 하려는 것이 정확히 그것이다. 상황별 추천, 추천 이유, 프리셋, 청취 기록이 모두 원본 데이터에 없던 부가가치다.

AdMob 고객센터는 남의 콘텐츠를 프레임에 넣어 허락 없이 수익화하는 것을 금지한다 [[S9]](#s9). 지켜야 할 선 세 가지다.

1. **스트림을 그대로 재생한다.** 재인코딩하지 않고, 방송국이 넣은 광고를 제거하지 않는다.
2. **방송국 정보와 홈페이지 링크를 표시한다.** radio-browser 가 `homepage` 필드를 준다.
3. **방송국이 요청하면 뺄 수 있는 구조를 만든다.** 프록시의 `stations` 표에서 한 줄을 지우면 된다. 문의 창구를 설정 화면에 둔다.

## 5. 광고 배치

| 화면 | 광고 | 근거 |
| --- | --- | --- |
| 추천 목록 | 배너 (목록 인라인) | 추천 순서와 이유가 부가가치다 |
| 탐색 · 검색 결과 | 배너 (하단) | |
| 프리셋 목록 | 배너 (하단) | 내용이 전부 사용자 본인 데이터다 |
| 기록 · 월간 리포트 | 배너 (하단) | 같다 |
| 재생 화면 | **없음** | |
| 미니 플레이어 | **없음** | |
| 히든 라디오 관련 화면 전부 | **없음** | 히든은 비공개 기능이다. 수익화 대상이 아니다 |
| 알람이 울려 열린 화면 | **없음** | 기상 직후 광고는 최악이다 |

보상형 광고는 쓰지 않는다. 기능을 광고로 여는 구조를 넣지 않는다.

## 6. 계정 위험

AdMob 게시자 계정은 zerolive 의 앱 전체가 공용으로 쓴다. **계정 정지는 앱 단위가 아니라 계정 단위다.** 한 앱의 위반으로 나머지 앱 수익까지 멈춘다.

그래서 애매한 것을 시도하지 않는다. 위 4번의 세 가지 선을 지키고, 유튜브·Apple Music·Spotify 콘텐츠 근처에는 광고를 두지 않는다.

## 7. 애플 심사에서 확인할 것

- **`exit(0)` 을 쓰지 않는다.** 1.x 는 히든 기능 해제 직후 앱을 강제 종료했다. 애플이 금지하는 동작이다.
- **Time Sensitive Notifications** 권한을 쓰려면 사용 이유를 적어야 한다. 알람 기능이므로 설명이 명확하다.
- **백그라운드 오디오**(`UIBackgroundModes = audio`)는 라디오·팟캐스트 재생이라 정당하다.
- 개인정보 수집 항목(App Privacy)에 **청취 기록을 서버로 보내지 않는다**는 점을 정확히 표기한다. 수집하는 것은 AdMob 의 광고 식별자와 설치 UUID 다. 설치 UUID 는 키체인에 있어 앱을 지웠다 깔아도 남으므로 '사용자 ID' 항목으로 표기한다.
- **App Tracking Transparency.** AdMob 이 광고 식별자(IDFA)를 쓰려면 ATT 허가창을 띄워야 한다. 거부하면 비개인화 광고로 간다. 문구는 `NSUserTrackingUsageDescription` 에 적는다.
- **광고 동의(UMP SDK).** 구글은 EEA·영국 사용자에게 인증된 동의창을 요구한다. 한국 사용자는 대상이 아니지만 SDK 는 같이 넣고 지역에 따라 자동으로 뜨게 둔다.

## 8. 출처

- <a id="s1"></a>**[S1]** [YouTube API Services — Developer Policies](https://developers.google.com/youtube/terms/developer-policies)
- <a id="s2"></a>**[S2]** [YouTube API Services — Required Minimum Functionality](https://developers.google.com/youtube/terms/required-minimum-functionality)
- <a id="s3"></a>**[S3]** [Identify Shorts in the API — Google Issue Tracker](https://issuetracker.google.com/issues/401671028)
- <a id="s4"></a>**[S4]** [YouTube Data API — Quota Costs](https://developers.google.com/youtube/v3/determine_quota_cost)
- <a id="s5"></a>**[S5]** [ytmusicapi — Unofficial API for YouTube Music](https://github.com/sigma67/ytmusicapi)
- <a id="s6"></a>**[S6]** [What are some examples of acceptable monetization options for the new MusicKit/Apple Music API? — Apple Developer Forums](https://developer.apple.com/forums/thread/80241)
- <a id="s7"></a>**[S7]** [Introducing some changes to our Web API — Spotify for Developers](https://developer.spotify.com/blog/2024-11-27-changes-to-the-web-api)
- <a id="s8"></a>**[S8]** [Google Publisher Policies](https://support.google.com/publisherpolicies/answer/10502938)
- <a id="s9"></a>**[S9]** [AdMob policies and restrictions](https://support.google.com/admob/answer/6128543)
