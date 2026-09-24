import type { Env } from '../types'

/**
 * APNs 로 알림 한 건을 보낸다.
 *
 * 인증은 인증서가 아니라 토큰 방식이다. 개발자 포털에서 받은 .p8 개인키로 ES256 JWT 를
 * 서명해 `authorization: bearer <jwt>` 에 넣는다. 이 JWT 는 한 시간 쓸 수 있어서
 * 같은 요청 안에서는 만들어 두고 돌려 쓴다.
 *
 * APNs 는 HTTP/2 만 받는다. 배포된 Worker 의 fetch() 는 되지만 로컬 `wrangler dev` 에서는
 * 협상이 안 돼 실패한다(`docs/03-proxy-api.md` 3.5). 발송 확인은 배포 환경에서 한다.
 */

const HOST = {
  prod: 'https://api.push.apple.com',
  sandbox: 'https://api.sandbox.push.apple.com',
} as const

export type PushEnv = keyof typeof HOST

export function hasAPNsKeys(env: Env): boolean {
  return Boolean(env.APNS_KEY && env.APNS_KEY_ID && env.APNS_TEAM_ID)
}

function b64url(bytes: ArrayBuffer | Uint8Array): string {
  const view = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes)
  let raw = ''
  for (const b of view) raw += String.fromCharCode(b)
  return btoa(raw).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

/** .p8 는 PKCS#8 개인키를 PEM 으로 감싼 것이다. 머리말과 줄바꿈을 걷어내고 바이트로 되돌린다. */
function pemToDer(pem: string): Uint8Array {
  const body = pem
    .replace(/-----BEGIN [^-]+-----/g, '')
    .replace(/-----END [^-]+-----/g, '')
    .replace(/\s+/g, '')
  const raw = atob(body)
  const out = new Uint8Array(raw.length)
  for (let i = 0; i < raw.length; i++) out[i] = raw.charCodeAt(i)
  return out
}

let cached: { token: string; at: number } | null = null

async function providerToken(env: Env): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  // 애플은 한 시간마다 새로 만들라고 한다. 조금 일찍(50분) 갈아 끼운다.
  if (cached && now - cached.at < 50 * 60) return cached.token

  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToDer(env.APNS_KEY as string),
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['sign'],
  )
  const header = b64url(new TextEncoder().encode(
    JSON.stringify({ alg: 'ES256', kid: env.APNS_KEY_ID }),
  ))
  const payload = b64url(new TextEncoder().encode(
    JSON.stringify({ iss: env.APNS_TEAM_ID, iat: now }),
  ))
  const signature = await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' },
    key,
    new TextEncoder().encode(`${header}.${payload}`),
  )
  const token = `${header}.${payload}.${b64url(signature)}`
  cached = { token, at: now }
  return token
}

export interface PushResult {
  ok: boolean
  status: number
  /** APNs 가 돌려준 사유. 'BadDeviceToken' 처럼 토큰을 지워야 하는 것이 있다. */
  reason: string | null
}

/** 토큰이 더는 쓸모없다는 뜻인지. 이러면 devices 에서 지운다. */
export function isDeadToken(result: PushResult): boolean {
  return result.status === 410
    || result.reason === 'BadDeviceToken'
    || result.reason === 'Unregistered'
    || result.reason === 'DeviceTokenNotForTopic'
}

export async function sendPush(
  env: Env,
  options: {
    deviceToken: string
    pushEnv: PushEnv
    payload: unknown
    /** 이 시각까지만 배달을 시도한다(유닉스 초). 알람은 지나면 의미가 없다. */
    expiration?: number
    collapseID?: string
  },
): Promise<PushResult> {
  if (!hasAPNsKeys(env)) return { ok: false, status: 0, reason: 'NoAPNsKey' }

  const jwt = await providerToken(env)
  const headers: Record<string, string> = {
    authorization: `bearer ${jwt}`,
    'apns-topic': env.APNS_TOPIC ?? 'com.zerolive.cloudRadioN',
    'apns-push-type': 'alert',
    'apns-priority': '10',
    'content-type': 'application/json',
  }
  if (options.expiration) headers['apns-expiration'] = String(options.expiration)
  if (options.collapseID) headers['apns-collapse-id'] = options.collapseID.slice(0, 64)

  const response = await fetch(`${HOST[options.pushEnv]}/3/device/${options.deviceToken}`, {
    method: 'POST',
    headers,
    body: JSON.stringify(options.payload),
    signal: AbortSignal.timeout(10_000),
  })

  if (response.status === 200) return { ok: true, status: 200, reason: null }

  let reason: string | null = null
  try {
    const body = (await response.json()) as { reason?: string }
    reason = body?.reason ?? null
  } catch {
    // 본문이 비어 있을 수 있다
  }
  return { ok: false, status: response.status, reason }
}
