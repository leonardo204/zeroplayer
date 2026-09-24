-- AFN 정리. 1.x 가 들고 있던 The Voice·Joe Radio·Legacy 는 streamtheworld 에서
-- mount 가 사라졌다(pls 는 200 을 주지만 NumberOfEntries=0 이라 재생할 주소가 없다).
-- 살아 있는 두 곳만 남기고, pls 를 거치지 않는 https AAC 주소로 바꾼다.
DELETE FROM hidden_channels WHERE id IN ('kr:afn-voice', 'kr:afn-joe', 'kr:afn-legacy');

UPDATE hidden_channels
SET stream_url = 'https://playerservices.streamtheworld.com/api/livestream-redirect/AFNP_OSNAAC.aac',
    stream_kind = 'direct',
    name = 'AFN The Eagle (오산)',
    updated_at = datetime('now')
WHERE id = 'kr:afn-eagle';

INSERT INTO hidden_channels (id, name, broadcaster, stream_url, stream_kind, schedule_kind, schedule_url, logo_url, sort_order, updated_at) VALUES
  ('kr:afn-daegu', 'AFN The Eagle (대구)', 'AFN',
   'https://playerservices.streamtheworld.com/api/livestream-redirect/AFNP_DGUAAC.aac',
   'direct', NULL, NULL, NULL, 14, datetime('now'));
