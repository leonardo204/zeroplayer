import type { Env } from '../types'
import type { FeedInfo } from './itunes'

/**
 * Podcast Index. 키가 있으면 이쪽을 먼저 쓰고, 없으면 iTunes 로 내려간다.
 *
 * 키는 Worker 시크릿 `PI_KEY`·`PI_SECRET` 에 둔다. 인증은 헤더 세 개다 —
 * 키, 요청 시각(유닉스 초), 그리고 `sha1(key + secret + 시각)` 을 Authorization 에 넣는다.
 */

const BASE = 'https://api.podcastindex.org/api/1.0'
const UA = 'zeroplayer/2.0'

export function hasKeys(env: Env): boolean {
  return Boolean(env.PI_KEY && env.PI_SECRET)
}

async function sha1Hex(input: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-1', new TextEncoder().encode(input))
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, '0')).join('')
}

async function call(env: Env, path: string, params: Record<string, string>): Promise<unknown> {
  if (!hasKeys(env)) throw new Error('Podcast Index 키가 없다')
  const at = Math.floor(Date.now() / 1000).toString()
  const url = new URL(BASE + path)
  for (const [key, value] of Object.entries(params)) url.searchParams.set(key, value)

  const response = await fetch(url.toString(), {
    headers: {
      'user-agent': UA,
      'x-auth-key': env.PI_KEY as string,
      'x-auth-date': at,
      authorization: await sha1Hex((env.PI_KEY as string) + (env.PI_SECRET as string) + at),
    },
    signal: AbortSignal.timeout(12_000),
  })
  if (!response.ok) throw new Error(`Podcast Index ${path} → ${response.status}`)
  return await response.json()
}

interface PIFeed {
  id?: number
  title?: string
  author?: string
  ownerName?: string
  url?: string
  image?: string
  artwork?: string
  language?: string
  description?: string
  episodeCount?: number
  categories?: Record<string, string>
}

function toFeed(row: PIFeed): FeedInfo | null {
  if (!row.id || !row.title || !row.url) return null
  return {
    feedId: `pi:${row.id}`,
    source: 'podcast_index',
    title: row.title,
    author: row.author ?? row.ownerName ?? null,
    feedUrl: row.url,
    artwork: row.artwork ?? row.image ?? null,
    language: row.language ? row.language.toLowerCase().slice(0, 5) : null,
    country: null,
    categories: Object.values(row.categories ?? {}).slice(0, 6),
    description: row.description ? row.description.slice(0, 1200) : null,
    episodeCount: row.episodeCount ?? 0,
  }
}

export async function piSearch(env: Env, term: string, limit: number): Promise<FeedInfo[]> {
  const payload = (await call(env, '/search/byterm', {
    q: term,
    max: String(Math.min(limit, 40)),
    fulltext: '0',
  })) as { feeds?: PIFeed[] }
  return (payload.feeds ?? []).map(toFeed).filter((f): f is FeedInfo => f !== null)
}

export async function piTrending(env: Env, lang: string, limit: number): Promise<FeedInfo[]> {
  const payload = (await call(env, '/podcasts/trending', {
    max: String(Math.min(limit, 40)),
    lang,
  })) as { feeds?: PIFeed[] }
  return (payload.feeds ?? []).map(toFeed).filter((f): f is FeedInfo => f !== null)
}

export async function piFeed(env: Env, id: string): Promise<FeedInfo | null> {
  const payload = (await call(env, '/podcasts/byfeedid', { id })) as { feed?: PIFeed }
  return payload.feed ? toFeed(payload.feed) : null
}
