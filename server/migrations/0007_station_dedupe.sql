-- M7 이후. 목록에 나오면 안 되는 줄을 가리는 값 두 가지.
--
-- stream_signed: 몇 시간이면 만료되는 서명이 붙은 주소.  radio-browser 에는
--   누군가의 브라우저에서 한 번 긁힌 KBS·MBC·SBS 주소가 그대로 올라와 있다.
--   등록된 날에는 살아 있어서 스트림 생사 점검으로는 안 걸러진다.
--   이 방송들은 히든 채널 표에 .pls 로 들어 있어 거기서는 멀쩡히 재생된다.
--
-- dedupe_key: 같은 방송을 코덱만 바꿔 여러 줄로 올린 것을 하나로 묶는 열쇠.
--   'KBS Classic FM' 은 열여섯 줄, 'Listen.moe Kpop' 은 세 줄이다.
--   값은 동기화할 때 src/lib/stationKeys.ts 가 계산해 넣는다.

ALTER TABLE stations ADD COLUMN stream_signed INTEGER DEFAULT 0;
ALTER TABLE stations ADD COLUMN dedupe_key TEXT;

-- 이미 들어 있는 줄의 서명 여부는 주소 모양만 보면 되므로 여기서 채운다.
UPDATE stations SET stream_signed = 1
WHERE (stream_url LIKE '%Policy=%' AND stream_url LIKE '%Signature=%')
   OR stream_url LIKE '%Key-Pair-Id=%'
   OR stream_url LIKE '%_lsu_sa_=%'
   OR stream_url LIKE '%token=eyJ%'
   OR stream_url LIKE '%hdnts=%'
   OR stream_url LIKE '%hdnt=%'
   OR stream_url LIKE '%wowzatokenendtime=%';

CREATE INDEX idx_stations_dedupe ON stations(dedupe_key);
CREATE INDEX idx_stations_signed ON stations(stream_signed);
