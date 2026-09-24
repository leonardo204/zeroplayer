/**
 * 랜딩·정책 페이지 공통 스타일.
 * 다른 zerolive 앱 랜딩(lnhud, md-editor, golf, wander)과 같은 결 —
 * 흰 바탕, 강조색 하나, 이모지 없음, Pretendard.
 * 강조색은 앱의 AccentColor(sRGB 0.286 0.647 0.796)를 그대로 가져왔다.
 */
export const CSS = `
:root{
  --acc:#49A5CB;--acc-dark:#1F6E92;--acc-light:#A6D6E8;--acc-bg:#EBF6FB;
  --dark:#14181D;--mid:#556069;--light:#8A939C;
  --surface:#F7FAFC;--border:#E3EAEF;--white:#fff;
  --night:#131A22;
  --radius:14px;--radius-lg:22px;
  --shadow:0 2px 16px rgba(20,24,29,.05);
  --shadow-lg:0 10px 38px rgba(73,165,203,.20);
  --font:'Pretendard Variable',Pretendard,-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;
  --mono:'SF Mono',ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;
}
*{margin:0;padding:0;box-sizing:border-box}
html{scroll-behavior:smooth}
body{font-family:var(--font);color:var(--dark);background:var(--white);line-height:1.65;
  -webkit-font-smoothing:antialiased;word-break:keep-all}
img{max-width:100%;height:auto;display:block}
a{color:var(--acc-dark);text-decoration:none}
a:hover{text-decoration:underline}

/* ── 상단 바 */
.nav{position:fixed;top:0;left:0;right:0;z-index:100;background:rgba(255,255,255,.85);
  backdrop-filter:blur(20px);-webkit-backdrop-filter:blur(20px);border-bottom:1px solid rgba(227,234,239,.7)}
.nav-inner{max-width:1080px;margin:0 auto;padding:0 24px;height:64px;display:flex;
  align-items:center;justify-content:space-between;gap:16px}
.nav-logo{display:flex;align-items:center;gap:10px;color:var(--dark);font-weight:700;font-size:16px;
  letter-spacing:-.3px;text-decoration:none;white-space:nowrap}
.nav-logo img{width:30px;height:30px;border-radius:7px}
.nav-links{display:flex;align-items:center;gap:22px}
.nav-links a{color:var(--mid);font-size:14px;font-weight:600;text-decoration:none}
.nav-links a:hover{color:var(--acc-dark)}
.lang{font-size:13px;font-weight:700;color:var(--light);border:1px solid var(--border);
  border-radius:999px;padding:5px 12px;text-decoration:none}
.lang:hover{color:var(--acc-dark);border-color:var(--acc-light);text-decoration:none}

.container{max-width:1080px;margin:0 auto;padding:0 24px}
.narrow{max-width:760px}
.text-center{text-align:center}
.mx-auto{margin-left:auto;margin-right:auto}

/* ── 섹션 공통 */
.section{padding:88px 0}
.section.alt{background:var(--surface);border-top:1px solid var(--border);border-bottom:1px solid var(--border)}
.section-badge{display:inline-block;font-size:12px;font-weight:800;letter-spacing:1.2px;
  text-transform:uppercase;color:var(--acc-dark);background:var(--acc-bg);
  border-radius:999px;padding:6px 14px;margin-bottom:18px}
.section-title{font-size:clamp(25px,3.6vw,38px);font-weight:800;letter-spacing:-1.1px;line-height:1.3;
  margin-bottom:16px}
.section-sub{font-size:clamp(15px,1.7vw,17.5px);color:var(--mid);max-width:660px}
.section-sub.mx-auto{margin-left:auto;margin-right:auto}
.accent{color:var(--acc)}

/* ── 히어로 */
.hero{padding:132px 0 76px;text-align:center;
  background:radial-gradient(120% 90% at 50% -10%,var(--acc-bg) 0%,#fff 62%)}
.hero .section-title{max-width:840px;margin-left:auto;margin-right:auto}
.hero .section-sub{margin:0 auto 30px}
.appstore-badge{display:inline-block;transition:transform .2s}
.appstore-badge:hover{transform:translateY(-2px);text-decoration:none}
.hero-meta{margin-top:14px;font-size:13.5px;color:var(--light)}

/* ── 상황 카드 — 앱이 프리셋으로 담는 다섯 가지를 그대로 보여 준다 */
.moods{display:grid;grid-template-columns:repeat(5,1fr);gap:14px;margin:44px auto 0;max-width:900px}
.mood{background:var(--night);color:#fff;border-radius:18px;padding:22px 14px;text-align:center;
  box-shadow:var(--shadow-lg)}
.mood .m-name{font-size:16px;font-weight:800;letter-spacing:-.3px}
.mood .m-time{margin-top:6px;font-size:12.5px;color:#9FB3C4;font-family:var(--mono)}

/* ── 기능 카드 */
.features-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:20px;margin-top:44px}
.feature{background:var(--white);border:1px solid var(--border);border-radius:var(--radius-lg);
  padding:28px 26px;box-shadow:var(--shadow);transition:transform .28s,box-shadow .28s}
.feature:hover{transform:translateY(-5px);box-shadow:var(--shadow-lg)}
.feature .ic{width:40px;height:40px;border-radius:11px;background:var(--acc-bg);color:var(--acc-dark);
  display:grid;place-items:center;font-size:16px;font-weight:800;margin-bottom:15px;font-family:var(--mono)}
.feature h3{font-size:17.5px;font-weight:800;letter-spacing:-.4px;margin-bottom:8px}
.feature p{font-size:14.5px;color:var(--mid)}

/* ── 두 칸 설명 */
.rows{margin-top:44px;display:grid;gap:18px}
.row{display:grid;grid-template-columns:150px 1fr;gap:20px;align-items:start;
  background:var(--white);border:1px solid var(--border);border-radius:var(--radius);padding:22px 24px}
.row .k{font-size:15px;font-weight:800;letter-spacing:-.3px;color:var(--acc-dark)}
.row .v{font-size:14.8px;color:var(--mid)}

/* ── FAQ */
.faq{margin-top:40px;display:grid;gap:12px}
.faq details{background:var(--white);border:1px solid var(--border);border-radius:var(--radius);
  padding:18px 22px}
.faq summary{cursor:pointer;font-weight:700;font-size:15.5px;letter-spacing:-.3px;list-style:none}
.faq summary::-webkit-details-marker{display:none}
.faq summary::after{content:'+';float:right;color:var(--acc);font-weight:800}
.faq details[open] summary::after{content:'–'}
.faq p{margin-top:12px;font-size:14.8px;color:var(--mid)}

/* ── 본문 문서(개인정보·지원) */
.doc{padding:120px 0 80px}
.doc h1{font-size:clamp(26px,3.4vw,34px);font-weight:800;letter-spacing:-1px;margin-bottom:10px}
.doc .updated{font-size:13.5px;color:var(--light);margin-bottom:36px}
.doc h2{font-size:19px;font-weight:800;letter-spacing:-.4px;margin:34px 0 10px}
.doc p{font-size:15.2px;color:var(--mid);margin-bottom:12px}
.doc ul{margin:0 0 14px 20px}
.doc li{font-size:15.2px;color:var(--mid);margin-bottom:7px}

/* ── 마무리 */
.cta{background:var(--night);color:#fff;text-align:center;padding:84px 0}
.cta h2{font-size:clamp(23px,3.2vw,32px);font-weight:800;letter-spacing:-.9px;margin-bottom:14px}
.cta p{color:#9FB3C4;font-size:16px;margin-bottom:28px}

/* ── 바닥글 */
footer{background:var(--surface);border-top:1px solid var(--border);padding:34px 0 40px;
  font-size:13.5px;color:var(--light)}
footer .container{display:flex;justify-content:space-between;align-items:center;gap:16px;flex-wrap:wrap}
footer a{color:var(--mid)}
footer .sib{margin-top:14px;padding-top:14px;border-top:1px solid var(--border);
  justify-content:flex-start;gap:10px;font-size:13px}
footer .sib .lb{color:var(--light);font-weight:700}

@media(max-width:900px){
  .nav-links{display:none}
  .features-grid{grid-template-columns:1fr 1fr}
  .moods{grid-template-columns:repeat(3,1fr)}
}
@media(max-width:640px){
  .section{padding:64px 0}
  .hero{padding:110px 0 56px}
  .features-grid{grid-template-columns:1fr}
  .moods{grid-template-columns:repeat(2,1fr)}
  .row{grid-template-columns:1fr;gap:6px}
  footer .container{flex-direction:column;align-items:flex-start}
}
`;
