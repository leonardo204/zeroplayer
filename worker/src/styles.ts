/**
 * 랜딩·정책 페이지 스타일.
 *
 * 앞선 판은 섹션마다 대문자 배지를 얹고, 기능을 여섯 장의 카드로 늘어놓고, 카드가
 * 마우스를 따라 들리게 했다. 흔한 템플릿의 모양이라 공들여 만든 앱이 아니라
 * 자동으로 찍어낸 페이지처럼 보였다. 그래서 규칙을 몇 개 세워 두고 다시 짰다.
 *
 *  - 배지·알약 라벨을 쓰지 않는다. 제목은 제목만으로 선다.
 *  - 테두리 상자를 늘어놓지 않는다. 구분은 머리카락 선과 여백으로 한다.
 *  - 마우스를 올려 움직이는 것은 누를 수 있는 것(링크·단추)뿐이다.
 *  - 강조색은 링크와 표시 한둘에만 쓴다. 배경을 물들이지 않는다.
 *  - 어두운 구역은 한 곳(알람)뿐이다. 밤에 쓰는 기능이라 뜻이 있다.
 *
 * 강조색은 앱의 AccentColor(sRGB 0.286 0.647 0.796)에서 왔다. 글자로 쓸 때는
 * 흰 바탕에서 대비가 모자라 한 단계 어두운 값을 따로 둔다.
 */
