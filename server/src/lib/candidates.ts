import type { Env } from '../types'
import { boostTags, SITUATIONS, type Daypart, type Situation, type SituationRule } from './situations'
import { ruleReasonText, type Lang } from './i18n'
import { artworkFor } from './logos'

/** 후보 한 건. 스트림 주소는 생사 판단과 HTTPS 여부에만 쓰고 앱에는 내보내지 않는다. */
export interface Candidate {
  id: string
  name: string
  country_code: string | null
  language: string | null
  codec: string | null
  bitrate: number | null
  votes: number | null
  clicks: number | null
  favicon: string | null
  stream_url: string
  dedupe_key: string | null
  hits: number
  boosts: number
  moodHits: number
  moodMiss: number
  tags: string[]
  moods: string[]
  scope: 'country' | 'global'
}


function holes(values: string[]): string {
  return values.map(() => '?').join(',')
}

interface QueryOptions {
  prefer: string[]
  boosts: string[]
  exclude: string[]
  preferMoods: string[]
  avoidMoods: string[]
  country: string | null
  limit: number
  secureOnly: boolean
  requirePrefer: boolean
  preferHighBitrate: boolean
}

type Row = Omit<Candidate, 'tags' | 'moods' | 'scope'>

async function query(env: Env, options: QueryOptions): Promise<Row[]> {
  const {
    prefer, boosts, exclude, preferMoods, avoidMoods,
    country, limit, secureOnly, requirePrefer, preferHighBitrate,
  } = options

  // 빈 목록을 IN 절에 넣을 수 없어 맞을 리 없는 값 하나를 채워 둔다.
  const boostList = boosts.length ? boosts : [' ']
  const goodMoods = preferMoods.length ? preferMoods : [' ']
  const badMoods = avoidMoods.length ? avoidMoods : [' ']

  // 만료되는 서명이 붙은 주소는 추천에 올리지 않고, 같은 방송은 대표 한 줄만 본다
  // (`stations.ts` 와 같은 조건이라 목록과 추천에 같은 줄이 나온다).
  const where: string[] = [
    's.is_hidden = 0', 'COALESCE(h.excluded, 0) = 0',
    's.stream_signed = 0', 's.is_primary = 1',
  ]
  const binds: unknown[] = [...prefer, ...boostList, ...goodMoods, ...badMoods]

  if (country) { where.push('s.country_code = ?'); binds.push(country) }
  if (secureOnly) where.push("s.stream_url LIKE 'https://%'")
  if (exclude.length) {
    where.push(`NOT EXISTS (SELECT 1 FROM station_tags x WHERE x.station_id = s.id AND x.tag IN (${holes(exclude)}))`)
    binds.push(...exclude)
  }
  if (requirePrefer) {
    where.push(`EXISTS (SELECT 1 FROM station_tags p WHERE p.station_id = s.id AND p.tag IN (${holes(prefer)}))`)
    binds.push(...prefer)
  }

  const bitrateTerm = preferHighBitrate ? ' + (CASE WHEN s.bitrate >= 96 THEN 1 ELSE 0 END)' : ''

  const { results } = await env.DB.prepare(`
    SELECT s.id, s.name, s.country_code, s.language, s.codec, s.bitrate, s.votes, s.clicks,
           s.favicon, s.stream_url, s.dedupe_key,
           (SELECT COUNT(*) FROM station_tags t WHERE t.station_id = s.id AND t.tag IN (${holes(prefer)})) AS hits,
           (SELECT COUNT(*) FROM station_tags b WHERE b.station_id = s.id AND b.tag IN (${holes(boostList)})) AS boosts,
           (SELECT COUNT(*) FROM station_moods m WHERE m.station_id = s.id AND m.mood IN (${holes(goodMoods)})) AS moodHits,
           (SELECT COUNT(*) FROM station_moods m WHERE m.station_id = s.id AND m.mood IN (${holes(badMoods)})) AS moodMiss
    FROM stations s
    LEFT JOIN station_health h ON h.station_id = s.id
    WHERE ${where.join(' AND ')}
    ORDER BY (hits * 2 + boosts + moodHits * 2 - moodMiss * 3${bitrateTerm}) DESC,
             s.clicks DESC, s.votes DESC, s.name COLLATE NOCASE ASC
    LIMIT ?
  `).bind(...binds, limit).all<Row>()

  return results
}

