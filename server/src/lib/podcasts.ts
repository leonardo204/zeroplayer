import type { Env } from '../types'
import { nowISO } from './http'
import { appleTopPodcasts, itunesLookup, itunesSearch, type FeedInfo } from './itunes'
import { hasKeys, piSearch, piTrending } from './podcastIndex'
import { fetchFeed } from './rss'

export interface FeedRow {
  feed_id: string
  source: string
  title: string
  author: string | null
  feed_url: string
  artwork: string | null
  language: string | null
  country: string | null
  categories: string | null
  description: string | null
  episode_count: number | null
  updated_at: string
  fetched_at: string
}

export interface EpisodeRow {
  id: string
  feed_id: string
  title: string
  audio_url: string
  duration_seconds: number | null
  published_at: string | null
  description: string | null
  artwork: string | null
}

/** 검색 결과를 다시 물어보기까지의 시간. iTunes 분당 제한을 피하려고 길게 둔다. */
const SEARCH_TTL = 6 * 3600 * 1000
/** 인기 목록 */
const CHART_TTL = 12 * 3600 * 1000
/** 에피소드 목록. 팟캐스트는 하루 한 편도 안 나오는 것이 많다. */
const EPISODE_TTL = 3 * 3600 * 1000

function isFresh(at: string | null, ttl: number): boolean {
  if (!at) return false
  const stamp = new Date(at).getTime()
  return Number.isFinite(stamp) && Date.now() - stamp < ttl
}

/** guid 를 짧고 안정된 문자로 줄인다. 같은 피드 안에서만 구분하면 된다. */
function shortHash(raw: string): string {
  let h1 = 0x811c9dc5
  let h2 = 0x01000193
  for (let i = 0; i < raw.length; i++) {
    const code = raw.charCodeAt(i)
    h1 = (h1 ^ code) * 16777619 >>> 0
    h2 = (h2 + code * (i + 1)) >>> 0
  }
  return h1.toString(36) + h2.toString(36)
}

export function episodeId(feedId: string, guid: string): string {
  return `${feedId}:${shortHash(guid)}`
}

export async function upsertFeeds(env: Env, feeds: FeedInfo[]): Promise<void> {
  if (!feeds.length) return
  const at = nowISO()
  const stmt = env.DB.prepare(`
    INSERT INTO podcasts (feed_id, source, title, author, feed_url, artwork, language, country,
                          categories, description, episode_count, updated_at, fetched_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(feed_id) DO UPDATE SET
      title = excluded.title,
      author = COALESCE(excluded.author, podcasts.author),
      feed_url = excluded.feed_url,
      artwork = COALESCE(excluded.artwork, podcasts.artwork),
      language = COALESCE(excluded.language, podcasts.language),
      country = COALESCE(excluded.country, podcasts.country),
      categories = excluded.categories,
      description = COALESCE(excluded.description, podcasts.description),
      episode_count = excluded.episode_count,
      updated_at = excluded.updated_at
  `)
  await env.DB.batch(feeds.map((feed) => stmt.bind(
    feed.feedId, feed.source, feed.title, feed.author, feed.feedUrl, feed.artwork,
    feed.language, feed.country, JSON.stringify(feed.categories), feed.description,
    feed.episodeCount, at, at,
  )))
}

/**
 * RSS 주소를 직접 받아 등록한다.
 *
 * iTunes Search 가 Worker 에서 막혀 있어(공용 IP 가 Apple 한도에 걸린다) 지금은 이게
 * 팟캐스트를 넣는 주된 길이다. Podcast Index 키가 들어오면 검색으로 대체된다.
 */
export async function addFeedByURL(
  env: Env,
  feedURL: string,
  options: { feedId?: string; country?: string | null; source?: string } = {},
): Promise<{ feedId: string; title: string; episodes: number }> {
  const parsed = await fetchFeed(feedURL, 60)
  if (!parsed.title) throw new Error(`${feedURL} 에서 제목을 읽지 못했다`)

  const feedId = options.feedId ?? `rss:${shortHash(feedURL)}`
  const info: FeedInfo = {
    feedId,
    source: 'itunes',
    title: parsed.title,
    author: parsed.author,
    feedUrl: feedURL,
    artwork: parsed.artwork,
    language: parsed.language,
    country: options.country ?? null,
    categories: parsed.categories,
    description: parsed.description,
    episodeCount: parsed.episodes.length,
  }
  // source 는 FeedInfo 의 두 값 밖에도 쓸 수 있게 여기서 덮어쓴다.
  await upsertFeeds(env, [{ ...info, source: (options.source ?? 'manual') as FeedInfo['source'] }])
  const row = await feedRow(env, feedId)
  const episodes = row ? await refreshEpisodes(env, row) : 0
  return { feedId, title: parsed.title, episodes }
}

