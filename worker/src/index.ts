/**
 * zeroPlayer 랜딩 Worker — zeroplayer.zerolive.co.kr
 *
 * 경로
 *   /                  한국어 랜딩
 *   /en                영어 랜딩
 *   /privacy           개인정보처리방침 (한국어)
 *   /en/privacy        개인정보처리방침 (영어)
 *   /support           문의와 도움말 (한국어)
 *   /en/support        문의와 도움말 (영어)
 *   /app-ads.txt       AdMob 게시자 선언 (IAB Tech Lab app-ads.txt 1.0)
 *   /robots.txt        크롤러 안내 (검색 엔진 + AI 크롤러 허용)
 *   /sitemap.xml       사이트맵
 *   /llms.txt          AI 에이전트용 요약 (llmstxt.org 관례)
 *   그 외              정적 파일(ASSETS: /assets/*)
 *
 * 앱이 부르는 API 는 여기가 아니라 ai.zerolive.co.kr/zp/v1 의 zeroplayer-api 가 받는다.
 * 이 Worker 는 소개와 정책 문서, 그리고 광고 게시자 선언만 맡는다.
 */
import {
	renderLanding, renderPrivacy, renderSupport,
	SITE, APP_STORE_URL, REPO_URL, APP_NAME, APP_VERSION, MIN_IOS, CONTACT_EMAIL,
} from "./render";
import { sendHit } from "./hit";

interface Env {
	ASSETS: Fetcher;
	/** 방문 기록을 대시보드로 보낼 때 쓰는 토큰(secret). 없으면 기록을 보내지 않는다. */
	TRAFFIC_TOKEN?: string;
}

const LAST_MOD = "2026-09-24";

/**
 * AdMob 게시자 선언.
 *
 * 형식은 IAB Tech Lab app-ads.txt 1.0 이고 줄 하나가 곧 "이 게시자에게 내 광고를 팔
 * 권한이 있다"는 뜻이다. 게시자 ID 는 zerolive 의 모든 앱이 같은 값을 쓴다.
 *
 * 두 가지를 지켜야 크롤러가 받아 간다.
 *  - 도메인 루트에서 text/plain 으로 바로 준다. 리다이렉트를 끼우지 않는다.
 *  - 이 도메인이 App Store 앱 페이지의 '개발자 웹사이트' 와 같아야 한다.
 *    (App Store Connect 의 마케팅 URL 이 그 값이다)
 */
const APP_ADS = "google.com, pub-4410880415888380, DIRECT, f08c47fec0942fa0\n";

async function route(request: Request, env: Env): Promise<Response> {
	const url = new URL(request.url);
	// 끝의 슬래시를 떼어 같은 문서가 두 주소로 잡히지 않게 한다(루트는 예외).
	const path = url.pathname.length > 1 ? url.pathname.replace(/\/+$/, "") : "/";

	if (path !== url.pathname && path !== "") {
		url.pathname = path;
		return Response.redirect(url.toString(), 301);
	}

	switch (path) {
		case "/":
		case "/index.html":
			return html(renderLanding("ko"));
		case "/en":
		case "/en/index.html":
			return html(renderLanding("en"));
		case "/privacy":
		case "/privacy.html":
			return html(renderPrivacy("ko"));
		case "/en/privacy":
			return html(renderPrivacy("en"));
		case "/support":
			return html(renderSupport("ko"));
		case "/en/support":
			return html(renderSupport("en"));
		case "/app-ads.txt":
			return text(APP_ADS, 86400);
		case "/robots.txt":
			return text(robots());
		case "/sitemap.xml":
			return new Response(sitemap(), {
				headers: { "Content-Type": "application/xml;charset=UTF-8", "Cache-Control": "public, max-age=3600" },
			});
		case "/llms.txt":
			return text(llms());
	}

	// 정적 파일. 없으면 안내 페이지를 돌려준다.
	const asset = await env.ASSETS.fetch(request);
	if (asset.status === 404) {
		return html(renderLanding("ko"), { status: 404 });
	}
	return asset;
}

