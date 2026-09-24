# zeroplayer-api — 프록시 Worker

앱이 부르는 서버는 이 Worker 하나다. `ai.zerolive.co.kr/zp/v1/*` 만 받고, 같은 도메인의
나머지 경로는 원래 있던 서비스가 그대로 가져간다.

## 배포

```sh
cd server
export PATH="/opt/homebrew/bin:$PATH"
npm install --include=dev      # NODE_ENV=production 이라 --include=dev 가 필요하다
npx wrangler deploy
```

D1 스키마를 바꿀 때는 `migrations/` 에 파일을 더하고 적용한다.

```sh
npx wrangler d1 migrations apply zeroplayer --remote
```

| 이름 | 값 |
| --- | --- |
| Worker | `zeroplayer-api` |
| 라우트 | `ai.zerolive.co.kr/zp/v1/*` (zone `zerolive.co.kr`) |
| D1 | `zeroplayer` · `04fa254c-e308-45cc-b258-349fc37d0b8b` |
| Workers AI | 태그 정규화·분위기 분류·추천 문구에 `@cf/meta/llama-3.3-70b-instruct-fp8-fast` |
| 팟캐스트 | 애플 나라별 인기 순위 + RSS. Podcast Index 는 시크릿 `PI_KEY`·`PI_SECRET` 을 넣으면 켜진다 |

## 앱이 쓰는 경로

```
GET  /zp/v1/health
GET  /zp/v1/recommend?situation=sleep&at=2026-09-24T23:10:00&country=KR&secure=1&limit=20
GET  /zp/v1/stations?country=KR&tag=jazz&lang=ko&q=&sort=popular&secure=1&limit=50&cursor=
GET  /zp/v1/stations/facets
GET  /zp/v1/stations/{id}
GET  /zp/v1/stations/{id}/stream
POST /zp/v1/stations/{id}/report   { "reason": "no_audio" | "error" | "wrong_content" }

GET  /zp/v1/podcasts/trending?country=KR&limit=30
GET  /zp/v1/podcasts/search?q=&country=KR&limit=30
GET  /zp/v1/podcasts/{feedID}
GET  /zp/v1/podcasts/{feedID}/episodes?limit=50&cursor=&secure=1
GET  /zp/v1/episodes/{episodeID}/stream
```

추천에 `timer=45` 를 붙이면 35~55분 에피소드가 앞에 섞인다. 에피소드 오디오 주소는
목록에 담지 않고 `/episodes/{id}/stream` 으로만 준다.

`recommend` 의 `situation` 은 `sleep·commute·study·work·wake` 다. 상황별 태그·분위기 규칙은
`src/lib/situations.ts` 에 있다. 응답의 `source` 가 `llm` 이면 밤에 만들어 둔 세트를 꺼내 준
것이고, `rule` 이면 그 자리에서 규칙으로 뽑은 것이다. 어느 쪽이든 항목 모양은 같다.

**`at` 에 오프셋을 붙이지 않는다.** `+09:00` 을 붙이면 질의 문자열에서 `+` 가 공백으로 풀려
서버가 시각을 놓치고 UTC 현재 시각으로 떨어진다. 기기 시계만 적어 보낸다.

`secure=1` 은 HTTPS 스트림만 내려준다. 목록 응답의 `isSecure` 도 같은 정보를 담는다.
평문 HTTP 스트림을 못 여는 기기에서 걸러 내려고 둔 것이다(아래 5번).

## 관리 경로

전부 `X-ZP-Admin` 헤더가 필요하다. 토큰은 Worker 시크릿 `ADMIN_TOKEN` 이고 사본은
`server/.dev.vars` 에 있다(git 에 올리지 않는다).

