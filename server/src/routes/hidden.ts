import type { Env } from '../types'
import { fail, json, nowISO } from '../lib/http'
import { installID } from './alarms'
import { loadNow, resolveHiddenStream } from '../lib/hiddenSchedule'

/**
 * 한국 지상파(히든).
 *
 * 토큰은 보안 장치가 아니라 문턱이다(`docs/03-proxy-api.md` 2번). 목적은 둘이다 —
 * 채널 목록이 공개 API 응답에 섞여 나가지 않게 하는 것, 설치 UUID 단위로 해제 기록을
 * 남겨 남용을 막는 것. 해제 엔드포인트 주소는 바이너리에 있으므로 뜯으면 부를 수 있다.
 */

interface ChannelRow {
  id: string
  name: string
  broadcaster: string
  logo_url: string | null
  schedule_kind: string | null
  sort_order: number
}

function randomToken(): string {
  const bytes = new Uint8Array(24)
  crypto.getRandomValues(bytes)
  return 'hid_' + [...bytes].map((b) => b.toString(16).padStart(2, '0')).join('')
}

/** 해제 토큰을 확인한다. 헤더와 설치 UUID 가 같은 줄을 가리켜야 통과한다. */
async function requireUnlocked(env: Env, request: Request): Promise<Response | null> {
  const install = installID(request)
  if (!install) return fail(400, 'no_install', 'X-ZP-Install 헤더가 필요하다.')
  const token = request.headers.get('x-zp-hidden')?.trim()
  if (!token) return fail(401, 'locked', '해제 토큰이 필요하다.')

  const row = await env.DB.prepare(
    'SELECT 1 AS ok FROM devices WHERE install_id = ? AND hidden_token = ? AND hidden_unlocked = 1',
  ).bind(install, token).first<{ ok: number }>()
  if (!row) return fail(401, 'locked', '해제 토큰이 맞지 않는다.')
  return null
}

/** 상태를 바꾸므로 POST 다. 이미 해제된 설치는 같은 토큰을 다시 준다. */
export async function unlockHidden(env: Env, request: Request): Promise<Response> {
  const install = installID(request)
  if (!install) return fail(400, 'no_install', 'X-ZP-Install 헤더가 필요하다.')

  const existing = await env.DB.prepare(
    'SELECT hidden_token FROM devices WHERE install_id = ? AND hidden_unlocked = 1',
  ).bind(install).first<{ hidden_token: string | null }>()

  if (existing?.hidden_token) {
    return json({ token: existing.hidden_token, alreadyUnlocked: true })
  }

  const token = randomToken()
  const at = nowISO()
  await env.DB.prepare(`
    INSERT INTO devices (install_id, hidden_unlocked, hidden_token, hidden_unlocked_at, last_seen_at)
    VALUES (?, 1, ?, ?, ?)
    ON CONFLICT(install_id) DO UPDATE SET
      hidden_unlocked = 1,
      hidden_token = excluded.hidden_token,
      hidden_unlocked_at = excluded.hidden_unlocked_at,
      last_seen_at = excluded.last_seen_at
  `).bind(install, token, at, at).run()

  return json({ token, alreadyUnlocked: false })
}

/** 해제를 되돌린다. 설정에서 '히든 기능 숨기기' 를 누르면 부른다. */
export async function lockHidden(env: Env, request: Request): Promise<Response> {
  const install = installID(request)
  if (!install) return fail(400, 'no_install', 'X-ZP-Install 헤더가 필요하다.')
  await env.DB.prepare(
    'UPDATE devices SET hidden_unlocked = 0, hidden_token = NULL WHERE install_id = ?',
  ).bind(install).run()
  return json({ ok: true })
}

export async function listHiddenChannels(env: Env, request: Request): Promise<Response> {
  const denied = await requireUnlocked(env, request)
  if (denied) return denied

  const { results } = await env.DB.prepare(`
    SELECT id, name, broadcaster, logo_url, schedule_kind, sort_order
    FROM hidden_channels WHERE enabled = 1 ORDER BY sort_order, name
  `).all<ChannelRow>()

  return json({
    items: results.map((row) => ({
      id: row.id,
      name: row.name,
      broadcaster: row.broadcaster,
      artworkURL: row.logo_url,
      hasSchedule: row.schedule_kind !== null,
    })),
  })
}

/** 재생 직전에만 부른다. 방송사 주소는 여기서만 나간다. */
export async function getHiddenStream(env: Env, request: Request, id: string): Promise<Response> {
  const denied = await requireUnlocked(env, request)
  if (denied) return denied

  const row = await env.DB.prepare(
    'SELECT stream_url, stream_kind FROM hidden_channels WHERE id = ? AND enabled = 1',
  ).bind(id).first<{ stream_url: string; stream_kind: string }>()
  if (!row) return fail(404, 'not_found', '그런 채널이 없다.')

  const resolved = await resolveHiddenStream(row.stream_url, row.stream_kind)
  if (!resolved) return fail(502, 'stream_unavailable', '지금 이 채널의 주소를 받지 못했다.')

  // 공개 방송국의 `/stream` 과 같은 모양으로 준다. 앱의 재생 코드는 종류를 구분하지 않는다.
  return json({ url: resolved, codec: null, bitrate: 0, recheckAfter: 1800, degraded: false })
}

/** 지금 방송 중인 프로그램. 파싱이 실패해도 200 을 주고 programName 을 비운다. */
export async function getHiddenNow(env: Env, request: Request, id: string): Promise<Response> {
  const denied = await requireUnlocked(env, request)
  if (denied) return denied

  const row = await env.DB.prepare(
    'SELECT id, name, schedule_kind, schedule_url FROM hidden_channels WHERE id = ? AND enabled = 1',
  ).bind(id).first<{ id: string; name: string; schedule_kind: string | null; schedule_url: string | null }>()
  if (!row) return fail(404, 'not_found', '그런 채널이 없다.')

  const now = await loadNow(env, row)
  return json({ ...now, refreshAfter: 300 })
}