export async function feedRow(env: Env, feedId: string): Promise<FeedRow | null> {
  return await env.DB.prepare('SELECT * FROM podcasts WHERE feed_id = ?').bind(feedId).first<FeedRow>()
}

async function rowsByIds(env: Env, ids: string[]): Promise<FeedRow[]> {
  if (!ids.length) return []
  const holes = ids.map(() => '?').join(',')
  const { results } = await env.DB.prepare(
    `SELECT * FROM podcasts WHERE feed_id IN (${holes})`,
  ).bind(...ids).all<FeedRow>()
  // 넘겨받은 순서를 지킨다. 검색·인기 목록의 순위가 순서 자체이기 때문이다.
  const map = new Map(results.map((row) => [row.feed_id, row]))
  return ids.map((id) => map.get(id)).filter((row): row is FeedRow => Boolean(row))
}

/** 검색. Podcast Index 키가 있으면 그쪽, 없으면 iTunes. 결과는 D1 에 캐시한다. */
export async function searchFeeds(
  env: Env,
  term: string,
  country: string,
  limit: number,
): Promise<{ rows: FeedRow[]; source: string; cached: boolean }> {
  const key = `${term.toLowerCase()}|${country}|${limit}`
  const cached = await env.DB.prepare(
    'SELECT payload, fetched_at FROM podcast_search_cache WHERE key = ?',
  ).bind(key).first<{ payload: string; fetched_at: string }>()

  if (cached && isFresh(cached.fetched_at, SEARCH_TTL)) {
    const ids = JSON.parse(cached.payload) as string[]
    return { rows: await rowsByIds(env, ids), source: 'cache', cached: true }
  }

  let feeds: FeedInfo[] = []
  let source = 'local'
  if (hasKeys(env)) {
    try {
      feeds = await piSearch(env, term, limit)
      source = 'podcast_index'
    } catch (error) {
      console.error('Podcast Index 검색 실패', error)
    }
  }

  // 키가 없는 동안은 이미 받아 둔 팟캐스트 안에서 찾는다.
  if (!feeds.length) {
    const like = `%${term}%`
    const local = await env.DB.prepare(
      'SELECT * FROM podcasts WHERE title LIKE ? OR author LIKE ? ' +
      'ORDER BY episode_count DESC LIMIT ?',
    ).bind(like, like, limit).all<FeedRow>()
    if (local.results.length) {
      const ids = local.results.map((row) => row.feed_id)
      await env.DB.prepare(
        'INSERT INTO podcast_search_cache (key, payload, fetched_at) VALUES (?, ?, ?) ' +
        'ON CONFLICT(key) DO UPDATE SET payload = excluded.payload, fetched_at = excluded.fetched_at',
      ).bind(key, JSON.stringify(ids), nowISO()).run()
      return { rows: local.results, source: 'local', cached: false }
    }
  }

  // 마지막으로 iTunes 를 찔러 본다. Worker 에서는 대개 429 라서 실패해도 넘어간다.
  if (!feeds.length) {
    try {
      feeds = await itunesSearch(term, country, limit)
      source = 'itunes'
    } catch (error) {
      console.error('iTunes 검색 실패', error)
    }
  }

  await upsertFeeds(env, feeds)
  const ids = feeds.map((f) => f.feedId)
  await env.DB.prepare(
    'INSERT INTO podcast_search_cache (key, payload, fetched_at) VALUES (?, ?, ?) ' +
    'ON CONFLICT(key) DO UPDATE SET payload = excluded.payload, fetched_at = excluded.fetched_at',
  ).bind(key, JSON.stringify(ids), nowISO()).run()

  // 캐시가 오래됐어도 새 결과가 비면 그 전 결과를 준다. 빈 목록보다 낫다.
  if (!ids.length && cached) {
    return { rows: await rowsByIds(env, JSON.parse(cached.payload) as string[]), source: 'stale', cached: true }
  }
  return { rows: await rowsByIds(env, ids), source, cached: false }
}

