/**
 * 썸네일이 없는 방송국을 방송사 로고로 메운다.
 *
 * radio-browser 의 favicon 칸은 절반 넘게 비어 있고, 채워져 있어도 16픽셀
 * 파비콘이거나 이미 지워진 주소인 경우가 많다. 이름에 방송사가 드러나는 것만
 * 손으로 모은 로고로 채운다. 여기에 없으면 앱이 이름 첫 글자로 타일을 그린다.
 *
 * 주소는 전부 방송사 자기 사이트의 공개 이미지이고 2026-09-24 에 응답을 확인했다.
 * 끊기면 이 표만 고친다.
 */

export const BROADCASTER_LOGOS: Record<string, string> = {
  kbs: 'https://res.static.kbs.co.kr/kbs_og.png',
  mbc: 'https://img.imbc.com/commons/2018/image/comm2018noti/meta_mbc.png',
  sbs: 'https://program-image.cloud.sbs.co.kr/og/2025/sbs_home.png',
  cbs: 'https://www.cbs.co.kr/img/og_image.png',
  tbs: 'https://tbs.seoul.kr/common/images/index/tbsLogo.jpg',
  ytn: 'https://radio.ytn.co.kr/img/comm/radio_sns_251212.png',
  cpbc: 'https://www.cpbc.co.kr/favicon.ico',
  arirang: 'https://www.arirang.com/favicon.ico',
}

/**
 * 이름에서 방송사를 가려낸다. 낱말 경계를 보기 때문에 'CBSN' 이나
 * 'Radio Tbsomething' 같은 이름이 끌려오지 않는다.
 */
const NAME_RULES: Array<{ key: string; re: RegExp }> = [
  { key: 'kbs', re: /(^|[^a-z])kbs([^a-z]|$)/i },
  { key: 'mbc', re: /(^|[^a-z])mbc([^a-z]|$)/i },
  { key: 'sbs', re: /(^|[^a-z])sbs([^a-z]|$)/i },
  { key: 'cpbc', re: /(^|[^a-z])cpbc([^a-z]|$)|가톨릭평화방송/i },
  { key: 'cbs', re: /(^|[^a-z])cbs([^a-z]|$)/i },
  { key: 'tbs', re: /(^|[^a-z])e?tbs([^a-z]|$)/i },
  { key: 'ytn', re: /(^|[^a-z])ytn([^a-z]|$)/i },
  { key: 'arirang', re: /arirang|아리랑/i },
]

/**
 * 썸네일이 비었을 때 쓸 주소. 한국 방송국에만 적용한다 —
 * 다른 나라에 같은 약칭을 쓰는 방송이 있어 엉뚱한 로고가 붙는 것을 막는다.
 */
export function fallbackArtwork(name: string, countryCode: string | null): string | null {
  if ((countryCode || '').toUpperCase() !== 'KR') return null
  for (const rule of NAME_RULES) {
    if (rule.re.test(name)) return BROADCASTER_LOGOS[rule.key] ?? null
  }
  return null
}

/**
 * favicon 이 쓸 만한 주소인지 보고, 평문 HTTP 는 HTTPS 로 올려 보낸다.
 *
 * 앱의 `AsyncImage` 는 `URLSession` 을 타기 때문에 ATS 가 평문 HTTP 를 막는다
 * (`NSAllowsArbitraryLoadsForMedia` 는 AVFoundation 이 여는 오디오에만 해당한다).
 * 그대로 두면 반드시 실패하므로 올려 본다 — 2026-09-24 실측으로 21건 중 18건이
 * HTTPS 로도 같은 그림을 준다. 나머지는 앱이 이름 타일로 대신 그린다.
 */
export function usableArtwork(raw: string | null | undefined): string | null {
  const v = (raw || '').trim()
  if (!v.startsWith('http')) return null
  return v.startsWith('http://') ? 'https://' + v.slice('http://'.length) : v
}

/** 목록·추천이 함께 쓰는 결정. 원본이 없으면 방송사 로고로 메운다. */
export function artworkFor(
  favicon: string | null | undefined,
  name: string,
  countryCode: string | null,
): string | null {
  return usableArtwork(favicon) ?? fallbackArtwork(name, countryCode)
}
