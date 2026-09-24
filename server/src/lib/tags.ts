import type { Env } from '../types'
import { nowISO } from './http'

/**
 * 앱이 보는 태그는 이 목록에 있는 것뿐이다.
 * radio-browser 원시 태그는 표기가 제각각이라('POP', 'musica pop', 'Pop Music')
 * 규칙으로 줄이고, 규칙으로 안 줄어드는 것만 LLM 이 이 목록 중 하나로 옮긴다.
 */
export const CANONICAL_TAGS = [
  'pop', 'rock', 'jazz', 'classical', 'electronic', 'dance', 'house', 'techno',
  'hiphop', 'rnb', 'soul', 'funk', 'blues', 'country', 'folk', 'metal', 'punk',
  'indie', 'reggae', 'latin', 'kpop', 'jpop', 'cpop', 'anime', 'oldies',
  'ambient', 'chillout', 'lounge', 'newage', 'soundtrack', 'gospel', 'christian',
  'news', 'talk', 'sports', 'comedy', 'culture', 'education', 'religion',
  'traditional', 'world', 'trot', 'ballad', 'instrumental', 'live', 'top40',
] as const

const CANONICAL_SET = new Set<string>(CANONICAL_TAGS)

/** 규칙만으로 확실한 것들. LLM 을 부르기 전에 여기서 최대한 줄인다. */
const RULE_MAP: Record<string, string> = {
  'pop music': 'pop', 'popmusic': 'pop', 'musica pop': 'pop', 'muzyka pop': 'pop',
  'rock music': 'rock', 'classic rock': 'rock', 'hard rock': 'rock', 'rock and roll': 'rock',
  'classic': 'classical', 'klassik': 'classical', 'classical music': 'classical', 'musica clasica': 'classical',
  'hip hop': 'hiphop', 'hip-hop': 'hiphop', 'rap': 'hiphop',
  'r n b': 'rnb', 'r&b': 'rnb', 'rhythm and blues': 'rnb',
  'k pop': 'kpop', 'korean pop': 'kpop', 'k-pop': 'kpop',
  'j pop': 'jpop', 'japanese pop': 'jpop', 'j-pop': 'jpop',
  'c pop': 'cpop', 'chinese pop': 'cpop',
  'electro': 'electronic', 'edm': 'electronic', 'elektronische musik': 'electronic',
  'chill': 'chillout', 'chill out': 'chillout', 'relax': 'chillout', 'relaxing': 'chillout',
  'easy listening': 'lounge', 'smooth jazz': 'jazz',
  'new age': 'newage', 'ost': 'soundtrack', 'film music': 'soundtrack',
  'nachrichten': 'news', 'noticias': 'news', 'information': 'news', 'info': 'news',
  'talk radio': 'talk', 'talkradio': 'talk', 'spoken word': 'talk',
  'sport': 'sports', 'fussball': 'sports', 'football': 'sports',
  'oldie': 'oldies', 'golden oldies': 'oldies', '60s': 'oldies', '70s': 'oldies',
  'top 40': 'top40', 'hits': 'top40', 'hit music': 'top40', 'charts': 'top40',
  'kultur': 'culture', 'cultura': 'culture',
  'religious': 'religion', 'christian music': 'christian', 'ccm': 'christian',
  'volksmusik': 'traditional', 'folk music': 'folk', 'world music': 'world',
  '국악': 'traditional', '트로트': 'trot', '발라드': 'ballad', '가요': 'kpop',
  '뉴스': 'news', '클래식': 'classical', '재즈': 'jazz', '팝': 'pop',
}

/** 대소문자·기호·발음 구별 기호를 걷어낸 모양으로 맞춘다. */
export function ruleNormalize(raw: string): string | null {
  const base = raw
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[_/|]+/g, ' ')
    .replace(/[^\p{L}\p{N}&\s-]+/gu, ' ')
    .replace(/\s+/g, ' ')
    .trim()
  if (!base || base.length > 32) return null
  if (RULE_MAP[base]) return RULE_MAP[base]
  const hyphened = base.replace(/\s+/g, '')
  if (CANONICAL_SET.has(base)) return base
  if (CANONICAL_SET.has(hyphened)) return hyphened
  return null
}

/** radio-browser 의 태그 문자열을 원시 항목으로 쪼갠다. */
export function splitRawTags(raw: string | null | undefined): string[] {
  if (!raw) return []
  return [...new Set(
    raw.split(',').map((t) => t.trim()).filter((t) => t.length > 0 && t.length <= 40),
  )].slice(0, 12)
}

/**
 * 한 방송국의 원시 태그를 앱에 보여줄 태그로 옮긴다.
 * alias 표에 판정이 없으면 그 태그는 아직 안 보여준다 — 정리되지 않은 표기가
 * 앱 목록에 섞이는 것보다 비어 있는 편이 낫다.
 */
