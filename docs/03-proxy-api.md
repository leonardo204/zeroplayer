# 프록시 API — ai.zerolive.co.kr

## 1. 프록시가 떠안는 일

앱은 프록시 한 곳만 부른다. 그래서 다음이 모두 서버 쪽 책임이다.

| 일 | 이유 |
| --- | --- |
| radio-browser 서버 목록을 DNS 로 받아 돌려 쓰고 실패하면 다음으로 넘기기 | radio-browser 가 단일 서버 직접 링크를 금지한다 |
| `zeroplayer/2.0` 형식 User-Agent 전송 | radio-browser 가 요구한다 |
| 방송국 목록 D1 캐시 | radio-browser 가 내려가도 앱은 돌아야 한다 |
| 스트림 생사 확인 | 인터넷 라디오는 조용히 죽는다 |
| `.pls` 파싱, 리다이렉트 추적, m3u8 확인 | 1.x 가 앱에서 하던 일 |
| 한국 지상파 편성표 파싱 | 방송사 페이지 구조가 바뀌면 서버만 고친다 |
| Podcast Index 호출과 RSS 정규화 | |
| 태그 정규화와 분위기 분류 (LLM) | `04-curation.md` |
| 상황별 추천 세트 생성 (LLM, 배치) | `04-curation.md` |
| 알람 예약과 APNs 발송 | |

**앱에 남기지 않는 것:** 스트림 주소, 방송사 도메인, radio-browser 주소, API 키. 전부 서버에만 둔다.

## 2. 인증

- 공개 엔드포인트는 앱 식별용 헤더만 요구한다. `X-ZP-Client: ios/2.0.0`, `X-ZP-Install: <설치 UUID>`.
- 설치 UUID 는 기기 식별자가 아니다. 앱이 처음 실행될 때 만들어 키체인에 넣고, 알람 등록과 남용 차단(rate limit)에만 쓴다.
- 히든 엔드포인트는 별도 토큰을 요구한다. 히든 기능을 해제할 때 서버에서 받아 키체인에 저장한다. 이렇게 하면 앱 바이너리를 뜯어도 한국 지상파 채널 목록이 바로 나오지 않는다.
- 이 토큰은 보안 장치가 아니라 문턱이다. 해제 엔드포인트 주소도 바이너리에 있으므로 뜯으면 부를 수 있다. 목적은 두 가지뿐이다. 히든 채널 목록이 공개 API 응답에 섞여 나가지 않게 하는 것, 그리고 설치 UUID 단위로 해제 기록을 남겨 남용을 막는 것.

## 3. 엔드포인트

버전 접두사 `/zp/v1`.

### 3.1 추천

```
GET /zp/v1/recommend
  ?situation=sleep|commute|study|work|wake
  &at=2026-09-23T23:10:00+09:00
  &country=KR
  &lang=ko
  &limit=20
```

```json
{
  "situation": "sleep",
  "generatedAt": "2026-09-23T04:00:00Z",
  "items": [
    {
      "kind": "station",
      "id": "rb:9f2c1e7a-...",
      "title": "Jazz24",
      "subtitle": "Seattle · Jazz",
      "reason": "늦은 시간에 어울리는 조용한 연주곡 위주 채널이다.",
      "artworkURL": "https://.../favicon.png",
      "tags": ["jazz", "smooth"],
      "moods": ["calm", "late-night"]
    },
    {
      "kind": "episode",
      "id": "pi:1420924:8817263",
      "title": "밤의 서점 · 12화",
      "subtitle": "42분",
      "durationSeconds": 2520,
      "reason": "취침 타이머 45분에 맞는 길이다."
    }
  ]
}
```

**`at` 은 오프셋 없이 보낸다.** `2026-09-24T23:10:00` 처럼 기기 시계만 적는다. `+09:00` 을
붙이면 질의 문자열에서 `+` 가 공백으로 풀려 서버가 시각을 통째로 놓친다. 서버는 문자열
앞부분에서 시·요일을 읽고, 오프셋이 붙어 와도 읽는다.

