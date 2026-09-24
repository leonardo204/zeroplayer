import type { Env } from '../types'
import { episodesForTimer } from '../lib/podcasts'
import { clampLimit, fail, json } from '../lib/http'
import { fallbackArtwork } from '../lib/logos'
import { collectCandidates, ruleReason, toItem, type RecommendItem } from '../lib/candidates'
import { daypartOf, isSituation, readLocalTime, SITUATIONS } from '../lib/situations'
import { GLOBAL_COUNTRY, loadSet, recommendCountries } from '../lib/recommendSets'

/**
 * GET /zp/v1/recommend
 *
 * 1단 규칙으로 좁히고, 2단 LLM 이 밤에 만들어 둔 세트가 있으면 그것을 내준다.
 * 세트가 없거나 나라가 다르면 규칙 결과를 즉석에서 만든다 — LLM 을 요청마다 부르지 않는다.
 * 3단(내 기록으로 다시 정렬)은 앱이 기기에서 한다.
 */
/**
 * 타이머 길이에 맞는 에피소드. 타이머를 켜고 상황을 고른 사람에게만 붙인다.
 * 에피소드를 못 찾으면 빈 배열이라 방송국 목록만 나간다.
 */
async function timerEpisodes(
  env: Env,
  minutes: number,
  country: string | null,
  secureOnly: boolean,
  max: number,
): Promise<unknown[]> {
  if (minutes <= 0 || max <= 0) return []
  try {
    const rows = await episodesForTimer(env, minutes, country, max, secureOnly)
    return rows.map((row) => {
      const runtime = Math.round((row.duration_seconds ?? 0) / 60)
      return {
        kind: 'episode' as const,
        id: row.id,
        title: row.title,
        subtitle: row.podcast_title + ' · ' + runtime + '분',
        reason: '자동 종료 ' + minutes + '분에 맞는 ' + runtime + '분 에피소드다.',
        artworkURL: row.artwork ?? row.podcast_artwork,
        tags: [] as string[],
        moods: [] as string[],
        isSecure: row.audio_url.startsWith('https://'),
        durationSeconds: row.duration_seconds ?? 0,
      }
    })
  } catch (error) {
    console.error('타이머 에피소드 조회 실패', error)
    return []
  }
}

/**
 * 저장된 세트는 만들 때의 썸네일을 그대로 들고 있다. 방송사 로고 표를 고쳐도
 * 다음 배치가 돌기 전까지는 반영되지 않으므로, 내보낼 때 한 번 더 메운다.
 */
function withArtwork(item: RecommendItem): RecommendItem {
  if (item.artworkURL || item.kind !== 'station') return item
  const country = (item.subtitle || '').split(' · ')[0] || null
  return { ...item, artworkURL: fallbackArtwork(item.title, country) }
}

export async function getRecommendations(env: Env, url: URL): Promise<Response> {
  const situation = url.searchParams.get('situation')
  if (!isSituation(situation)) {
    return fail(400, 'bad_situation', 'situation 은 ' + Object.keys(SITUATIONS).join(', ') + ' 중 하나다.')
  }

  const rule = SITUATIONS[situation]
  const limit = clampLimit(url.searchParams.get('limit'), 20, 50)
  const country = url.searchParams.get('country')?.toUpperCase().trim() || null
  const secureOnly = url.searchParams.get('secure') === '1'
  const timerMinutes = Number.parseInt(url.searchParams.get('timer') ?? '0', 10) || 0
  const { hour, isWeekend, at } = readLocalTime(url.searchParams.get('at'))
  const daypart = daypartOf(hour)
  const dayType = isWeekend ? 'weekend' : 'weekday'

  const head = {
    situation,
    daypart,
    dayType,
    country,
    generatedAt: at.toISOString(),
  }

  // 세트는 HTTPS 스트림만 담는다. 평문 HTTP 까지 달라는 요청이면 규칙으로 직접 뽑는다.
  const setCountry = country && recommendCountries(env).includes(country) ? country : GLOBAL_COUNTRY
  if (secureOnly || country === null) {
    const stored = await loadSet(env, situation, dayType, daypart, setCountry)
    if (stored) {
      const episodes = await timerEpisodes(env, timerMinutes, country, secureOnly, 3)
      return json({
        ...head,
        source: stored.model && stored.model !== 'rule' ? 'llm' : 'rule',
        model: stored.model,
        builtAt: stored.createdAt,
        items: [...episodes, ...stored.items.map(withArtwork)].slice(0, limit),
      }, {
        // 타이머를 끼면 사람마다 값이 달라 엣지에 오래 남겨 두지 않는다.
        headers: { 'cache-control': timerMinutes > 0 ? 'public, max-age=300' : 'public, max-age=900' },
      })
    }
  }

  const candidates = await collectCandidates(env, { rule, daypart, country, limit, secureOnly })
  const episodes = await timerEpisodes(env, timerMinutes, country, secureOnly, 3)
  return json({
    ...head,
    source: 'rule',
    model: null,
    builtAt: null,
    items: [
      ...episodes,
      ...candidates.map((candidate) => toItem(candidate, ruleReason(candidate, rule))),
    ].slice(0, limit),
  }, { headers: { 'cache-control': 'public, max-age=300' } })
}
