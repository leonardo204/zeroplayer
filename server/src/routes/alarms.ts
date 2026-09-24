import type { Env } from '../types'
import { fail, json, nowISO } from '../lib/http'
import { isValidTimezone, nextFireISO, parseWeekdays } from '../lib/schedule'

/**
 * 기기 등록과 알람 CRUD.
 *
 * 누가 부르는지는 `X-ZP-Install` 헤더의 설치 UUID 로만 가린다. 기기 식별자가 아니고
 * 앱이 처음 실행될 때 만들어 키체인에 둔 값이다(`docs/03-proxy-api.md` 2번).
 * 이 값으로 남의 알람을 읽을 수는 있지만 UUID 를 알아내야 하고, 알람에는 개인을
 * 알아볼 값이 없다. 그 이상의 인증은 2.0 범위에 넣지 않는다.
 */

const SOURCE_KINDS = new Set(['station', 'episode', 'auto'])
const SITUATIONS = new Set(['sleep', 'commute', 'study', 'work', 'wake'])

interface AlarmRow {
  id: string
  hour: number
  minute: number
  weekdays: string
  timezone: string
  source_kind: string
  source_id: string | null
  source_title: string | null
  situation: string | null
  label: string | null
  enabled: number
  next_fire_at: string | null
  last_sent_at: string | null
}

function toDTO(row: AlarmRow) {
  return {
    alarmID: row.id,
    hour: row.hour,
    minute: row.minute,
    weekdays: [...parseWeekdays(row.weekdays)].sort((a, b) => a - b),
    timezone: row.timezone,
    source: {
      kind: row.source_kind,
      id: row.source_id,
      title: row.source_title,
      situation: row.situation,
    },
    label: row.label,
    enabled: row.enabled === 1,
    nextFireAt: row.next_fire_at,
    lastSentAt: row.last_sent_at,
  }
}

export function installID(request: Request): string | null {
  const raw = request.headers.get('x-zp-install')?.trim()
  if (!raw || raw.length < 8 || raw.length > 64) return null
  return raw
}

/** 알람을 걸려면 기기 줄이 먼저 있어야 한다. 없으면 토큰 없이 만들어 둔다. */
async function touchDevice(env: Env, install: string, appVersion: string | null): Promise<void> {
  await env.DB.prepare(`
    INSERT INTO devices (install_id, app_version, last_seen_at)
    VALUES (?, ?, ?)
    ON CONFLICT(install_id) DO UPDATE SET
      app_version = COALESCE(excluded.app_version, devices.app_version),
      last_seen_at = excluded.last_seen_at
  `).bind(install, appVersion, nowISO()).run()
}

/** POST /push/token — APNs 기기 토큰을 등록한다. 토큰은 앱을 지우거나 되살리면 바뀐다. */
export async function registerPushToken(env: Env, request: Request): Promise<Response> {
  const install = installID(request)
  if (!install) return fail(400, 'no_install', 'X-ZP-Install 헤더가 필요하다.')

  let body: { token?: string; env?: string; appVersion?: string }
  try {
    body = (await request.json()) as typeof body
  } catch {
    return fail(400, 'bad_body', '본문을 읽지 못했다.')
  }

  const token = body.token?.trim()
  if (!token || !/^[0-9a-fA-F]{64,200}$/.test(token)) {
    return fail(400, 'bad_token', '기기 토큰 모양이 아니다.')
  }
  const pushEnv = body.env === 'sandbox' ? 'sandbox' : 'prod'

  await env.DB.prepare(`
    INSERT INTO devices (install_id, push_token, push_env, app_version, last_seen_at)
    VALUES (?, ?, ?, ?, ?)
    ON CONFLICT(install_id) DO UPDATE SET
      push_token = excluded.push_token,
      push_env = excluded.push_env,
      app_version = COALESCE(excluded.app_version, devices.app_version),
      last_seen_at = excluded.last_seen_at
  `).bind(install, token, pushEnv, body.appVersion ?? null, nowISO()).run()

  return json({ ok: true, env: pushEnv })
}

/** DELETE /push/token — 알림 권한을 끈 경우. 토큰만 지우고 알람은 남긴다(로컬 백업은 계속 울린다). */
export async function deletePushToken(env: Env, request: Request): Promise<Response> {
  const install = installID(request)
  if (!install) return fail(400, 'no_install', 'X-ZP-Install 헤더가 필요하다.')
  await env.DB.prepare('UPDATE devices SET push_token = NULL WHERE install_id = ?').bind(install).run()
  return json({ ok: true })
}

export async function listAlarms(env: Env, request: Request): Promise<Response> {
  const install = installID(request)
  if (!install) return fail(400, 'no_install', 'X-ZP-Install 헤더가 필요하다.')
  const { results } = await env.DB.prepare(`
    SELECT id, hour, minute, weekdays, timezone, source_kind, source_id, source_title,
           situation, label, enabled, next_fire_at, last_sent_at
    FROM alarms WHERE install_id = ? ORDER BY hour, minute
  `).bind(install).all<AlarmRow>()
  return json({ items: results.map(toDTO) })
}

interface AlarmInput {
  hour?: number
  minute?: number
  weekdays?: number[]
  timezone?: string
  label?: string
  enabled?: boolean
  source?: { kind?: string; id?: string; title?: string; situation?: string }
}