export const CSS = `
:root{
  --ink:#0F1419;--body:#57626C;--faint:#8B959E;
  --acc:#49A5CB;--acc-ink:#12708F;
  --line:#E7ECEF;--line-soft:#F0F3F5;
  --bg:#fff;--bg-alt:#FAFBFC;--night:#101820;
  --font:'Pretendard Variable',Pretendard,-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;
  --mono:ui-monospace,'SF Mono',SFMono-Regular,Menlo,monospace;
  --wide:1120px;--prose:680px;
}
*{margin:0;padding:0;box-sizing:border-box}
html{scroll-behavior:smooth;-webkit-text-size-adjust:100%}
body{font-family:var(--font);color:var(--ink);background:var(--bg);
  font-size:16px;line-height:1.75;-webkit-font-smoothing:antialiased;word-break:keep-all}
img{max-width:100%;height:auto;display:block}
a{color:var(--acc-ink);text-decoration:none}
a:hover{text-decoration:underline;text-underline-offset:3px}
svg{display:block}
::selection{background:#D6EBF4}

.wrap{max-width:var(--wide);margin:0 auto;padding:0 28px}
.prose{max-width:var(--prose)}

/* ── 상단 바 ─────────────────────────────────────────────── */
.nav{position:sticky;top:0;z-index:50;background:rgba(255,255,255,.88);
  backdrop-filter:saturate(180%) blur(12px);-webkit-backdrop-filter:saturate(180%) blur(12px);
  border-bottom:1px solid var(--line)}
.nav .wrap{height:58px;display:flex;align-items:center;gap:28px}
.brand{display:flex;align-items:center;gap:9px;color:var(--ink);font-weight:650;font-size:15.5px;
  letter-spacing:-.02em;white-space:nowrap}
.brand:hover{text-decoration:none}
.brand img{width:26px;height:26px;border-radius:6px}
.nav nav{display:flex;gap:22px;margin-left:auto}
.nav nav a{color:var(--body);font-size:14.5px;font-weight:500}
.nav nav a:hover{color:var(--ink);text-decoration:none}
.nav .lang{color:var(--faint);font-size:13px;font-weight:600;letter-spacing:.02em;
  padding-left:22px;border-left:1px solid var(--line)}
.nav .lang:hover{color:var(--ink);text-decoration:none}

/* ── 제목 체계 ───────────────────────────────────────────── */
h1,h2,h3{letter-spacing:-.03em;line-height:1.22;font-weight:700}
.h-hero{font-size:clamp(30px,4.6vw,50px);letter-spacing:-.038em;line-height:1.14}
.h-sec{font-size:clamp(22px,2.8vw,31px)}
.lede{font-size:clamp(16.5px,1.5vw,18.5px);color:var(--body);line-height:1.72}
.note{font-size:14px;color:var(--faint)}
.mark{color:var(--acc-ink)}

/* ── 구역 ────────────────────────────────────────────────── */
.sec{padding:84px 0;border-top:1px solid var(--line)}
.sec.alt{background:var(--bg-alt)}
.sec-head{max-width:620px;margin-bottom:46px}
.sec-head .h-sec{margin-bottom:14px}

/* ── 히어로 ──────────────────────────────────────────────── */
.hero{padding:72px 0 76px}
.hero-grid{display:grid;grid-template-columns:1fr 300px;gap:72px;align-items:center}
.hero .h-hero{margin-bottom:22px}
.hero .lede{margin-bottom:32px;max-width:520px}
.hero-cta{display:flex;align-items:center;gap:20px;flex-wrap:wrap}
.hero-spec{margin-top:26px;font-size:13.5px;color:var(--faint);display:flex;gap:9px;flex-wrap:wrap}
.hero-spec b{font-weight:600;color:var(--body)}
.hero-spec span:not(:last-child)::after{content:'·';margin-left:9px;color:#C3CCD3}

/* 화면 캡처. 가짜 기기 테두리를 그리지 않는다 — 실제 화면 비율에 둥근 모서리와
   머리카락 선만 준다. 그림자는 아주 얕게. */
.shot{border-radius:26px;border:1px solid var(--line);overflow:hidden;
  box-shadow:0 1px 2px rgba(15,20,25,.04),0 12px 32px -12px rgba(15,20,25,.14)}
.shot img{width:100%}

/* ── 다섯 가지 상황: 표로 읽힌다 ─────────────────────────── */
.moods{border-top:1px solid var(--line)}
.mood{display:grid;grid-template-columns:34px 92px 1fr 128px;gap:18px;align-items:baseline;
  padding:20px 2px;border-bottom:1px solid var(--line)}
.mood .g{grid-row:span 1;align-self:center;color:var(--acc-ink);opacity:.9}
.mood .n{font-weight:650;font-size:16.5px;letter-spacing:-.02em}
.mood .d{color:var(--body);font-size:15px}
.mood .t{font-family:var(--mono);font-size:12.5px;color:var(--faint);text-align:right;
  letter-spacing:-.01em;white-space:nowrap}

/* ── 화면 캡처 줄 ────────────────────────────────────────── */
.strip{display:grid;grid-template-columns:repeat(3,1fr);gap:34px}
.strip figure{display:flex;flex-direction:column;gap:16px}
.strip figcaption{font-size:14.5px;color:var(--body)}
.strip figcaption b{display:block;color:var(--ink);font-weight:650;font-size:15.5px;
  letter-spacing:-.02em;margin-bottom:3px}

/* ── 기능: 정의 목록, 카드가 아니다 ─────────────────────── */
.defs{border-top:1px solid var(--line)}
.def{display:grid;grid-template-columns:232px 1fr;gap:36px;padding:26px 2px;
  border-bottom:1px solid var(--line)}
.def dt{font-weight:650;font-size:16.5px;letter-spacing:-.025em}
.def dd{color:var(--body);font-size:15.2px}
.def dd .sub{display:block;margin-top:7px;font-size:13.8px;color:var(--faint)}

/* ── 알람(어두운 구역) ──────────────────────────────────── */
.night{background:var(--night);color:#F2F5F7;border:0;padding:92px 0}
.night .h-sec{color:#fff}
.night .lede{color:#A9B6C1}
.night .note{color:#76848F}
.night a{color:#8FD0E8}
.night .tones{margin-top:40px;display:grid;grid-template-columns:repeat(4,1fr);gap:0 28px;
  border-top:1px solid #222D38}
.night .tone{padding:15px 0;border-bottom:1px solid #222D38;font-size:14.5px}
.night .tone b{font-weight:600;color:#fff}
.night .tone i{font-style:normal;display:block;font-size:12.8px;color:#76848F;margin-top:1px}
.night-grid{display:grid;grid-template-columns:1fr 268px;gap:64px;align-items:center}

/* ── 사양 표 ─────────────────────────────────────────────── */
.spec{border-top:1px solid var(--line);max-width:760px}
.spec div{display:grid;grid-template-columns:168px 1fr;gap:24px;padding:14px 2px;
  border-bottom:1px solid var(--line-soft);font-size:15px}
.spec dt{color:var(--faint);font-size:14px}
.spec dd{color:var(--ink)}

/* ── FAQ ─────────────────────────────────────────────────── */
.faq{border-top:1px solid var(--line);max-width:var(--prose)}
.faq details{border-bottom:1px solid var(--line)}
.faq summary{cursor:pointer;list-style:none;padding:19px 34px 19px 2px;position:relative;
  font-weight:600;font-size:16px;letter-spacing:-.02em}
.faq summary::-webkit-details-marker{display:none}
.faq summary::after{content:'';position:absolute;right:6px;top:50%;width:9px;height:9px;
  margin-top:-5px;border-right:1.6px solid var(--faint);border-bottom:1.6px solid var(--faint);
  transform:rotate(45deg);transition:transform .18s}
.faq details[open] summary::after{transform:rotate(-135deg);margin-top:-2px}
.faq summary:hover{color:var(--acc-ink)}
.faq p{padding:0 2px 21px;color:var(--body);font-size:15.2px}

/* ── 내려받기 줄 ────────────────────────────────────────── */
.get{padding:76px 0;border-top:1px solid var(--line);text-align:center}
.get .h-sec{margin-bottom:12px}
.get .lede{margin:0 auto 28px;max-width:480px}
.badge{display:inline-block;line-height:0}
.badge:hover{text-decoration:none;opacity:.85}

/* ── 본문 문서(개인정보·문의) ──────────────────────────── */
.doc{padding:64px 0 88px}
.doc h1{font-size:clamp(26px,3.2vw,34px);margin-bottom:8px}
.doc .updated{font-size:13.5px;color:var(--faint);margin-bottom:40px;padding-bottom:20px;
  border-bottom:1px solid var(--line)}
.doc h2{font-size:18.5px;margin:38px 0 12px;letter-spacing:-.025em}
.doc p{color:var(--body);margin-bottom:13px;font-size:15.5px}
.doc ul{margin:0 0 16px 0;list-style:none}
.doc li{color:var(--body);margin-bottom:9px;font-size:15.5px;padding-left:16px;position:relative}
.doc li::before{content:'';position:absolute;left:1px;top:11px;width:5px;height:5px;
  border-radius:50%;background:var(--line);box-shadow:0 0 0 1px var(--line)}
.doc b{color:var(--ink);font-weight:600}
.doc code{font-family:var(--mono);font-size:13.5px;background:var(--bg-alt);
  border:1px solid var(--line);border-radius:5px;padding:1px 5px}
.doc .back{display:inline-block;margin-top:44px;font-size:14.5px}

/* ── 바닥글 ──────────────────────────────────────────────── */
footer{border-top:1px solid var(--line);background:var(--bg-alt);padding:40px 0 48px;
  font-size:13.8px;color:var(--faint)}
footer .rowa{display:flex;justify-content:space-between;align-items:baseline;gap:20px;flex-wrap:wrap}
footer .rowb{margin-top:20px;padding-top:20px;border-top:1px solid var(--line);
  display:flex;gap:8px 14px;flex-wrap:wrap;align-items:baseline;font-size:13.2px}
footer a{color:var(--body)}
footer .lbl{color:var(--faint)}
footer .rowb span[aria-hidden]{color:#C3CCD3;margin:0 -4px}

@media(max-width:920px){
  .hero-grid{grid-template-columns:1fr;gap:48px}
  .hero-grid .shot{max-width:280px}
  .night-grid{grid-template-columns:1fr;gap:44px}
  .night-grid .shot{max-width:250px}
  .night .tones{grid-template-columns:1fr 1fr;gap:0 24px}
  .strip{grid-template-columns:1fr;gap:40px;max-width:420px}
  .nav nav{display:none}
  .nav .lang{margin-left:auto}
  .def{grid-template-columns:1fr;gap:6px}
  .mood{grid-template-columns:30px 1fr;gap:14px;row-gap:4px;padding:18px 2px}
  .mood .d{grid-column:2}
  .mood .t{grid-column:2;text-align:left}
}
@media(max-width:560px){
  .wrap{padding:0 20px}
  .h-hero br{display:none}
  .sec{padding:62px 0}
  .hero{padding:52px 0 58px}
  .night{padding:66px 0}
  .spec div{grid-template-columns:1fr;gap:2px;padding:12px 2px}
  footer .rowa{flex-direction:column;gap:10px}
}
@media(prefers-reduced-motion:reduce){
  html{scroll-behavior:auto}
  *{transition:none!important}
}
`;