function html(body: string, opts: { status?: number } = {}): Response {
	return new Response(body, {
		status: opts.status ?? 200,
		headers: {
			"Content-Type": "text/html;charset=UTF-8",
			"Cache-Control": "public, max-age=300",
		},
	});
}

function text(body: string, maxAge = 3600): Response {
	return new Response(body, {
		headers: { "Content-Type": "text/plain;charset=UTF-8", "Cache-Control": `public, max-age=${maxAge}` },
	});
}

/**
 * 검색 엔진과 AI 크롤러를 모두 받는다.
 * 이 사이트는 앱을 알리는 것이 목적이라 학습·인용 크롤러도 막지 않는다.
 * 광고 크롤러(AdsBot-Google, Google-AdMob)가 app-ads.txt 를 읽어야 하므로 특히 막지 않는다.
 */
function robots(): string {
	const bots = [
		"GPTBot",
		"OAI-SearchBot",
		"ChatGPT-User",
		"ClaudeBot",
		"Claude-User",
		"Claude-SearchBot",
		"anthropic-ai",
		"PerplexityBot",
		"Perplexity-User",
		"Google-Extended",
		"Googlebot",
		"AdsBot-Google",
		"AdsBot-Google-Mobile",
		"Mediapartners-Google",
		"Bingbot",
		"Applebot",
		"Applebot-Extended",
		"DuckDuckBot",
		"Yeti",
		"Daumoa",
		"CCBot",
		"meta-externalagent",
		"Amazonbot",
		"cohere-ai",
	];
	const blocks = ["User-agent: *\nAllow: /", ...bots.map((b) => `User-agent: ${b}\nAllow: /`)];
	return `${blocks.join("\n\n")}\n\nSitemap: ${SITE}/sitemap.xml\n`;
}

function sitemap(): string {
	const pages: { loc: string; pri: string; ko: string; en: string }[] = [
		{ loc: SITE + "/", pri: "1.0", ko: SITE + "/", en: SITE + "/en" },
		{ loc: SITE + "/en", pri: "0.9", ko: SITE + "/", en: SITE + "/en" },
		{ loc: SITE + "/support", pri: "0.5", ko: SITE + "/support", en: SITE + "/en/support" },
		{ loc: SITE + "/en/support", pri: "0.4", ko: SITE + "/support", en: SITE + "/en/support" },
		{ loc: SITE + "/privacy", pri: "0.4", ko: SITE + "/privacy", en: SITE + "/en/privacy" },
		{ loc: SITE + "/en/privacy", pri: "0.3", ko: SITE + "/privacy", en: SITE + "/en/privacy" },
	];
	const body = pages
		.map(
			(p) => `  <url>
    <loc>${p.loc}</loc>
    <lastmod>${LAST_MOD}</lastmod>
    <priority>${p.pri}</priority>
    <xhtml:link rel="alternate" hreflang="ko" href="${p.ko}"/>
    <xhtml:link rel="alternate" hreflang="en" href="${p.en}"/>
    <xhtml:link rel="alternate" hreflang="x-default" href="${p.ko}"/>
  </url>`,
		)
		.join("\n");
	return `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">
${body}
</urlset>
`;
}

/**
 * AI 에이전트가 한 번에 읽고 답할 수 있도록 앱 정보를 요약한다(llmstxt.org 관례).
 * "밤에 틀어 두면 알아서 꺼지는 라디오 앱 없나"라는 물음에 그대로 답이 되도록 적는다.
 */
