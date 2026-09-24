-- M4. 분위기 분류와 상황별 추천 세트.
-- station_moods 표는 0001 에서 이미 만들었다. 여기서는 언제 분류했는지와 세트 보관만 더한다.

-- 분위기를 언제 붙였는지. NULL 이면 아직 분류 전이다.
-- station_moods 에 줄이 없는 것과 '분류했지만 붙일 분위기가 없었다' 를 구분하려고 둔다.
ALTER TABLE stations ADD COLUMN moods_at TEXT;

-- 상황별 추천 세트. 하루 한 번 배치로 만든다.
CREATE TABLE recommendation_sets (
  id         TEXT PRIMARY KEY,         -- 'sleep|weekday|22-02|KR'
  situation  TEXT NOT NULL,
  daypart    TEXT NOT NULL,            -- '22-02' 같은 시간대 구간
  day_type   TEXT NOT NULL,            -- 'weekday' | 'weekend'
  country    TEXT NOT NULL,            -- 나라 코드, 전 세계는 'ZZ'
  payload    TEXT NOT NULL,            -- 항목 배열 JSON. reason 포함
  model      TEXT,                     -- 어느 모델이 만들었는지. 'rule' 이면 LLM 이 실패한 것
  created_at TEXT NOT NULL
);

CREATE INDEX idx_stations_moods_at ON stations(moods_at);
CREATE INDEX idx_reco_created ON recommendation_sets(created_at);
