import type { Env } from '../types'
import { nowISO } from './http'

/**
 * 분위기. 태그가 '무엇을 트는가'라면 분위기는 '언제 듣기 좋은가'다.
 * 상황 규칙(`situations.ts`)이 이 값으로 후보를 좁힌다.
 */
export const CANONICAL_MOODS = [
  'calm',        // 잔잔하다
  'late-night',  // 밤에 어울린다
  'focus',       // 집중을 방해하지 않는다
  'background',  // 배경으로 깔아 두기 좋다
  'energetic',   // 활기차다
  'morning',     // 아침에 어울린다
  'warm',        // 편안하고 친근하다
  'talky',       // 말이 많다
] as const

export type Mood = (typeof CANONICAL_MOODS)[number]

const MOOD_SET = new Set<string>(CANONICAL_MOODS)

/**
 * 태그만으로 확실한 분위기. LLM 을 부르기 전에 여기서 최대한 채운다.
 * 태그가 하나도 없는 방송국만 모델에게 묻는다.
 */
const MOOD_BY_TAG: Record<string, Mood[]> = {
  ambient: ['calm', 'late-night', 'focus', 'background'],
  chillout: ['calm', 'background', 'late-night'],
  lounge: ['calm', 'background', 'warm'],
  newage: ['calm', 'focus', 'late-night'],
  instrumental: ['focus', 'background', 'calm'],
  classical: ['calm', 'focus'],
  soundtrack: ['focus', 'background'],
  jazz: ['calm', 'warm', 'late-night'],
  blues: ['warm', 'late-night'],
  soul: ['warm', 'background'],
  rnb: ['warm', 'background'],
  folk: ['calm', 'warm'],
  ballad: ['calm', 'warm'],
  oldies: ['warm', 'background'],
  country: ['warm', 'background'],
  gospel: ['warm'],
  christian: ['calm', 'warm'],
  traditional: ['calm', 'warm'],
  world: ['background', 'warm'],
  anime: ['energetic'],
  pop: ['energetic', 'background'],
  top40: ['energetic', 'morning'],
  dance: ['energetic'],
  house: ['energetic', 'background'],
  techno: ['energetic'],
  electronic: ['background', 'energetic'],
  funk: ['energetic', 'warm'],
  hiphop: ['energetic'],
  rock: ['energetic'],
  metal: ['energetic'],
  punk: ['energetic'],
  indie: ['background', 'warm'],
  latin: ['energetic', 'warm'],
  reggae: ['warm', 'background'],
  kpop: ['energetic'],
  jpop: ['energetic'],
  cpop: ['energetic'],
  trot: ['warm'],
  news: ['talky', 'morning'],
  talk: ['talky'],
  culture: ['talky', 'calm'],
  education: ['talky', 'focus'],
  comedy: ['talky', 'energetic'],
  religion: ['talky', 'calm'],
  sports: ['talky', 'energetic'],
  live: ['energetic'],
}

/** 태그에서 분위기를 뽑는다. 두 태그가 같은 분위기를 가리키면 그만큼 확신이 높다. */
export function moodsFromTags(tags: string[]): Array<{ mood: Mood; confidence: number }> {
  const score = new Map<Mood, number>()
  for (const tag of tags) {
    const moods = MOOD_BY_TAG[tag]
    if (!moods) continue
    // 태그가 첫째로 가리키는 분위기에 더 큰 값을 준다.
    moods.forEach((mood, index) => {
      score.set(mood, (score.get(mood) ?? 0) + 1 / (index + 1))
    })
  }
  if (!score.size) return []
  const max = Math.max(...score.values())
  return [...score.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 4)
    .map(([mood, value]) => ({ mood, confidence: Math.min(1, value / max) }))
}

export const MOOD_MODEL = '@cf/meta/llama-3.3-70b-instruct-fp8-fast'

const MOOD_RESPONSE_FORMAT = {
  type: 'json_schema',
  json_schema: {
    type: 'object',
    properties: {
      stations: {
        type: 'array',
        items: {
          type: 'object',
          properties: {
            id: { type: 'string' },
            moods: {
              type: 'array',
              items: { type: 'string', enum: [...CANONICAL_MOODS] },
            },
          },
          required: ['id', 'moods'],
        },
      },
    },
    required: ['stations'],
  },
} as const

function moodSystemPrompt(): string {
  return [
    'You label internet-radio stations with listening moods.',
    'Input is a JSON array of stations with an id, a name, a country and a language.',
    'For each station, return one to three moods that describe when it is good to listen to it.',
    'Judge from the station name: broadcaster names, call signs and words like FM, radio, news, jazz, hits.',
    'Return an empty array when the name tells you nothing.',
    'Copy the id exactly as given. Never invent stations.',
    `Allowed moods: ${CANONICAL_MOODS.join(', ')}`,
  ].join('\n')
}

interface MoodRow {
  id: string
  name: string
  country_code: string | null
  language: string | null
}

interface ClassifyResult { byRule: number; asked: number; decided: number }

type MoodAssignment = { stationID: string; moods: Array<{ mood: string; confidence: number }> }