`secure=1` 을 붙이면 HTTPS 스트림만 온다. 앱이 스스로 고르는 자리(프리셋 자동 선택)는 이걸 쓴다.

응답에는 `daypart`, `dayType`, `source`, `model`, `builtAt` 이 함께 온다. `source` 가 `"llm"`
이면 밤에 만들어 둔 세트를 꺼내 준 것이고, `"rule"` 이면 그 자리에서 규칙으로 뽑은 것이다.
둘의 항목 모양은 같아서 앱은 구분하지 않아도 된다.

세트는 매일 04:00 KST 배치가 만든다(`POST /zp/v1/admin/recommend/build` 로 직접 돌릴 수도
있다). 조합은 상황 5 × 시간대 6 × 평일·주말 2 × 나라 2 로 120개고, 사용자 수와 무관하다.
세트에는 HTTPS 스트림만 담는다 — 앱이 골라서 그대로 트는 목록이기 때문이다. 평문 HTTP 까지
달라는 요청(`secure` 없이 `country` 를 준 경우)은 규칙으로 즉석에서 뽑아 준다.
앱은 받은 목록을 **기기에서 다시 정렬한다**(`04-curation.md` 3단계). 서버 순서는 시작점이다.

**M3 구현 상태.** 1단 규칙만 돈다. 상황 다섯 가지의 태그 규칙은 `server/src/lib/situations.ts`
에 있다. 후보가 모자라면 세 번에 걸쳐 조건을 푼다 — 나라 안에서 태그를 맞춘 것 → 전 세계에서
태그를 맞춘 것 → 나라 안에서 제외 규칙만 건 것. 같은 방송을 올린 줄이 여럿이라 이름이 같으면
하나만 남긴다. 분위기(`station_moods`)는 아직 비어 있어 보지 않는다.

### 3.2 방송국

```
GET /zp/v1/stations?country=KR&tag=jazz&lang=ko&q=&sort=popular&secure=1&limit=50&cursor=
GET /zp/v1/stations/{id}
GET /zp/v1/stations/facets          → 국가·태그·언어 목록과 각 개수
```

`secure=1` 은 HTTPS 스트림만 내려준다. 목록 항목의 `isSecure` 도 같은 값을 담는다.
평문 HTTP 를 못 여는 기기에서 걸러 내려고 M2 에서 더했다. `cursor` 는 오프셋 문자열이다.
목록과 facets 응답에는 5분 엣지 캐시가 붙는다.

```
GET /zp/v1/stations/{id}/stream
```

```json
{ "url": "http://stream.example.org/jazz24.aac", "codec": "aac", "bitrate": 128, "recheckAfter": 3600 }
```

스트림 URL 은 재생 직전에 이 엔드포인트로 받는다. 앱에 캐시하지 않는다. 방송국이 주소를 바꾸면 서버만 고친다. `url` 은 방송국 원본 주소 그대로다. 프록시가 오디오를 중계하지 않는다(`02-architecture.md` 5번). `recheckAfter` 는 같은 채널을 이어 들을 때 주소를 다시 물어볼 주기다.

```
POST /zp/v1/stations/{id}/report
Body: { "reason": "no_audio" | "error" | "wrong_content" }
```

앱이 15초 안에 첫 오디오를 못 받으면 신고한다. 신고가 쌓인 채널은 추천에서 빠진다.

### 3.3 팟캐스트

```
GET /zp/v1/podcasts/trending?country=KR&limit=30
GET /zp/v1/podcasts/search?q=&country=KR&limit=30
GET /zp/v1/podcasts/{feedID}
GET /zp/v1/podcasts/{feedID}/episodes?limit=50&cursor=&secure=1
GET /zp/v1/episodes/{episodeID}
GET /zp/v1/episodes/{episodeID}/stream
```

