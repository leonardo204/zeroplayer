/**
 * 화면을 그린다. 글은 content.ts, 스타일은 styles.ts 가 맡는다.
 * 한국어가 기본이고 /en 아래가 영어다.
 */
import { CSS } from "./styles";
import { COPY, type Copy, type Lang } from "./content";

export const SITE = "https://zeroplayer.zerolive.co.kr";
export const APP_STORE_URL = "https://apps.apple.com/kr/app/zeroplayer/id1610259595";
export const REPO_URL = "https://github.com/leonardo204/zeroplayer";
export const CONTACT_EMAIL = "zerolive7@gmail.com";
export const APP_NAME = "zeroPlayer";
export const APP_VERSION = "2.0";
export const MIN_IOS = "17.0";

function paths(lang: Lang) {
	const base = lang === "en" ? "/en" : "";
	return {
		home: base === "" ? "/" : base,
		privacy: `${base}/privacy`,
		support: `${base}/support`,
		other: lang === "en" ? "/" : "/en",
	};
}

function esc(s: string): string {
	return s
		.replace(/&/g, "&amp;")
		.replace(/</g, "&lt;")
		.replace(/>/g, "&gt;")
		.replace(/"/g, "&quot;");
}

function appStoreBadge(c: Copy): string {
	return `<a href="${APP_STORE_URL}" target="_blank" rel="noopener" class="appstore-badge" aria-label="${esc(c.badgeAria)}">
  <svg width="168" height="50" viewBox="0 0 160 48" fill="none" xmlns="http://www.w3.org/2000/svg" role="img" aria-hidden="true">
    <rect width="160" height="48" rx="9" fill="#000"/>
    <path d="M27.9 24.6c0-3.1 2.5-4.6 2.7-4.7-1.5-2.1-3.7-2.4-4.5-2.5-1.9-.2-3.8 1.1-4.7 1.1-1 0-2.5-1.1-4.1-1.1-2.1 0-4.1 1.2-5.1 3.1-2.2 3.8-.6 9.4 1.5 12.5 1.1 1.5 2.3 3.2 4 3.1 1.6-.1 2.2-1 4.2-1s2.5 1 4.2 1c1.7 0 2.9-1.5 4-3 1.3-1.7 1.8-3.4 1.8-3.5-.1 0-3.5-1.3-3.5-5.3zm-3.1-9.7c.9-1.1 1.5-2.6 1.3-4.2-1.3.1-2.9.9-3.8 2-.8 1-1.5 2.5-1.3 4 1.4.1 2.9-.7 3.8-1.8z" fill="#fff"/>
    <text x="49" y="20" font-family="-apple-system,BlinkMacSystemFont,sans-serif" font-size="9" fill="#fff" letter-spacing=".3">${esc(c.badgeSmall)}</text>
    <text x="49" y="36" font-family="-apple-system,BlinkMacSystemFont,sans-serif" font-size="17" font-weight="600" fill="#fff" letter-spacing="-.3">${esc(c.badgeBig)}</text>
  </svg>
</a>`;
}

/**
 * 같은 사람이 만든 다른 앱 — 바닥글에 서로를 걸어 둔다.
 *
 * 서브도메인끼리 서로 모르는 채 떨어져 있으면 검색 엔진이 각자를 외딴 섬으로 보고
 * robots.txt 만 확인하고 돌아간다. 새로 만든 곳일수록 그렇다.
 * 자기 자신은 빼고 그리고, 한국어 이름밖에 없는 앱은 영어 화면에서도 그대로 쓴다.
 */
const SIBLINGS: { host: string; ko: string; en: string }[] = [
	{ host: "lnhud", ko: "LnHud", en: "LnHud" },
	{ host: "md-editor", ko: "MarkChartEditor", en: "MarkChartEditor" },
	{ host: "golf", ko: "라운드온", en: "RoundOn" },
	{ host: "wander", ko: "Wandery", en: "Wandery" },
	{ host: "hamzzi-diet", ko: "햄찌 다이어트", en: "햄찌 다이어트" },
	{ host: "zeroplayer", ko: "zeroPlayer", en: "zeroPlayer" },
];
const SELF_HOST = "zeroplayer";
const PORTFOLIO = "https://me.zerolive.co.kr";

function siblingLinks(lang: Lang): string {
	return SIBLINGS.filter((s) => s.host !== SELF_HOST)
		.map((s) => `<a href="https://${s.host}.zerolive.co.kr/">${esc(lang === "en" ? s.en : s.ko)}</a>`)
		.join(" &nbsp;·&nbsp; ");
}

interface ShellOpts {
	lang: Lang;
	title: string;
	desc: string;
	keywords?: string;
	canonical: string;
	altKo: string;
	altEn: string;
	body: string;
	jsonLd?: unknown[];
}

function shell(o: ShellOpts): string {
	const c = COPY[o.lang];
	const p = paths(o.lang);
	const ld = [siteJsonLd(o.lang), orgJsonLd(), ...(o.jsonLd ?? [])]
		.map((x) => `<script type="application/ld+json">${JSON.stringify(x)}</script>`)
		.join("\n");

	return `<!DOCTYPE html>
<html lang="${c.htmlLang}">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(o.title)}</title>
<meta name="description" content="${esc(o.desc)}">
${o.keywords ? `<meta name="keywords" content="${esc(o.keywords)}">` : ""}
<meta name="author" content="zerolive">
<meta name="theme-color" content="#49A5CB">
<meta name="robots" content="index,follow,max-image-preview:large,max-snippet:-1">
<link rel="canonical" href="${o.canonical}">
<link rel="alternate" hreflang="ko" href="${o.altKo}">
<link rel="alternate" hreflang="en" href="${o.altEn}">
<link rel="alternate" hreflang="x-default" href="${o.altKo}">
<meta property="og:site_name" content="${APP_NAME}">
<meta property="og:title" content="${esc(o.title)}">
<meta property="og:description" content="${esc(o.desc)}">
<meta property="og:url" content="${o.canonical}">
<meta property="og:type" content="website">
<meta property="og:locale" content="${o.lang === "ko" ? "ko_KR" : "en_US"}">
<meta property="og:image" content="${SITE}/assets/icon.png">
<meta name="twitter:card" content="summary">
<meta name="twitter:title" content="${esc(o.title)}">
<meta name="twitter:description" content="${esc(o.desc)}">
<meta name="twitter:image" content="${SITE}/assets/icon.png">
<link rel="icon" href="/assets/icon.png">
<link rel="apple-touch-icon" href="/assets/icon.png">
<link rel="preconnect" href="https://cdn.jsdelivr.net">
<link href="https://cdn.jsdelivr.net/gh/orioncactus/pretendard@v1.3.9/dist/web/variable/pretendardvariable-dynamic-subset.min.css" rel="stylesheet">
<style>${CSS}</style>
${ld}
</head>
<body>

<nav class="nav">
  <div class="nav-inner">
    <a href="${p.home}" class="nav-logo">
      <img src="/assets/icon.png" alt="" width="30" height="30">
      <span>${APP_NAME}</span>
    </a>
    <div class="nav-links">
      <a href="${p.home}#features">${esc(c.navFeatures)}</a>
      <a href="${p.home}#how">${esc(c.navHow)}</a>
      <a href="${p.home}#privacy">${esc(c.navPrivacy)}</a>
      <a href="${p.home}#faq">${esc(c.navFaq)}</a>
      <a href="${p.support}">${esc(c.navSupport)}</a>
    </div>
    <a class="lang" href="${p.other}" hreflang="${o.lang === "ko" ? "en" : "ko"}">${esc(c.langSwitchLabel)}</a>
  </div>
</nav>

${o.body}

<footer>
  <div class="container">
    <span>© 2026 ${APP_NAME} · <a href="${PORTFOLIO}${o.lang === "en" ? "/en" : "/ko"}">${esc(c.footerNote)}</a></span>
    <span>
      <a href="${p.privacy}">${esc(c.footerPrivacy)}</a> &nbsp;·&nbsp;
      <a href="${p.support}">${esc(c.footerSupport)}</a> &nbsp;·&nbsp;
      <a href="mailto:${CONTACT_EMAIL}">${esc(c.footerContact)}</a>
    </span>
  </div>
  <div class="container sib"><span class="lb">${esc(c.footerMore)}</span>${siblingLinks(o.lang)}</div>
</footer>

</body>
</html>`;
}

/** 사이트 자체를 설명한다. 검색 결과에 사이트 이름이 제대로 표기되게 한다. */
function siteJsonLd(lang: Lang): unknown {
	const c = COPY[lang];
	return {
		"@context": "https://schema.org",
		"@type": "WebSite",
		"@id": SITE + "/#website",
		name: APP_NAME,
		url: SITE + "/",
		description: c.desc,
		inLanguage: ["ko", "en"],
		publisher: { "@id": SITE + "/#publisher" },
	};
}

function orgJsonLd(): unknown {
	return {
		"@context": "https://schema.org",
		"@type": "Person",
		"@id": SITE + "/#publisher",
		name: "zerolive",
		alternateName: "YONGSUB LEE",
		url: PORTFOLIO,
		email: CONTACT_EMAIL,
		sameAs: [REPO_URL, PORTFOLIO],
	};
}

function appJsonLd(lang: Lang): unknown {
	const c = COPY[lang];
	return {
		"@context": "https://schema.org",
		"@type": "MobileApplication",
		name: APP_NAME,
		operatingSystem: `iOS ${MIN_IOS}+`,
		applicationCategory: "MultimediaApplication",
		softwareVersion: APP_VERSION,
		description: c.desc,
		url: SITE + (lang === "en" ? "/en" : "/"),
		downloadUrl: APP_STORE_URL,
		installUrl: APP_STORE_URL,
		image: SITE + "/assets/icon.png",
		author: { "@id": SITE + "/#publisher" },
		offers: { "@type": "Offer", price: "0", priceCurrency: "KRW" },
	};
}

function faqJsonLd(lang: Lang): unknown {
	const c = COPY[lang];
	return {
		"@context": "https://schema.org",
		"@type": "FAQPage",
		mainEntity: c.faqs.map((f) => ({
			"@type": "Question",
			name: f.q,
			acceptedAnswer: { "@type": "Answer", text: f.a },
		})),
	};
}

export function renderLanding(lang: Lang): string {
	const c = COPY[lang];
	const p = paths(lang);

	const body = `
<header class="hero">
  <div class="container">
    <h1 class="section-title">${esc(c.heroTitle)}</h1>
    <p class="section-sub">${esc(c.heroSub)}</p>
    ${appStoreBadge(c)}
    <p class="hero-meta">${esc(c.heroMeta)}</p>
    <div class="moods">
      ${c.moods.map((m) => `<div class="mood"><div class="m-name">${esc(m.name)}</div><div class="m-time">${esc(m.time)}</div></div>`).join("\n      ")}
    </div>
  </div>
</header>

<section class="section alt" id="situations">
  <div class="container text-center">
    <span class="section-badge">${esc(c.moodsBadge)}</span>
    <h2 class="section-title">${esc(c.moodsTitle)}</h2>
    <p class="section-sub mx-auto">${esc(c.moodsSub)}</p>
  </div>
</section>

<section class="section" id="features">
  <div class="container">
    <span class="section-badge">${esc(c.featBadge)}</span>
    <h2 class="section-title">${esc(c.featTitle)}</h2>
    <p class="section-sub">${esc(c.featSub)}</p>
    <div class="features-grid">
      ${c.features.map((f) => `<article class="feature"><div class="ic">${esc(f.ic)}</div><h3>${esc(f.h)}</h3><p>${esc(f.p)}</p></article>`).join("\n      ")}
    </div>
  </div>
</section>

<section class="section alt" id="how">
  <div class="container">
    <span class="section-badge">${esc(c.howBadge)}</span>
    <h2 class="section-title">${esc(c.howTitle)}</h2>
    <p class="section-sub">${esc(c.howSub)}</p>
    <div class="rows">
      ${c.rows.map((r) => `<div class="row"><div class="k">${esc(r.k)}</div><div class="v">${esc(r.v)}</div></div>`).join("\n      ")}
    </div>
  </div>
</section>

<section class="section" id="privacy">
  <div class="container text-center">
    <span class="section-badge">${esc(c.privBadge)}</span>
    <h2 class="section-title">${esc(c.privTitle)}</h2>
    <p class="section-sub mx-auto">${esc(c.privSub)}</p>
    <p style="margin-top:22px"><a href="${p.privacy}">${esc(c.footerPrivacy)}</a></p>
  </div>
</section>

<section class="section alt" id="faq">
  <div class="container narrow">
    <span class="section-badge">${esc(c.faqBadge)}</span>
    <h2 class="section-title">${esc(c.faqTitle)}</h2>
    <div class="faq">
      ${c.faqs.map((f) => `<details><summary>${esc(f.q)}</summary><p>${esc(f.a)}</p></details>`).join("\n      ")}
    </div>
  </div>
</section>

<section class="cta">
  <div class="container">
    <h2>${esc(c.ctaTitle)}</h2>
    <p>${esc(c.ctaSub)}</p>
    ${appStoreBadge(c)}
  </div>
</section>
`;

	return shell({
		lang,
		title: c.title,
		desc: c.desc,
		keywords: c.keywords,
		canonical: SITE + (lang === "en" ? "/en" : "/"),
		altKo: SITE + "/",
		altEn: SITE + "/en",
		body,
		jsonLd: [appJsonLd(lang), faqJsonLd(lang)],
	});
}

export function renderPrivacy(lang: Lang): string {
	const c = COPY[lang];
	const body = lang === "ko" ? PRIVACY_KO : PRIVACY_EN;
	return shell({
		lang,
		title: `${c.privacyTitle} — ${APP_NAME}`,
		desc:
			lang === "ko"
				? "zeroPlayer 개인정보처리방침. 계정이 없고, 청취 기록과 프리셋은 기기 안에만 저장합니다."
				: "zeroPlayer privacy policy. No account, and listening history and presets stay on the device.",
		canonical: SITE + (lang === "en" ? "/en/privacy" : "/privacy"),
		altKo: SITE + "/privacy",
		altEn: SITE + "/en/privacy",
		body: `<main class="doc"><div class="container narrow">
<h1>${esc(c.privacyTitle)}</h1>
<p class="updated">${esc(c.privacyUpdated)}</p>
${body}
</div></main>`,
	});
}

export function renderSupport(lang: Lang): string {
	const c = COPY[lang];
	const body = lang === "ko" ? SUPPORT_KO : SUPPORT_EN;
	return shell({
		lang,
		title: `${c.supportTitle} — ${APP_NAME}`,
		desc:
			lang === "ko"
				? "zeroPlayer 문의와 도움말. 소리가 안 날 때, 타이머가 안 맞을 때 먼저 볼 것."
				: "zeroPlayer support. What to check when there is no sound or the timer behaves oddly.",
		canonical: SITE + (lang === "en" ? "/en/support" : "/support"),
		altKo: SITE + "/support",
		altEn: SITE + "/en/support",
		body: `<main class="doc"><div class="container narrow">
<h1>${esc(c.supportTitle)}</h1>
<p class="updated">${esc(c.supportUpdated)}</p>
${body}
</div></main>`,
	});
}

const PRIVACY_KO = `
<p>zeroPlayer 는 계정을 만들지 않습니다. 이름·이메일·전화번호를 묻지 않고 로그인 화면도 없습니다.
이 문서는 그럼에도 오가는 값이 무엇인지 적어 둔 것입니다.</p>

<h2>기기에만 남는 것</h2>
<p>다음은 전부 아이폰·아이패드 안에만 저장되고 서버로 보내지 않습니다. 앱을 지우면 함께 사라집니다.</p>
<ul>
  <li>프리셋 — 이름, 아이콘, 걸어 둔 방송국, 타이머 길이</li>
  <li>즐겨찾기</li>
  <li>청취 기록 — 무엇을 언제 얼마나 들었는지, 어느 프리셋에서 시작했는지</li>
  <li>팟캐스트를 듣던 위치</li>
  <li>타이머 기본값 같은 설정</li>
</ul>
<p>추천 목록을 내 기록에 맞춰 다시 세우는 계산도 기기 안에서 합니다. 그래서 무엇을 들었는지가
밖으로 나갈 이유가 없습니다. 기록은 설정 화면에서 언제든 지울 수 있습니다.</p>

<h2>서버로 가는 것</h2>
<p>방송국과 팟캐스트 목록은 개발자가 운영하는 서버(<code>ai.zerolive.co.kr</code>)가 내려 줍니다.
앱이 그 서버를 부를 때 함께 가는 값은 다음뿐입니다.</p>
<ul>
  <li>설치 식별자 — 앱을 처음 열 때 만드는 무작위 UUID 입니다. 기기 식별자가 아니고 애플 계정과도
      무관합니다. 앱을 지우고 다시 깔면 다른 값이 됩니다. 알람 등록과 남용 차단에만 씁니다.</li>
  <li>앱 판 번호와 요청한 조건(나라·장르·검색어 같은 것)</li>
  <li>재생이 실패한 방송국의 번호 — 죽은 방송을 목록에서 빼려고 보냅니다</li>
  <li>모든 인터넷 요청에 따라오는 접속 IP. 서버 앞단(Cloudflare)이 일시적으로 기록합니다</li>
</ul>
<p>무엇을 얼마나 들었는지, 어떤 프리셋을 쓰는지는 보내지 않습니다.</p>

<h2>알람을 켰을 때</h2>
<p>알람을 쓰시면 애플 푸시 서비스(APNs)가 발급한 기기 토큰을 서버에 보관합니다. 정해진 시각에
알림을 보내기 위한 것이고, 알람을 모두 끄거나 앱을 지우면 더는 쓰이지 않습니다.
알림 권한은 알람을 처음 켤 때만 묻습니다.</p>

<h2>스트림 재생</h2>
<p>방송을 틀면 앱이 그 방송국 서버에 직접 연결합니다. 소리가 개발자 서버를 거치지 않습니다.
그래서 방송국 쪽에는 접속 IP 처럼 일반적인 접속 기록이 남습니다. 그 기록은 해당 방송국이
관리하며 개발자가 볼 수 없습니다.</p>

<h2>광고</h2>
<p>목록과 기록 화면에 Google AdMob 배너가 들어갑니다. 재생 화면, 미니 플레이어, 알람이 울려
열린 화면에는 광고를 두지 않습니다. 광고를 봐야 열리는 기능도 없습니다.</p>
<p>AdMob 은 광고를 고르고 성과를 재기 위해 기기의 광고 식별자와 대략적인 위치(나라 수준) 같은
값을 쓸 수 있습니다. iOS 는 앱이 추적에 쓰는 식별자를 쓰기 전에 허락을 묻고, 거절하셔도
앱의 모든 기능은 그대로 쓰실 수 있습니다(광고가 덜 맞춤될 뿐입니다).
자세한 내용은 <a href="https://policies.google.com/technologies/partner-sites" target="_blank" rel="noopener">Google 의 파트너 사이트 정책</a>에 있습니다.</p>

<h2>어린이</h2>
<p>만 14세 미만을 대상으로 만든 앱이 아니며, 나이를 묻거나 어린이 정보를 일부러 모으지 않습니다.</p>

<h2>바뀌면</h2>
<p>이 문서가 바뀌면 맨 위 날짜를 고치고, 크게 달라지는 경우 앱 안에서 알려 드립니다.</p>

<h2>문의</h2>
<p>궁금한 것이나 지워 달라고 하실 것이 있으면 <a href="mailto:${CONTACT_EMAIL}">${CONTACT_EMAIL}</a> 로 보내 주세요.</p>
`;

const PRIVACY_EN = `
<p>zeroPlayer has no accounts. It never asks for a name, an email address or a phone number,
and there is no sign-in screen. This page describes what does travel, despite that.</p>

<h2>Stays on your device</h2>
<p>All of the following is stored on your iPhone or iPad and never sent to a server.
Deleting the app deletes it too.</p>
<ul>
  <li>Presets — name, icon, the station attached to it, timer length</li>
  <li>Favourites</li>
  <li>Listening history — what you played, when, for how long, and which preset started it</li>
  <li>Your position in a podcast episode</li>
  <li>Settings such as the default timer</li>
</ul>
<p>The reordering that adapts recommendations to your history is computed on the device as well,
so there is no reason for what you listen to to leave it. You can erase the history at any time
from the Settings tab.</p>

<h2>Sent to the server</h2>
<p>Station and podcast lists come from a server run by the developer
(<code>ai.zerolive.co.kr</code>). These are the only values that travel with a request.</p>
<ul>
  <li>An install identifier — a random UUID created the first time you open the app. It is not a
      device identifier and has nothing to do with your Apple account; reinstalling produces a new
      one. It is used only for alarm registration and abuse limits.</li>
  <li>The app version and the query you made (country, genre, search term and the like)</li>
  <li>The id of a station that failed to play, so dead stations can be removed from the list</li>
  <li>The connecting IP address that comes with any internet request; the edge (Cloudflare) logs it
      briefly</li>
</ul>
<p>What you listened to, for how long, and which presets you use are not sent.</p>

<h2>When alarms are on</h2>
<p>If you use alarms, the device token issued by Apple Push Notification service is kept on the
server so a notification can be delivered at the time you set. Turning all alarms off, or deleting
the app, stops it being used. Notification permission is requested only when you first turn an
alarm on.</p>

<h2>Stream playback</h2>
<p>When you play a station the app connects to that station's own server. Audio does not pass
through the developer's server. The station therefore records ordinary access information such as
your IP address. That log belongs to the station and the developer cannot see it.</p>

<h2>Advertising</h2>
<p>Google AdMob banners appear on the list and history screens. There are no ads on the playback
screen, the mini player, or the screen an alarm opens, and no feature is locked behind watching
an ad.</p>
<p>AdMob may use the device advertising identifier and coarse (country-level) location to select
ads and measure them. iOS asks for your permission before an app uses the tracking identifier, and
declining leaves every feature of the app working — the ads are simply less targeted. See
<a href="https://policies.google.com/technologies/partner-sites" target="_blank" rel="noopener">Google's partner sites policy</a> for details.</p>

<h2>Children</h2>
<p>This app is not directed at children under 14. It does not ask for an age and does not knowingly
collect information from children.</p>

<h2>Changes</h2>
<p>If this page changes, the date at the top is updated, and significant changes are announced
inside the app.</p>

<h2>Contact</h2>
<p>Questions, or a request to delete something, go to
<a href="mailto:${CONTACT_EMAIL}">${CONTACT_EMAIL}</a>.</p>
`;

const SUPPORT_KO = `
<p>막히신 부분이 아래에 없으면 <a href="mailto:${CONTACT_EMAIL}">${CONTACT_EMAIL}</a> 로 보내 주세요.
어느 기기, 어느 iOS 판, 어떤 방송국이었는지를 함께 적어 주시면 빨리 찾습니다.</p>

<h2>눌렀는데 소리가 안 납니다</h2>
<p>인터넷 라디오는 방송국 쪽이 조용히 멈추는 일이 잦습니다. 앱은 15초 안에 첫 소리가 오지 않으면
실패로 보고 알려 드리고, 그 사실을 서버에 보냅니다. 같은 신고가 쌓인 방송은 목록에서 빠집니다.
다른 방송국에서도 같은 일이 생긴다면 기기가 인터넷에 붙어 있는지, 저전력 모드가 켜져 있지 않은지
확인해 주세요.</p>

<h2>화면을 끄면 끊깁니다</h2>
<p>설정 앱의 일반 → 백그라운드 앱 새로 고침과, 저전력 모드를 확인해 주세요. 저전력 모드에서는
iOS 가 네트워크를 강하게 제한합니다. 그래도 끊긴다면 어느 방송국인지 알려 주세요 —
회선이 약한 방송국은 앱이 버퍼를 늘려도 버티지 못합니다.</p>

<h2>타이머가 끝나도 안 꺼집니다</h2>
<p>타이머는 프리셋마다 따로 있습니다. 프리셋의 타이머를 0분으로 두면 끄지 않습니다.
재생 화면의 자동 종료 단추에서 지금 걸린 타이머와 남은 시간을 볼 수 있습니다.</p>

<h2>곡명이 안 보입니다</h2>
<p>방송국이 곡 정보를 소리와 함께 보내는 경우에만 나옵니다. 보내지 않는 곳이 꽤 있고,
그럴 때는 채널 이름만 표시됩니다. 앱이 고칠 수 있는 부분이 아닙니다.</p>

<h2>알람이 안 울립니다</h2>
<p>세 가지를 확인해 주세요. 알림 권한이 켜져 있는지, 무음 스위치가 내려가 있지 않은지,
벨소리 볼륨이 0 이 아닌지입니다. iOS 알림은 무음 모드에서 소리를 내지 않습니다.
그리고 알림은 한 번만 울립니다 — 시계 앱처럼 끌 때까지 반복하지 않습니다.</p>

<h2>듣던 자리가 사라졌습니다</h2>
<p>팟캐스트는 듣던 위치를 기기에 저장합니다. 앱을 지웠다 다시 깔면 함께 사라집니다.
라디오는 실시간 방송이라 위치라는 것이 없습니다.</p>

<h2>기록을 지우고 싶습니다</h2>
<p>설정 탭에서 청취 기록 지우기를 누르시면 됩니다. 되돌릴 수 없고 월간 리포트도 함께 비워집니다.
기록은 원래 기기 안에만 있어서 따로 요청하실 것이 없습니다.</p>
`;

const SUPPORT_EN = `
<p>If your problem is not below, write to <a href="mailto:${CONTACT_EMAIL}">${CONTACT_EMAIL}</a>.
Telling me the device, the iOS version and the station involved makes it much quicker to find.</p>

<h2>I tapped a station and there is no sound</h2>
<p>Internet radio stations go quiet fairly often at their end. If no audio arrives within 15
seconds the app treats it as a failure, tells you, and reports it to the server; stations with
enough reports drop out of the list. If it happens with every station, check that the device is
online and that Low Power Mode is off.</p>

<h2>Playback stops when the screen turns off</h2>
<p>Check Background App Refresh under Settings → General, and Low Power Mode, which makes iOS
restrict network use heavily. If it still stops, tell me which station — some have connections too
weak to survive even with a larger buffer.</p>

<h2>The timer runs out but playback continues</h2>
<p>Each preset carries its own timer, and a preset with the timer set to 0 minutes never stops.
The sleep-timer button on the playback screen shows the timer currently running and the time
left.</p>

<h2>No track title is shown</h2>
<p>The title appears only when the station sends it along with the audio. A fair number do not, and
then you see the station name alone. This is not something the app can fix.</p>

<h2>The alarm did not sound</h2>
<p>Check three things: notification permission is on, the silent switch is not engaged, and the
ringer volume is not at zero. iOS notifications stay silent in silent mode. Note also that the
sound plays once — it does not repeat until dismissed the way the Clock app does.</p>

<h2>My position in an episode is gone</h2>
<p>Podcast positions are stored on the device, so deleting and reinstalling the app removes them.
Radio is live, so there is no position to keep.</p>

<h2>I want to erase my history</h2>
<p>Settings tab → Erase listening history. It cannot be undone and the monthly report is cleared
with it. The history only ever existed on your device, so there is nothing to request from me.</p>
`;
