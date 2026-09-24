import type { Env } from '../types'
import { clampLimit, decodeCursor, fail, json, nowISO } from '../lib/http'

/** 앱이 받는 방송국 한 건. 스트림 주소는 여기에 넣지 않는다. */
interface StationDTO {
  id: string
  name: string
  countryCode: string | null
  language: string | null
  codec: string | null
  bitrate: number
  votes: number
  clicks: number
  artworkURL: string | null
  homepage: string | null
  tags: string[]
  isSecure: boolean
  updatedAt: string
}

interface Row {
  id: string
  name: string
  country_code: string | null
  language: string | null
  codec: string | null
  bitrate: number | null
  votes: number | null
  clicks: number | null
  favicon: string | null
  homepage: string | null
  stream_url: string
  updated_at: string
}

function toDTO(row: Row, tags: string[]): StationDTO {
  return {
    id: row.id,
    name: row.name,
    countryCode: row.country_code,
    language: row.language,
    codec: row.codec,
    bitrate: row.bitrate ?? 0,
    votes: row.votes ?? 0,
    clicks: row.clicks ?? 0,
    artworkURL: row.favicon && row.favicon.startsWith('http') ? row.favicon : null,
    homepage: row.homepage,
    tags,
    isSecure: row.stream_url.startsWith('https://'),
    updatedAt: row.updated_at,
  }
}

async function tagsFor(env: Env, ids: string[]): Promise<Map<string, string[]>> {
  const map = new Map<string, string[]>()
  if (!ids.length) return map
  const holes = ids.map(() => '?').join(',')
  const { results } = await env.DB.prepare(
    `SELECT station_id, tag FROM station_tags WHERE station_id IN (${holes}) ORDER BY tag`,
  ).bind(...ids).all<{ station_id: string; tag: string }>()
  for (const r of results) {
    const list = map.get(r.station_id) ?? []
    list.push(r.tag)
    map.set(r.station_id, list)
  }
  return map
}

export async function listStations(env: Env, url: URL): Promise<Response> {
  const limit = clampLimit(url.searchParams.get('limit'), 50, 200)
  const offset = decodeCursor(url.searchParams.get('cursor'))
  const country = url.searchParams.get('country')?.toUpperCase().trim()
  const tag = url.searchParams.get('tag')?.toLowerCase().trim()
  const lang = url.searchParams.get('lang')?.toLowerCase().trim()
  const q = url.searchParams.get('q')?.trim()
  const sort = url.searchParams.get('sort') ?? 'popular'

  // 만료되는 서명이 붙은 주소는 목록에 올리지 않는다. 등록된 날에는 살아 있어
  // 생사 점검으로는 안 걸러지고, 하루만 지나면 앱에서 403 이 난다.
  // 만료되는 서명이 붙은 주소는 목록에 올리지 않는다. 등록된 날에는 살아 있어
  // 생사 점검으로는 안 걸러지고, 하루만 지나면 앱에서 403 이 난다.
  // is_primary 는 같은 방송의 코덱 변종 가운데 대표 한 줄만 남기는 값이다.
  const where: string[] = [
    's.is_hidden = 0', 'COALESCE(h.excluded, 0) = 0',
    's.stream_signed = 0', 's.is_primary = 1',
  ]
  const binds: unknown[] = []
  if (country) { where.push('s.country_code = ?'); binds.push(country) }
  if (lang) { where.push('s.language = ?'); binds.push(lang) }
  if (q) { where.push('s.name LIKE ?'); binds.push(`%${q}%`) }
  if (tag) {
    where.push('EXISTS (SELECT 1 FROM station_tags t WHERE t.station_id = s.id AND t.tag = ?)')
    binds.push(tag)
  }
  // 평문 HTTP 스트림을 못 여는 기기를 위해 앱이 골라 부를 수 있게 둔다.
  if (url.searchParams.get('secure') === '1') {
    where.push("s.stream_url LIKE 'https://%'")
  }

  const order = sort === 'name'
    ? 's.name COLLATE NOCASE ASC'
    : sort === 'recent'
      ? 's.updated_at DESC'
      : 's.clicks DESC, s.votes DESC, s.name COLLATE NOCASE ASC'

  const { results } = await env.DB.prepare(`
    SELECT s.id, s.name, s.country_code, s.language, s.codec, s.bitrate,
           s.votes, s.clicks, s.favicon, s.homepage, s.stream_url, s.updated_at
    FROM stations s
    LEFT JOIN station_health h ON h.station_id = s.id
    WHERE ${where.join(' AND ')}
    ORDER BY ${order}
    LIMIT ? OFFSET ?
  `).bind(...binds, limit + 1, offset).all<Row>()

  const hasMore = results.length > limit
  const page = hasMore ? results.slice(0, limit) : results
  const tagMap = await tagsFor(env, page.map((r) => r.id))

  return json({
    items: page.map((r) => toDTO(r, tagMap.get(r.id) ?? [])),
    nextCursor: hasMore ? String(offset + limit) : null,
  }, { headers: { 'cache-control': 'public, max-age=300' } })
}

