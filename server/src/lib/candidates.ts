import type { Env } from '../types'
import { boostTags, type Daypart, type SituationRule } from './situations'

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
  hits: number
  boosts: number
  moodHits: number
  moodMiss: number
  tags: string[]
  moods: string[]
  scope: 'country' | 'global'
}

export const TAG_LABEL: Record<string, string> = {
  ambient: '앰비언트', chillout: '칠아웃', lounge: '라운지', newage: '뉴에이지',
  classical: '클래식', jazz: '재즈', instrumental: '연주곡', soundtrack: '사운드트랙',
  blues: '블루스', soul: '소울', news: '뉴스', talk: '토크', pop: '팝', rock: '록',
  top40: '최신 인기곡', dance: '댄스', kpop: '케이팝', jpop: '제이팝', cpop: '중국 음악',
  hiphop: '힙합', culture: '교양', oldies: '옛 노래', electronic: '일렉트로닉',
  house: '하우스', techno: '테크노', funk: '펑크', indie: '인디', latin: '라틴',
  world: '월드뮤직', country: '컨트리', metal: '메탈', reggae: '레게', folk: '포크',
  rnb: '알앤비', ballad: '발라드', gospel: '가스펠', christian: '기독교', religion: '종교',
  comedy: '코미디', anime: '애니메이션', sports: '스포츠', punk: '펑크록',
  traditional: '전통음악', education: '교육', live: '라이브', trot: '트로트',
}

export function tagLabel(tag: string): string {
  return TAG_LABEL[tag] ?? tag
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

  const where: string[] = ['s.is_hidden = 0', 'COALESCE(h.excluded, 0) = 0']
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
           s.favicon, s.stream_url,
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

  const [tagRows, moodRows] = await env.DB.batch<{ station_id: string; value: string }>([
    env.DB.prepare(`SELECT station_id, tag AS value FROM station_tags WHERE station_id IN (${holes(ids)}) ORDER BY tag`).bind(...ids),
    env.DB.prepare(`SELECT station_id, mood AS value FROM station_moods WHERE station_id IN (${holes(ids)}) ORDER BY confidence DESC`).bind(...ids),
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
      const nameKey = row.name.toLowerCase().replace(/[^a-z0-9가-힣]+/g, '')
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
export function ruleReason(candidate: Candidate, rule: SituationRule): string {
  const matched = candidate.tags.filter((tag) => rule.prefer.includes(tag)).slice(0, 2).map(tagLabel)
  const head = matched.length
    ? matched.join('·') + ' 채널이다.'
    : rule.label + '에서 뺄 이유가 없는 채널이다.'
  const tail = candidate.scope === 'global'
    ? ' ' + rule.note + '. 국내 후보가 적어 다른 나라까지 넓혔다.'
    : ' ' + rule.note + '.'
  return head + tail
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
    artworkURL: candidate.favicon && candidate.favicon.startsWith('http') ? candidate.favicon : null,
    tags: candidate.tags,
    moods: candidate.moods,
    isSecure: candidate.stream_url.startsWith('https://'),
  }
}
