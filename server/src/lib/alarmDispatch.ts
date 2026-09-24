import type { Env } from '../types'
import { nowISO } from './http'
import { nextFireISO } from './schedule'
import { hasAPNsKeys, isDeadToken, sendPush, type PushEnv } from './apns'
import { collectCandidates } from './candidates'
import { SITUATIONS, daypartOf, type Situation } from './situations'
import { GLOBAL_COUNTRY, loadSet } from './recommendSets'

/**
 * 매분 돌며 울릴 때가 된 알람을 보낸다.
 *
 * 푸시가 도착해도 앱이 저절로 소리를 내지는 못한다(`docs/01-features.md` 5.1).
 * 사용자가 알림을 탭하거나 '재생' 단추를 눌러야 앱이 열리고 재생이 시작된다.
 * 그래서 본문에 무엇을 틀지 적어 두는 것이 중요하다 — 탭할 이유가 거기에 있다.
 */

interface DueRow {
  id: string
  install_id: string
  hour: number
  minute: number
  weekdays: string
  timezone: string
  source_kind: string
  source_id: string | null
  source_title: string | null
  situation: string | null
  label: string | null
  next_fire_at: string
  push_token: string | null
  push_env: string | null
}

export interface DispatchResult {
  due: number
  sent: number
  skipped: number
  failed: number
}

/** 알림에 담을 소스. 자동 선택이면 지금 시각에 맞는 것을 여기서 고른다. */
interface Chosen {
  kind: 'station' | 'episode'
  id: string
  title: string
  reason: string | null
}

async function resolveSource(env: Env, row: DueRow, at: Date): Promise<Chosen | null> {
  if (row.source_kind !== 'auto') {
    if (!row.source_id) return null
    if (row.source_title) {
      return {
        kind: row.source_kind === 'episode' ? 'episode' : 'station',
        id: row.source_id,
        title: row.source_title,
        reason: null,
      }
    }
    // 제목을 안 들고 있으면 지금 읽어 온다. 방송국 이름이 바뀌었을 수도 있다.
    const found = await env.DB.prepare('SELECT name FROM stations WHERE id = ?')
      .bind(row.source_id).first<{ name: string }>()
    return {
      kind: row.source_kind === 'episode' ? 'episode' : 'station',
      id: row.source_id,
      title: found?.name ?? '저장해 둔 방송',
      reason: null,
    }
  }

  // 자동 선택. 밤에 만들어 둔 세트가 있으면 그걸 쓰고, 없으면 규칙으로 즉석에서 고른다.
  const situation = (row.situation ?? 'wake') as Situation
  const rule = SITUATIONS[situation]
  if (!rule) return null

  // 사용자의 시계로 몇 시인지 본다. 알람은 그 사람의 아침에 울린다.
  const localHour = Number.parseInt(
    new Intl.DateTimeFormat('en-US', { timeZone: row.timezone, hour12: false, hour: '2-digit' })
      .format(at).replace(/\D/g, ''),
    10,
  ) % 24
  const daypart = daypartOf(localHour)
  const weekday = new Date(at).getUTCDay()
  const dayType = [0, 6].includes(weekday) ? 'weekend' : 'weekday'

  const stored = await loadSet(env, situation, dayType, daypart, GLOBAL_COUNTRY)
  const first = stored?.items?.[0] as { id?: string; title?: string; reason?: string } | undefined
  if (first?.id && first.title) {
    return { kind: 'station', id: first.id, title: first.title, reason: first.reason ?? null }
  }

  const candidates = await collectCandidates(env, {
    rule, daypart, country: null, limit: 1, secureOnly: true,
  })
  const pick = candidates[0]
  if (!pick) return null
  return { kind: 'station', id: pick.id, title: pick.name, reason: null }
}

function buildPayload(row: DueRow, chosen: Chosen): unknown {
  const title = row.label?.trim() || '알람'
  // 무엇을 틀지 한 줄로 적는다. 이유가 있으면 붙여 탭할 까닭을 만든다.
  const body = chosen.reason
    ? `${chosen.title} · ${chosen.reason}`
    : `${chosen.title} 을(를) 재생할 준비가 됐습니다. 눌러서 시작하세요.`

  return {
    aps: {
      alert: { title, body },
      sound: 'default',
      category: 'ZP_ALARM',
      'interruption-level': 'time-sensitive',
      'relevance-score': 1,
    },
    zp: {
      alarmID: row.id,
      kind: chosen.kind,
      id: chosen.id,
      title: chosen.title,
    },
  }
}

