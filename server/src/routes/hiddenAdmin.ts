import type { Env } from '../types'
import { fail, json, nowISO } from '../lib/http'

/**
 * 지상파 채널 관리 — 대시보드가 화면에서 고칠 수 있게 연 경로.
 *
 * 그동안 방송사가 주소를 바꿀 때마다 `wrangler d1 execute` 로 손으로 고쳤다. 터미널을 열 수
 * 있는 자리에서만, 오타가 나도 아무도 안 막아 주는 채로.
 *
 * 대시보드에 zeroplayer D1 을 직접 물리는 방법도 있었다. 그러면 저쪽이 이 스키마를 알아야
 * 하고, 컬럼을 하나 고칠 때마다 두 저장소의 배포 순서를 맞춰야 한다. 표를 아는 쪽이 표를
 * 다루는 편이 낫다 — 여기에 경로를 두고 저쪽은 화면만 만든다.
 *
 *   GET   /zp/v1/admin/hidden/channels        전부(꺼진 것까지)
 *   PATCH /zp/v1/admin/hidden/channels/{id}   고칠 칸만 골라 보낸다
 */

interface AdminRow {
  id: string
  name: string
  broadcaster: string
  stream_url: string
  stream_kind: string
  schedule_kind: string | null
  schedule_url: string | null
  logo_url: string | null
  sort_order: number
  enabled: number
  updated_at: string
}

/** 고칠 수 있는 칸. 여기 없는 이름이 오면 통째로 거절한다 — 조용히 무시하면 고쳐진 줄 안다. */
const EDITABLE = new Set([
  'name', 'broadcaster', 'stream_url', 'stream_kind',
  'schedule_kind', 'schedule_url', 'logo_url', 'sort_order', 'enabled',
])

const KINDS = new Set(['direct', 'pls'])

/**
 * 서명이 붙는 주소는 pls 로 둬야 한다.
 *
 * KBS·MBC·SBS 는 serpent0 의 .pls 가 부를 때마다 새로 서명된 m3u8 을 준다. 그 m3u8 을
 * 직접 적어 두면 처음 몇 시간은 되다가 서명이 만료돼 403 이 난다. 화면에서 고치다가 이
 * 함정에 빠지기 쉬워서 여기서 막는다.
 */
function kindWarning(url: string, kind: string): string | null {
  if (kind !== 'direct') return null
  if (/serpent0|\.pls(\?|$)/i.test(url)) {
    return '이 주소는 부를 때마다 새로 서명돼요. stream_kind 를 pls 로 두지 않으면 몇 시간 뒤 403 이 나요.'
  }
  return null
}

export async function listChannelsAdmin(env: Env): Promise<Response> {
  const { results } = await env.DB.prepare(
    'SELECT * FROM hidden_channels ORDER BY sort_order, name',
  ).all<AdminRow>()
  return json({
    items: results.map((r) => ({
      ...r,
      enabled: r.enabled === 1,
      warning: kindWarning(r.stream_url, r.stream_kind),
    })),
  })
}

export async function patchChannelAdmin(env: Env, id: string, request: Request): Promise<Response> {
  const body = (await request.json().catch(() => null)) as Record<string, unknown> | null
  if (!body || typeof body !== 'object') return fail(400, 'bad_request', 'JSON 본문이 필요하다.')

  const unknown = Object.keys(body).filter((k) => !EDITABLE.has(k))
  if (unknown.length) return fail(400, 'bad_field', `고칠 수 없는 칸이다: ${unknown.join(', ')}`)

  const sets: string[] = []
  const binds: unknown[] = []
  for (const [k, v] of Object.entries(body)) {
    if (k === 'enabled') {
      sets.push('enabled = ?')
      binds.push(v ? 1 : 0)
    } else if (k === 'sort_order') {
      const n = Number(v)
      if (!Number.isFinite(n)) return fail(400, 'bad_value', 'sort_order 는 숫자다.')
      sets.push('sort_order = ?')
      binds.push(Math.trunc(n))
    } else if (k === 'stream_kind') {
      const s = String(v ?? '').trim()
      if (!KINDS.has(s)) return fail(400, 'bad_value', "stream_kind 는 direct 나 pls 다.")
      sets.push('stream_kind = ?')
      binds.push(s)
    } else if (k === 'stream_url') {
      const s = String(v ?? '').trim()
      if (!/^https?:\/\//i.test(s)) return fail(400, 'bad_value', 'stream_url 은 http(s) 주소다.')
      sets.push('stream_url = ?')
      binds.push(s.slice(0, 500))
    } else {
      const s = v == null || String(v).trim() === '' ? null : String(v).trim().slice(0, 300)
      sets.push(`${k} = ?`)
      binds.push(s)
    }
  }
  if (!sets.length) return fail(400, 'bad_request', '고칠 칸이 없다.')

  const before = await env.DB.prepare('SELECT * FROM hidden_channels WHERE id = ?')
    .bind(id).first<AdminRow>()
  if (!before) return fail(404, 'not_found', '그런 채널이 없다.')

  sets.push('updated_at = ?')
  binds.push(nowISO(), id)
  await env.DB.prepare(`UPDATE hidden_channels SET ${sets.join(', ')} WHERE id = ?`)
    .bind(...binds).run()

  const after = await env.DB.prepare('SELECT * FROM hidden_channels WHERE id = ?')
    .bind(id).first<AdminRow>()
  // 편성표 캐시는 채널 설정이 바뀌면 낡은 값이다. 지워서 다음 요청에 다시 받게 한다.
  if (after && (after.schedule_kind !== before.schedule_kind || after.schedule_url !== before.schedule_url)) {
    await env.DB.prepare('DELETE FROM hidden_now_cache WHERE channel_id = ?').bind(id).run()
  }
  return json({
    ok: true,
    item: after ? { ...after, enabled: after.enabled === 1, warning: kindWarning(after.stream_url, after.stream_kind) } : null,
  })
}

/**
 * 주소가 실제로 열리는지 본다. 고치고 나서 되는지는 앱을 켜 봐야 알았다.
 * pls 는 한 번 풀어 안에 든 주소까지 확인한다 — 겉만 200 이고 속이 죽은 경우가 있다.
 */
export async function probeChannelAdmin(env: Env, id: string): Promise<Response> {
  const row = await env.DB.prepare('SELECT stream_url, stream_kind FROM hidden_channels WHERE id = ?')
    .bind(id).first<{ stream_url: string; stream_kind: string }>()
  if (!row) return fail(404, 'not_found', '그런 채널이 없다.')

  const started = Date.now()

  try {
    const res = await fetch(row.stream_url, {
      headers: { 'user-agent': 'zeroplayer/2.0' },
      signal: AbortSignal.timeout(10_000),
    })
    const head = (await res.text()).slice(0, 200)
    return json({
      url: row.stream_url,
      kind: row.stream_kind,
      status: res.status,
      ms: Date.now() - started,
      head,
    })
  } catch (error) {
    return json({ url: row.stream_url, kind: row.stream_kind, error: String(error), ms: Date.now() - started })
  }
}