export function resolveTags(rawTags: string[], aliases: Map<string, string | null>): string[] {
  const out = new Set<string>()
  for (const raw of rawTags) {
    const byRule = ruleNormalize(raw)
    if (byRule) {
      out.add(byRule)
      continue
    }
    const mapped = aliases.get(raw.toLowerCase())
    if (mapped) out.add(mapped)
  }
  return [...out].slice(0, 8)
}

export async function loadAliases(env: Env): Promise<Map<string, string | null>> {
  const { results } = await env.DB.prepare(
    'SELECT raw, normalized FROM tag_aliases',
  ).all<{ raw: string; normalized: string | null }>()
  return new Map(results.map((r) => [r.raw, r.normalized]))
}

/** 규칙으로 못 줄인 태그를 판정 대기로 등록해 둔다. */
export async function recordUnknownTags(env: Env, rawTags: string[]): Promise<void> {
  const pending = rawTags.filter((t) => ruleNormalize(t) === null)
  if (!pending.length) return
  const at = nowISO()
  const stmt = env.DB.prepare(
    'INSERT OR IGNORE INTO tag_aliases (raw, normalized, origin, created_at) VALUES (?, NULL, ?, ?)',
  )
  await env.DB.batch(pending.map((t) => stmt.bind(t.toLowerCase(), 'rule', at)))
}

/** 모델에게 주는 지시. 표준 목록 밖의 답을 못 쓰게 스키마로 막는다. */
export function buildTagSystemPrompt(): string {
  return [
    'You normalize messy internet-radio station tags into one fixed vocabulary.',
    'Input is a JSON array of raw tags in any language.',
    'For every input tag, return the single allowed value that best matches its meaning.',
    'Return an empty string when no allowed value fits (place names, callsigns, bitrates, station names).',
    'Keep the input tags exactly as given in the "tag" field. Do not invent tags.',
    `Allowed values: ${CANONICAL_TAGS.join(', ')}`,
  ].join('\n')
}

export const TAG_MODEL = '@cf/meta/llama-3.3-70b-instruct-fp8-fast'

export const TAG_RESPONSE_FORMAT = {
  type: 'json_schema',
  json_schema: {
    type: 'object',
    properties: {
      mappings: {
        type: 'array',
        items: {
          type: 'object',
          properties: {
            tag: { type: 'string' },
            value: { type: 'string', enum: ['', ...CANONICAL_TAGS] },
          },
          required: ['tag', 'value'],
        },
      },
    },
    required: ['mappings'],
  },
} as const

interface NormalizeResult { asked: number; decided: number }

/**
 * 판정 대기 태그를 Workers AI 로 표준 태그에 맞춘다.
 * 맞는 것이 없으면 빈 문자열로 적어 다시 묻지 않는다.
 */
export async function normalizePendingTags(env: Env, maxBatches = 6): Promise<NormalizeResult> {
  const batchSize = 25
  let asked = 0
  let decided = 0

  for (let i = 0; i < maxBatches; i++) {
    const { results } = await env.DB.prepare(
      'SELECT raw FROM tag_aliases WHERE normalized IS NULL LIMIT ?',
    ).bind(batchSize).all<{ raw: string }>()
    if (!results.length) break
    asked += results.length

    let mapping = new Map<string, string>()
    try {
      const answer = (await env.AI.run(TAG_MODEL as never, {
        messages: [
          { role: 'system', content: buildTagSystemPrompt() },
          { role: 'user', content: JSON.stringify(results.map((r) => r.raw)) },
        ],
        response_format: TAG_RESPONSE_FORMAT,
        max_tokens: 1200,
      } as never)) as { response?: unknown }

      const payload = typeof answer?.response === 'string'
        ? JSON.parse(answer.response)
        : answer?.response
      const rows = (payload as { mappings?: Array<{ tag?: string; value?: string }> })?.mappings ?? []
      mapping = new Map(rows.map((r) => [String(r.tag ?? ''), String(r.value ?? '').trim().toLowerCase()]))
    } catch (error) {
      console.error('태그 정규화 실패', error)
      break
    }

    const at = nowISO()
    const stmt = env.DB.prepare(
      'UPDATE tag_aliases SET normalized = ?, origin = ?, created_at = ? WHERE raw = ?',
    )
    const binds = results.map((row) => {
      const answer = mapping.get(row.raw) ?? ''
      const value = CANONICAL_SET.has(answer) ? answer : ''
      return stmt.bind(value, 'ai', at, row.raw)
    })
    await env.DB.batch(binds)
    decided += binds.length
    if (results.length < batchSize) break
  }

  return { asked, decided }
}