/**
 * 분위기를 쓴다. 방송국 하나마다 D1 을 왕복하면 수천 번이 되므로 묶어 보낸다.
 * 한 묶음이 너무 크면 D1 이 받지 않아 문장 수로 잘라 나눈다.
 */
async function writeMoods(env: Env, assignments: MoodAssignment[], at: string): Promise<void> {
  const del = env.DB.prepare('DELETE FROM station_moods WHERE station_id = ?')
  const insert = env.DB.prepare(
    'INSERT OR REPLACE INTO station_moods (station_id, mood, confidence) VALUES (?, ?, ?)',
  )
  const mark = env.DB.prepare('UPDATE stations SET moods_at = ? WHERE id = ?')

  let chunk: D1PreparedStatement[] = []
  const flush = async () => {
    if (!chunk.length) return
    await env.DB.batch(chunk)
    chunk = []
  }

  for (const entry of assignments) {
    chunk.push(del.bind(entry.stationID))
    for (const mood of entry.moods) {
      if (!MOOD_SET.has(mood.mood)) continue
      chunk.push(insert.bind(entry.stationID, mood.mood, mood.confidence))
    }
    chunk.push(mark.bind(at, entry.stationID))
    if (chunk.length >= 120) await flush()
  }
  await flush()
}

/**
 * 아직 분류하지 않은 방송국에 분위기를 붙인다.
 *
 * 태그가 있으면 규칙 표로 바로 정하고, 태그가 하나도 없는 것만 모델에게 이름을 보여 준다.
 * 이렇게 하면 LLM 호출이 '태그 없는 방송국 수'에만 비례한다.
 */
export async function classifyPendingMoods(env: Env, maxBatches = 6): Promise<ClassifyResult> {
  const ruleBatch = 400
  const aiBatch = 20
  let byRule = 0
  let asked = 0
  let decided = 0
  const at = nowISO()

  // 1) 태그가 있는 방송국은 규칙으로 끝낸다.
  for (let i = 0; i < 12; i++) {
    const { results } = await env.DB.prepare(`
      SELECT s.id, GROUP_CONCAT(t.tag) AS tags
      FROM stations s
      JOIN station_tags t ON t.station_id = s.id
      WHERE s.moods_at IS NULL
      GROUP BY s.id
      LIMIT ?
    `).bind(ruleBatch).all<{ id: string; tags: string | null }>()
    if (!results.length) break

    await writeMoods(env, results.map((row) => ({
      stationID: row.id,
      moods: moodsFromTags((row.tags ?? '').split(',').filter(Boolean)),
    })), at)
    byRule += results.length
    if (results.length < ruleBatch) break
  }

  // 2) 태그가 없는 방송국만 모델에게 묻는다.
  for (let i = 0; i < maxBatches; i++) {
    const { results } = await env.DB.prepare(`
      SELECT s.id, s.name, s.country_code, s.language
      FROM stations s
      WHERE s.moods_at IS NULL
      LIMIT ?
    `).bind(aiBatch).all<MoodRow>()
    if (!results.length) break
    asked += results.length

    let answerMap = new Map<string, string[]>()
    try {
      const answer = (await env.AI.run(MOOD_MODEL as never, {
        messages: [
          { role: 'system', content: moodSystemPrompt() },
          {
            role: 'user',
            content: JSON.stringify(results.map((row) => ({
              id: row.id,
              name: row.name,
              country: row.country_code ?? '',
              language: row.language ?? '',
            }))),
          },
        ],
        response_format: MOOD_RESPONSE_FORMAT,
        max_tokens: 1200,
      } as never)) as { response?: unknown }

      const payload = typeof answer?.response === 'string' ? JSON.parse(answer.response) : answer?.response
      const rows = (payload as { stations?: Array<{ id?: string; moods?: string[] }> })?.stations ?? []
      answerMap = new Map(rows.map((r) => [String(r.id ?? ''), (r.moods ?? []).map(String)]))
    } catch (error) {
      console.error('분위기 분류 실패', error)
      break
    }

    // 답이 없어도 `moods_at` 은 채운다. 안 그러면 같은 방송국을 계속 다시 묻는다.
    await writeMoods(env, results.map((row) => ({
      stationID: row.id,
      moods: (answerMap.get(row.id) ?? [])
        .filter((mood) => MOOD_SET.has(mood))
        .slice(0, 3)
        .map((mood, index) => ({ mood, confidence: Math.max(0.3, 0.8 - index * 0.2) })),
    })), at)
    decided += results.length
    if (results.length < aiBatch) break
  }

  return { byRule, asked, decided }
}

/** 태그 정규화가 다시 돌면 분위기도 다시 계산해야 한다. */
export async function resetMoodsForRetagged(env: Env): Promise<number> {
  const result = await env.DB.prepare(`
    UPDATE stations SET moods_at = NULL
    WHERE moods_at IS NOT NULL
      AND EXISTS (SELECT 1 FROM station_tags t WHERE t.station_id = stations.id)
      AND NOT EXISTS (SELECT 1 FROM station_moods m WHERE m.station_id = stations.id)
  `).run()
  return result.meta.changes ?? 0
}