/** 나라별 인기 목록. 애플이 공개하는 순위를 쓰고 feed_url 은 lookup 으로 채운다. */
export async function chartFeeds(
  env: Env,
  country: string,
  limit: number,
): Promise<{ rows: FeedRow[]; source: string }> {
  const newest = await env.DB.prepare(
    'SELECT fetched_at FROM podcast_charts WHERE country = ? ORDER BY fetched_at DESC LIMIT 1',
  ).bind(country).first<{ fetched_at: string }>()

  if (!newest || !isFresh(newest.fetched_at, CHART_TTL)) {
    try {
      await refreshChart(env, country, Math.max(limit, 30))
    } catch (error) {
      console.error('인기 목록 갱신 실패', country, error)
    }
  }

  const { results } = await env.DB.prepare(`
    SELECT p.* FROM podcast_charts c JOIN podcasts p ON p.feed_id = c.feed_id
    WHERE c.country = ? ORDER BY c.rank LIMIT ?
  `).bind(country, limit).all<FeedRow>()
  return { rows: results, source: newest ? 'chart' : 'chart-fresh' }
}

export async function refreshChart(env: Env, country: string, limit: number): Promise<number> {
  let feeds: FeedInfo[] = []

  if (hasKeys(env)) {
    try {
      feeds = await piTrending(env, country === 'KR' ? 'ko' : 'en', limit)
    } catch (error) {
      console.error('Podcast Index 인기 목록 실패', error)
    }
  }

  // 순위는 애플이 주지만 feed_url 은 안 준다. 이미 등록해 둔 것을 먼저 쓰고,
  // 모르는 id 만 iTunes lookup 을 시도한다(Worker 에서는 대개 막힌다).
  let ranked: string[] = feeds.map((f) => f.feedId)
  if (!feeds.length) {
    const ids = (await appleTopPodcasts(country, limit)).map((id) => `it:${id}`)
    ranked = ids
    const holes = ids.map(() => '?').join(',')
    const known = ids.length
      ? (await env.DB.prepare(`SELECT feed_id FROM podcasts WHERE feed_id IN (${holes})`)
          .bind(...ids).all<{ feed_id: string }>()).results.map((r) => r.feed_id)
      : []
    const unknown = ids.filter((id) => !known.includes(id)).map((id) => id.slice(3))
    for (let i = 0; i < unknown.length; i += 20) {
      try {
        feeds.push(...await itunesLookup(unknown.slice(i, i + 20), country))
      } catch (error) {
        console.error('iTunes lookup 실패', error)
        break
      }
    }
  }

  if (feeds.length) await upsertFeeds(env, feeds)
  if (!ranked.length) return 0

  const at = nowISO()
  const stmt = env.DB.prepare(
    'INSERT INTO podcast_charts (country, rank, feed_id, fetched_at) VALUES (?, ?, ?, ?) ' +
    'ON CONFLICT(country, rank) DO UPDATE SET feed_id = excluded.feed_id, fetched_at = excluded.fetched_at',
  )
  await env.DB.batch(ranked.map((feedId, index) => stmt.bind(country, index + 1, feedId, at)))
  await env.DB.prepare('DELETE FROM podcast_charts WHERE country = ? AND rank > ?')
    .bind(country, ranked.length).run()
  return ranked.length
}

/** 에피소드 목록. 오래됐으면 RSS 를 다시 읽는다. 읽기가 실패하면 있던 것을 그대로 준다. */
export async function episodesFor(
  env: Env,
  feed: FeedRow,
  limit: number,
  force = false,
): Promise<{ rows: EpisodeRow[]; refreshed: boolean }> {
  const newest = await env.DB.prepare(
    'SELECT fetched_at FROM episodes WHERE feed_id = ? ORDER BY fetched_at DESC LIMIT 1',
  ).bind(feed.feed_id).first<{ fetched_at: string }>()

  let refreshed = false
  if (force || !newest || !isFresh(newest.fetched_at, EPISODE_TTL)) {
    try {
      refreshed = await refreshEpisodes(env, feed) > 0
    } catch (error) {
      console.error('에피소드 갱신 실패', feed.feed_id, error)
    }
  }

  const { results } = await env.DB.prepare(`
    SELECT id, feed_id, title, audio_url, duration_seconds, published_at, description, artwork
    FROM episodes WHERE feed_id = ?
    ORDER BY COALESCE(published_at, '') DESC LIMIT ?
  `).bind(feed.feed_id, limit).all<EpisodeRow>()
  return { rows: results, refreshed }
}