```sh
TOKEN=$(grep ADMIN_TOKEN .dev.vars | sed 's/.*= "//;s/"//')

# 한 나라만 동기화. limit=0 이면 전체를 받고, prune=1 이면 사라진 방송국을 지운다
curl -X POST -H "x-zp-admin: $TOKEN" \
  "https://ai.zerolive.co.kr/zp/v1/admin/sync?country=KR&limit=0&prune=1"

# 설정에 적힌 나라 전부
curl -X POST -H "x-zp-admin: $TOKEN" "https://ai.zerolive.co.kr/zp/v1/admin/sync"

# 판정 대기 태그를 LLM 에 넘긴다. 한 묶음이 25개, batches 로 묶음 수를 정한다
curl -X POST -H "x-zp-admin: $TOKEN" "https://ai.zerolive.co.kr/zp/v1/admin/tags/normalize?batches=4"

# 분위기 분류. 태그가 있는 방송국은 규칙으로, 태그가 없는 것만 모델에 묻는다
curl -X POST -H "x-zp-admin: $TOKEN" "https://ai.zerolive.co.kr/zp/v1/admin/moods/classify?batches=2"

# 상황별 추천 세트 생성. sets 로 한 번에 만들 개수를 정한다. force=1 이면 오늘 만든 것도 다시 만든다
curl -X POST -H "x-zp-admin: $TOKEN" "https://ai.zerolive.co.kr/zp/v1/admin/recommend/build?sets=8"

# 팟캐스트 피드를 주소로 등록한다(iTunes 검색이 Worker 에서 막혀 지금은 이게 주 경로다)
curl -X POST -H "x-zp-admin: $TOKEN" \
  "https://ai.zerolive.co.kr/zp/v1/admin/podcasts/add?feed=<RSS%20주소>&id=it:437788220&country=KR"

# 인기 목록과 그 피드들의 에피소드를 받아 둔다(매일 03:10 KST 배치와 같은 일)
curl -X POST -H "x-zp-admin: $TOKEN" "https://ai.zerolive.co.kr/zp/v1/admin/podcasts/sync?country=KR&feeds=25"

# 워커에서 특정 주소가 열리는지 본다
curl -H "x-zp-admin: $TOKEN" "https://ai.zerolive.co.kr/zp/v1/admin/probe?url=<주소>"

# 스트림 생사 점검 한 묶음
curl -X POST -H "x-zp-admin: $TOKEN" "https://ai.zerolive.co.kr/zp/v1/admin/streams/check?size=150"
```

## 배치

| 주기 | 하는 일 |
| --- | --- |
| 6시간마다 | radio-browser 동기화 |
| 매시 17분 | 스트림 생사 점검 150건 (오래 안 본 것부터) |
| 매일 20:40 UTC | 판정 대기 태그 정규화와 태그 재계산 |

## 알아둘 것

1. **radio-browser 서버는 하드코딩하지 않는다.** `all.api.radio-browser.info/json/servers` 로
   목록을 받아 섞어 쓰고, 실패하면 다음 서버로 넘어간다. User-Agent 도 반드시 보낸다.
2. **태그는 두 단계로 줄인다.** 규칙으로 줄 수 있는 것은 `src/lib/tags.ts` 의 표에서 끝내고,
   남은 것만 LLM 에 묻는다. 판정 결과는 `tag_aliases` 에 쌓여 다시 묻지 않는다.
   원문은 `stations.raw_tags` 에 그대로 있어서 규칙을 고치면 언제든 다시 계산할 수 있다.
3. **IP 주소로 된 스트림은 점검하지 않는다.** Cloudflare 안에서는 IP 로 직접 나가는 요청이
   1밀리초 만에 403 으로 막힌다. 살았는지 알 수 없으므로 판정을 미루고 앱 신고에만 맡긴다.
4. **목록 응답은 엣지에 5분 캐시된다.** 서버에서 방송국을 지워도 앱에 사라지기까지 최대 5분이
   걸린다. 즉시 확인하려면 쿼리 문자열을 바꿔 부른다.
5. **평문 HTTP 스트림이 전체의 35%다.** 이것을 앱이 열 수 있는지는 아직 확정되지 않았다.
   `CONTEXT.md` 의 M2 기록을 본다.
