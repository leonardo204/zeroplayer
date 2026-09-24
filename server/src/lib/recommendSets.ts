import type { Env } from '../types'
import { nowISO } from './http'
import { collectCandidates, ruleReason, toItem, type Candidate, type RecommendItem } from './candidates'
import { SITUATIONS, type Daypart, type Situation } from './situations'
import { DAYPART_LABEL, DAY_TYPE_LABEL, SITUATION_TEXT, type Lang } from './i18n'

export const SET_MODEL = '@cf/meta/llama-3.3-70b-instruct-fp8-fast'

const DAYPARTS: Daypart[] = ['06-09', '09-12', '12-18', '18-22', '22-02', '02-06']
const DAY_TYPES = ['weekday', 'weekend'] as const
/** 만들어 두는 언어. 앱이 `lang` 으로 골라 간다. */
export const SET_LANGS: Lang[] = ['ko', 'en']

/** 전 세계 세트의 나라 자리. 나라를 안 고른 사용자가 받는 목록이다. */
export const GLOBAL_COUNTRY = 'ZZ'

export function setID(
  situation: string, dayType: string, daypart: string, country: string, lang: Lang,
): string {
  return `${situation}|${dayType}|${daypart}|${country}|${lang}`
}


const SET_RESPONSE_FORMAT = {
  type: 'json_schema',
  json_schema: {
    type: 'object',
    properties: {
      items: {
        type: 'array',
        items: {
          type: 'object',
          properties: {
            id: { type: 'string' },
            reason: { type: 'string' },
          },
          required: ['id', 'reason'],
        },
      },
    },
    required: ['items'],
  },
} as const

function systemPrompt(lang: Lang, situation: Situation, daypart: Daypart, dayType: string): string {
  const situationLabel = SITUATION_TEXT[lang][situation].label
  const daypartLabel = DAYPART_LABEL[lang][daypart]
  const dayTypeLabel = DAY_TYPE_LABEL[lang][dayType]

  if (lang === 'en') {
    return [
      'You are an editor who picks internet radio channels to fit a moment.',
      `The moment is "${situationLabel}" and the time is ${daypartLabel} on ${dayTypeLabel}.`,
      'The input is an array of candidate channels. Each has id, name, tags, moods and country.',
      'Reorder them to fit the moment and attach one English sentence to each channel.',
      '',
      'Sentence rules:',
      '- One full sentence between 30 and 90 characters, ending with a period.',
      '- Never answer with a fragment like "For sleep" or "Calming rain".',
      '- Say only why it fits the moment. Do not repeat the channel name.',
      '- Plain words. Avoid "perfect", "ultimate", "a variety of", "seamless".',
      '- Invent nothing that is not in the tags. If unsure, use only the tags and moods.',
      '',
      'Copy each id exactly from the input. Never invent a channel that is not in the input.',
    ].join('\n')
  }

  return [
    '너는 인터넷 라디오 채널을 상황에 맞게 골라 주는 편집자다.',
    `지금 상황은 "${situationLabel}"이고 시간대는 ${dayTypeLabel} ${daypartLabel}이다.`,
    '입력은 후보 채널 배열이다. 각 채널에 id, 이름, 태그, 분위기, 나라가 들어 있다.',
    '이 상황에 잘 맞는 순서로 다시 배열하고, 각 채널에 한국어 한 문장을 붙여라.',
    '',
    '문장 규칙:',
    '- 40자 이내 한 문장으로 쓴다.',
    '- 왜 이 상황에 맞는지만 쓴다. 채널 이름을 다시 말하지 않는다.',
    '- "~합니다" 로 끝낸다.',
    '- "이러한", "이를 통해", "최적의", "다양한" 같은 말을 쓰지 않는다.',
    '- 태그에 없는 사실을 지어내지 않는다. 확실하지 않으면 태그와 분위기만 가지고 쓴다.',
    '',
    'id 는 입력에 있는 값을 그대로 옮긴다. 입력에 없는 채널을 만들지 않는다.',
  ].join('\n')
}

function toPromptRow(candidate: Candidate) {
  return {
    id: candidate.id,
    name: candidate.name,
    tags: candidate.tags,
    moods: candidate.moods,
    country: candidate.country_code ?? '',
  }
}

