import type { Env } from '../types'
import { fail, json, nowISO } from '../lib/http'
import { installID, touchDevice } from './alarms'

/**
 * 자동 선택에서 빼 달라고 한 방송국 목록.
 *
 * iOS 25 이하만 이 경로를 쓴다. 거기서는 알람에 무엇을 틀지 서버가 고르기 때문에
 * (`lib/alarmDispatch.ts`) 기기에만 두면 아침에 뺀 방송이 그대로 온다.
 * iOS 26 이상은 앱이 고르므로 올릴 이유가 없고, AlarmKit 권한을 받는 순간 앱이
 * 빈 목록을 올려 이 표를 비운다.
 *
 * 받는 것은 방송국 번호뿐이다. 무엇을 얼마나 들었는지는 오지 않는다.
 */

/** 한 기기가 담을 수 있는 최대. 이보다 많으면 취향이 아니라 오류다. */
const MAX_STATIONS = 300

/**
 * PUT /exclusions — 목록 전체를 덮어쓴다.
 *
 * 하나씩 더하고 빼는 경로를 두지 않는다. 기기와 서버가 어긋났을 때 되맞출 길이
 * 없어지기 때문이다. 기기가 가진 것이 정답이고 서버는 그것을 그대로 받는다.
 */
export async function replaceExclusions(env: Env, request: Request): Promise<Response> {
  const install = installID(request)
  if (!install) return fail(400, 'no_install', 'X-ZP-Install 헤더가 필요하다.')

  let body: { stations?: unknown }
  try {
    body = (await request.json()) as typeof body
  } catch {
    return fail(400, 'bad_body', '본문을 읽지 못했다.')
  }

  const raw = body?.stations
  if (!Array.isArray(raw)) return fail(400, 'bad_stations', 'stations 는 배열이어야 한다.')
  if (raw.length > MAX_STATIONS) {
    return fail(400, 'too_many', `한 번에 ${MAX_STATIONS}개까지 받는다.`)
  }

  // 모르는 모양이 오면 조용히 버리지 않고 통째로 거절한다. 버리면 맞춰진 줄 안다.
  const ids: string[] = []
  for (const value of raw) {
    if (typeof value !== 'string') return fail(400, 'bad_stations', '방송국 번호는 문자열이어야 한다.')
    const id = value.trim()
    if (!id || id.length > 120) return fail(400, 'bad_stations', `방송국 번호 모양이 아니다: ${id.slice(0, 40)}`)
    if (!ids.includes(id)) ids.push(id)
  }

  await touchDevice(env, install, null)

  const now = nowISO()
  const statements = [
    env.DB.prepare('DELETE FROM excluded_stations WHERE install_id = ?').bind(install),
    ...ids.map((id) =>
      env.DB.prepare(
        'INSERT OR IGNORE INTO excluded_stations (install_id, station_id, created_at) VALUES (?,?,?)',
      ).bind(install, id, now),
    ),
  ]
  // batch 는 한 트랜잭션으로 돈다. 지우고 넣는 사이에 알람 배치가 끼어들어 빈 목록을
  // 보는 일이 없다.
  await env.DB.batch(statements)

  return json({ ok: true, stations: ids.length })
}

/** GET /exclusions — 기기가 자기 목록을 되맞출 때 쓴다. */
export async function listExclusions(env: Env, request: Request): Promise<Response> {
  const install = installID(request)
  if (!install) return fail(400, 'no_install', 'X-ZP-Install 헤더가 필요하다.')

  const { results } = await env.DB.prepare(
    'SELECT station_id, created_at FROM excluded_stations WHERE install_id = ? ORDER BY created_at DESC',
  ).bind(install).all<{ station_id: string; created_at: string }>()

  return json({ stations: results.map((row) => row.station_id) })
}

/** 알람 발송이 후보를 걸러낼 때 읽는다. 없으면 빈 집합이다. */
export async function excludedFor(env: Env, install: string): Promise<Set<string>> {
  const { results } = await env.DB.prepare(
    'SELECT station_id FROM excluded_stations WHERE install_id = ?',
  ).bind(install).all<{ station_id: string }>()
  return new Set(results.map((row) => row.station_id))
}
