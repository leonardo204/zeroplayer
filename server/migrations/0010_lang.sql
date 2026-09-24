-- 다국어. 추천 세트는 언어별로 따로 만들고, 알람 알림은 기기 언어로 보낸다.
--
-- 방송국 이름과 한국 지상파 편성표는 고유명사라 그대로 둔다.
-- 옮기는 것은 서버가 만드는 문구뿐이다 — 추천 이유와 알람 본문.

-- 기기가 쓰는 말. 'ko' | 'en'. /push/token 에서 받는다.
ALTER TABLE devices ADD COLUMN lang TEXT NOT NULL DEFAULT 'ko';

-- 세트 id 에 언어를 붙인다. 지금까지 만든 것은 전부 한국어다.
UPDATE recommendation_sets SET id = id || '|ko' WHERE id NOT LIKE '%|ko' AND id NOT LIKE '%|en';