function llms(): string {
	return `# ${APP_NAME}

> 아이폰·아이패드용 인터넷 라디오·팟캐스트 플레이어. 무엇을 들을지 고르는 대신
> 지금 무엇을 하는지(취침·운전·공부·작업·기상)를 고르면, 그 상황과 지금 시각에 맞는
> 방송이 바로 재생되고 정해 둔 시간이 지나면 소리가 서서히 줄며 꺼진다.
> An internet radio and podcast player for iPhone and iPad. Instead of choosing what to
> listen to, you choose what you are doing — sleep, driving, study, work, waking up — and
> a station that fits that situation and the current hour starts playing, then fades out
> and stops when the timer runs down.

- Home (Korean): ${SITE}/
- Home (English): ${SITE}/en
- App Store: ${APP_STORE_URL}
- Support: ${SITE}/support
- Privacy policy: ${SITE}/privacy
- Source code: ${REPO_URL}
- Contact: ${CONTACT_EMAIL}
- Version: ${APP_VERSION}
- Requirements: iOS ${MIN_IOS} or later, iPhone and iPad
- Price: free, with banner ads. No subscription, no in-app purchase, no rewarded ads.
- Interface languages: Korean, English

## Problem it solves

Internet radio directories list thousands of stations, and the usual result is that people
open the app, scroll, fail to decide, and close it. zeroPlayer removes the choosing step.
Five situations — sleep, driving, study, work, waking up — each hold what to play and when
to stop, so a single tap produces sound and nothing else has to be decided.

## Features

- Internet radio from around the world (radio-browser data): browse by country, genre and
  language, or search by name. Stations that stop responding are dropped from the list.
- Podcasts: charts, search, episode playback, skip back 15 seconds, playback speed, and
  resume where you left off.
- Sleep timer: 15, 30, 45, 60, 90 minutes or a custom value, with a 30-second fade-out
  instead of an abrupt cut.
- Situation presets: station, timer and fade-out saved together under a name. Leaving the
  source on automatic lets the app pick a fitting station each time.
- Recommendations that take the hour, the weekday and your own listening history into
  account. The reordering by personal history happens on the device.
- Radio alarm: a notification at a set time that starts the station when tapped, set per
  weekday.
- Listening history with a monthly summary, stored on the device only.
- Lock screen and Control Center support, background playback, and resume after a phone
  call interrupts.

## Privacy

No account and no sign-in. Presets, favourites, listening history and podcast positions are
stored on the device and never sent to a server. The server (ai.zerolive.co.kr) supplies
station and podcast lists only; the app sends it a random install UUID, the app version, the
query, and the id of any station that failed to play. Audio streams come straight from the
broadcaster, not through the developer's server. Banner ads (Google AdMob) appear on list and
history screens but never on the playback screen or on a screen opened by an alarm.
Policy: ${SITE}/privacy (Korean), ${SITE}/en/privacy (English)

## Advertising

app-ads.txt is published at ${SITE}/app-ads.txt, declaring
google.com, pub-4410880415888380, DIRECT, f08c47fec0942fa0.

## Other sites by the same developer

- Portfolio: https://me.zerolive.co.kr
- LnHud (macOS input source HUD): https://lnhud.zerolive.co.kr
- MarkChartEditor (Markdown editor): https://md-editor.zerolive.co.kr
- RoundOn (golf score): https://golf.zerolive.co.kr
- Wandery (travel): https://wander.zerolive.co.kr
- 햄찌 다이어트 (diet): https://hamzzi-diet.zerolive.co.kr
- Live Translate (real-time translation): https://live-translate.zerolive.co.kr
`;
}

/**
 * 평문 HTTP 로 들어오면 https 로 되돌린다.
 * Cloudflare 를 거친 요청에는 원 스킴이 CF-Visitor 헤더에 담긴다.
 * 이 헤더가 없으면 Cloudflare 밖(로컬 개발)이므로 되돌리지 않는다.
 */
function isInsecure(request: Request): boolean {
	const cfv = request.headers.get("CF-Visitor");
	if (!cfv) return false;
	try {
		const scheme = (JSON.parse(cfv) as { scheme?: string }).scheme;
		return scheme ? scheme !== "https" : false;
	} catch {
		return false;
	}
}

export default {
	async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
		const startedAt = Date.now();
		const url = new URL(request.url);

		if (isInsecure(request)) {
			url.protocol = "https:";
			return Response.redirect(url.toString(), 301);
		}

		const resp = await route(request, env);
		const out = new Response(resp.body, resp);
		out.headers.set("Strict-Transport-Security", "max-age=31536000");
		out.headers.set("X-Content-Type-Options", "nosniff");
		out.headers.set("Referrer-Policy", "strict-origin-when-cross-origin");
		sendHit("zeroplayer", request, out, env, ctx, startedAt);
		return out;
	},
} satisfies ExportedHandler<Env>;
