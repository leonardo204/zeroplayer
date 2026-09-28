-- 자동 선택에서 빼 달라고 한 방송국.
--
-- 기기가 기준이고 여기 있는 것은 사본이다. iOS 25 이하에서는 알람에 무엇을 틀지
-- **서버가** 고르기 때문에(`lib/alarmDispatch.ts`), 기기에만 두면 아침에 뺀 방송이
-- 그대로 온다. iOS 26 이상은 앱이 고르므로 올라오지 않고, AlarmKit 권한을 받는 순간
-- 앱이 빈 목록을 올려 이 표에서 지운다.
--
-- 담는 것은 방송국 번호뿐이다. 무엇을 얼마나 들었는지는 여기 오지 않는다.
CREATE TABLE IF NOT EXISTS excluded_stations (
  install_id TEXT NOT NULL REFERENCES devices(install_id) ON DELETE CASCADE,
  station_id TEXT NOT NULL,
  created_at TEXT NOT NULL,
  PRIMARY KEY (install_id, station_id)
);