`feedID` 는 `it:<애플 번호>` 또는 `pi:<Podcast Index 번호>` 이고, 에피소드 ID 는
`<feedID>:<guid 해시>` 다. 에피소드 응답에는 `durationSeconds`·`publishedAt`·`isSecure` 가 있다.

**에피소드 오디오 주소는 목록에 담지 않는다.** 방송국과 같은 규칙(`02-architecture.md` 5번)을
지켜 재생 직전에 `/episodes/{id}/stream` 으로만 준다. 팟캐스트 오디오도 평문 HTTP 가 흔해서
`isSecure` 로 구분하고, 앱이 고르는 자리에서는 `secure=1` 로 HTTPS 만 받는다.

**소스는 세 가지이고 순서가 있다.** Podcast Index 키(`PI_KEY`·`PI_SECRET`)가 있으면 그쪽,
없으면 D1 에 이미 있는 것에서 찾는다(`source: "local"`). 애플 나라별 인기 순위
(`rss.marketingtools.apple.com`)는 키 없이 열려서 순위에 쓴다.

**iTunes Search 는 Worker 에서 안 열린다.** 나가는 IP 가 Cloudflare 공용이라 Apple 한도에
이미 걸려 있어 429·403 만 온다(2026-09 실측). 아래 7번의 '분당 약 20회' 는 자기 컴퓨터에서
부를 때 이야기다. 그래서 피드는 `POST /admin/podcasts/add?feed=<RSS 주소>&id=it:<번호>` 로
직접 등록한다. 등록은 RSS 를 읽어 팟캐스트와 에피소드를 함께 넣는다.

추천에 `timer=45` 를 붙이면 35~55분 에피소드가 목록 맨 앞에 최대 3편 섞인다.

### 3.4 히든 — 한국 지상파

```
POST /zp/v1/hidden/unlock         → 해제 토큰 발급 (설치 UUID 기준). 상태를 바꾸므로 GET 이 아니다
GET /zp/v1/hidden/channels        → 채널 목록 (토큰 필요)
GET /zp/v1/hidden/channels/{id}/stream
GET /zp/v1/hidden/channels/{id}/now
```

`now` 응답:

```json
{
  "programName": "볼륨을 높여요",
  "startTime": "20:00",
  "endTime": "22:00",
  "artworkURL": "https://...",
  "refreshAfter": 300
}
```

편성표 파싱은 서버가 한다. **1.x 의 파싱 규칙을 그대로 옮긴다.** KBS 는 `og:image`·`og:description` 메타 태그, MBC 는 `control.imbc.com/Schedule/PCONAIR?type=radio` JSON, SBS 는 `__NEXT_DATA__` 스크립트, TBS 는 HTML 본문, CBS 는 편성표 하드코딩. 다만 앱 안에서 강제 언랩으로 자르던 것을 서버에서 실패 허용으로 바꾼다. 파싱이 실패하면 `programName` 을 비워 보내고 앱은 채널명만 표시한다.

`serpent0.duckdns.org` 의 `.pls` 주소는 서버의 채널 표에만 둔다. 나중에 끊기면 이 표만 고친다. 앱은 그대로 둔다.

### 3.5 알람

```
POST /zp/v1/push/token
Body: { "token": "<APNs device token>", "env": "prod" }

POST /zp/v1/alarms
Body: {
  "hour": 7, "minute": 0,
  "weekdays": [2,3,4,5,6],
  "timezone": "Asia/Seoul",
  "source": { "kind": "station", "id": "rb:..." } 또는 { "kind": "auto", "situation": "wake" }
}
→ { "alarmID": "alm_..." }

PATCH  /zp/v1/alarms/{alarmID}
DELETE /zp/v1/alarms/{alarmID}
```

