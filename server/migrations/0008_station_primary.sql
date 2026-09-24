-- 묶음마다 대표 한 줄을 미리 정해 둔다.
--
-- 목록은 묶음 질의로, 추천은 먼저 나온 줄로 대표를 골라서 같은 방송인데도
-- 화면마다 다른 이름이 보였다('KBS Classic FM' 과 '(BSOD) KBS Classic FM').
-- 대표를 여기에 적어 두면 두 곳이 같은 줄을 쓰고 질의도 단순해진다.
--
-- 값은 src/lib/stationKeys.ts 의 rekeyStations 가 채운다.

ALTER TABLE stations ADD COLUMN is_primary INTEGER DEFAULT 1;
CREATE INDEX idx_stations_primary ON stations(is_primary);
