import type { Env } from '../types'
import { nowISO } from './http'

/**
 * 한국 지상파 편성표. 1.x 가 앱 안에서 하던 파싱을 그대로 서버로 옮겼다.
 *
 * 1.x 와 다른 점은 하나다 — **실패해도 던지지 않는다.** 1.x 는 강제 언랩으로 잘라서
 * 방송사가 페이지를 바꾸면 앱이 죽었다. 여기서는 못 읽으면 프로그램 이름을 비우고
 * 앱은 채널 이름만 보여 준다. 재생은 편성표와 무관하게 된다.
 *
 * 실측(2026-09-24)한 응답 모양은 각 파서 주석에 적었다.
 */

const UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15'
/** 편성표 캐시 수명. 프로그램은 30분~2시간 단위라 5분이면 충분하다. */
const CACHE_SECONDS = 300

export interface NowPlayingInfo {
  programName: string | null
  startTime: string | null
  endTime: string | null
  artworkURL: string | null
}

const EMPTY: NowPlayingInfo = { programName: null, startTime: null, endTime: null, artworkURL: null }

async function fetchText(url: string, timeoutMs = 10_000): Promise<string | null> {
  try {
    const response = await fetch(url, {
      headers: { 'user-agent': UA, accept: '*/*' },
      signal: AbortSignal.timeout(timeoutMs),
    })
    if (!response.ok) return null
    return await response.text()
  } catch {
    return null
  }
}

/** 'HHMM' 을 'HH:MM' 으로. 이미 콜론이 있으면 그대로 둔다. */
function colonize(raw: string | null | undefined): string | null {
  if (!raw) return null
  const digits = raw.trim()
  if (/^\d{2}:\d{2}$/.test(digits)) return digits
  if (/^\d{4}$/.test(digits)) return digits.slice(0, 2) + ':' + digits.slice(2)
  const found = digits.match(/(\d{1,2}):(\d{2})/)
  if (found) return found[1].padStart(2, '0') + ':' + found[2]
  return null
}

