-- M5. 팟캐스트. Podcast Index 키가 없어도 iTunes Search·애플 인기 목록으로 채운다.

CREATE TABLE podcasts (
  feed_id       TEXT PRIMARY KEY,      -- 'pi:<id>'(Podcast Index) 또는 'it:<collectionId>'(iTunes)
  source        TEXT NOT NULL,         -- 'podcast_index' | 'itunes'
  title         TEXT NOT NULL,
  author        TEXT,
  feed_url      TEXT NOT NULL,
  artwork       TEXT,
  language      TEXT,
  country       TEXT,
  categories    TEXT,                  -- JSON 배열
  description   TEXT,
  episode_count INTEGER DEFAULT 0,
  updated_at    TEXT NOT NULL,
  fetched_at    TEXT NOT NULL
);

-- RSS 에서 읽은 에피소드. audio_url 은 앱에 목록으로 내보내지 않는다 —
-- 방송국과 같게 재생 직전에 /episodes/{id}/stream 으로만 준다.
CREATE TABLE episodes (
  id               TEXT PRIMARY KEY,   -- '<feed_id>:<guid 해시>'
  feed_id          TEXT NOT NULL REFERENCES podcasts(feed_id) ON DELETE CASCADE,
  title            TEXT NOT NULL,
  audio_url        TEXT NOT NULL,
  duration_seconds INTEGER,
  published_at     TEXT,
  description      TEXT,
  artwork          TEXT,
  fetched_at       TEXT NOT NULL
);

-- 애플 인기 목록. 나라별 순위를 그대로 담는다.
CREATE TABLE podcast_charts (
  country    TEXT NOT NULL,
  rank       INTEGER NOT NULL,
  feed_id    TEXT NOT NULL,
  fetched_at TEXT NOT NULL,
  PRIMARY KEY (country, rank)
);

-- 검색 결과 캐시. iTunes Search 가 IP 기준 분당 약 20회라 반드시 끼운다.
CREATE TABLE podcast_search_cache (
  key        TEXT PRIMARY KEY,         -- 'q|lang|limit'
  payload    TEXT NOT NULL,            -- feed_id 배열 JSON
  fetched_at TEXT NOT NULL
);

CREATE INDEX idx_episodes_feed ON episodes(feed_id, published_at DESC);
CREATE INDEX idx_episodes_duration ON episodes(duration_seconds);
CREATE INDEX idx_podcasts_country ON podcasts(country);
