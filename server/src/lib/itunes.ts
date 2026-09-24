/**
 * Podcast Index 키가 없는 동안 쓰는 임시 소스.
 *
 * iTunes Search 는 키가 없지만 IP 기준 분당 약 20회 제한이 있고(`docs/03-proxy-api.md` 7번),
 * Worker 의 나가는 IP 는 여러 사용자가 함께 쓴다. 그래서 결과를 반드시 D1 에 캐시하고
 * 여기서는 한 번에 한 질의만 보낸다.
 */

export interface FeedInfo {
  feedId: string
  source: 'itunes' | 'podcast_index'
  title: string
  author: string | null
  feedUrl: string
  artwork: string | null
  language: string | null
  country: string | null
  categories: string[]
  description: string | null
  episodeCount: number
}

const UA = 'zeroplayer/2.0 (+https://zerolive.co.kr)'

async function getJSON(url: string): Promise<unknown> {
  const response = await fetch(url, {
    headers: { 'user-agent': UA, accept: 'application/json' },
    signal: AbortSignal.timeout(12_000),
  })
  if (!response.ok) throw new Error(`${url} → ${response.status}`)
  return await response.json()
}

interface ITunesResult {
  collectionId?: number
  collectionName?: string
  artistName?: string
  feedUrl?: string
  artworkUrl600?: string
  artworkUrl100?: string
  genres?: string[]
  trackCount?: number
  country?: string
  primaryGenreName?: string
}

/** iTunes 의 3글자 국가 코드를 2글자로 옮긴다. 목록에 없으면 비워 둔다. */
const COUNTRY3: Record<string, string> = {
  KOR: 'KR', USA: 'US', JPN: 'JP', GBR: 'GB', DEU: 'DE', FRA: 'FR', CAN: 'CA',
  AUS: 'AU', ITA: 'IT', ESP: 'ES', NLD: 'NL', BRA: 'BR', MEX: 'MX', SWE: 'SE',
  POL: 'PL', CHN: 'CN', TWN: 'TW', HKG: 'HK', IND: 'IN', RUS: 'RU',
}

function toFeed(row: ITunesResult): FeedInfo | null {
  if (!row.collectionId || !row.collectionName || !row.feedUrl) return null
  return {
    feedId: `it:${row.collectionId}`,
    source: 'itunes',
    title: row.collectionName,
    author: row.artistName ?? null,
    feedUrl: row.feedUrl,
    artwork: row.artworkUrl600 ?? row.artworkUrl100 ?? null,
    language: null,
    country: row.country ? (COUNTRY3[row.country] ?? null) : null,
    // '팟캐스트' 는 장르가 아니라 매체 이름이라 뺀다.
    categories: (row.genres ?? []).filter((g) => g !== '팟캐스트' && g !== 'Podcasts'),
    description: null,
    episodeCount: row.trackCount ?? 0,
  }
}

export async function itunesSearch(term: string, country: string, limit: number): Promise<FeedInfo[]> {
  const url = new URL('https://itunes.apple.com/search')
  url.searchParams.set('term', term)
  url.searchParams.set('media', 'podcast')
  url.searchParams.set('entity', 'podcast')
  url.searchParams.set('country', country)
  url.searchParams.set('limit', String(Math.min(limit, 50)))
  const payload = (await getJSON(url.toString())) as { results?: ITunesResult[] }
  const seen = new Set<string>()
  const out: FeedInfo[] = []
  for (const row of payload.results ?? []) {
    const feed = toFeed(row)
    // 같은 프로그램이 collectionId 만 다르게 두 번 올라오는 경우가 있다. feed_url 로 접는다.
    if (!feed || seen.has(feed.feedUrl)) continue
    seen.add(feed.feedUrl)
    out.push(feed)
  }
  return out
}

/** collectionId 로 feed_url 을 받는다. 인기 목록은 id 만 주기 때문에 필요하다. */
export async function itunesLookup(ids: string[], country: string): Promise<FeedInfo[]> {
  if (!ids.length) return []
  const url = new URL('https://itunes.apple.com/lookup')
  url.searchParams.set('id', ids.join(','))
  url.searchParams.set('entity', 'podcast')
  url.searchParams.set('country', country)
  const payload = (await getJSON(url.toString())) as { results?: ITunesResult[] }
  return (payload.results ?? []).map(toFeed).filter((f): f is FeedInfo => f !== null)
}

/** 애플이 공개하는 나라별 인기 팟캐스트. 키가 없고 제한 안내도 없다. */
export async function appleTopPodcasts(country: string, limit: number): Promise<string[]> {
  const lower = country.toLowerCase()
  const url = `https://rss.marketingtools.apple.com/api/v2/${lower}/podcasts/top/${Math.min(limit, 100)}/podcasts.json`
  const payload = (await getJSON(url)) as { feed?: { results?: Array<{ id?: string }> } }
  return (payload.feed?.results ?? []).map((r) => r.id).filter((id): id is string => Boolean(id))
}