async function labelsFor(env: Env, ids: string[]): Promise<{
  tags: Map<string, string[]>
  moods: Map<string, string[]>
}> {
  const tags = new Map<string, string[]>()
  const moods = new Map<string, string[]>()
  if (!ids.length) return { tags, moods }

  // D1 은 한 문장에 값 100개까지라 90개씩 잘라 묻는다.
  for (let i = 0; i < ids.length; i += 90) {
    const slice = ids.slice(i, i + 90)
    const [tagRows, moodRows] = await env.DB.batch<{ station_id: string; value: string }>([
      env.DB.prepare(`SELECT station_id, tag AS value FROM station_tags WHERE station_id IN (${holes(slice)}) ORDER BY tag`).bind(...slice),
      env.DB.prepare(`SELECT station_id, mood AS value FROM station_moods WHERE station_id IN (${holes(slice)}) ORDER BY confidence DESC`).bind(...slice),
    ])

    for (const row of tagRows.results) {
      const list = tags.get(row.station_id) ?? []
      list.push(row.value)
      tags.set(row.station_id, list)
    }
    for (const row of moodRows.results) {
      const list = moods.get(row.station_id) ?? []
      list.push(row.value)
      moods.set(row.station_id, list)
    }
  }
  return { tags, moods }
}

/**
 * 1단 규칙으로 후보를 모은다.
 *
 * 후보가 모자라면 세 번에 걸쳐 조건을 푼다. 빈 목록을 주는 것보다 넓히는 쪽이 낫다.
 * radio-browser 에는 같은 방송을 올린 줄이 여럿 있어('KBS Classic FM' 이 세 줄)
 * 이름이 같으면 한 번만 담는다.
 */
export async function collectCandidates(
  env: Env,
  options: {
    rule: SituationRule
    daypart: Daypart
    country: string | null
    limit: number
    secureOnly: boolean
  },
): Promise<Candidate[]> {
  const { rule, daypart, country, limit, secureOnly } = options
  const boosts = boostTags(daypart, rule)
  const picked = new Map<string, Candidate>()
  const seenNames = new Set<string>()

  const passes: Array<{ country: string | null; requirePrefer: boolean; scope: 'country' | 'global' }> = [
    { country, requirePrefer: true, scope: 'country' },
    { country: null, requirePrefer: true, scope: 'global' },
    { country, requirePrefer: false, scope: 'country' },
  ]

  for (const pass of passes) {
    if (picked.size >= limit) break
    // 나라를 안 받았으면 1번 통과가 이미 전 세계다. 같은 질의를 두 번 하지 않는다.
    if (pass.scope === 'global' && country === null) continue

    const rows = await query(env, {
      prefer: rule.prefer,
      boosts,
      exclude: rule.exclude,
      preferMoods: rule.preferMoods,
      avoidMoods: rule.avoidMoods,
      country: pass.country,
      limit: limit * 2,
      secureOnly,
      requirePrefer: pass.requirePrefer,
      preferHighBitrate: rule.preferHighBitrate ?? false,
    })

    for (const row of rows) {
      if (picked.size >= limit) break
      if (picked.has(row.id)) continue
      // 같은 방송의 코덱 변종은 한 번만 넣는다. 열쇠는 동기화할 때 계산해 둔 것을 쓴다.
      const nameKey = row.dedupe_key ?? row.id
      if (seenNames.has(nameKey)) continue
      seenNames.add(nameKey)
      const scope = country && row.country_code === country ? 'country' : pass.scope
      picked.set(row.id, { ...row, tags: [], moods: [], scope })
    }
  }

  const list = [...picked.values()]
  const { tags, moods } = await labelsFor(env, list.map((row) => row.id))
  for (const candidate of list) {
    candidate.tags = tags.get(candidate.id) ?? []
    candidate.moods = moods.get(candidate.id) ?? []
  }
  return list
}

/** 규칙 단계의 reason. 무엇으로 걸렀는지 그대로 적는다. LLM 이 실패해도 이 문구가 남는다. */
export function ruleReason(candidate: Candidate, situation: Situation, lang: Lang): string {
  const matched = candidate.tags.filter((tag) => SITUATIONS[situation].prefer.includes(tag)).slice(0, 2)
  return ruleReasonText(lang, situation, matched, candidate.scope === 'global')
}

/** 앱이 받는 한 건. 세트에 저장하는 모양과 즉석 응답이 같다. */
export interface RecommendItem {
  kind: 'station'
  id: string
  title: string
  subtitle: string | null
  reason: string
  artworkURL: string | null
  tags: string[]
  moods: string[]
  isSecure: boolean
}

export function toItem(candidate: Candidate, reason: string): RecommendItem {
  return {
    kind: 'station',
    id: candidate.id,
    title: candidate.name,
    subtitle: [candidate.country_code, candidate.bitrate ? candidate.bitrate + 'k' : null]
      .filter(Boolean).join(' · ') || null,
    reason,
    artworkURL: artworkFor(candidate.favicon, candidate.name, candidate.country_code),
    tags: candidate.tags,
    moods: candidate.moods,
    isSecure: candidate.stream_url.startsWith('https://'),
  }
}
