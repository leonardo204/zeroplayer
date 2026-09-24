/** 앱이 받는 응답은 전부 JSON 이다. 오류도 같은 모양으로 돌려준다. */
export function json(body: unknown, init: ResponseInit = {}): Response {
  const headers = new Headers(init.headers)
  headers.set('content-type', 'application/json; charset=utf-8')
  if (!headers.has('cache-control')) headers.set('cache-control', 'no-store')
  return new Response(JSON.stringify(body), { ...init, headers })
}

export function fail(status: number, code: string, message: string): Response {
  return json({ error: { code, message } }, { status })
}

export function nowISO(): string {
  return new Date().toISOString()
}

/** 목록 응답의 커서. 지금은 오프셋 하나뿐이라 그대로 문자열로 쓴다. */
export function decodeCursor(raw: string | null): number {
  if (!raw) return 0
  const n = Number.parseInt(raw, 10)
  return Number.isFinite(n) && n > 0 ? n : 0
}

export function clampLimit(raw: string | null, fallback: number, max: number): number {
  const n = Number.parseInt(raw ?? '', 10)
  if (!Number.isFinite(n) || n <= 0) return fallback
  return Math.min(n, max)
}