/** 보낸 뒤 다음 울릴 시각을 다시 적는다. 반복이 없으면 알람을 꺼 둔다. */
async function reschedule(env: Env, row: DueRow, firedAt: number): Promise<void> {
  const next = row.weekdays
    ? nextFireISO(
        { hour: row.hour, minute: row.minute, weekdays: row.weekdays, timezone: row.timezone },
        firedAt,
      )
    : null

  await env.DB.prepare(`
    UPDATE alarms SET next_fire_at = ?, last_sent_at = ?, enabled = ?, updated_at = ?
    WHERE id = ?
  `).bind(next, new Date(firedAt).toISOString(), next ? 1 : 0, nowISO(), row.id).run()
}

export async function dispatchDueAlarms(env: Env, limit = 50): Promise<DispatchResult> {
  const now = Date.now()
  // 1분마다 도는 배치가 몇 초 늦게 깨어날 수 있다. 조금 지난 것까지 함께 집는다.
  const cutoff = new Date(now + 20_000).toISOString()
  // 너무 오래 지난 것은 보내지 않는다. 아침 7시 알람이 9시에 오면 놀라기만 한다.
  const floor = new Date(now - 10 * 60_000).toISOString()

  const { results } = await env.DB.prepare(`
    SELECT a.id, a.install_id, a.hour, a.minute, a.weekdays, a.timezone,
           a.source_kind, a.source_id, a.source_title, a.situation, a.label, a.next_fire_at,
           d.push_token, d.push_env
    FROM alarms a
    LEFT JOIN devices d ON d.install_id = a.install_id
    WHERE a.enabled = 1 AND a.next_fire_at IS NOT NULL AND a.next_fire_at <= ?
    ORDER BY a.next_fire_at
    LIMIT ?
  `).bind(cutoff, limit).all<DueRow>()

  const out: DispatchResult = { due: results.length, sent: 0, skipped: 0, failed: 0 }
  if (!results.length) return out

  for (const row of results) {
    const firedAt = Date.parse(row.next_fire_at)

    // 너무 늦었거나(기기가 꺼져 있었거나 배치가 밀렸다) 토큰이 없으면 건너뛰고 다음으로 민다.
    if (row.next_fire_at < floor || !row.push_token || !hasAPNsKeys(env)) {
      out.skipped++
      await reschedule(env, row, firedAt)
      continue
    }

    // 같은 분에 두 번 보내지 않는다. 배치가 겹쳐 돌아도 한 번만 나간다.
    const claimed = await env.DB.prepare(
      'INSERT OR IGNORE INTO alarm_sends (alarm_id, fired_at, sent_at, ok, detail) VALUES (?,?,?,?,?)',
    ).bind(row.id, row.next_fire_at, nowISO(), 0, 'sending').run()
    if (!claimed.meta.changes) {
      out.skipped++
      continue
    }

    let detail = ''
    let ok = false
    try {
      const chosen = await resolveSource(env, row, new Date(firedAt))
      if (!chosen) {
        detail = '재생할 소스를 고르지 못했다'
      } else {
        const result = await sendPush(env, {
          deviceToken: row.push_token,
          pushEnv: (row.push_env === 'sandbox' ? 'sandbox' : 'prod') as PushEnv,
          payload: buildPayload(row, chosen),
          // 30분이 지나면 배달을 그만둔다. 알람은 지나면 뜻이 없다.
          expiration: Math.floor(firedAt / 1000) + 1800,
          collapseID: row.id,
        })
        ok = result.ok
        detail = result.ok ? chosen.title : `${result.status} ${result.reason ?? ''}`.trim()
        if (isDeadToken(result)) {
          await env.DB.prepare('UPDATE devices SET push_token = NULL WHERE install_id = ?')
            .bind(row.install_id).run()
          detail += ' (토큰을 지웠다)'
        }
      }
    } catch (error) {
      detail = String(error)
    }

    ok ? out.sent++ : out.failed++
    await env.DB.prepare(
      'UPDATE alarm_sends SET sent_at = ?, ok = ?, detail = ? WHERE alarm_id = ? AND fired_at = ?',
    ).bind(nowISO(), ok ? 1 : 0, detail.slice(0, 300), row.id, row.next_fire_at).run()
    await reschedule(env, row, firedAt)
  }

  return out
}

/** 오래된 발송 기록을 치운다. 중복 발송을 막는 용도라 며칠이면 충분하다. */
export async function pruneAlarmSends(env: Env, days = 7): Promise<number> {
  const before = new Date(Date.now() - days * 86_400_000).toISOString()
  const result = await env.DB.prepare('DELETE FROM alarm_sends WHERE fired_at < ?').bind(before).run()
  return result.meta.changes ?? 0
}
