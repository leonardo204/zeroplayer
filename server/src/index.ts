import type { Env } from './types'
import { fail, json } from './lib/http'
import { getFacets, getStation, getStream, listStations, reportStation } from './routes/stations'
import { markSync, rebuildTags, syncAll, syncCountry } from './lib/sync'
import { checkStreamBatch } from './lib/streamCheck'
import { normalizePendingTags } from './lib/tags'
import {
  getEpisode,
  getEpisodeStream,
  getPodcast,
  listEpisodes,
  searchPodcasts,
  trendingPodcasts,
} from './routes/podcasts'
import { addFeedByURL, syncPodcasts } from './lib/podcasts'
import { hasKeys } from './lib/podcastIndex'
import { classifyPendingMoods, resetMoodsForRetagged } from './lib/moods'
import { buildSets } from './lib/recommendSets'
import { getRecommendations } from './routes/recommend'

const PREFIX = '/zp/v1'

function requireAdmin(env: Env, request: Request): Response | null {
  const token = env.ADMIN_TOKEN
  if (!token) return fail(503, 'admin_disabled', '관리 토큰이 설정돼 있지 않다.')
  if (request.headers.get('x-zp-admin') !== token) return fail(401, 'unauthorized', '관리 토큰이 맞지 않는다.')
  return null
}

