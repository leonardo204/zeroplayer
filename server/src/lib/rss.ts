/**
 * 팟캐스트 RSS 를 읽는다.
 *
 * Workers 에는 DOMParser 가 없어서 정규식으로 읽는다. 피드가 제각각이라
 * 한 항목이라도 못 읽으면 그 항목만 버리고 넘어간다 — 하나 때문에 목록 전체를
 * 잃는 쪽이 더 나쁘다.
 */

export interface ParsedEpisode {
  guid: string
  title: string
  audioURL: string
  durationSeconds: number | null
  publishedAt: string | null
  description: string | null
  artwork: string | null
}

export interface ParsedFeed {
  title: string | null
  author: string | null
  description: string | null
  artwork: string | null
  language: string | null
  categories: string[]
  episodes: ParsedEpisode[]
}

const ENTITIES: Record<string, string> = {
  amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: ' ', '#39': "'", '#34': '"',
}

function decode(raw: string): string {
  return raw
    .replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1')
    .replace(/&(#x?[0-9a-fA-F]+|[a-zA-Z]+);/g, (whole, name: string) => {
      if (ENTITIES[name]) return ENTITIES[name]
      if (name.startsWith('#x') || name.startsWith('#X')) {
        return String.fromCodePoint(Number.parseInt(name.slice(2), 16))
      }
      if (name.startsWith('#')) return String.fromCodePoint(Number.parseInt(name.slice(1), 10))
      return whole
    })
    .replace(/\s+/g, ' ')
    .trim()
}

/** 본문에서 태그를 걷어낸다. 설명에 HTML 이 들어 있는 피드가 많다. */
function plain(raw: string): string {
  return decode(raw.replace(/<[^>]*>/g, ' ')).slice(0, 1200)
}

function tag(xml: string, name: string): string | null {
  const match = xml.match(new RegExp(`<${name}(?:\\s[^>]*)?>([\\s\\S]*?)</${name}>`, 'i'))
  return match ? match[1] : null
}

function attr(xml: string, name: string, key: string): string | null {
  const open = xml.match(new RegExp(`<${name}\\s[^>]*>`, 'i'))
  if (!open) return null
  const found = open[0].match(new RegExp(`${key}\\s*=\\s*["']([^"']+)["']`, 'i'))
  return found ? decode(found[1]) : null
}

/** '00:36:26' · '36:26' · '2186' 세 가지가 모두 온다. */
export function parseDuration(raw: string | null): number | null {
  if (!raw) return null
  const text = raw.trim()
  if (!text) return null
  if (/^\d+(\.\d+)?$/.test(text)) {
    const seconds = Math.round(Number.parseFloat(text))
    return seconds > 0 ? seconds : null
  }
  const parts = text.split(':').map((p) => Number.parseInt(p, 10))
  if (parts.some((p) => !Number.isFinite(p))) return null
  const seconds = parts.reduce((acc, part) => acc * 60 + part, 0)
  return seconds > 0 ? seconds : null
}

function parseDate(raw: string | null): string | null {
  if (!raw) return null
  const at = new Date(decode(raw))
  return Number.isNaN(at.getTime()) ? null : at.toISOString()
}

export function parseFeed(xml: string, limit = 60): ParsedFeed {
  const firstItem = xml.search(/<item[\s>]/i)
  const header = firstItem > 0 ? xml.slice(0, firstItem) : xml

  const categories = [...header.matchAll(/<itunes:category\s[^>]*text\s*=\s*["']([^"']+)["']/gi)]
    .map((m) => decode(m[1]))
  const headerImage = attr(header, 'itunes:image', 'href') ?? tag(tag(header, 'image') ?? '', 'url')

  const episodes: ParsedEpisode[] = []
  for (const match of xml.matchAll(/<item[\s>][\s\S]*?<\/item>/gi)) {
    if (episodes.length >= limit) break
    const item = match[0]
    const audioURL = attr(item, 'enclosure', 'url')
    const title = tag(item, 'title') ?? tag(item, 'itunes:title')
    if (!audioURL || !title) continue

    const guid = decode(tag(item, 'guid') ?? '') || audioURL
    episodes.push({
      guid,
      title: decode(title),
      audioURL,
      durationSeconds: parseDuration(tag(item, 'itunes:duration')),
      publishedAt: parseDate(tag(item, 'pubDate')),
      description: (() => {
        const raw = tag(item, 'itunes:summary') ?? tag(item, 'description') ?? tag(item, 'content:encoded')
        const text = raw ? plain(raw) : ''
        return text.length ? text : null
      })(),
      artwork: attr(item, 'itunes:image', 'href'),
    })
  }

  return {
    title: (() => { const t = tag(header, 'title'); return t ? decode(t) : null })(),
    author: (() => { const a = tag(header, 'itunes:author') ?? tag(header, 'managingEditor'); return a ? decode(a) : null })(),
    description: (() => {
      const d = tag(header, 'itunes:summary') ?? tag(header, 'description')
      const text = d ? plain(d) : ''
      return text.length ? text : null
    })(),
    artwork: headerImage ? decode(headerImage) : null,
    language: (() => {
      const l = tag(header, 'language')
      return l ? decode(l).toLowerCase().slice(0, 5) : null
    })(),
    categories: [...new Set(categories)].slice(0, 6),
    episodes,
  }
}

export async function fetchFeed(feedURL: string, limit = 60): Promise<ParsedFeed> {
  const response = await fetch(feedURL, {
    headers: { 'user-agent': 'zeroplayer/2.0 (+https://zerolive.co.kr)', accept: 'application/rss+xml, application/xml, text/xml' },
    signal: AbortSignal.timeout(20_000),
    redirect: 'follow',
  })
  if (!response.ok) throw new Error(`${feedURL} → ${response.status}`)
  // 큰 피드는 1MB 만 읽는다. 최신 에피소드가 앞에 있어서 뒤를 잘라도 목록이 채워진다.
  const text = (await response.text()).slice(0, 1_000_000)
  return parseFeed(text, limit)
}
