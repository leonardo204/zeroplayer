import type { Env } from '../types'
import { clampLimit, decodeCursor, fail, json } from '../lib/http'
import {
  chartFeeds,
  episodesFor,
  feedRow,
  searchFeeds,
  type EpisodeRow,
  type FeedRow,
} from '../lib/podcasts'

function toPodcast(row: FeedRow) {
  return {
    feedID: row.feed_id,
    title: row.title,
    author: row.author,
    artworkURL: row.artwork,
    language: row.language,
    country: row.country,
    categories: row.categories ? (JSON.parse(row.categories) as string[]) : [],
    description: row.description,
    episodeCount: row.episode_count ?? 0,
  }
}

/** audio_url 은 넣지 않는다. 방송국과 같게 재생 직전에만 준다. */
function toEpisode(row: EpisodeRow, podcastTitle: string, fallbackArtwork: string | null) {
  return {
    id: row.id,
    feedID: row.feed_id,
    title: row.title,
    podcastTitle,
    durationSeconds: row.duration_seconds ?? 0,
    publishedAt: row.published_at,
    description: row.description,
    artworkURL: row.artwork ?? fallbackArtwork,
    isSecure: row.audio_url.startsWith('https://'),
  }
}

export async function searchPodcasts(env: Env, url: URL): Promise<Response> {
  const term = url.searchParams.get('q')?.trim() ?? ''
  if (term.length < 2) return fail(400, 'bad_query', '검색어를 두 글자 이상 넣는다.')
  const country = url.searchParams.get('country')?.toUpperCase().trim() || 'KR'
  const limit = clampLimit(url.searchParams.get('limit'), 30, 50)

  const { rows, source } = await searchFeeds(env, term, country, limit)
  return json({ source, items: rows.map(toPodcast) }, {
    headers: { 'cache-control': 'public, max-age=600' },
  })
}

export async function trendingPodcasts(env: Env, url: URL): Promise<Response> {
  const country = url.searchParams.get('country')?.toUpperCase().trim() || 'KR'
  const limit = clampLimit(url.searchParams.get('limit'), 30, 50)
  const { rows, source } = await chartFeeds(env, country, limit)
  return json({ source, country, items: rows.map(toPodcast) }, {
    headers: { 'cache-control': 'public, max-age=1800' },
  })
}

export async function getPodcast(env: Env, feedID: string): Promise<Response> {
  const row = await feedRow(env, feedID)
  if (!row) return fail(404, 'not_found', '그런 팟캐스트가 없다.')
  return json(toPodcast(row), { headers: { 'cache-control': 'public, max-age=1800' } })
}

export async function listEpisodes(env: Env, feedID: string, url: URL): Promise<Response> {
  const row = await feedRow(env, feedID)
  if (!row) return fail(404, 'not_found', '그런 팟캐스트가 없다.')

  const limit = clampLimit(url.searchParams.get('limit'), 50, 100)
  const offset = decodeCursor(url.searchParams.get('cursor'))
  const { rows } = await episodesFor(env, row, offset + limit + 1)
  const secureOnly = url.searchParams.get('secure') === '1'
  const filtered = secureOnly ? rows.filter((r) => r.audio_url.startsWith('https://')) : rows

  const page = filtered.slice(offset, offset + limit)
  const hasMore = filtered.length > offset + limit
  return json({
    podcast: toPodcast(row),
    items: page.map((episode) => toEpisode(episode, row.title, row.artwork)),
    nextCursor: hasMore ? String(offset + limit) : null,
  }, { headers: { 'cache-control': 'public, max-age=600' } })
}

async function episodeRow(env: Env, id: string) {
  return await env.DB.prepare(`
    SELECT e.id, e.feed_id, e.title, e.audio_url, e.duration_seconds, e.published_at,
           e.description, e.artwork, p.title AS podcast_title, p.artwork AS podcast_artwork
    FROM episodes e JOIN podcasts p ON p.feed_id = e.feed_id
    WHERE e.id = ?
  `).bind(id).first<EpisodeRow & { podcast_title: string; podcast_artwork: string | null }>()
}

export async function getEpisode(env: Env, id: string): Promise<Response> {
  const row = await episodeRow(env, id)
  if (!row) return fail(404, 'not_found', '그런 에피소드가 없다.')
  return json(toEpisode(row, row.podcast_title, row.podcast_artwork), {
    headers: { 'cache-control': 'public, max-age=600' },
  })
}

/** 재생 직전에만 부르는 자리. 앱은 이 응답을 저장하지 않는다. */
export async function getEpisodeStream(env: Env, id: string): Promise<Response> {
  const row = await episodeRow(env, id)
  if (!row) return fail(404, 'not_found', '그런 에피소드가 없다.')
  return json({
    url: row.audio_url,
    codec: null,
    bitrate: 0,
    durationSeconds: row.duration_seconds ?? 0,
    recheckAfter: 3600,
    degraded: false,
  })
}
