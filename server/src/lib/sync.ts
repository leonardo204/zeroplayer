import type { Env } from '../types'
import { nowISO } from './http'
import { stationsByCountry, type RBStation } from './radioBrowser'
import { loadAliases, recordUnknownTags, resolveTags, splitRawTags } from './tags'
import { dedupeKey, isExpiringSignedURL } from './stationKeys'

/** url_resolved 를 기본으로 쓰되, 원본 쪽만 HTTPS 면 그쪽을 고른다. */
function pickStreamURL(s: RBStation): string | null {
  const resolved = (s.url_resolved || '').trim()
  const plain = (s.url || '').trim()
  const candidates = [resolved, plain].filter(Boolean)
  if (!candidates.length) return null
  const secure = candidates.find((u) => u.startsWith('https://'))
  return secure ?? candidates[0]
}

export interface SyncResult {
  country: string
  received: number
  written: number
  removed: number
}

export async function syncCountry(
  env: Env,
  countryCode: string,
  limit: number,
  pruneMissing: boolean,
): Promise<SyncResult> {
  const stations = await stationsByCountry(countryCode, limit)
  const aliases = await loadAliases(env)
  const at = nowISO()

  const upsert = env.DB.prepare(`
    INSERT INTO stations (
      id, source, name, stream_url, homepage, favicon, country_code, language,
      codec, bitrate, votes, clicks, is_hidden, raw_tags, stream_signed, dedupe_key, updated_at
    ) VALUES (?, 'radio_browser', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?, ?)
    ON CONFLICT(id) DO UPDATE SET
      name = excluded.name,
      stream_url = excluded.stream_url,
      homepage = excluded.homepage,
      favicon = excluded.favicon,
      country_code = excluded.country_code,
      language = excluded.language,
      codec = excluded.codec,
      bitrate = excluded.bitrate,
      votes = excluded.votes,
      clicks = excluded.clicks,
      raw_tags = excluded.raw_tags,
      stream_signed = excluded.stream_signed,
      dedupe_key = excluded.dedupe_key,
      updated_at = excluded.updated_at
  `)
  const ensureHealth = env.DB.prepare(
    'INSERT OR IGNORE INTO station_health (station_id, fail_streak, report_count, excluded) VALUES (?, 0, 0, 0)',
  )
  const clearTags = env.DB.prepare('DELETE FROM station_tags WHERE station_id = ?')
  const addTag = env.DB.prepare('INSERT OR IGNORE INTO station_tags (station_id, tag) VALUES (?, ?)')

  const seen: string[] = []
  const unknownTags = new Set<string>()
  let statements: D1PreparedStatement[] = []
  let written = 0

  const flush = async () => {
    if (!statements.length) return
    await env.DB.batch(statements)
    statements = []
  }

  for (const s of stations) {
    const url = pickStreamURL(s)
    if (!url || !s.stationuuid || !s.name?.trim()) continue

    const id = `rb:${s.stationuuid}`
    seen.push(id)
    const country = (s.countrycode || countryCode).toUpperCase()
    const rawTags = splitRawTags(s.tags)
    rawTags.forEach((t) => unknownTags.add(t))

    statements.push(
      upsert.bind(
        id,
        s.name.trim(),
        url,
        s.homepage || null,
        s.favicon || null,
        country,
        (s.languagecodes || s.language || '').split(',')[0]?.trim() || null,
        s.hls === 1 ? 'hls' : (s.codec || '').toLowerCase() || null,
        Number.isFinite(s.bitrate) ? s.bitrate : 0,
        Number.isFinite(s.votes) ? s.votes : 0,
        Number.isFinite(s.clickcount) ? s.clickcount : 0,
        s.tags || null,
        isExpiringSignedURL(url) ? 1 : 0,
        dedupeKey(s.name.trim(), country, id),
        at,
      ),
      ensureHealth.bind(id),
      clearTags.bind(id),
    )
    for (const tag of resolveTags(rawTags, aliases)) {
      statements.push(addTag.bind(id, tag))
    }
    written++
    if (statements.length >= 60) await flush()
  }
  await flush()

  let removed = 0
  if (pruneMissing && seen.length) {
    const { results } = await env.DB.prepare(
      "SELECT id FROM stations WHERE country_code = ? AND source = 'radio_browser'",
    ).bind(countryCode.toUpperCase()).all<{ id: string }>()
    const keep = new Set(seen)
    const gone = results.map((r) => r.id).filter((id) => !keep.has(id))
    if (gone.length) {
      const del = env.DB.prepare('DELETE FROM stations WHERE id = ?')
      for (let i = 0; i < gone.length; i += 60) {
        await env.DB.batch(gone.slice(i, i + 60).map((id) => del.bind(id)))
      }
      removed = gone.length
    }
  }

  await recordUnknownTags(env, [...unknownTags])
  await markSync(env, `radio_browser:${countryCode}`, true, `받음 ${stations.length} · 저장 ${written} · 삭제 ${removed}`)

  return { country: countryCode, received: stations.length, written, removed }
}