function validate(input: AlarmInput, base?: AlarmRow): { error: string } | {
  hour: number; minute: number; weekdays: string; timezone: string
  sourceKind: string; sourceID: string | null; sourceTitle: string | null
  situation: string | null; label: string | null; enabled: number
} {
  const hour = input.hour ?? base?.hour
  const minute = input.minute ?? base?.minute
  if (!Number.isInteger(hour) || hour! < 0 || hour! > 23) return { error: 'hour 는 0~23 이다.' }
  if (!Number.isInteger(minute) || minute! < 0 || minute! > 59) return { error: 'minute 는 0~59 이다.' }

  const weekdays = input.weekdays
    ? [...new Set(input.weekdays.filter((d) => Number.isInteger(d) && d >= 1 && d <= 7))].sort().join(',')
    : (base?.weekdays ?? '')

  const timezone = input.timezone ?? base?.timezone ?? 'UTC'
  if (!isValidTimezone(timezone)) return { error: 'timezone 이 IANA 이름이 아니다.' }

  const sourceKind = input.source?.kind ?? base?.source_kind ?? 'auto'
  if (!SOURCE_KINDS.has(sourceKind)) return { error: "source.kind 는 station·episode·auto 중 하나다." }

  const situation = input.source?.situation ?? base?.situation ?? null
  if (sourceKind === 'auto') {
    const chosen = situation ?? 'wake'
    if (!SITUATIONS.has(chosen)) return { error: 'source.situation 이 상황 값이 아니다.' }
  }

  const sourceID = input.source?.id ?? base?.source_id ?? null
  if (sourceKind !== 'auto' && !sourceID) return { error: 'source.id 가 필요하다.' }

  return {
    hour: hour!, minute: minute!, weekdays, timezone,
    sourceKind,
    sourceID: sourceKind === 'auto' ? null : sourceID,
    sourceTitle: input.source?.title ?? base?.source_title ?? null,
    situation: sourceKind === 'auto' ? (situation ?? 'wake') : null,
    label: input.label ?? base?.label ?? null,
    enabled: (input.enabled ?? (base ? base.enabled === 1 : true)) ? 1 : 0,
  }
}

function newAlarmID(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(9))
  return 'alm_' + [...bytes].map((b) => b.toString(16).padStart(2, '0')).join('')
}

export async function createAlarm(env: Env, request: Request): Promise<Response> {
  const install = installID(request)
  if (!install) return fail(400, 'no_install', 'X-ZP-Install 헤더가 필요하다.')

  let input: AlarmInput
  try {
    input = (await request.json()) as AlarmInput
  } catch {
    return fail(400, 'bad_body', '본문을 읽지 못했다.')
  }

  const v = validate(input)
  if ('error' in v) return fail(400, 'bad_alarm', v.error)

  await touchDevice(env, install, request.headers.get('x-zp-client'))

  const id = newAlarmID()
  const at = nowISO()
  const next = v.enabled
    ? nextFireISO({ hour: v.hour, minute: v.minute, weekdays: v.weekdays, timezone: v.timezone })
    : null

  await env.DB.prepare(`
    INSERT INTO alarms (id, install_id, hour, minute, weekdays, timezone,
                        source_kind, source_id, source_title, situation, label,
                        enabled, next_fire_at, created_at, updated_at)
    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
  `).bind(
    id, install, v.hour, v.minute, v.weekdays, v.timezone,
    v.sourceKind, v.sourceID, v.sourceTitle, v.situation, v.label,
    v.enabled, next, at, at,
  ).run()

  return json({ alarmID: id, nextFireAt: next }, { status: 201 })
}

export async function updateAlarm(env: Env, id: string, request: Request): Promise<Response> {
  const install = installID(request)
  if (!install) return fail(400, 'no_install', 'X-ZP-Install 헤더가 필요하다.')

  const base = await env.DB.prepare(`
    SELECT id, hour, minute, weekdays, timezone, source_kind, source_id, source_title,
           situation, label, enabled, next_fire_at, last_sent_at
    FROM alarms WHERE id = ? AND install_id = ?
  `).bind(id, install).first<AlarmRow>()
  if (!base) return fail(404, 'not_found', '그런 알람이 없다.')

  let input: AlarmInput
  try {
    input = (await request.json()) as AlarmInput
  } catch {
    return fail(400, 'bad_body', '본문을 읽지 못했다.')
  }

  const v = validate(input, base)
  if ('error' in v) return fail(400, 'bad_alarm', v.error)

  const next = v.enabled
    ? nextFireISO({ hour: v.hour, minute: v.minute, weekdays: v.weekdays, timezone: v.timezone })
    : null

  await env.DB.prepare(`
    UPDATE alarms SET hour=?, minute=?, weekdays=?, timezone=?,
                      source_kind=?, source_id=?, source_title=?, situation=?, label=?,
                      enabled=?, next_fire_at=?, updated_at=?
    WHERE id=? AND install_id=?
  `).bind(
    v.hour, v.minute, v.weekdays, v.timezone,
    v.sourceKind, v.sourceID, v.sourceTitle, v.situation, v.label,
    v.enabled, next, nowISO(), id, install,
  ).run()

  return json({ alarmID: id, nextFireAt: next })
}

export async function deleteAlarm(env: Env, id: string, request: Request): Promise<Response> {
  const install = installID(request)
  if (!install) return fail(400, 'no_install', 'X-ZP-Install 헤더가 필요하다.')
  const result = await env.DB.prepare('DELETE FROM alarms WHERE id = ? AND install_id = ?')
    .bind(id, install).run()
  if (!result.meta.changes) return fail(404, 'not_found', '그런 알람이 없다.')
  return json({ ok: true })
}
