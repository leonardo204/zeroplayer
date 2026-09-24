-- M7. 한국 지상파(히든). 채널 표와 해제 기록, 편성표 캐시.
--
-- 방송사 주소를 앱에 두지 않는다는 원칙은 공개 방송국과 같다. 다른 점은 목록 자체도
-- 토큰 없이는 내주지 않는다는 것이다 — 앱 바이너리를 뜯어도 채널 이름이 바로 나오지 않게 한다.

CREATE TABLE hidden_channels (
  id            TEXT PRIMARY KEY,      -- 'kr:kbs-2fm' 처럼 사람이 읽을 수 있게 둔다
  name          TEXT NOT NULL,
  broadcaster   TEXT NOT NULL,         -- 'KBS' | 'MBC' | 'SBS' | 'CBS' | 'TBS' | 'AFN'
  stream_url    TEXT NOT NULL,
  stream_kind   TEXT NOT NULL DEFAULT 'direct',  -- 'direct' | 'pls' (pls 는 서버가 풀어서 준다)
  schedule_kind TEXT,                  -- 'kbs' | 'mbc' | 'sbs' | 'tbs' | 'cbs' | NULL(편성표 없음)
  schedule_url  TEXT,
  logo_url      TEXT,
  sort_order    INTEGER NOT NULL DEFAULT 0,
  enabled       INTEGER NOT NULL DEFAULT 1,
  updated_at    TEXT NOT NULL
);

-- 편성표 캐시. 방송사 페이지를 사람마다 부르지 않는다.
CREATE TABLE hidden_now_cache (
  channel_id   TEXT PRIMARY KEY REFERENCES hidden_channels(id) ON DELETE CASCADE,
  program_name TEXT,
  start_time   TEXT,                   -- 'HH:MM'. 못 읽으면 NULL
  end_time     TEXT,
  artwork_url  TEXT,
  ok           INTEGER NOT NULL DEFAULT 0,
  detail       TEXT,                   -- 실패했을 때 무엇이 막았는지
  fetched_at   TEXT NOT NULL
);

-- 해제 토큰. 설치 UUID 하나에 하나다.
ALTER TABLE devices ADD COLUMN hidden_token TEXT;
ALTER TABLE devices ADD COLUMN hidden_unlocked_at TEXT;

CREATE INDEX idx_hidden_channels_order ON hidden_channels(enabled, sort_order);
CREATE INDEX idx_devices_hidden_token ON devices(hidden_token);

-- 채널 표. 1.x 의 목록을 옮기되 실측(2026-09-24)으로 확인한 주소만 넣는다.
--   · KBS·MBC·SBS 는 serpent0 의 .pls 가 부를 때마다 새로 서명된 주소를 준다.
--     m3u8 주소를 직접 적어 두면 서명이 만료돼 403 이 난다(M2 에서 확인).
--   · CBS 는 1.x 의 aac.cbs.co.kr 이 죽어 m-aac 쪽 https 주소로 바꿨다.
--   · TBS 는 1.x 가 재생 페이지 주소를 들고 있었다. 실제 스트림 주소를 따로 적는다.
--   · AFN 은 평문 HTTP 를 주던 pls 를 https 쪽으로 바꿨다.
INSERT INTO hidden_channels (id, name, broadcaster, stream_url, stream_kind, schedule_kind, schedule_url, logo_url, sort_order, updated_at) VALUES
  ('kr:kbs-1radio',      'KBS 1라디오',    'KBS', 'http://serpent0.duckdns.org:8088/kbs1radio.pls', 'pls', 'kbs', '21',      NULL,  1, datetime('now')),
  ('kr:kbs-happyfm',     'KBS 해피FM',     'KBS', 'http://serpent0.duckdns.org:8088/kbs2radio.pls', 'pls', 'kbs', '22',      NULL,  2, datetime('now')),
  ('kr:kbs-classicfm',   'KBS 클래식FM',   'KBS', 'http://serpent0.duckdns.org:8088/kbsfm.pls',     'pls', 'kbs', '24',      NULL,  3, datetime('now')),
  ('kr:kbs-coolfm',      'KBS 쿨FM',       'KBS', 'http://serpent0.duckdns.org:8088/kbs2fm.pls',    'pls', 'kbs', '25',      NULL,  4, datetime('now')),
  ('kr:mbc-standardfm',  'MBC 표준FM',     'MBC', 'http://serpent0.duckdns.org:8088/mbcsfm.pls',    'pls', 'mbc', '표준FM',   NULL,  5, datetime('now')),
  ('kr:mbc-fm4u',        'MBC FM4U',       'MBC', 'http://serpent0.duckdns.org:8088/mbcfm.pls',     'pls', 'mbc', 'FM4U',    NULL,  6, datetime('now')),
  ('kr:sbs-lovefm',      'SBS 러브FM',     'SBS', 'http://serpent0.duckdns.org:8088/sbs2fm.pls',    'pls', 'sbs', 'LOVE FM', NULL,  7, datetime('now')),
  ('kr:sbs-powerfm',     'SBS 파워FM',     'SBS', 'http://serpent0.duckdns.org:8088/sbsfm.pls',     'pls', 'sbs', 'POWER FM',NULL,  8, datetime('now')),
  ('kr:cbs-standardfm',  'CBS 표준FM',     'CBS', 'https://m-aac.cbs.co.kr/mweb_cbs981/_definst_/cbs981.stream/playlist.m3u8', 'direct', NULL, NULL, NULL,  9, datetime('now')),
  ('kr:cbs-musicfm',     'CBS 음악FM',     'CBS', 'https://m-aac.cbs.co.kr/mweb_cbs939/_definst_/cbs939.stream/playlist.m3u8', 'direct', 'cbs', 'music', NULL, 10, datetime('now')),
  ('kr:tbs-fm',          'TBS FM',         'TBS', 'https://cdnfm.tbs.seoul.kr/tbs/_definst_/tbs_fm_web_360.smil/playlist.m3u8',  'direct', 'tbs', 'CH_A', NULL, 11, datetime('now')),
  ('kr:tbs-efm',         'TBS eFM',        'TBS', 'https://cdnefm.tbs.seoul.kr/tbs/_definst_/tbs_efm_web_360.smil/playlist.m3u8','direct', 'tbs', 'CH_B', NULL, 12, datetime('now')),
  ('kr:afn-eagle',       'AFN The Eagle',  'AFN', 'https://playerservices.streamtheworld.com/pls/AFNP_OSN.pls',  'pls', NULL, NULL, NULL, 13, datetime('now')),
  ('kr:afn-voice',       'AFN The Voice',  'AFN', 'https://playerservices.streamtheworld.com/pls/AFN_VCE.pls',   'pls', NULL, NULL, NULL, 14, datetime('now')),
  ('kr:afn-joe',         'AFN Joe Radio',  'AFN', 'https://playerservices.streamtheworld.com/pls/AFN_JOEP.pls',  'pls', NULL, NULL, NULL, 15, datetime('now')),
  ('kr:afn-legacy',      'AFN Legacy',     'AFN', 'https://playerservices.streamtheworld.com/pls/AFN_LGYP.pls',  'pls', NULL, NULL, NULL, 16, datetime('now'));
