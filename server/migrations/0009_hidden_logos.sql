-- 지상파 채널에 방송사 로고를 붙인다.
-- 편성표가 오는 채널은 재생 중에 프로그램 이미지로 바뀌고, 이 로고는 그 전까지와
-- 편성표가 실패했을 때 쓰는 바탕이다. AFN 두 곳은 사이트가 외부 요청을 막아
-- 로고를 못 구했다 — 앱이 이름 첫 글자로 타일을 그린다.
UPDATE hidden_channels SET logo_url = 'https://res.static.kbs.co.kr/kbs_og.png' WHERE broadcaster = 'KBS';
UPDATE hidden_channels SET logo_url = 'https://img.imbc.com/commons/2018/image/comm2018noti/meta_mbc.png' WHERE broadcaster = 'MBC';
UPDATE hidden_channels SET logo_url = 'https://program-image.cloud.sbs.co.kr/og/2025/sbs_home.png' WHERE broadcaster = 'SBS';
UPDATE hidden_channels SET logo_url = 'https://www.cbs.co.kr/img/og_image.png' WHERE broadcaster = 'CBS';
UPDATE hidden_channels SET logo_url = 'https://tbs.seoul.kr/common/images/index/tbsLogo.jpg' WHERE broadcaster = 'TBS';
