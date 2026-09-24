export interface Env {
  DB: D1Database
  AI: Ai
  ADMIN_TOKEN?: string
  /** Podcast Index 키. 없으면 iTunes Search 로 내려간다. */
  PI_KEY?: string
  PI_SECRET?: string
  SYNC_FULL_COUNTRIES: string
  SYNC_TOP_COUNTRIES: string
  SYNC_TOP_PER_COUNTRY: string
  STREAM_CHECK_BATCH: string
  /** APNs 인증 키(.p8) 본문. 시크릿으로 넣는다 */
  APNS_KEY?: string
  APNS_KEY_ID?: string
  APNS_TEAM_ID?: string
  /** 푸시를 받을 앱의 번들 ID */
  APNS_TOPIC?: string
  PODCAST_COUNTRIES: string
  PODCAST_FEEDS_PER_COUNTRY: string
  /** 추천 세트를 미리 만들어 둘 나라. 쉼표로 나눈다. 전 세계 세트는 항상 함께 만든다 */
  RECOMMEND_COUNTRIES?: string
}

export interface StationRow {
  id: string
  source: string
  name: string
  stream_url: string
  homepage: string | null
  favicon: string | null
  country_code: string | null
  language: string | null
  codec: string | null
  bitrate: number | null
  votes: number
  clicks: number
  is_hidden: number
  updated_at: string
}
