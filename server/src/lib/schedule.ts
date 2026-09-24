/**
 * 알람이 다음에 울릴 시각을 계산한다.
 *
 * 사용자는 '평일 아침 7시' 를 자기 시계로 말한다. 서버는 그것을 UTC 한 시점으로 바꿔
 * `alarms.next_fire_at` 에 적어 둔다. 매분 도는 배치가 시간대 계산을 다시 하지 않도록
 * 미리 적어 두는 것이다.
 *
 * 서머타임이 있는 나라에서는 같은 '아침 7시' 가 계절마다 다른 UTC 시각이다. 그래서
 * 발송할 때마다 다음 시각을 새로 계산한다.
 */

/** 그 시점에 그 지역의 시계가 UTC 보다 얼마나 앞서 있는지(밀리초). */
function offsetMs(ts: number, timezone: string): number {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: timezone,
    hour12: false,
    year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', second: '2-digit',
  }).formatToParts(new Date(ts))

  const get = (type: string) => Number.parseInt(parts.find((p) => p.type === type)?.value ?? '0', 10)
  // 자정을 en-US 가 '24' 로 주는 경우가 있다.
  const hour = get('hour') % 24
  const asIfUTC = Date.UTC(get('year'), get('month') - 1, get('day'), hour, get('minute'), get('second'))
  return asIfUTC - ts
}

/** 그 지역의 벽시계 시각을 UTC 한 시점으로 되돌린다. */
function wallToUTC(
  y: number, m: number, d: number, hour: number, minute: number, timezone: string,
): number {
  const wall = Date.UTC(y, m - 1, d, hour, minute, 0)
  let ts = wall
  // 오프셋이 그 시점에 따라 달라지므로 두세 번 되짚으면 수렴한다(서머타임 경계 포함).
  for (let i = 0; i < 3; i++) {
    const next = wall - offsetMs(ts, timezone)
    if (next === ts) break
    ts = next
  }
  return ts
}

/** 그 지역의 지금 날짜. */
function localDate(ts: number, timezone: string): { y: number; m: number; d: number } {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: timezone, year: 'numeric', month: '2-digit', day: '2-digit',
  }).formatToParts(new Date(ts))
  const get = (type: string) => Number.parseInt(parts.find((p) => p.type === type)?.value ?? '0', 10)
  return { y: get('year'), m: get('month'), d: get('day') }
}

export function isValidTimezone(value: string): boolean {
  try {
    new Intl.DateTimeFormat('en-US', { timeZone: value })
    return true
  } catch {
    return false
  }
}

/** '2,3,4,5,6' → Set{2,3,4,5,6}. 1=일 … 7=토. */
export function parseWeekdays(raw: string): Set<number> {
  return new Set(
    raw.split(',')
      .map((v) => Number.parseInt(v.trim(), 10))
      .filter((n) => Number.isInteger(n) && n >= 1 && n <= 7),
  )
}

/**
 * `from` 이후 처음 울릴 시각(UTC 밀리초). 요일이 비어 있으면 가장 가까운 한 번만 울린다.
 * 반복 요일이 있는데 앞으로 8일 안에 하나도 없으면 null 을 준다(있을 수 없는 입력).
 */
export function nextFireAt(
  options: { hour: number; minute: number; weekdays: string; timezone: string },
  from: number = Date.now(),
): number | null {
  const { hour, minute, timezone } = options
  const days = parseWeekdays(options.weekdays)
  const base = localDate(from, timezone)

  for (let k = 0; k < 9; k++) {
    // 날짜를 더할 때는 UTC 달력으로 센다. 월말·윤년을 알아서 넘긴다.
    const cursor = new Date(Date.UTC(base.y, base.m - 1, base.d + k))
    const weekday = cursor.getUTCDay() + 1 // getUTCDay 는 0=일 이라 1 을 더한다
    if (days.size > 0 && !days.has(weekday)) continue

    const ts = wallToUTC(
      cursor.getUTCFullYear(), cursor.getUTCMonth() + 1, cursor.getUTCDate(),
      hour, minute, timezone,
    )
    if (ts > from) return ts
  }
  return null
}

export function nextFireISO(
  options: { hour: number; minute: number; weekdays: string; timezone: string },
  from: number = Date.now(),
): string | null {
  const ts = nextFireAt(options, from)
  return ts === null ? null : new Date(ts).toISOString()
}
