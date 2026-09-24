import type { Env } from './types'
import { fail, json } from './lib/http'
import { getFacets, getStation, getStream, listStations, reportStation } from './routes/stations'
import { markSync, rebuildTags, syncAll, syncCountry } from './lib/sync'
import { checkStreamBatch } from './lib/streamCheck'
import { normalizePendingTags } from './lib/tags'

const PREFIX = '/zp/v1'

function requireAdmin(env: Env, request: Request): Response | null {
  const token = env.ADMIN_TOKEN
  if (!token) return fail(503, 'admin_disabled', '관리 토큰이 설정돼 있지 않다.')
  if (request.headers.get('x-zp-admin') !== token) return fail(401, 'unauthorized', '관리 토큰이 맞지 않는다.')
  return null
}

async function health(env: Env): Promise<Response> {
  const [stations, excluded, tagged, pending, jobs] = await env.DB.batch<Record<string, unknown>>([
    env.DB.prepare('SELECT COUNT(*) AS n FROM stations'),
    env.DB.prepare('SELECT COUNT(*) AS n FROM station_health WHERE excluded = 1'),
    env.DB.prepare('SELECT COUNT(DISTINCT station_id) AS n FROM station_tags'),
    env.DB.prepare('SELECT COUNT(*) AS n FROM tag_aliases WHERE normalized IS NULL'),
    env.DB.prepare('SELECT job, last_run_at, last_ok_at, ok, detail FROM sync_state ORDER BY job'),
  ])

  return json({
    ok: true,
    stations: (stations.results[0]?.n as number) ?? 0,
    excluded: (excluded.results[0]?.n as number) ?? 0,
    taggedStations: (tagged.results[0]?.n as number) ?? 0,
    pendingTagAliases: (pending.results[0]?.n as number) ?? 0,
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
        } else if (event.cron === '40 20 * * *') {
          await normalizePendingTags(env)
          await rebuildTags(env)
          await markSync(env, 'tag_normalize', true, '표준 태그 재계산 완료')
        }
      } catch (error) {
        console.error('배치 실패', event.cron, error)
        await markSync(env, `cron:${event.cron}`, false, String(error))
      }
    }
    ctx.waitUntil(run())
  },
}
