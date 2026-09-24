import type { Env } from '../types'
import { nowISO } from './http'
import { markSync } from './sync'

/**
 * 인터넷 라디오는 조용히 죽는다. 오래 안 본 것부터 한 묶음씩 확인한다.
 * 오디오를 받아 보는 것이 아니라 응답 머리와 content-type 만 본다.
 */
/**
 * Cloudflare 안에서는 IP 주소로 직접 나가는 요청이 막힌다(1ms 만에 403 이 온다).
 * 그런 주소는 서버가 살았는지 알 수 없으므로 판정하지 않고 넘긴다 —
 * 이 방송국들의 생사는 앱이 보내는 신고로만 가른다.
 */
function isAddressLiteral(raw: string): boolean {
  try {
    const host = new URL(raw).hostname
    if (host.startsWith('[')) return true                    // IPv6
    return /^\d{1,3}(\.\d{1,3}){3}$/.test(host)
  } catch {
    return false
  }
}

async function probe(url: string): Promise<boolean> {
  try {
    const res = await fetch(url, {
      method: 'GET',
      headers: { 'user-agent': 'zeroplayer/2.0.0', range: 'bytes=0-1', icy: '1' },
      redirect: 'follow',
      signal: AbortSignal.timeout(8000),
    })
    if (!res.ok && res.status !== 206) {
      await res.body?.cancel()
      return false
    }
    const type = (res.headers.get('content-type') || '').toLowerCase()
    await res.body?.cancel()
    if (!type) return true // 일부 아이스캐스트 서버는 헤더를 비워 보낸다
    return type.includes('audio')
      || type.includes('video')            // 일부 서버가 mp3 를 video/ 로 준다
      || type.includes('mpegurl')          // HLS
      || type.includes('octet-stream')
      || type.includes('ogg')
  } catch {
    return false
  }
}

export interface CheckResult { checked: number; ok: number; skipped: number; excluded: number }

export async function checkStreamBatch(env: Env, size: number): Promise<CheckResult> {
  const { results } = await env.DB.prepare(`
    SELECT s.id AS id, s.stream_url AS url
    FROM stations s
    JOIN station_health h ON h.station_id = s.id
    ORDER BY h.last_checked_at IS NOT NULL, h.last_checked_at ASC
    LIMIT ?
  `).bind(size).all<{ id: string; url: string }>()
  if (!results.length) return { checked: 0, ok: 0, skipped: 0, excluded: 0 }

  const skipped = results.filter((row) => isAddressLiteral(row.url))
  const targets = results.filter((row) => !isAddressLiteral(row.url))

  const verdicts: Array<{ id: string; alive: boolean }> = []
  const concurrency = 12
  for (let i = 0; i < targets.length; i += concurrency) {
    const slice = targets.slice(i, i + concurrency)
    const alive = await Promise.all(slice.map((row) => probe(row.url)))
    slice.forEach((row, idx) => verdicts.push({ id: row.id, alive: alive[idx] }))
  }

  const at = nowISO()
  const okStmt = env.DB.prepare(`
    UPDATE station_health
    SET last_ok_at = ?, last_checked_at = ?, fail_streak = 0, excluded = 0
    WHERE station_id = ?
  `)
  const failStmt = env.DB.prepare(`
    UPDATE station_health
    SET last_fail_at = ?, last_checked_at = ?, fail_streak = fail_streak + 1,
        excluded = CASE WHEN fail_streak + 1 >= 3 THEN 1 ELSE excluded END
    WHERE station_id = ?
  `)
  const skipStmt = env.DB.prepare(
    'UPDATE station_health SET last_checked_at = ? WHERE station_id = ?',
  )
  const statements = [
    ...verdicts.map((v) => (v.alive ? okStmt.bind(at, at, v.id) : failStmt.bind(at, at, v.id))),
    ...skipped.map((row) => skipStmt.bind(at, row.id)),
  ]
  for (let i = 0; i < statements.length; i += 60) {
    await env.DB.batch(statements.slice(i, i + 60))
  }

  const okCount = verdicts.filter((v) => v.alive).length
  const excluded = await env.DB.prepare(
    'SELECT COUNT(*) AS n FROM station_health WHERE excluded = 1',
  ).first<{ n: number }>()
  await markSync(env, 'stream_check', true, `점검 ${verdicts.length} · 정상 ${okCount} · 보류 ${skipped.length}`)

  return { checked: verdicts.length, ok: okCount, skipped: skipped.length, excluded: excluded?.n ?? 0 }
}
