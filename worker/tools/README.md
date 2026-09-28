# 공유 카드 그림 만들기

`og.jpg`(한국어)·`og-en.jpg`(영어) 를 만드는 자리다. 1200×630 이고
`worker/public/assets/` 에 들어간다.

512px 아이콘을 `og:image` 로 쓰면 카톡·슬랙·X 가 작은 카드(`summary`)로 그린다.
1200×630 을 주면 큰 카드(`summary_large_image`)가 되고 화면 캡처가 크게 붙는다.

## 다시 만들기

`og-ko.html` 과 `og-en.html` 이 곧 그림이다. 랜딩과 같은 글꼴(Pretendard)·같은 색을 쓰고
`../public/assets/` 의 캡처를 그대로 가리키므로 따로 복사할 것이 없다.

```sh
cd worker/tools
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
for L in ko en; do
  "$CHROME" --headless --disable-gpu --hide-scrollbars --force-device-scale-factor=2 \
    --window-size=1200,630 --screenshot="raw-$L.png" --virtual-time-budget=6000 \
    "file://$PWD/og-$L.html"
  sips -z 630 1200 "raw-$L.png" --out "shot-$L.png"
done
sips -s format jpeg -s formatOptions 86 shot-ko.png --out ../public/assets/og.jpg
sips -s format jpeg -s formatOptions 86 shot-en.png --out ../public/assets/og-en.jpg
rm -f raw-*.png shot-*.png
```

`--force-device-scale-factor=2` 로 찍고 반으로 줄이는 것이 요점이다. 1배로 찍으면
글자 가장자리가 거칠다.

## 고칠 때

- 문구는 `og-*.html` 안에 그대로 있다. 랜딩의 `heroTitle` 과 맞춰 둔다.
- 영어는 제목이 길어 `h1` 을 45px 로 낮춰 두 줄에 맞췄다. 문구를 바꾸면 줄 수를 확인한다.
- 캡처를 바꾸면 `.s1`·`.s2`·`.s3` 의 `left`·`top` 을 다시 본다. 오른쪽 끝에서 잘리기 쉽다.
- 바꾼 뒤에는 `og:image:alt`(`src/content.ts` 의 `ogImageAlt`)도 함께 고친다.