/** 모델이 준 순서와 문구를 후보에 맞춰 넣는다. 빠진 후보는 규칙 문구로 뒤에 붙인다. */
function merge(
  candidates: Candidate[],
  answers: Array<{ id: string; reason: string }>,
  situation: Situation,
  limit: number,
  lang: Lang,
): RecommendItem[] {
  const byID = new Map(candidates.map((c) => [c.id, c]))
  const used = new Set<string>()
  const items: RecommendItem[] = []

  for (const answer of answers) {
    const candidate = byID.get(answer.id)
    if (!candidate || used.has(answer.id)) continue
    used.add(answer.id)
    const reason = answer.reason.trim()
    // 문장이 비었거나 지나치게 길면 규칙 문구를 쓴다. 화면에서 두 줄을 넘기지 않게.
    //
    // 길이 하한이 언어마다 다르다. 한국어는 한 글자에 뜻이 많아 여섯 자면 문장이지만,
    // 영어에서 여섯 자는 'For sleep' 같은 조각이다. 조각이 들어오면 규칙 문구가 낫다.
    const floor = lang === 'en' ? 25 : 6
    const ceiling = lang === 'en' ? 95 : 80
    const usable = reason.length >= floor && reason.length <= ceiling
    items.push(toItem(candidate, usable ? reason : ruleReason(candidate, situation, lang)))
    if (items.length >= limit) break
  }

  for (const candidate of candidates) {
    if (items.length >= limit) break
    if (used.has(candidate.id)) continue
    items.push(toItem(candidate, ruleReason(candidate, situation, lang)))
  }

  return items
}

interface BuildOneResult { id: string; model: string; count: number }

async function buildOne(
  env: Env,
  situation: Situation,
  dayType: string,
  daypart: Daypart,
  country: string,
  limit: number,
  lang: Lang,
): Promise<BuildOneResult | null> {
  const rule = SITUATIONS[situation]
  const candidates = await collectCandidates(env, {
    rule,
    daypart,
    country: country === GLOBAL_COUNTRY ? null : country,
    limit: limit * 2,
    // 세트는 앱이 그대로 재생에 쓰는 목록이다. 평문 HTTP 를 못 여는 기기가 있어
    // 여기서는 HTTPS 만 담는다. 직접 고르는 탐색 탭은 그대로 전부 보여준다.
    secureOnly: true,
  })
  if (!candidates.length) return null

  let items: RecommendItem[] | null = null
  let model = 'rule'

  try {
    const answer = (await env.AI.run(SET_MODEL as never, {
      messages: [
        {
          role: 'system',
          content: systemPrompt(lang, situation, daypart, dayType),
        },
        { role: 'user', content: JSON.stringify(candidates.slice(0, limit * 2).map(toPromptRow)) },
      ],
      response_format: SET_RESPONSE_FORMAT,
      max_tokens: 2000,
    } as never)) as { response?: unknown }

    const payload = typeof answer?.response === 'string' ? JSON.parse(answer.response) : answer?.response
    const rows = (payload as { items?: Array<{ id?: string; reason?: string }> })?.items ?? []
    if (rows.length) {
      items = merge(
        candidates,
        rows.map((r) => ({ id: String(r.id ?? ''), reason: String(r.reason ?? '') })),
        situation,
        limit,
        lang,
      )
      model = SET_MODEL
    }
  } catch (error) {
    console.error('추천 세트 생성 실패', situation, daypart, country, lang, error)
  }

  // LLM 이 실패하면 1단 결과를 그대로 저장한다. 목록이 비는 것보다 낫다.
  if (!items) items = merge(candidates, [], situation, limit, lang)

  const id = setID(situation, dayType, daypart, country, lang)
  await env.DB.prepare(`
    INSERT INTO recommendation_sets (id, situation, daypart, day_type, country, payload, model, created_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(id) DO UPDATE SET
      payload = excluded.payload, model = excluded.model, created_at = excluded.created_at
  `).bind(id, situation, daypart, dayType, country, JSON.stringify(items), model, nowISO()).run()

  return { id, model, count: items.length }
}

export interface BuildResult {
  built: BuildOneResult[]
  remaining: number
}

/**
 * 상황 × 시간대 × 평일·주말 × 나라 조합으로 세트를 만든다.
 *
 * 조합은 유한하다. 나라 한 곳에 60가지고, 사용자가 몇 명이든 그대로다.
 * 그래서 요청마다 LLM 을 부르지 않고 이 배치에서 미리 만들어 둔다.
 * 한 번에 다 만들면 오래 걸리니 `maxSets` 만큼 끊어 돌린다 — 남은 수를 함께 돌려준다.
 */
