export interface Env {
  DB: D1Database
  AI: Ai
  ADMIN_TOKEN?: string
  SYNC_FULL_COUNTRIES: string
  SYNC_TOP_COUNTRIES: string
  SYNC_TOP_PER_COUNTRY: string
  STREAM_CHECK_BATCH: string
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
