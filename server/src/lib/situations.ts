/**
 * 1단 규칙. 상황·시각으로 후보를 좁힌다. LLM 을 부르지 않는다.
 *
 * 태그 값은 `station_tags` 에 실제로 들어 있는 표준 태그 45개에서 골랐다.
 * 분위기(`station_moods`)는 M4 에서 채웠고 순위를 미는 데만 쓴다 — 분위기가 비어 있는
 * 방송국이 남아 있어서, 분위기로 후보를 자르면 목록이 얇아진다.
 */

export type Situation = 'sleep' | 'commute' | 'study' | 'work' | 'wake'

export interface SituationRule {
  label: string
  /** 이 태그가 붙은 채널만 남긴다 */
  prefer: string[]
  /** 하나라도 붙어 있으면 뺀다 */
  exclude: string[]
  /** 이 분위기가 붙어 있으면 위로 올린다. 후보를 자르지는 않는다 */
  preferMoods: string[]
  /** 이 분위기가 붙어 있으면 아래로 내린다 */
  avoidMoods: string[]
  /** 규칙 설명. 응답의 reason 에 그대로 들어간다 */
  note: string
  /** 비트레이트가 높은 쪽을 먼저 보여줄지. 끊김이 곤란한 상황에만 켠다 */
  preferHighBitrate?: boolean
}

export const SITUATIONS: Record<Situation, SituationRule> = {
  sleep: {
    label: '취침',
    prefer: ['ambient', 'chillout', 'lounge', 'newage', 'classical', 'jazz', 'instrumental', 'soundtrack', 'blues', 'soul'],
    exclude: ['news', 'talk', 'sports', 'metal', 'punk', 'techno', 'comedy', 'religion', 'live'],
    preferMoods: ['calm', 'late-night'],
    avoidMoods: ['energetic', 'talky', 'morning'],
    note: '잔잔한 음악만 남기고 뉴스·토크는 뺐다',
  },
  commute: {
    label: '운전',
    prefer: ['news', 'talk', 'pop', 'rock', 'top40', 'dance', 'kpop', 'hiphop', 'culture', 'oldies'],
    exclude: ['ambient', 'newage', 'instrumental'],
    preferMoods: ['energetic', 'talky', 'morning'],
    avoidMoods: ['calm', 'late-night'],
    note: '말과 활기 있는 음악을 함께 두고 끊김이 적은 쪽을 앞에 놨다',
    preferHighBitrate: true,
  },
  study: {
    label: '공부',
    prefer: ['classical', 'instrumental', 'ambient', 'chillout', 'newage', 'jazz', 'lounge', 'soundtrack'],
    exclude: ['news', 'talk', 'sports', 'metal', 'punk', 'comedy', 'hiphop', 'religion', 'live'],
    preferMoods: ['focus', 'calm', 'background'],
    avoidMoods: ['talky', 'energetic'],
    note: '가사와 말이 적은 채널만 남겼다',
  },
  work: {
    label: '작업',
    prefer: ['chillout', 'electronic', 'house', 'lounge', 'techno', 'jazz', 'funk', 'soul', 'indie', 'pop'],
    exclude: ['news', 'talk', 'sports', 'religion'],
    preferMoods: ['background', 'focus'],
    avoidMoods: ['talky'],
    note: '배경으로 깔아 두기 좋은 쪽을 골랐다',
  },
  wake: {
    label: '기상',
    prefer: ['news', 'pop', 'top40', 'dance', 'kpop', 'jpop', 'culture', 'talk'],
    exclude: ['ambient', 'newage', 'metal', 'punk'],
    preferMoods: ['morning', 'energetic', 'talky'],
    avoidMoods: ['late-night', 'calm'],
    note: '아침에 정신이 드는 쪽으로 뉴스와 밝은 음악을 골랐다',
  },
}

export function isSituation(value: string | null): value is Situation {
  return value !== null && value in SITUATIONS
}

/** 시간대 여섯 구간. `docs/04-curation.md` 3번과 같다. */
export type Daypart = '06-09' | '09-12' | '12-18' | '18-22' | '22-02' | '02-06'

export function daypartOf(hour: number): Daypart {
  if (hour >= 6 && hour < 9) return '06-09'
  if (hour >= 9 && hour < 12) return '09-12'
  if (hour >= 12 && hour < 18) return '12-18'
  if (hour >= 18 && hour < 22) return '18-22'
  if (hour >= 22 || hour < 2) return '22-02'
  return '02-06'
}

/** 같은 상황이라도 시각에 따라 위로 올릴 태그가 다르다. 후보를 자르지는 않고 순서만 민다. */
const DAYPART_BOOST: Record<Daypart, string[]> = {
  '06-09': ['news', 'culture', 'top40'],
  '09-12': ['pop', 'classical', 'jazz'],
  '12-18': ['pop', 'rock', 'dance', 'electronic'],
  '18-22': ['jazz', 'soul', 'lounge', 'indie'],
  '22-02': ['ambient', 'chillout', 'lounge', 'newage', 'jazz'],
  '02-06': ['ambient', 'chillout', 'newage', 'classical'],
}

export function boostTags(daypart: Daypart, rule: SituationRule): string[] {
  const excluded = new Set(rule.exclude)
  return DAYPART_BOOST[daypart].filter((tag) => !excluded.has(tag))
}

/** `at` 파라미터에서 현지 시각과 요일을 꺼낸다. 오프셋이 붙어 있으면 그 오프셋을 그대로 쓴다. */
export function readLocalTime(raw: string | null): { hour: number; isWeekend: boolean; at: Date } {
  const fallback = new Date()
  if (!raw) {
    return { hour: fallback.getUTCHours(), isWeekend: [0, 6].includes(fallback.getUTCDay()), at: fallback }
  }

  // '2026-09-23T23:10' 의 앞부분이 사용자가 보고 있는 시계다. Date 로 바꾸면 UTC 로
  // 돌아가 버리니 문자열에서 직접 읽는다. 오프셋의 '+' 가 공백으로 풀려 Date 가
  // NaN 이 되는 경우도 있어서, Date 파싱보다 이 규칙을 먼저 본다.
  const local = raw.match(/^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})/)
  const parsed = new Date(raw)
  if (local) {
    const hour = Number.parseInt(local[4], 10)
    const day = new Date(Date.UTC(
      Number.parseInt(local[1], 10),
      Number.parseInt(local[2], 10) - 1,
      Number.parseInt(local[3], 10),
    )).getUTCDay()
    return {
      hour,
      isWeekend: [0, 6].includes(day),
      at: Number.isNaN(parsed.getTime()) ? fallback : parsed,
    }
  }

  if (Number.isNaN(parsed.getTime())) {
    return { hour: fallback.getUTCHours(), isWeekend: [0, 6].includes(fallback.getUTCDay()), at: fallback }
  }

  return { hour: parsed.getUTCHours(), isWeekend: [0, 6].includes(parsed.getUTCDay()), at: parsed }
}