export async function buildSets(
  env: Env,
  options: { countries?: string[]; maxSets?: number; limit?: number; force?: boolean } = {},
): Promise<BuildResult> {
  const countries = options.countries ?? recommendCountries(env)
  const maxSets = options.maxSets ?? 8
  const limit = options.limit ?? 20
  const situations = Object.keys(SITUATIONS) as Situation[]

  // 오늘 이미 만든 세트는 건너뛴다. 배치를 나눠 돌려도 같은 조합을 다시 만들지 않는다.
  const fresh = new Set<string>()
  if (!options.force) {
    const since = new Date(Date.now() - 20 * 60 * 60 * 1000).toISOString()
    const { results } = await env.DB.prepare(
      'SELECT id FROM recommendation_sets WHERE created_at >= ?',
    ).bind(since).all<{ id: string }>()
    for (const row of results) fresh.add(row.id)
  }

  const todo: Array<[Situation, string, Daypart, string, Lang]> = []
  for (const country of countries) {
    for (const situation of situations) {
      for (const dayType of DAY_TYPES) {
        for (const daypart of DAYPARTS) {
          for (const lang of SET_LANGS) {
            if (fresh.has(setID(situation, dayType, daypart, country, lang))) continue
            todo.push([situation, dayType, daypart, country, lang])
          }
        }
      }
    }
  }

  const built: BuildOneResult[] = []
  for (const [situation, dayType, daypart, country, lang] of todo.slice(0, maxSets)) {
    const result = await buildOne(env, situation, dayType, daypart, country, limit, lang)
    if (result) built.push(result)
  }

  return { built, remaining: Math.max(0, todo.length - maxSets) }
}

/** 세트를 만들어 둘 나라. 방송국을 받아오는 나라와 전 세계 자리를 함께 쓴다. */
export function recommendCountries(env: Env): string[] {
  const configured = (env.RECOMMEND_COUNTRIES ?? 'KR')
    .split(',')
    .map((code) => code.trim().toUpperCase())
    .filter(Boolean)
  return [...new Set([...configured, GLOBAL_COUNTRY])]
}

export interface StoredSet {
  items: RecommendItem[]
  model: string | null
  createdAt: string
}

export async function loadSet(
  env: Env,
  situation: Situation,
  dayType: string,
  daypart: Daypart,
  country: string,
  lang: Lang,
): Promise<StoredSet | null> {
  const row = await env.DB.prepare(
    'SELECT payload, model, created_at FROM recommendation_sets WHERE id = ?',
  ).bind(setID(situation, dayType, daypart, country, lang)).first<{
    payload: string
    model: string | null
    created_at: string
  }>()
  if (!row) return null

  let items: RecommendItem[]
  try {
    items = JSON.parse(row.payload) as RecommendItem[]
  } catch {
    return null
  }
  if (!Array.isArray(items) || !items.length) return null

  const live = await keepPlayable(env, items)
  if (!live.length) return null
  return { items: live, model: row.model, createdAt: row.created_at }
}

/**
 * 세트를 만든 뒤에 목록에서 빠진 방송국을 걸러 낸다.
 *
 * 세트는 하루에 한 번만 다시 만들어서, 그 사이에 죽거나 만료 서명이 드러난
 * 방송국, 또는 같은 방송의 대표에서 밀려난 줄이 그대로 남아 있을 수 있다. 앱은 이 목록을 눌러 바로 재생하므로
 * 여기서 걸러 주지 않으면 사용자가 403 을 본다. 에피소드는 방송국 표에 없으니
 * 그대로 통과시킨다.
 */
async function keepPlayable(env: Env, items: RecommendItem[]): Promise<RecommendItem[]> {
  const stationIDs = items.filter((i) => i.kind === 'station').map((i) => i.id)
  if (!stationIDs.length) return items

  const holes = stationIDs.map(() => '?').join(',')
  const { results } = await env.DB.prepare(`
    SELECT s.id FROM stations s
    LEFT JOIN station_health h ON h.station_id = s.id
    WHERE s.id IN (${holes}) AND s.is_hidden = 0
      AND s.stream_signed = 0 AND s.is_primary = 1 AND COALESCE(h.excluded, 0) = 0
  `).bind(...stationIDs).all<{ id: string }>()

  const alive = new Set(results.map((r) => r.id))
  return items.filter((i) => i.kind !== 'station' || alive.has(i.id))
}