export async function syncAll(env: Env): Promise<SyncResult[]> {
  const full = (env.SYNC_FULL_COUNTRIES || '').split(',').map((c) => c.trim()).filter(Boolean)
  const top = (env.SYNC_TOP_COUNTRIES || '').split(',').map((c) => c.trim()).filter(Boolean)
  const perCountry = Number.parseInt(env.SYNC_TOP_PER_COUNTRY || '200', 10) || 200
  const out: SyncResult[] = []

  for (const code of full) {
    try {
      out.push(await syncCountry(env, code, 0, true))
    } catch (error) {
      await markSync(env, `radio_browser:${code}`, false, String(error))
    }
  }
  for (const code of top) {
    try {
      out.push(await syncCountry(env, code, perCountry, false))
    } catch (error) {
      await markSync(env, `radio_browser:${code}`, false, String(error))
    }
  }
  return out
}

/** 원시 태그가 이미 저장돼 있으므로, 정규화 규칙이 바뀌면 여기서 다시 계산한다. */
export async function rebuildTags(env: Env, limit = 3000): Promise<number> {
  const aliases = await loadAliases(env)
  const { results } = await env.DB.prepare(
    "SELECT id, raw_tags FROM stations WHERE raw_tags IS NOT NULL AND raw_tags != '' LIMIT ?",
  ).bind(limit).all<{ id: string; raw_tags: string }>()

  const clearTags = env.DB.prepare('DELETE FROM station_tags WHERE station_id = ?')
  const addTag = env.DB.prepare('INSERT OR IGNORE INTO station_tags (station_id, tag) VALUES (?, ?)')
  let statements: D1PreparedStatement[] = []
  let touched = 0

  for (const row of results) {
    statements.push(clearTags.bind(row.id))
    for (const tag of resolveTags(splitRawTags(row.raw_tags), aliases)) {
      statements.push(addTag.bind(row.id, tag))
    }
    touched++
    if (statements.length >= 60) {
      await env.DB.batch(statements)
      statements = []
    }
  }
  if (statements.length) await env.DB.batch(statements)
  return touched
}

export async function markSync(env: Env, job: string, ok: boolean, detail: string): Promise<void> {
  const at = nowISO()
  await env.DB.prepare(`
    INSERT INTO sync_state (job, last_run_at, last_ok_at, ok, detail)
    VALUES (?, ?, ?, ?, ?)
    ON CONFLICT(job) DO UPDATE SET
      last_run_at = excluded.last_run_at,
      last_ok_at = CASE WHEN excluded.ok = 1 THEN excluded.last_run_at ELSE sync_state.last_ok_at END,
      ok = excluded.ok,
      detail = excluded.detail
  `).bind(job, at, ok ? at : null, ok ? 1 : 0, detail.slice(0, 400)).run()
}
