# 알람 멜로디 20곡 — 권리 정리

## 요약

곡은 저작권이 끝났고, **연주는 우리가 했다.** 그래서 음원의 권리자가 우리다.
남의 녹음을 가져오지 않았으므로 제3자 녹음권이 걸릴 자리가 없다.

## 곡 (저작권 소멸)

작곡가 사후 70년이 기준이다. 아래는 모두 그 기간이 지났다.

| 작곡가 | 사망 | 보호 종료 | 쓴 곡 |
| --- | --- | --- | --- |
| Pachelbel | 1706 | 1776 | 카논 |
| Vivaldi | 1741 | 1811 | 사계 '봄' |
| Bach | 1750 | 1820 | 미뉴에트, 전주곡, 첼로 1번, 인벤션 1번, 에어 |
| Haydn | 1809 | 1879 | 놀람 교향곡 2악장 |
| Mozart | 1791 | 1861 | 터키 행진곡, 나흐트무지크, 작은 별, 소나타 K.545 |
| Beethoven | 1827 | 1897 | 환희의 송가, 엘리제를 위하여, 교향곡 5번 |
| Rossini | 1868 | 1938 | 윌리엄 텔 서곡 피날레 |
| Grieg | 1907 | 1977 | 페르 귄트 '아침' |
| Strauss II | 1899 | 1969 | 아름답고 푸른 도나우 |
| Dvorak | 1904 | 1974 | 신세계 교향곡 2악장 |
| Elgar | 1934 | 2004 | 사랑의 인사 |

## 음색 (사운드폰트)

**FluidR3 GM — MIT.** 원저작자가 배포 파일에 직접 적어 둔 문장이다.

> Copyright (c) 2000-2002, 2008 Frank Wen <getfrank@gmail.com>
> I hereby release Fluid under the MIT license, as described in COPYING.

받은 곳: https://github.com/urban-1/fluid-soundfont (`original-files/README`)

사운드폰트 파일(148MB)은 **앱에 들어가지 않는다.** 미리 구워 둔 음원만 들어간다.
MIT 는 저작자 표시와 라이선스 전문 포함을 요구하므로, 설정 화면의
'오픈소스 라이선스' 항목에 위 문장과 MIT 전문을 넣는다.

## 만든 방법

```
melodies.py   악보를 쓴다(작곡가별 함수 하나씩)
render.swift  AVAudioUnitSampler + FluidR3 로 연주해 WAV 로 굽는다
post.py       목표 크기(-8 dBFS)까지 눌러 키우고 페이드를 걸어 앱용으로 바꾼다
```

되살리려면 `python3 melodies.py scores && for f in scores/*.txt; do ./render FluidR3_GM.sf2 "$f" "out/$(basename $f .txt).wav"; done && python3 post.py`

## 앱에 든 20곡과 키

키는 `AlarmSoundCatalog.tones` 의 `id` 이자 파일 이름이다. 저장값에도 쓰이므로
한번 정하면 바꾸지 않는다 — 바꾸면 그 곡을 고른 알람이 기본음으로 떨어진다.

| 화면 이름 | 키 | 파일 |
| --- | --- | --- |
| 아침 | `grieg-morning` | `zptone-grieg-morning.caf` |
| 미뉴에트 | `bach-minuet` | `zptone-bach-minuet.caf` |
| 전주곡 | `bach-prelude` | `zptone-bach-prelude.caf` |
| 환희의 송가 | `beethoven-joy` | `zptone-beethoven-joy.caf` |
| 카논 | `pachelbel-canon` | `zptone-pachelbel-canon.caf` |
| 봄 | `vivaldi-spring` | `zptone-vivaldi-spring.caf` |
| 터키 행진곡 | `mozart-turca` | `zptone-mozart-turca.caf` |
| 나흐트무지크 | `mozart-nacht` | `zptone-mozart-nacht.caf` |
| 무반주 첼로 1번 | `bach-cello1` | `zptone-bach-cello1.caf` |
| 엘리제를 위하여 | `beethoven-elise` | `zptone-beethoven-elise.caf` |
| 작은 별 | `mozart-twinkle` | `zptone-mozart-twinkle.caf` |
| 소나타 K.545 | `mozart-k545` | `zptone-mozart-k545.caf` |
| 인벤션 1번 | `bach-invention1` | `zptone-bach-invention1.caf` |
| 놀람 교향곡 | `haydn-surprise` | `zptone-haydn-surprise.caf` |
| 신세계 2악장 | `dvorak-newworld` | `zptone-dvorak-newworld.caf` |
| 윌리엄 텔 | `rossini-tell` | `zptone-rossini-tell.caf` |
| 아름다운 도나우 | `strauss-danube` | `zptone-strauss-danube.caf` |
| 에어 | `bach-air` | `zptone-bach-air.caf` |
| 교향곡 5번 | `beethoven-fifth` | `zptone-beethoven-fifth.caf` |
| 사랑의 인사 | `elgar-salut` | `zptone-elgar-salut.caf` |

## 잰 값

실기기에 들어가는 형태로 재본 것이다(22.05kHz 모노, 음량을 가장 크게).

| 항목 | 값 |
| --- | --- |
| 길이 | 22.5 ~ 29.0초 (알람음 한도 30초 미만) |
| 크기 | 피크 98~100%, RMS −8.0 ~ −8.2 dBFS |
| 음량 슬라이더를 가장 작게 | RMS −18.5 dBFS (그래도 들린다) |
| 번들 용량 | 20곡 5.9MB (곡당 약 300KB) |
