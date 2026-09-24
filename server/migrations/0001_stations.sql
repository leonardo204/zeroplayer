-- M2. 방송국 목록과 생사 기록. 팟캐스트·기기·알람 표는 해당 마일스톤에서 추가한다.

CREATE TABLE stations (
  id            TEXT PRIMARY KEY,      -- 'rb:<uuid>' 또는 'kr:<slug>'
  source        TEXT NOT NULL,         -- 'radio_browser' | 'manual'
  name          TEXT NOT NULL,
  stream_url    TEXT NOT NULL,
  homepage      TEXT,
  favicon       TEXT,
  country_code  TEXT,
  language      TEXT,
  codec         TEXT,
  bitrate       INTEGER,
  votes         INTEGER DEFAULT 0,
  clicks        INTEGER DEFAULT 0,
  is_hidden     INTEGER DEFAULT 0,     -- 1 이면 한국 지상파. 토큰 없이는 안 준다
  raw_tags      TEXT,                  -- radio-browser 원문. 정규화 규칙이 바뀌면 여기서 다시 계산한다
  updated_at    TEXT NOT NULL
);

-- 정규화된 태그. 'pop','POP','música pop','Pop Music' → 'pop'
CREATE TABLE station_tags (
  station_id TEXT NOT NULL REFERENCES stations(id) ON DELETE CASCADE,
  tag        TEXT NOT NULL,
  PRIMARY KEY (station_id, tag)
);

-- radio-browser 원시 태그를 표준 태그로 옮기는 표. 규칙으로 못 줄인 것만 LLM 이 채운다.
CREATE TABLE tag_aliases (
  raw        TEXT PRIMARY KEY,
  normalized TEXT,                     -- NULL 이면 아직 판정 전
  origin     TEXT NOT NULL,            -- 'rule' | 'ai' | 'manual'
  created_at TEXT NOT NULL
);

-- LLM 이 붙인 분위기. M4 에서 채운다.
CREATE TABLE station_moods (
  station_id TEXT NOT NULL REFERENCES stations(id) ON DELETE CASCADE,
  mood       TEXT NOT NULL,
  confidence REAL,
  PRIMARY KEY (station_id, mood)
);

-- 스트림 생사. 앱 신고와 서버 점검 결과가 함께 쌓인다
CREATE TABLE station_health (
  station_id     TEXT PRIMARY KEY REFERENCES stations(id) ON DELETE CASCADE,
  last_ok_at     TEXT,
  last_fail_at   TEXT,
  last_checked_at TEXT,
  fail_streak    INTEGER DEFAULT 0,
  report_count   INTEGER DEFAULT 0,
  excluded       INTEGER DEFAULT 0     -- 1 이면 목록과 추천에서 제외
);

-- 배치 작업이 어디까지 했는지. /zp/v1/health 가 이 표를 읽는다.
CREATE TABLE sync_state (
  job        TEXT PRIMARY KEY,         -- 'radio_browser:KR', 'stream_check', 'tag_normalize'
  last_run_at TEXT,
  last_ok_at  TEXT,
  ok          INTEGER DEFAULT 0,
  detail      TEXT
);

CREATE INDEX idx_stations_country ON stations(country_code, is_hidden);
CREATE INDEX idx_stations_clicks ON stations(clicks DESC);
CREATE INDEX idx_station_tags_tag ON station_tags(tag);
CREATE INDEX idx_health_check_order ON station_health(last_checked_at);