서버는 Cron Trigger 로 분 단위로 돌며 `next_fire_at <= now` 인 알람을 찾는다. 발송 직전에 소스의 현재 정보를 조회해 알림 본문을 만들고, 발송 후 다음 발송 시각을 다시 써 둔다.

APNs 는 HTTP/2 만 받는다. 배포된 Worker 의 `fetch()` 는 APNs 와 통신이 되지만, 로컬 `wrangler dev` 에서는 HTTP/2 협상이 안 돼 실패한다 [[S5]](#s5). 그래서 발송 테스트는 배포 환경에서 한다. JWT 서명은 Workers 의 WebCrypto 로 되고, Workers 용 클라이언트(`cloudflare-apns2`)가 있다 [[S6]](#s6). APNs 인증 키(.p8)는 App Store Connect API 키와 다른 것이라 개발자 포털 Keys 에서 APNs 용으로 새로 만든다.

푸시 payload:

```json
{
  "aps": {
    "alert": { "title": "알람", "body": "KBS 쿨FM · 지금 〈볼륨을 높여요〉 방송 중" },
    "sound": "alarm_soft.caf",
    "category": "ZP_ALARM",
    "interruption-level": "time-sensitive"
  },
  "zp": { "alarmID": "alm_...", "kind": "station", "id": "rb:..." }
}
```

`interruption-level: time-sensitive` 를 쓰면 집중 모드에서도 표시된다. 앱에 Time Sensitive Notifications 권한(entitlement)이 필요하다. 권한 승인 전에도 payload 에 담아 보내는 것은 문제가 없다 — iOS 가 조용히 보통 알림으로 내린다.

**M6 실측 메모.** 세 가지가 계획과 달랐다.

발송 본문의 편성표 조회는 한국 지상파가 대상이라 M7 로 넘겼다. 지금은 자동 선택 알람이 그 시각의 추천 세트에서 한 곳을 골라 `"<채널 이름> · <추천 문구>"` 로 적는다.

알람 사운드는 시스템 기본음(`"sound": "default"`)을 쓴다. 30초짜리 커스텀 사운드는 M8 에 넣는다.

발급받은 APNs 키가 sandbox 전용이다. 같은 JWT 로 sandbox 는 `400 BadDeviceToken`(인증 통과), 배포 환경은 `403 BadEnvironmentKeyInToken` 이 온다. 출시 전에 배포 환경도 되는 키로 다시 만들어야 한다.

같은 분에 두 번 보내지 않도록 `alarm_sends(alarm_id, fired_at)` 에 먼저 줄을 잡고 발송한다. 10분 넘게 지난 알람은 보내지 않고 다음 시각으로 민다 — 아침 7시 알람이 9시에 오면 놀라기만 한다.

### 3.6 상태

```
GET /zp/v1/health     → 데이터 소스별 마지막 갱신 시각과 성공 여부
```

## 4. D1 스키마

```sql
-- 방송국. radio-browser 에서 받아 정규화한 결과
CREATE TABLE stations (
  id            TEXT PRIMARY KEY,      -- 'rb:<uuid>' 또는 'kr:<slug>'
  source        TEXT NOT NULL,         -- 'radio_browser' | 'manual'
  name          TEXT NOT NULL,
  stream_url    TEXT NOT NULL,
  homepage      TEXT,
  favicon       TEXT,
  country_code  TEXT,
  language      TEXT,
  codec         TEXT,
  bitrate       INTEGER,
  votes         INTEGER DEFAULT 0,
  clicks        INTEGER DEFAULT 0,
  is_hidden     INTEGER DEFAULT 0,     -- 1 이면 한국 지상파. 토큰 없이는 안 준다
  raw_tags      TEXT,                  -- radio-browser 원문. 정규화 규칙이 바뀌면 여기서 다시 계산한다
  updated_at    TEXT NOT NULL
);

-- radio-browser 원시 태그를 표준 태그로 옮기는 표. 규칙으로 못 줄인 것만 LLM 이 채운다.
-- normalized 가 NULL 이면 판정 전, 빈 문자열이면 '맞는 표준 태그 없음' 이다.
CREATE TABLE tag_aliases (
  raw        TEXT PRIMARY KEY,
  normalized TEXT,
  origin     TEXT NOT NULL,           -- 'rule' | 'ai' | 'manual'
  created_at TEXT NOT NULL
);

-- 배치가 어디까지 했는지. /zp/v1/health 가 이 표를 읽는다
CREATE TABLE sync_state (
  job         TEXT PRIMARY KEY,       -- 'radio_browser:KR', 'stream_check', 'tag_normalize'
  last_run_at TEXT,
  last_ok_at  TEXT,
  ok          INTEGER DEFAULT 0,
  detail      TEXT
);

-- 정규화된 태그. 'pop','POP','música pop','Pop Music' → 'pop'
CREATE TABLE station_tags (
  station_id TEXT NOT NULL REFERENCES stations(id) ON DELETE CASCADE,
  tag        TEXT NOT NULL,
  PRIMARY KEY (station_id, tag)
);

-- LLM 이 붙인 분위기. calm, energetic, late-night, focus, background ...
CREATE TABLE station_moods (
  station_id TEXT NOT NULL REFERENCES stations(id) ON DELETE CASCADE,
  mood       TEXT NOT NULL,
  confidence REAL,
  PRIMARY KEY (station_id, mood)
);

-- 스트림 생사. 앱 신고와 서버 점검 결과가 함께 쌓인다
CREATE TABLE station_health (
  station_id     TEXT PRIMARY KEY REFERENCES stations(id) ON DELETE CASCADE,
  last_ok_at     TEXT,
  last_fail_at   TEXT,
  fail_streak    INTEGER DEFAULT 0,
  report_count   INTEGER DEFAULT 0,
  excluded       INTEGER DEFAULT 0     -- 1 이면 추천에서 제외
);

-- 상황별 추천 세트. 하루 한 번 배치로 만든다
CREATE TABLE recommendation_sets (
  id         TEXT PRIMARY KEY,         -- 'sleep|weekday|22-02|KR'
  situation  TEXT NOT NULL,
  daypart    TEXT NOT NULL,            -- '22-02' 같은 시간대 구간
  day_type   TEXT NOT NULL,            -- 'weekday' | 'weekend'
  country    TEXT NOT NULL,
  payload    TEXT NOT NULL,            -- 항목 배열 JSON. reason 포함
  model      TEXT,                     -- 어느 모델이 만들었는지
  created_at TEXT NOT NULL
);

-- 팟캐스트
CREATE TABLE podcasts (
  feed_id     TEXT PRIMARY KEY,        -- Podcast Index feed id
  title       TEXT NOT NULL,
  author      TEXT,
  feed_url    TEXT NOT NULL,
  artwork     TEXT,
  language    TEXT,
  categories  TEXT,                    -- JSON 배열
  updated_at  TEXT NOT NULL
);

-- 기기와 알람
CREATE TABLE devices (
  install_id  TEXT PRIMARY KEY,
  push_token  TEXT,
  platform    TEXT DEFAULT 'ios',
  app_version TEXT,
  hidden_unlocked INTEGER DEFAULT 0,
  last_seen_at TEXT
);

CREATE TABLE alarms (
  id          TEXT PRIMARY KEY,
  install_id  TEXT NOT NULL REFERENCES devices(install_id) ON DELETE CASCADE,
  hour        INTEGER NOT NULL,
  minute      INTEGER NOT NULL,
  weekdays    TEXT NOT NULL,           -- '2,3,4,5,6'
  timezone    TEXT NOT NULL,
  source_kind TEXT NOT NULL,           -- 'station' | 'podcast' | 'auto'
  source_id   TEXT,
  situation   TEXT,
  enabled     INTEGER DEFAULT 1,
  next_fire_at TEXT,                  -- UTC. 시간대별 계산을 매분 하지 않도록 미리 써 둔다
  last_sent_at TEXT,
  created_at  TEXT NOT NULL
);

CREATE INDEX idx_stations_country ON stations(country_code, is_hidden);
CREATE INDEX idx_alarms_due ON alarms(enabled, next_fire_at);
```

## 5. 배치 작업 (Cron Trigger)

| 주기 | 일 |
| --- | --- |
| 분마다 | `next_fire_at` 이 지난 알람 조회, APNs 발송, 다음 발송 시각 갱신 |
| 6시간마다 | radio-browser 동기화. 전체를 받는 나라는 사라진 방송국까지 정리한다 |
| 매일 05:40 KST | 판정 대기 태그를 Workers AI 로 정규화하고 태그를 다시 계산 |
| 매일 04:00 KST | 상황별 추천 세트 재생성 (M4) |
| 매시 17분 | 스트림 생사 점검 150건. `fail_streak >= 3` 이면 `excluded = 1`. IP 주소로 된 주소는 판정을 미룬다 — Cloudflare 안에서 IP 직접 접근이 막혀 살았는지 알 수 없다 |
| 매일 | Podcast Index 인기 목록 갱신 |

## 6. 시작 규모

전 세계 방송국을 전부 넣지 않는다. 처음에는 **한국 116개 + 주요 국가 인기순 상위**로 수천 개 규모로 시작하고, 사용자가 실제로 듣는 나라부터 넓힌다. 태그 정규화와 분위기 분류에 드는 LLM 비용이 방송국 수에 비례하기 때문이다.

## 7. 데이터 소스 조건

| 소스 | 라이선스 | 비용 | 제약 |
| --- | --- | --- | --- |
| radio-browser | 데이터는 퍼블릭 도메인, 소프트웨어는 오픈소스. *"You may use it in free and non free software"* [[S1]](#s1) [[S2]](#s2) | 무료, 키 없음 | User-Agent 필수. 서버 주소 하드코딩 금지 |
| Podcast Index | MIT. *"always be available for free, for any use"* [[S3]](#s3) | 무료, 키 발급 | 재판매 금지. 사용량 제한은 서버 재량 |
| iTunes Search | 명시 없음 | 무료, 키 없음 | **분당 약 20회** (IP 기준) [[S4]](#s4). 다만 Cloudflare Worker 에서는 공용 IP 가 이미 한도에 걸려 429·403 만 온다(2026-09 실측) |

iTunes Search 는 주 소스로 쓰지 않는다. 애초에 Worker 에서 열리지 않아 지금은 보완용으로도 못 쓴다 — 피드는 관리 경로로 직접 등록한다(3.3). Podcast Index 에 한국 팟캐스트 메타데이터가 빈약할 때 보완용으로만 쓰고, 결과는 D1 에 캐시해 호출 수를 줄인다.

## 8. 출처

- <a id="s1"></a>**[S1]** [API.radio-browser.info docs](https://api.radio-browser.info/)
- <a id="s2"></a>**[S2]** [radio-browser.info FAQ](https://www.radio-browser.info/faq)
- <a id="s3"></a>**[S3]** [Podcast Index — Terms of Service](https://api.podcastindex.org/tos_v1.0.html)
- <a id="s4"></a>**[S4]** [iTunes Search API: Constructing Searches](https://developer.apple.com/library/archive/documentation/AudioVideo/Conceptual/iTuneSearchAPI/Searching.html)
- <a id="s5"></a>**[S5]** [APNS HTTP/2 Requests via fetch() Failing on macOS but Working in Workers — cloudflare/workerd #4841](https://github.com/cloudflare/workerd/issues/4841)
- <a id="s6"></a>**[S6]** [cloudflare-apns2 — Workers 용 APNs 클라이언트](https://github.com/FiveSheepCo/cloudflare-apns2)
