# 알람음 굽는 도구

앱에 든 알람음 20곡을 만드는 자리다. 결과물은
`Sources/Resources/AlarmTones/zptone-<키>.caf` 로 들어가고, 목록은
`Sources/Core/Notifications/AlarmSound.swift` 의 `AlarmSoundCatalog.tones` 다.

## 왜 직접 연주하는가

남의 녹음을 쓰면 권리가 걸린다. 오픈소스 알람음을 셋 알아봤는데 전부 막혔다.

| 알아본 것 | 결과 |
| --- | --- |
| AOSP `data/sounds/alarms` | Apache 2.0 이 맞다. 다만 전자음 계열이고 16종뿐이다 |
| `robbiehanson/AlarmClock` (MIT) | 레포는 MIT 인데 음원 출처가 지워져 있다. 원저작자 표시·copyright 태그가 없고 Credits 에 사운드만 빠졌다 |
| Freesound CC0 | 라이선스는 깨끗한데 단음이라 멜로디가 안 된다 |

그래서 **저작권이 끝난 고전을 우리가 연주해 굽는다.** 녹음의 권리자가 우리라서
제3자 권리가 걸릴 자리가 없다. 곡은 전부 사후 70년이 지난 작곡가의 것이다.

음색은 **FluidR3 GM** 사운드폰트를 쓴다. 원저작자 Frank Wen 이 배포 파일에
직접 적어 둔 문장으로 MIT 를 확인했다 — "I hereby release Fluid under the MIT
license, as described in COPYING." 사운드폰트(148MB)는 저장소에 넣지 않는다.
구울 때만 받아 쓰고, 앱에는 구운 결과만 들어간다.

## 준비

```sh
cd tools/alarm-tones
curl -fsSL -o FluidR3_GM.sf2 \
  https://github.com/urish/cinto/raw/master/static/sf2/FluidR3_GM.sf2
swiftc -O render.swift -o render
```

`render.swift` 는 `AVAudioUnitSampler` 로 악보를 연주해 WAV 로 굽는다.
외부 도구(fluidsynth·sox·ffmpeg)가 필요 없다.

## 굽기

```sh
mkdir -p scores out
python3 melodies.py scores        # 악보 20개
for f in scores/*.txt; do
  ./render FluidR3_GM.sf2 "$f" "out/$(basename "${f%.txt}").wav"
done
python3 post.py                   # preview/(스테레오)  app/(22.05k 모노)
```

`post.py` 가 곡마다 목표 크기(RMS −8.0 dBFS)에 닿을 만큼만 눌러 키운다. 곡에 따라
1.7~7배까지 달라서 고정값으로는 맞지 않는다. 끝에 점검 결과를 찍는다.

## 앱에 넣기

```sh
mkdir -p caf
for f in app/*.wav; do
  afconvert "$f" "caf/$(basename "${f%.wav}").caf" -d ima4 -f caff
done
```

IMA4 로 담으면 곡당 1.1MB → 300KB 로 줄고, 애플이 알람음으로 받아 주는 형식이다
(MP3 는 알람 화면만 뜨고 소리가 안 난다 — `docs/10-alarmkit.md`).

파일 이름을 ASCII 로 바꿔 `Sources/Resources/AlarmTones/zptone-<키>.caf` 로 옮기고,
`AlarmSoundCatalog.tones` 에 한 줄을 더한다. 키는 파일 이름과 저장값에 쓰이므로
한번 정하면 바꾸지 않는다 — 바꾸면 그 소리를 고른 알람이 기본음으로 떨어진다.

## 곡을 고치거나 더할 때

`melodies.py` 의 함수 하나가 곡 하나다. 되돌려주는 값은 이렇다.

```python
dict(tempo_len=<한바퀴 초>, inst={<슬롯>: (<GM프로그램>, <볼륨>, <팬>, <게인dB>)},
     notes=[(<슬롯>, <시작초>, <길이초>, <미디음>, <세기>), ...], rev=<리버브>)
```

`write_score` 가 한 바퀴를 26초까지 되풀이해 채운다. 알람음 한도가 30초 미만이라
그 안에서 끝나야 한다.

## 정직하게 적어 두는 것

악보를 기억으로 적은 것이라 음이 틀린 곳이 있을 수 있다. 확신도가 갈린다.

- **원곡 대조가 된 것** — 미뉴에트, 전주곡, 환희의 송가, 카논, 엘리제, 작은 별,
  K.545 앞머리, 인벤션 1번 주제, 놀람 교향곡, 교향곡 5번, 무반주 첼로 1~3마디
- **기억으로 적은 것** — 아침, 봄, 터키 행진곡, 나흐트무지크, 신세계 2악장,
  윌리엄 텔, 도나우, 에어, 사랑의 인사

무반주 첼로 1번은 1~3마디가 원곡이고 4마디째는 원곡 진행 대신 1마디로 되돌려
주음으로 닫았다. 그 뒤 마디가 확실하지 않아 억지로 적지 않았다.