export async function refreshEpisodes(env: Env, feed: FeedRow): Promise<number> {
  const parsed = await fetchFeed(feed.feed_url, 60)
  if (!parsed.episodes.length) return 0

  const at = nowISO()
  const stmt = env.DB.prepare(`
    INSERT INTO episodes (id, feed_id, title, audio_url, duration_seconds, published_at,
                          description, artwork, fetched_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(id) DO UPDATE SET
      title = excluded.title,
      audio_url = excluded.audio_url,
      duration_seconds = COALESCE(excluded.duration_seconds, episodes.duration_seconds),
      published_at = COALESCE(excluded.published_at, episodes.published_at),
      description = COALESCE(excluded.description, episodes.description),
      artwork = COALESCE(excluded.artwork, episodes.artwork),
      fetched_at = excluded.fetched_at
  `)
  await env.DB.batch(parsed.episodes.map((episode) => stmt.bind(
    episodeId(feed.feed_id, episode.guid), feed.feed_id, episode.title, episode.audioURL,
    episode.durationSeconds, episode.publishedAt, episode.description,
    episode.artwork ?? feed.artwork, at,
  )))

  // 피드가 채워 주는 값으로 팟캐스트 쪽 빈칸도 메운다.
  await env.DB.prepare(`
    UPDATE podcasts SET
      language = COALESCE(?, language),
      description = COALESCE(description, ?),
      artwork = COALESCE(artwork, ?),
      author = COALESCE(author, ?),
      fetched_at = ?
    WHERE feed_id = ?
  `).bind(parsed.language, parsed.description, parsed.artwork, parsed.author, at, feed.feed_id).run()

  return parsed.episodes.length
}

/**
 * 타이머 길이에 맞는 에피소드. `docs/07-roadmap.md` M5 의 완료 기준이 이것이다.
 * 45분으로 두면 35~55분 에피소드를 준다.
 */
export async function episodesForTimer(
  env: Env,
  minutes: number,
  country: string | null,
  limit: number,
  secureOnly = false,
): Promise<Array<EpisodeRow & { podcast_title: string; podcast_artwork: string | null }>> {
  const target = minutes * 60
  const low = Math.max(60, target - 10 * 60)
  const high = target + 10 * 60
  const binds: unknown[] = [low, high]
  const secureTerm = secureOnly ? " AND e.audio_url LIKE 'https://%'" : ''
  let countryTerm = ''
  if (country) {
    // 나라가 맞는 것을 먼저 보여주되, 모자라면 다른 나라 것도 남긴다.
    countryTerm = 'CASE WHEN p.country = ? THEN 0 ELSE 1 END,'
    binds.push(country)
  }

  const { results } = await env.DB.prepare(`
    SELECT e.id, e.feed_id, e.title, e.audio_url, e.duration_seconds, e.published_at,
           e.description, e.artwork, p.title AS podcast_title, p.artwork AS podcast_artwork
    FROM episodes e JOIN podcasts p ON p.feed_id = e.feed_id
    WHERE e.duration_seconds BETWEEN ? AND ?${secureTerm}
    ORDER BY ${countryTerm} ABS(e.duration_seconds - ${target}), COALESCE(e.published_at, '') DESC
    LIMIT ?
  `).bind(...binds, limit).all<EpisodeRow & { podcast_title: string; podcast_artwork: string | null }>()
  return results
}

/** 배치. 인기 목록을 갱신하고 그 피드들의 에피소드를 받아 둔다. */
export async function syncPodcasts(
  env: Env,
  country: string,
  feedLimit: number,
): Promise<{ country: string; feeds: number; episodes: number }> {
  const feeds = await refreshChart(env, country, feedLimit)
  const { results } = await env.DB.prepare(`
    SELECT p.* FROM podcast_charts c JOIN podcasts p ON p.feed_id = c.feed_id
    WHERE c.country = ? ORDER BY c.rank LIMIT ?
  `).bind(country, feedLimit).all<FeedRow>()

  let episodes = 0
  for (const feed of results) {
    try {
      episodes += await refreshEpisodes(env, feed)
    } catch (error) {
      console.error('에피소드 동기화 실패', feed.feed_id, error)
    }
  }
  return { country, feeds, episodes }
}
