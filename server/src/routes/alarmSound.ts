// 쓰지 않는다 — 배포에 올리지 않은 채 남겨 둔 것이다.
//
// 방송 앞부분을 알람음으로 쓰는 길은 실기기에서 재 본 뒤 접었다. 커스텀 알람음은
// 한 번 울리고 끝나고, +14dB 로 눌러 키워도 시스템 기본 알람음보다 작게 들린다.
// 깨우는 소리는 기본음으로 두고 방송은 알람 화면의 단추를 누른 뒤부터 낸다
// (`docs/10-alarmkit.md` 10.3). 그래서 `src/index.ts` 에 경로를 걸지 않았다.
//
// 다시 쓸 일이 생기면 `index.ts` 에 아래 두 줄을 넣는다. 다만 이 경로는 요청 하나에
// 방송 서버로 나가는 요청이 한 번 붙어서, 공개로 열어 두면 남이 우리 Worker 를
// 중계기로 쓸 수 있다. 여는 김에 설치 ID 확인이나 상한을 함께 둔다.
//
//   const alarmSoundMatch = path.match(/^\/stations\/([^/]+)\/alarm-sound$/)
//   if (method === 'GET' && alarmSoundMatch) {
//     return await getAlarmSound(env, decodeURIComponent(alarmSoundMatch[1]), url)
//   }

import { fail } from '../lib/http'
import type { Env } from '../types'

/// 알람음으로 쓸 방송 앞부분을 잘라 내려준다.
///
/// AlarmKit 과 UNNotificationSound 는 알람음 파일을 **발화 시점에** 읽는다.
/// 그래서 앱이 돌 때마다 이 경로로 최신 조각을 받아 `Library/Sounds` 에 덮어쓰면
/// 다음 알람이 그 소리로 울린다(실기기 확인, docs/10-alarmkit.md).
///
/// 길이 한도가 30초라 29초까지만 준다. 넘기면 시스템이 기본 알람음으로 바꿔 버린다.
///
/// **아직 배포하지 않았다.** `wrangler dev --remote` 로만 시험했다.
/// 폰이 이 조각을 받아 링형 PCM WAV 로 바꿔야 소리가 난다. MP3 를 그대로 알람음으로
/// 넣으면 알람 화면은 뜨는데 소리가 안 난다.
/// HLS 방송은 바이트를 잘라도 재생되지 않아 이 경로로 못 받는다.

/** 알람음 최대 길이. 30초를 넘기면 시스템이 기본음으로 바꾼다. */
const MAX_SECONDS = 29
const DEFAULT_SECONDS = 25
/** 업스트림에서 기다릴 최대 시간. 이걸 넘기면 받은 만큼만 준다. */
const FETCH_BUDGET_MS = 20_000
/** 아무리 비트레이트가 높아도 이 이상은 받지 않는다. */
const MAX_BYTES = 1_200_000

/** 바이트를 그대로 잘라도 되는 코덱. 프레임이 이어 붙는 형식이라야 한다. */
const CUTTABLE = new Set(['mp3', 'mpeg', 'aac', 'aacp', 'aac+'])

interface Row {
  url: string
  codec: string | null
  bitrate: number | null
  name: string
}

export async function getAlarmSound(env: Env, id: string, url: URL): Promise<Response> {
  const row = await env.DB.prepare(`
    SELECT stream_url AS url, codec, bitrate, name
    FROM stations
    WHERE id = ? AND is_hidden = 0 AND stream_signed = 0
  `).bind(id).first<Row>()
  if (!row) return fail(404, 'not_found', '그런 방송국이 없다.')

  const codec = (row.codec ?? '').toLowerCase()
  if (!CUTTABLE.has(codec)) {
    // HLS·OGG 는 앞부분을 잘라도 재생 가능한 파일이 되지 않는다.
    return fail(415, 'codec_not_cuttable', `${codec || '알 수 없는'} 코덱은 알람음으로 자를 수 없다.`)
  }

  const seconds = clampSeconds(url.searchParams.get('seconds'))
  // 비트레이트를 모르면 128kbps 로 본다. 모자라면 예산 안에서 더 받는다.
  const kbps = row.bitrate && row.bitrate > 0 ? row.bitrate : 128
  const want = Math.min(MAX_BYTES, Math.ceil((kbps * 1000 / 8) * seconds))

  const started = Date.now()
  let upstream: Response
  try {
    upstream = await fetch(row.url, {
      headers: { 'user-agent': 'zeroplayer/2.0', 'icy-metadata': '0' },
      signal: AbortSignal.timeout(FETCH_BUDGET_MS),
    })
  } catch (error) {
    return fail(502, 'upstream_failed', `방송에 붙지 못했다: ${String(error)}`)
  }
  if (!upstream.ok || !upstream.body) {
    return fail(502, 'upstream_failed', `방송이 ${upstream.status} 를 돌려줬다.`)
  }

  const chunks: Uint8Array[] = []
  let total = 0
  const reader = upstream.body.getReader()
  try {
    while (total < want && Date.now() - started < FETCH_BUDGET_MS) {
      const { done, value } = await reader.read()
      if (done) break
      if (!value) continue
      chunks.push(value)
      total += value.byteLength
    }
  } catch {
    // 예산이 다 되어 abort 가 걸린 경우다. 받은 만큼으로 계속 간다.
  } finally {
    // 더 받을 필요가 없으니 업스트림을 끊는다. 안 끊으면 계속 흘러 들어온다.
    await reader.cancel().catch(() => {})
  }

  if (total < 8_000) {
    return fail(502, 'too_short', `받은 것이 ${total} 바이트뿐이다.`)
  }

  const body = new Uint8Array(total)
  let offset = 0
  for (const chunk of chunks) {
    body.set(chunk, offset)
    offset += chunk.byteLength
  }

  const contentType = codec === 'mp3' || codec === 'mpeg' ? 'audio/mpeg' : 'audio/aac'
  return new Response(body, {
    headers: {
      'content-type': contentType,
      'content-length': String(total),
      // 앱이 파일 이름을 정할 때 쓴다. 확장자가 형식과 맞아야 한다.
      'x-zp-codec': codec,
      'x-zp-seconds': String(seconds),
      // 헤더에는 ASCII 만 넣을 수 있어 이름은 퍼센트 인코딩해 준다.
      'x-zp-station': encodeURIComponent(row.name),
      'x-zp-elapsed-ms': String(Date.now() - started),
      // 같은 방송을 여러 기기가 받을 수 있으니 짧게 캐시한다.
      'cache-control': 'public, max-age=300',
    },
  })
}

function clampSeconds(raw: string | null): number {
  const n = Number.parseInt(raw ?? '', 10)
  if (!Number.isFinite(n) || n <= 0) return DEFAULT_SECONDS
  return Math.min(n, MAX_SECONDS)
}