export async function getStation(env: Env, id: string): Promise<Response> {
  const row = await env.DB.prepare(`
    SELECT s.id, s.name, s.country_code, s.language, s.codec, s.bitrate,
           s.votes, s.clicks, s.favicon, s.homepage, s.stream_url, s.updated_at
    FROM stations s WHERE s.id = ? AND s.is_hidden = 0 AND s.stream_signed = 0
  `).bind(id).first<Row>()
  if (!row) return fail(404, 'not_found', '그런 방송국이 없다.')
  const tagMap = await tagsFor(env, [id])
  return json(toDTO(row, tagMap.get(id) ?? []), { headers: { 'cache-control': 'public, max-age=300' } })
}

/** 재생 직전에만 부르는 자리. 앱은 이 응답을 저장하지 않는다. */
export async function getStream(env: Env, id: string): Promise<Response> {
  const row = await env.DB.prepare(`
    SELECT s.stream_url AS url, s.codec AS codec, s.bitrate AS bitrate,
           COALESCE(h.excluded, 0) AS excluded
    FROM stations s
    LEFT JOIN station_health h ON h.station_id = s.id
    WHERE s.id = ? AND s.is_hidden = 0 AND s.stream_signed = 0
  `).bind(id).first<{ url: string; codec: string | null; bitrate: number | null; excluded: number }>()
  if (!row) return fail(404, 'not_found', '그런 방송국이 없다.')

  return json({
    url: row.url,
    codec: row.codec,
    bitrate: row.bitrate ?? 0,
    recheckAfter: row.excluded ? 600 : 3600,
    degraded: row.excluded === 1,
  })
}

export async function getFacets(env: Env): Promise<Response> {
  const base = 'FROM stations s LEFT JOIN station_health h ON h.station_id = s.id WHERE s.is_hidden = 0 AND COALESCE(h.excluded, 0) = 0 AND s.stream_signed = 0 AND s.is_primary = 1'
  const [countries, languages, tags] = await env.DB.batch<{ value: string; count: number }>([
    env.DB.prepare(`SELECT s.country_code AS value, COUNT(*) AS count ${base} AND s.country_code IS NOT NULL GROUP BY s.country_code ORDER BY count DESC`),
    env.DB.prepare(`SELECT s.language AS value, COUNT(*) AS count ${base} AND s.language IS NOT NULL AND s.language != '' GROUP BY s.language ORDER BY count DESC LIMIT 60`),
    env.DB.prepare(`SELECT t.tag AS value, COUNT(*) AS count FROM station_tags t JOIN stations s ON s.id = t.station_id LEFT JOIN station_health h ON h.station_id = s.id WHERE s.is_hidden = 0 AND COALESCE(h.excluded, 0) = 0 AND s.stream_signed = 0 AND s.is_primary = 1 GROUP BY t.tag ORDER BY count DESC`),
  ])

  return json({
    countries: countries.results,
    languages: languages.results,
    tags: tags.results,
  }, { headers: { 'cache-control': 'public, max-age=1800' } })
}

const REPORT_REASONS = new Set(['no_audio', 'error', 'wrong_content'])

/** 앱이 15초 안에 첫 오디오를 못 받으면 신고한다. 쌓이면 목록에서 뺀다. */
export async function reportStation(env: Env, id: string, request: Request): Promise<Response> {
  let reason = 'error'
  try {
    const body = (await request.json()) as { reason?: string }
    if (body?.reason && REPORT_REASONS.has(body.reason)) reason = body.reason
  } catch {
    // 본문이 없어도 신고는 받는다
  }

  const exists = await env.DB.prepare('SELECT 1 AS x FROM stations WHERE id = ?').bind(id).first()
  if (!exists) return fail(404, 'not_found', '그런 방송국이 없다.')

  const at = nowISO()
  await env.DB.prepare(`
    INSERT INTO station_health (station_id, last_fail_at, fail_streak, report_count, excluded)
    VALUES (?, ?, 1, 1, 0)
    ON CONFLICT(station_id) DO UPDATE SET
      last_fail_at = excluded.last_fail_at,
      report_count = station_health.report_count + 1,
      excluded = CASE WHEN station_health.report_count + 1 >= 5 THEN 1 ELSE station_health.excluded END
  `).bind(id, at).run()

  return json({ ok: true, reason })
}
