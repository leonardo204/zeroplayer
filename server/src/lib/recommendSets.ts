import type { Env } from '../types'
import { nowISO } from './http'
import { collectCandidates, ruleReason, toItem, type Candidate, type RecommendItem } from './candidates'
import { SITUATIONS, type Daypart, type Situation } from './situations'

export const SET_MODEL = '@cf/meta/llama-3.3-70b-instruct-fp8-fast'

const DAYPARTS: Daypart[] = ['06-09', '09-12', '12-18', '18-22', '22-02', '02-06']
const DAY_TYPES = ['weekday', 'weekend'] as const

/** 전 세계 세트의 나라 자리. 나라를 안 고른 사용자가 받는 목록이다. */
export const GLOBAL_COUNTRY = 'ZZ'

export function setID(situation: string, dayType: string, daypart: string, country: string): string {
  return `${situation}|${dayType}|${daypart}|${country}`
}

const DAYPART_LABEL: Record<Daypart, string> = {
  '06-09': '이른 아침',
  '09-12': '오전',
  '12-18': '낮',
  '18-22': '저녁',
  '22-02': '밤',
  '02-06': '새벽',
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

function systemPrompt(situationLabel: string, daypartLabel: string, dayTypeLabel: string): string {
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
): RecommendItem[] {
  const rule = SITUATIONS[situation]
  const byID = new Map(candidates.map((c) => [c.id, c]))
  const used = new Set<string>()
  const items: RecommendItem[] = []

  for (const answer of answers) {
    const candidate = byID.get(answer.id)
    if (!candidate || used.has(answer.id)) continue
    used.add(answer.id)
    const reason = answer.reason.trim()
    // 문장이 비었거나 지나치게 길면 규칙 문구를 쓴다. 화면에서 두 줄을 넘기지 않게.
    const usable = reason.length >= 6 && reason.length <= 80
    items.push(toItem(candidate, usable ? reason : ruleReason(candidate, rule)))
    if (items.length >= limit) break
  }

  for (const candidate of candidates) {
    if (items.length >= limit) break
    if (used.has(candidate.id)) continue
    items.push(toItem(candidate, ruleReason(candidate, rule)))
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
          content: systemPrompt(
            rule.label,
            DAYPART_LABEL[daypart],
            dayType === 'weekend' ? '주말' : '평일',
          ),
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
      )
      model = SET_MODEL
    }
  } catch (error) {
    console.error('추천 세트 생성 실패', situation, daypart, country, error)
  }

  // LLM 이 실패하면 1단 결과를 그대로 저장한다. 목록이 비는 것보다 낫다.
  if (!items) items = merge(candidates, [], situation, limit)

  const id = setID(situation, dayType, daypart, country)
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

  const todo: Array<[Situation, string, Daypart, string]> = []
  for (const country of countries) {
    for (const situation of situations) {
      for (const dayType of DAY_TYPES) {
        for (const daypart of DAYPARTS) {
          if (fresh.has(setID(situation, dayType, daypart, country))) continue
          todo.push([situation, dayType, daypart, country])
        }
      }
    }
  }

  const built: BuildOneResult[] = []
  for (const [situation, dayType, daypart, country] of todo.slice(0, maxSets)) {
    const result = await buildOne(env, situation, dayType, daypart, country, limit)
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
): Promise<StoredSet | null> {
  const row = await env.DB.prepare(
    'SELECT payload, model, created_at FROM recommendation_sets WHERE id = ?',
  ).bind(setID(situation, dayType, daypart, country)).first<{
    payload: string
    model: string | null
    created_at: string
  }>()
  if (!row) return null

  try {
    const items = JSON.parse(row.payload) as RecommendItem[]
    if (!Array.isArray(items) || !items.length) return null
    return { items, model: row.model, createdAt: row.created_at }
  } catch {
    return null
  }
}
