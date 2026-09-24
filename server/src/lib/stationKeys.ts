/**
 * 방송국 줄에서 계산해 두는 값 두 가지.
 *
 * 둘 다 동기화할 때 한 번 정하고 `stations` 에 적어 둔다. 조회할 때마다
 * 문자열을 만지면 3,000줄을 매번 훑게 된다.
 */

/**
 * 몇 시간이면 만료되는 서명이 붙은 주소인지.
 *
 * radio-browser 에는 누군가의 브라우저에서 한 번 긁힌 주소가 그대로 올라와 있다.
 * KBS 는 CloudFront 서명(`Policy`·`Signature`), SBS 는 `token`, MBC 는 `_lsu_sa_`
 * 를 붙이는데 전부 하루 안쪽에 만료돼 403 이 된다. 등록된 날에는 살아 있으니
 * 스트림 생사 점검으로는 걸러지지 않는다 — 주소 모양으로 가려야 한다.
 *
 * 이 방송들은 히든 채널 표에 `.pls` 로 들어 있고, 거기서는 재생 직전에 새
 * 서명을 받아 오므로 멀쩡히 재생된다.
 */
export function isExpiringSignedURL(raw: string): boolean {
  let query = ''
  try {
    query = new URL(raw).search.toLowerCase()
  } catch {
    return false
  }
  if (!query) return false
  if (query.includes('policy=') && query.includes('signature=')) return true
  if (query.includes('key-pair-id=')) return true
  if (query.includes('_lsu_sa_=')) return true
  // SBS 는 JWT 를 token 으로 붙인다. 짧은 숫자 토큰까지 막지 않도록 머리를 본다.
  if (/[?&]token=eyj/.test(query)) return true
  if (/[?&]hdnts?=/.test(query)) return true      // Akamai
  if (/[?&]wowzatokenendtime=/.test(query)) return true
  return false
}

/**
 * 이름에서 떼어 낼 말. 같은 방송을 코덱만 바꿔 여러 줄로 올린 것을 하나로 본다.
 *
 * 코덱과 비트레이트만 넣는다. 'no pub'(광고 없음)·'hifi'·'original' 처럼 내용이
 * 갈리는 말은 남겨 둔다 — 'FIP' 와 'FIP (no pub)' 은 다른 방송이고, 합쳐 버리면
 * 사용자가 찾던 쪽이 목록에서 사라진다.
 */
const CODEC_WORDS = new Set([
  'mp3', 'aac', 'aacp', 'aac+', 'he-aac', 'ogg', 'vorbis', 'opus', 'flac',
  'hls', 'm3u', 'm3u8', 'pls', 'mpeg', 'mp2', 'wma', 'stream', 'streaming',
  'kbps', 'kbit', 'kb',
])

/**
 * 중복을 묶는 열쇠. `나라|정규화한 이름` 이다.
 *
 * 'Listen.moe Kpop' 과 'Listen.moe Kpop (MP3)' 는 코덱만 다른 같은 방송이고,
 * 'KBS Classic FM' 은 올린 사람만 다른 줄이 열네 개다. 목록에서는 한 줄만 보여준다.
 *
 * 나라를 열쇠에 넣는 이유는 'Radio 1' 처럼 흔한 이름이 여러 나라에 따로
 * 있기 때문이다. 이름만으로 묶으면 남의 나라 방송이 사라진다.
 *
 * 이름이 통째로 지워지면(주소만 적어 둔 줄 등) 묶지 않고 자기 자신만 남긴다.
 */
export function dedupeKey(name: string, countryCode: string | null, id: string): string {
  const base = (name || '')
    // 이름 앞에 붙은 짧은 괄호는 올린 사람 표기다('(BSOD) KBS Classic FM').
    // 뒤에 붙은 괄호는 품질이나 편성 차이라 그대로 둔다('FIP (no pub)').
    .replace(/^\s*[([][^)\]]{1,12}[)\]]\s*/, ' ')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/\d+\s*(k|kb|kbps|kbit\/s)\b/g, ' ')   // 128k, 192 kbps
    .replace(/[^\p{L}\p{N}]+/gu, ' ')
    .trim()

  const words = base.split(' ').filter((w) => w && !CODEC_WORDS.has(w))
  const key = words.join('')
  if (!key) return `id:${id}`
  return `${(countryCode || '--').toUpperCase()}|${key}`
}

/**
 * 이미 들어 있는 줄의 `dedupe_key` 를 다시 계산해 넣는다.
 *
 * 정규화 규칙을 고쳤을 때와 이 값이 생기기 전에 받아 둔 줄을 채울 때 쓴다.
 * 동기화는 새로 받은 줄만 건드리므로 옛 줄은 이 경로로만 채워진다.
 */
export async function rekeyStations(env: import('../types').Env): Promise<{ scanned: number; changed: number }> {
  const { results } = await env.DB.prepare(
    'SELECT id, name, country_code, stream_url, clicks, votes, dedupe_key, stream_signed, is_primary FROM stations',
  ).all<{
    id: string
    name: string
    country_code: string | null
    stream_url: string
    clicks: number | null
    votes: number | null
    dedupe_key: string | null
    stream_signed: number
    is_primary: number
  }>()

  // 1단계. 줄마다 열쇠와 서명 여부를 정하고 묶음별로 모은다.
  const groups = new Map<string, Array<{ id: string; score: number }>>()
  const keyed = results.map((row) => {
    const key = dedupeKey(row.name, row.country_code, row.id)
    const signed = isExpiringSignedURL(row.stream_url) ? 1 : 0
    // 대표는 재생되는 것 먼저, 그다음 인기순이다.
    const score = (signed ? 0 : 4_000_000_000)
      + (row.stream_url.startsWith('https://') ? 2_000_000_000 : 0)
      + (row.clicks ?? 0) * 1000 + (row.votes ?? 0)
    const list = groups.get(key) ?? []
    list.push({ id: row.id, score })
    groups.set(key, list)
    return { row, key, signed }
  })

  // 2단계. 묶음마다 점수가 가장 높은 줄 하나만 대표로 둔다.
  const primaries = new Set<string>()
  for (const list of groups.values()) {
    let best = list[0]
    for (const item of list) {
      if (item.score > best.score || (item.score === best.score && item.id < best.id)) best = item
    }
    primaries.add(best.id)
  }

  const stmt = env.DB.prepare(
    'UPDATE stations SET dedupe_key = ?, stream_signed = ?, is_primary = ? WHERE id = ?',
  )
  const changes: D1PreparedStatement[] = []
  for (const { row, key, signed } of keyed) {
    const primary = primaries.has(row.id) ? 1 : 0
    if (key === row.dedupe_key && signed === row.stream_signed && primary === row.is_primary) continue
    changes.push(stmt.bind(key, signed, primary, row.id))
  }
  for (let i = 0; i < changes.length; i += 80) {
    await env.DB.batch(changes.slice(i, i + 80))
  }
  return { scanned: results.length, changed: changes.length }
}