function httpsify(url: string | null | undefined): string | null {
  if (!url) return null
  const trimmed = url.trim()
  if (!trimmed.startsWith('http')) return null
  // 앱이 평문 HTTP 이미지를 못 여는 기기가 있다. 같은 주소의 https 를 준다.
  return trimmed.replace(/^http:\/\//, 'https://')
}

// ─────────────────────────────────────────────────────────── 방송사별 파서

/**
 * KBS. `og:description` 한 줄에 전부 들어 있다.
 *   <meta property="og:description" content="2FM 가비의 슈퍼라디오 15:00~15:30">
 * 앞의 채널 약칭은 버리고 뒤의 'HH:MM~HH:MM' 을 떼어 낸 나머지가 프로그램 이름이다.
 */
async function parseKBS(channelCode: string): Promise<NowPlayingInfo> {
  const html = await fetchText(
    `https://onair.kbs.co.kr/index.html?sname=onair&stype=live&ch_code=${encodeURIComponent(channelCode)}&ch_type=radioList`,
  )
  if (!html) return EMPTY

  const meta = (property: string): string | null => {
    const found = html.match(new RegExp(`<meta property="${property}" content="([^"]*)"`))
    return found ? found[1].trim() : null
  }

  const description = meta('og:description')
  const artwork = httpsify(meta('og:image'))
  if (!description) return { ...EMPTY, artworkURL: artwork }

  const time = description.match(/(\d{1,2}:\d{2})\s*~\s*(\d{1,2}:\d{2})\s*$/)
  let name = time ? description.slice(0, time.index).trim() : description
  // 앞에 붙는 채널 약칭을 뗀다. 실측(2026-09-24)한 값은 네 가지다 —
  //   '1라디오 지금 이 사람', '2라디오 은가은의 빛나는 트로트', '1FM 명연주 명음반', '2FM 가비의 슈퍼라디오'
  name = name.replace(/^[1-9](?:TV|FM|R|라디오)\s+/, '').trim()

  return {
    programName: name || null,
    startTime: time ? colonize(time[1]) : null,
    endTime: time ? colonize(time[2]) : null,
    artworkURL: artwork,
  }
}

/**
 * MBC. 전 채널이 한 JSON 에 함께 온다.
 *   GET https://control.imbc.com/Schedule/PCONAIR?type=radio
 *   { "RadioList": [ { "TypeTitle": "FM4U", "Title": ..., "StartTime": "1400", "EndTime": "1600", "Photo": ... } ] }
 * 1.x 는 응답이 <body><p> 로 감싸여 온다고 보고 잘라 냈다. 지금은 순수 JSON 이라
 * 감싸개가 있으면 벗기고 없으면 그대로 읽는다.
 */
async function parseMBC(typeTitle: string): Promise<NowPlayingInfo> {
  const raw = await fetchText('https://control.imbc.com/Schedule/PCONAIR?type=radio')
  if (!raw) return EMPTY

  const body = raw.includes('<body>') ? raw.replace(/^[\s\S]*<body>\s*<p>/, '').replace(/<\/p>\s*<\/body>[\s\S]*$/, '') : raw
  let list: Array<Record<string, unknown>>
  try {
    list = (JSON.parse(body) as { RadioList?: Array<Record<string, unknown>> }).RadioList ?? []
  } catch {
    return EMPTY
  }

  const row = list.find((item) => String(item.TypeTitle ?? '').trim() === typeTitle)
  if (!row) return EMPTY
  return {
    programName: String(row.Title ?? '').trim() || null,
    startTime: colonize(String(row.StartTime ?? '')),
    endTime: colonize(String(row.EndTime ?? '')),
    artworkURL: httpsify(String(row.Photo ?? '')),
  }
}

/**
 * SBS. Next.js 페이지에 심어 둔 JSON 을 꺼낸다.
 *   <script id="__NEXT_DATA__" type="application/json">{...}</script>
 *   props.pageProps.radio[] = { channelname: 'POWER FM', title, starttime: '14:00', endtime, thumbimg }
 */
async function parseSBS(channelName: string): Promise<NowPlayingInfo> {
  const html = await fetchText('https://www.sbs.co.kr/ko/live?div=gnb_pc', 14_000)
  if (!html) return EMPTY

  const found = html.match(/<script id="__NEXT_DATA__" type="application\/json">([\s\S]*?)<\/script>/)
  if (!found) return EMPTY

  let list: Array<Record<string, unknown>>
  try {
    const parsed = JSON.parse(found[1]) as {
      props?: { pageProps?: { radio?: Array<Record<string, unknown>> } }
    }
    list = parsed.props?.pageProps?.radio ?? []
  } catch {
    return EMPTY
  }

  const key = channelName.replace(/\s+/g, '').toUpperCase()
  const row = list.find((item) => String(item.channelname ?? '').replace(/\s+/g, '').toUpperCase() === key)
  if (!row) return EMPTY
  return {
    programName: String(row.title ?? '').trim() || null,
    startTime: colonize(String(row.starttime ?? '')),
    endTime: colonize(String(row.endtime ?? '')),
    artworkURL: httpsify(String(row.thumbimg ?? '')),
  }
}

/**
 * TBS. 재생 페이지 HTML 에 그대로 적혀 있다.
 *   <span class="time">15:00 ~ 16:00</span> … <span class="tit">최일구의 허리케인 라디오</span>
 *   posterUrl = "http://tbs.seoul.kr/common/images/video/ONAIR_FM_….png"
 */
async function parseTBS(channelCode: string): Promise<NowPlayingInfo> {
  const html = await fetchText(
    `https://tbs.seoul.kr/player/live.do?channelCode=${encodeURIComponent(channelCode)}`,
  )
  if (!html) return EMPTY

  const time = html.match(/class="time">\s*(\d{1,2}:\d{2})\s*~\s*(\d{1,2}:\d{2})/)
  const title = html.match(/class="tit">\s*([^<]+)</)
  const poster = html.match(/posterUrl\s*=\s*"([^"]+)"/)

  return {
    programName: title ? title[1].trim() || null : null,
    startTime: time ? colonize(time[1]) : null,
    endTime: time ? colonize(time[2]) : null,
    artworkURL: httpsify(poster ? poster[1] : null),
  }
}

/**
 * CBS. 편성표를 내주는 자리가 없어 1.x 처럼 표를 들고 있는다.
 * 방송사가 개편하면 이 표만 고친다 — 서버라서 앱을 새로 올릴 필요가 없다.
 * 1.x 가 함께 들고 있던 이미지 주소는 개인 서버(zerolive7.iptime.org)라 지금 죽어 있어 뺐다.
 */
const CBS_MUSIC: Array<{ start: string; end: string; name: string }> = [
  { start: '00:00', end: '02:00', name: '시작하는 밤 박준입니다' },
  { start: '02:00', end: '04:00', name: '이지민의 All that Jazz' },
  { start: '04:00', end: '06:00', name: '김윤주의 내가 매일 기쁘게' },
  { start: '06:00', end: '07:00', name: '정민아의 Amazing Grace' },
  { start: '07:00', end: '09:00', name: '김용신의 그대와 여는 아침' },
  { start: '09:00', end: '11:00', name: '강석우의 아름다운 당신에게' },
  { start: '11:00', end: '12:00', name: '신지혜의 영화음악' },
  { start: '12:00', end: '14:00', name: '이수영의 12시에 만납시다' },
  { start: '14:00', end: '16:00', name: '한동준의 FM POPS' },
  { start: '16:00', end: '18:00', name: '박승화의 가요속으로' },
  { start: '18:00', end: '20:00', name: '배미향의 저녁스케치' },
  { start: '20:00', end: '22:00', name: '김현주의 행복한 동행' },
  { start: '22:00', end: '24:00', name: '허윤희의 꿈과 음악사이에' },
]