async function health(env: Env): Promise<Response> {
  const [stations, excluded, tagged, pending, moodPending, sets, podcasts, episodes, jobs] = await env.DB.batch<Record<string, unknown>>([
    env.DB.prepare('SELECT COUNT(*) AS n FROM stations'),
    env.DB.prepare('SELECT COUNT(*) AS n FROM station_health WHERE excluded = 1'),
    env.DB.prepare('SELECT COUNT(DISTINCT station_id) AS n FROM station_tags'),
    env.DB.prepare('SELECT COUNT(*) AS n FROM tag_aliases WHERE normalized IS NULL'),
    env.DB.prepare('SELECT COUNT(*) AS n FROM stations WHERE moods_at IS NULL'),
    env.DB.prepare('SELECT COUNT(*) AS n FROM recommendation_sets'),
    env.DB.prepare('SELECT COUNT(*) AS n FROM podcasts'),
    env.DB.prepare('SELECT COUNT(*) AS n FROM episodes'),
    env.DB.prepare('SELECT job, last_run_at, last_ok_at, ok, detail FROM sync_state ORDER BY job'),
  ])

  return json({
    ok: true,
    stations: (stations.results[0]?.n as number) ?? 0,
    excluded: (excluded.results[0]?.n as number) ?? 0,
    taggedStations: (tagged.results[0]?.n as number) ?? 0,
    pendingTagAliases: (pending.results[0]?.n as number) ?? 0,
    pendingMoodStations: (moodPending.results[0]?.n as number) ?? 0,
    recommendationSets: (sets.results[0]?.n as number) ?? 0,
    podcasts: (podcasts.results[0]?.n as number) ?? 0,
    episodes: (episodes.results[0]?.n as number) ?? 0,
    podcastIndexKeys: hasKeys(env),
    jobs: jobs.results,
  })
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url)
    if (!url.pathname.startsWith(PREFIX)) return fail(404, 'not_found', '없는 경로다.')
    const path = url.pathname.slice(PREFIX.length) || '/'
    const method = request.method.toUpperCase()

    try {
      if (method === 'GET' && path === '/health') return await health(env)
      if (method === 'GET' && path === '/recommend') return await getRecommendations(env, url)
      if (method === 'GET' && path === '/stations') return await listStations(env, url)
      if (method === 'GET' && path === '/stations/facets') return await getFacets(env)

      const streamMatch = path.match(/^\/stations\/([^/]+)\/stream$/)
      if (method === 'GET' && streamMatch) return await getStream(env, decodeURIComponent(streamMatch[1]))

      const reportMatch = path.match(/^\/stations\/([^/]+)\/report$/)
      if (method === 'POST' && reportMatch) {
        return await reportStation(env, decodeURIComponent(reportMatch[1]), request)
      }

      const detailMatch = path.match(/^\/stations\/([^/]+)$/)
      if (method === 'GET' && detailMatch) return await getStation(env, decodeURIComponent(detailMatch[1]))

      if (method === 'GET' && path === '/podcasts/search') return await searchPodcasts(env, url)
      if (method === 'GET' && path === '/podcasts/trending') return await trendingPodcasts(env, url)

      const episodesMatch = path.match(/^\/podcasts\/([^/]+)\/episodes$/)
      if (method === 'GET' && episodesMatch) {
        return await listEpisodes(env, decodeURIComponent(episodesMatch[1]), url)
      }

      const podcastMatch = path.match(/^\/podcasts\/([^/]+)$/)
      if (method === 'GET' && podcastMatch) return await getPodcast(env, decodeURIComponent(podcastMatch[1]))

      const episodeStreamMatch = path.match(/^\/episodes\/([^/]+)\/stream$/)
      if (method === 'GET' && episodeStreamMatch) {
        return await getEpisodeStream(env, decodeURIComponent(episodeStreamMatch[1]))
      }

      const episodeMatch = path.match(/^\/episodes\/([^/]+)$/)
      if (method === 'GET' && episodeMatch) return await getEpisode(env, decodeURIComponent(episodeMatch[1]))

      if (path.startsWith('/admin/')) {
        const denied = requireAdmin(env, request)
        if (denied) return denied
        if (method === 'POST' && path === '/admin/sync') {
          const country = url.searchParams.get('country')
          if (country) {
            const limit = Number.parseInt(url.searchParams.get('limit') ?? '0', 10) || 0
            const prune = url.searchParams.get('prune') === '1'
            return json(await syncCountry(env, country.toUpperCase(), limit, prune))
          }
          return json({ results: await syncAll(env) })
        }
        if (method === 'POST' && path === '/admin/tags/normalize') {
          const batches = Number.parseInt(url.searchParams.get('batches') ?? '6', 10) || 6
          const result = await normalizePendingTags(env, batches)
          const touched = await rebuildTags(env)
          return json({ ...result, rebuilt: touched })
        }
        if (method === 'POST' && path === '/admin/moods/classify') {
          const batches = Number.parseInt(url.searchParams.get('batches') ?? '6', 10) || 6
          return json(await classifyPendingMoods(env, batches))
        }
        if (method === 'POST' && path === '/admin/recommend/build') {
          const maxSets = Number.parseInt(url.searchParams.get('sets') ?? '8', 10) || 8
          const countries = url.searchParams.get('countries')?.split(',').map((c) => c.trim().toUpperCase()).filter(Boolean)
          const force = url.searchParams.get('force') === '1'
          return json(await buildSets(env, { maxSets, countries, force }))
        }
        // 임시 확인용. 워커에서 특정 주소가 열리는지 본다.
        if (method === 'GET' && path === '/admin/probe') {
          const target = url.searchParams.get('url') ?? ''
          const started = Date.now()
          try {
            const response = await fetch(target, {
              headers: { 'user-agent': 'zeroplayer/2.0', accept: 'application/json' },
              signal: AbortSignal.timeout(15_000),
            })
            const body = (await response.text()).slice(0, 300)
            return json({ target, status: response.status, ms: Date.now() - started, body })
          } catch (error) {
            return json({ target, error: String(error), ms: Date.now() - started })
          }
        }
        // 피드 주소로 팟캐스트를 직접 등록한다. iTunes 검색이 막혀 있어 지금은 이게 주 경로다.
        if (method === 'POST' && path === '/admin/podcasts/add') {
          const feed = url.searchParams.get('feed')
          if (!feed) return fail(400, 'bad_request', 'feed 에 RSS 주소를 넣는다.')
          try {
            const result = await addFeedByURL(env, feed, {
              feedId: url.searchParams.get('id') ?? undefined,
              country: url.searchParams.get('country')?.toUpperCase() ?? null,
              source: url.searchParams.get('source') ?? 'manual',
            })
            return json(result)
          } catch (error) {
            // 피드가 죽었거나 RSS 가 아닌 경우다. 서버 잘못과 구분해서 돌려준다.
            return fail(502, 'feed_error', String(error))
          }
        }
        if (method === 'POST' && path === '/admin/podcasts/sync') {
          const feeds = Number.parseInt(url.searchParams.get('feeds') ?? env.PODCAST_FEEDS_PER_COUNTRY, 10) || 30
          const countries = (url.searchParams.get('country') ?? env.PODCAST_COUNTRIES)
            .split(',').map((c) => c.trim().toUpperCase()).filter(Boolean)
          const results = []
          for (const country of countries) results.push(await syncPodcasts(env, country, feeds))
          return json({ results })
        }
        if (method === 'POST' && path === '/admin/streams/check') {
          const size = Number.parseInt(url.searchParams.get('size') ?? env.STREAM_CHECK_BATCH, 10) || 150
          return json(await checkStreamBatch(env, size))
        }
      }

      return fail(404, 'not_found', '없는 경로다.')
    } catch (error) {
      console.error('요청 처리 실패', url.pathname, error)
      return fail(500, 'internal', '서버에서 처리하지 못했다.')
    }
  },

  async scheduled(event: ScheduledController, env: Env, ctx: ExecutionContext): Promise<void> {
    const run = async () => {
      try {
        if (event.cron === '0 */6 * * *') {
          await syncAll(env)
        } else if (event.cron === '17 * * * *') {
          const size = Number.parseInt(env.STREAM_CHECK_BATCH, 10) || 150
          await checkStreamBatch(env, size)
        } else if (event.cron === '10 18 * * *') {
          const feeds = Number.parseInt(env.PODCAST_FEEDS_PER_COUNTRY, 10) || 30
          const countries = env.PODCAST_COUNTRIES.split(',').map((c) => c.trim().toUpperCase()).filter(Boolean)
          let total = 0
          for (const country of countries) total += (await syncPodcasts(env, country, feeds)).episodes
          await markSync(env, 'podcast_sync', true, '에피소드 ' + total + '편')
        } else if (event.cron === '40 20 * * *') {
          await normalizePendingTags(env)
          await rebuildTags(env)
          await resetMoodsForRetagged(env)
          const moods = await classifyPendingMoods(env, 6)
          await markSync(env, 'tag_normalize', true,
            `표준 태그 재계산 · 분위기 규칙 ${moods.byRule}건 · 모델 ${moods.decided}건`)
        } else if (event.cron === '0 19 * * *') {
          // 04:00 KST. 한 번에 다 만들지 않고 남은 것은 다음 날로 넘긴다.
          const result = await buildSets(env, { maxSets: 24 })
          await markSync(env, 'recommend_build', true,
            `세트 ${result.built.length}건 생성 · 남음 ${result.remaining}`)
        }
      } catch (error) {
        console.error('배치 실패', event.cron, error)
        await markSync(env, `cron:${event.cron}`, false, String(error))
      }
    }
    ctx.waitUntil(run())
  },
}
