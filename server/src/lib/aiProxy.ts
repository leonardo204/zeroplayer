import type { Env } from '../types'

/**
 * 모델 호출은 전부 ai.zerolive.co.kr 의 AI 프록시(/v1/ai)를 거친다.
 *
 * 2026-10 까지는 Workers AI(llama-3.3-70b) 바인딩을 직접 불렀다. 그런데 응답 없이 붙드는 일이
 * 잦아(10-06 시험 3회 모두 45초 무응답) 추천 세트 배치가 15분 한도에 끊겼고, 바인딩 호출이라
 * 대시보드 비용 집계에서도 빠져 있었다. 프록시를 거치면 둘 다 풀린다.
 *
 * 모델 이름은 코드에 두지 않는다. 용도 이름(`X-Ai-Kind`)만 보내고, 실제 모델은 프록시의
 * 앱 설정(zeroplayer 앱의 models 표)이 정한다. 모델을 바꿀 때 재배포가 필요 없다.
 *   recommend → 추천 세트 문구 · tags → 태그 정규화 · moods → 분위기 분류
 */

const ENDPOINT = 'https://ai.zerolive.co.kr/v1/ai'

/** 호출 하나에 줄 시간. 넘기면 부르는 쪽이 규칙으로 대체한다(배치가 15분 한도에 끊기지 않게). */
export const AI_TIMEOUT_MS = 45_000

export type AIKind = 'recommend' | 'tags' | 'moods'

export class AITimeout extends Error {
  constructor(ms: number) { super(`AI 응답이 ${ms}ms 안에 오지 않았다`) }
}

export interface AIResult {
  /** 모델이 돌려준 JSON 을 푼 값 */
  data: unknown
  /** 실제로 답한 모델. 프록시 설정에서 정해지므로 응답에서 읽는다 */
  model: string
}

/**
 * JSON 스키마에 맞춘 답 하나를 받는다. 실패하면 던진다 — 부르는 쪽이 규칙으로 대체한다.
 *
 * `schema` 는 JSON Schema 본체다. OpenRouter 는 `{name, strict, schema}` 로 감싸야 받는다.
 */
export async function askJSON(
  env: Env,
  kind: AIKind,
  options: { system: string; user: string; schema: object; maxTokens: number; timeoutMs: number },
): Promise<AIResult> {
  if (!env.AI_PROXY_TOKEN) throw new Error('AI_PROXY_TOKEN 이 없다')

  let response: Response
  try {
    response = await fetch(ENDPOINT, {
      method: 'POST',
      headers: {
        authorization: `Bearer ${env.AI_PROXY_TOKEN}`,
        'content-type': 'application/json',
        'x-ai-kind': kind,
      },
      body: JSON.stringify({
        messages: [
          { role: 'system', content: options.system },
          { role: 'user', content: options.user },
        ],
        response_format: {
          type: 'json_schema',
          json_schema: { name: kind, strict: true, schema: options.schema },
        },
        max_tokens: options.maxTokens,
        meta: { src: 'zeroplayer-api' },
      }),
      signal: AbortSignal.timeout(options.timeoutMs),
    })
  } catch (error) {
    if (error instanceof Error && (error.name === 'TimeoutError' || error.name === 'AbortError')) {
      throw new AITimeout(options.timeoutMs)
    }
    throw error
  }

  const text = await response.text()
  if (!response.ok) throw new Error(`AI 프록시 ${response.status}: ${text.slice(0, 200)}`)

  const body = JSON.parse(text) as {
    model?: string
    choices?: Array<{ finish_reason?: string; native_finish_reason?: string; message?: { content?: string } }>
  }
  const choice = body.choices?.[0]
  const content = choice?.message?.content
  if (typeof content !== 'string' || !content.trim()) throw new Error('AI 응답이 비었다')
  try {
    return { data: JSON.parse(content), model: body.model ?? kind }
  } catch {
    // 왜 끊겼는지 남긴다. length 면 출력 한도, 그 밖이면 모델 쪽 사정이다.
    throw new Error(`AI 답이 JSON 이 아니다 (finish=${choice?.finish_reason}/${choice?.native_finish_reason}, ${content.length}자, 끝="${content.slice(-80)}")`)
  }
}
