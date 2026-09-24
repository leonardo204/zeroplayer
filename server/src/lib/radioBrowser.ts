/**
 * radio-browser 접근 규칙 두 가지를 여기서만 지킨다.
 *  - 단일 서버를 하드코딩하지 않는다. 목록을 받아 돌려 쓰고 실패하면 다음으로 넘긴다.
 *  - User-Agent 를 반드시 보낸다.
 * 앱은 이 파일이 부르는 주소를 전혀 모른다.
 */

const DIRECTORY = 'https://all.api.radio-browser.info/json/servers'
const FALLBACK_HOSTS = ['de1.api.radio-browser.info', 'de2.api.radio-browser.info']
const USER_AGENT = 'zeroplayer/2.0.0 (+https://zerolive.co.kr)'

let hostCache: { hosts: string[]; at: number } | null = null
const HOST_TTL_MS = 30 * 60 * 1000

export interface RBStation {
  stationuuid: string
  name: string
  url: string
  url_resolved: string
  homepage: string
  favicon: string
  tags: string
  countrycode: string
  language: string
  languagecodes: string
  codec: string
  bitrate: number
  votes: number
  clickcount: number
  lastcheckok: number
  hls: number
}

async function hosts(): Promise<string[]> {
  if (hostCache && Date.now() - hostCache.at < HOST_TTL_MS) return hostCache.hosts
  try {
    const res = await fetch(DIRECTORY, {
      headers: { 'user-agent': USER_AGENT, accept: 'application/json' },
      signal: AbortSignal.timeout(8000),
    })
    if (res.ok) {
      const list = (await res.json()) as Array<{ name?: string }>
      const names = [...new Set(list.map((s) => s.name).filter((n): n is string => !!n))]
      if (names.length) {
        const shuffled = names.sort(() => Math.random() - 0.5)
        hostCache = { hosts: shuffled, at: Date.now() }
        return shuffled
      }
    }
  } catch {
    // 목록 조회가 실패해도 아래 기본값으로 계속 간다.
  }
  hostCache = { hosts: [...FALLBACK_HOSTS], at: Date.now() }
  return hostCache.hosts
}

/** 살아 있는 서버를 찾을 때까지 넘겨 가며 호출한다. */
async function call<T>(path: string): Promise<T> {
  const candidates = await hosts()
  let lastError: unknown = new Error('radio-browser 서버 목록이 비어 있다')
  for (const host of candidates.slice(0, 3)) {
    try {
      const res = await fetch(`https://${host}${path}`, {
        headers: { 'user-agent': USER_AGENT, accept: 'application/json' },
        signal: AbortSignal.timeout(20000),
      })
      if (!res.ok) {
        lastError = new Error(`${host} → HTTP ${res.status}`)
        continue
      }
      return (await res.json()) as T
    } catch (error) {
      lastError = error
      hostCache = null // 다음 호출에서 목록을 다시 받는다
    }
  }
  throw lastError
}

/** 한 나라의 방송국을 인기순으로 받는다. limit 이 0 이면 그 나라 전체를 받는다. */
export function stationsByCountry(code: string, limit: number): Promise<RBStation[]> {
  const params = new URLSearchParams({
    countrycode: code,
    hidebroken: 'true',
    order: 'clickcount',
    reverse: 'true',
  })
  if (limit > 0) params.set('limit', String(limit))
  return call<RBStation[]>(`/json/stations/search?${params.toString()}`)
}
