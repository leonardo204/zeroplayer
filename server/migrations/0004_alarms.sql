-- M6. 기기와 알람. 푸시 토큰은 설치 UUID 에 묶는다(기기 식별자가 아니다).

CREATE TABLE devices (
  install_id   TEXT PRIMARY KEY,      -- 앱이 처음 실행될 때 만들어 키체인에 둔 UUID
  push_token   TEXT,                  -- APNs 기기 토큰. 없으면 푸시를 못 보낸다
  push_env     TEXT DEFAULT 'prod',   -- 'prod' | 'sandbox'. 개발 빌드는 sandbox 로 보내야 받는다
  platform     TEXT DEFAULT 'ios',
  app_version  TEXT,
  hidden_unlocked INTEGER DEFAULT 0,  -- M7 에서 쓴다
  last_seen_at TEXT
);

CREATE TABLE alarms (
  id           TEXT PRIMARY KEY,      -- 'alm_<랜덤>'
  install_id   TEXT NOT NULL REFERENCES devices(install_id) ON DELETE CASCADE,
  hour         INTEGER NOT NULL,
  minute       INTEGER NOT NULL,
  weekdays     TEXT NOT NULL,         -- '2,3,4,5,6'. 1=일 … 7=토. 빈 문자열이면 한 번만 울린다
  timezone     TEXT NOT NULL,         -- 'Asia/Seoul'
  source_kind  TEXT NOT NULL,         -- 'station' | 'episode' | 'auto'
  source_id    TEXT,
  source_title TEXT,                  -- 목록에 무엇이 걸려 있는지 보여주려고 들고 있는다
  situation    TEXT,                  -- source_kind='auto' 일 때 'wake' 등
  label        TEXT,
  enabled      INTEGER DEFAULT 1,
  next_fire_at TEXT,                  -- UTC ISO. 시간대 계산을 매분 하지 않도록 미리 써 둔다
  last_sent_at TEXT,
  created_at   TEXT NOT NULL,
  updated_at   TEXT NOT NULL
);

-- 발송 기록. 같은 분에 두 번 보내지 않으려고 둔다.
CREATE TABLE alarm_sends (
  alarm_id  TEXT NOT NULL REFERENCES alarms(id) ON DELETE CASCADE,
  fired_at  TEXT NOT NULL,            -- 울리기로 했던 시각(UTC ISO)
  sent_at   TEXT NOT NULL,
  ok        INTEGER NOT NULL,
  detail    TEXT,
  PRIMARY KEY (alarm_id, fired_at)
);

CREATE INDEX idx_alarms_due ON alarms(enabled, next_fire_at);
CREATE INDEX idx_alarms_install ON alarms(install_id);