/** 서울 시각의 분. Worker 는 UTC 로 도니 시간대를 지정해 읽는다. */
function seoulMinutes(): number {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Asia/Seoul', hour: '2-digit', minute: '2-digit', hour12: false,
  }).formatToParts(new Date())
  const hour = Number(parts.find((p) => p.type === 'hour')?.value ?? '0')
  const minute = Number(parts.find((p) => p.type === 'minute')?.value ?? '0')
  return (hour % 24) * 60 + minute
}

function parseCBS(): NowPlayingInfo {
  const now = seoulMinutes()
  const toMinutes = (hhmm: string) => Number(hhmm.slice(0, 2)) * 60 + Number(hhmm.slice(3, 5))
  const row = CBS_MUSIC.find((item) => now >= toMinutes(item.start) && now < toMinutes(item.end))
  if (!row) return EMPTY
  return { programName: row.name, startTime: row.start, endTime: row.end === '24:00' ? '00:00' : row.end, artworkURL: null }
}

// ─────────────────────────────────────────────────────────── 스트림 주소

/**
 * `.pls` 는 부를 때마다 새로 서명된 주소를 준다. 그래서 목록에 담아 두지 않고
 * 재생 직전에 푼다 — M2 에서 radio-browser 에 적힌 KBS·MBC 주소가 전부 403 이던 이유가
 * 서명이 만료된 주소를 저장해 뒀기 때문이다.
 */
export async function resolveHiddenStream(url: string, kind: string): Promise<string | null> {
  if (kind !== 'pls') return url

  const body = await fetchText(url, 12_000)
  if (!body) return null

  const lines = body.split(/\r?\n/)
  const files = lines
    .filter((line) => /^File\d+=/i.test(line.trim()))
    .map((line) => line.trim().replace(/^File\d+=/i, '').trim())
    .filter((value) => value.startsWith('http'))
  if (!files.length) return null

  // 평문 HTTP 는 기기에서 안 열린다. https 를 먼저 고르고 없으면 첫 줄을 준다.
  return files.find((value) => value.startsWith('https://')) ?? files[0]
}

// ─────────────────────────────────────────────────────────── 캐시와 진입점

export interface HiddenChannelRef {
  id: string
  name: string
  schedule_kind: string | null
  schedule_url: string | null
}

async function parseNow(channel: HiddenChannelRef): Promise<NowPlayingInfo> {
  const key = channel.schedule_url ?? ''
  switch (channel.schedule_kind) {
    case 'kbs': return await parseKBS(key)
    case 'mbc': return await parseMBC(key)
    case 'sbs': return await parseSBS(key)
    case 'tbs': return await parseTBS(key)
    case 'cbs': return parseCBS()
    default: return EMPTY
  }
}

/** 캐시가 살아 있으면 그대로 주고, 아니면 방송사에 물어 다시 채운다. */
export async function loadNow(env: Env, channel: HiddenChannelRef): Promise<NowPlayingInfo> {
  const cached = await env.DB.prepare(
    'SELECT program_name, start_time, end_time, artwork_url, fetched_at FROM hidden_now_cache WHERE channel_id = ?',
  ).bind(channel.id).first<{
    program_name: string | null
    start_time: string | null
    end_time: string | null
    artwork_url: string | null
    fetched_at: string
  }>()

  if (cached) {
    const age = (Date.now() - Date.parse(cached.fetched_at)) / 1000
    if (Number.isFinite(age) && age >= 0 && age < CACHE_SECONDS) {
      return {
        programName: cached.program_name,
        startTime: cached.start_time,
        endTime: cached.end_time,
        artworkURL: cached.artwork_url,
      }
    }
  }

  const fresh = await parseNow(channel)
  const ok = fresh.programName ? 1 : 0
  await env.DB.prepare(`
    INSERT INTO hidden_now_cache (channel_id, program_name, start_time, end_time, artwork_url, ok, detail, fetched_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(channel_id) DO UPDATE SET
      program_name = excluded.program_name,
      start_time = excluded.start_time,
      end_time = excluded.end_time,
      artwork_url = excluded.artwork_url,
      ok = excluded.ok,
      detail = excluded.detail,
      fetched_at = excluded.fetched_at
  `).bind(
    channel.id, fresh.programName, fresh.startTime, fresh.endTime, fresh.artworkURL,
    ok, ok ? null : '편성표를 읽지 못했다', nowISO(),
  ).run()

  // 방금 읽기에 실패했는데 예전 값이 남아 있으면 그쪽이 낫다 — 잠깐 막힌 것일 수 있다.
  if (!ok && cached?.program_name) {
    return {
      programName: cached.program_name,
      startTime: cached.start_time,
      endTime: cached.end_time,
      artworkURL: cached.artwork_url,
    }
  }
  return fresh
}
