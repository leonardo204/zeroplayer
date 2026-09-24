/**
 * 랜딩과 정책 문서에 들어가는 글. 한국어가 기준이고 영어는 같은 내용을 옮긴 것이다.
 * 화면 구조는 render.ts 가, 글은 여기가 맡는다.
 */
export type Lang = "ko" | "en";

export interface Mood {
	name: string;
	time: string;
}
export interface Feature {
	ic: string;
	h: string;
	p: string;
}
export interface Row {
	k: string;
	v: string;
}
export interface Faq {
	q: string;
	a: string;
}

export interface Copy {
	htmlLang: string;
	title: string;
	desc: string;
	keywords: string;

	navFeatures: string;
	navHow: string;
	navPrivacy: string;
	navFaq: string;
	navSupport: string;
	langSwitchLabel: string;

	badgeAria: string;
	badgeSmall: string;
	badgeBig: string;

	heroTitle: string;
	heroSub: string;
	heroMeta: string;

	moodsBadge: string;
	moodsTitle: string;
	moodsSub: string;
	moods: Mood[];

	featBadge: string;
	featTitle: string;
	featSub: string;
	features: Feature[];

	howBadge: string;
	howTitle: string;
	howSub: string;
	rows: Row[];

	privBadge: string;
	privTitle: string;
	privSub: string;

	faqBadge: string;
	faqTitle: string;
	faqs: Faq[];

	ctaTitle: string;
	ctaSub: string;

	footerNote: string;
	footerPrivacy: string;
	footerSupport: string;
	footerContact: string;
	footerMore: string;

	privacyTitle: string;
	privacyUpdated: string;

	supportTitle: string;
	supportUpdated: string;
}

const KO: Copy = {
	htmlLang: "ko",
	title: "zeroPlayer — 상황에 맞는 인터넷 라디오와 팟캐스트",
	desc:
		"취침·운전·공부·작업·기상. 상황을 누르면 지금 시각에 어울리는 인터넷 라디오나 팟캐스트가 바로 재생되고, 정해 둔 시간이 지나면 소리가 서서히 줄며 꺼집니다. iPhone·iPad 무료 앱.",
	keywords:
		"인터넷 라디오,라디오 앱,팟캐스트,수면 타이머,취침 타이머,자동 종료,라디오 알람,아이폰 라디오,zeroPlayer",

	navFeatures: "기능",
	navHow: "쓰는 법",
	navPrivacy: "개인정보",
	navFaq: "자주 묻는 것",
	navSupport: "문의",
	langSwitchLabel: "EN",

	badgeAria: "App Store 에서 zeroPlayer 내려받기",
	badgeSmall: "Download on the",
	badgeBig: "App Store",

	heroTitle: "무엇을 들을지 고르는 대신, 지금 무엇을 하는지만 고릅니다",
	heroSub:
		"취침을 누르면 잔잔한 채널이 흐르고 45분 뒤 소리가 서서히 줄며 꺼집니다. 운전을 누르면 뉴스와 밝은 음악이 끊기지 않는 회선으로 이어집니다. 방송국 목록을 뒤지는 일은 앱이 대신합니다.",
	heroMeta: "iPhone · iPad · iOS 17.0 이상 · 무료",

	moodsBadge: "다섯 가지 상황",
	moodsTitle: "누르면 바로 소리가 납니다",
	moodsSub:
		"상황마다 무엇을 틀고 언제 끌지를 미리 담아 둡니다. 시각과 요일까지 함께 보기 때문에 같은 취침이라도 밤 열한 시와 새벽 세 시에 다른 채널이 나옵니다.",
	moods: [
		{ name: "취침", time: "45분 뒤 꺼짐" },
		{ name: "운전", time: "끄지 않음" },
		{ name: "공부", time: "90분 뒤 꺼짐" },
		{ name: "작업", time: "끄지 않음" },
		{ name: "기상", time: "30분 뒤 꺼짐" },
	],

	featBadge: "기능",
	featTitle: "라디오에 필요한 것만 담았습니다",
	featSub: "듣는 동안 화면을 다시 볼 일이 없게 만드는 것이 목표입니다.",
	features: [
		{
			ic: "01",
			h: "전 세계 인터넷 라디오",
			p: "나라·장르·언어로 찾고 이름으로 검색합니다. 응답하지 않는 방송은 자동으로 목록에서 빠지므로 눌렀는데 아무 소리도 안 나는 일이 줄어듭니다.",
		},
		{
			ic: "02",
			h: "팟캐스트",
			p: "인기 목록과 검색, 에피소드 재생을 담았습니다. 15초 되감기와 재생 속도 조절이 있고, 앱을 껐다 켜도 듣던 자리에서 이어집니다.",
		},
		{
			ic: "03",
			h: "자동 종료 타이머",
			p: "15·30·45·60·90분 중에 고르거나 직접 적습니다. 끝나는 순간 뚝 끊기지 않고 마지막 30초 동안 소리가 서서히 줄어듭니다.",
		},
		{
			ic: "04",
			h: "상황 프리셋",
			p: "채널·타이머·페이드아웃을 한 장에 담아 이름을 붙입니다. 소스를 자동 선택으로 두면 그때그때 어울리는 방송을 앱이 고릅니다.",
		},
		{
			ic: "05",
			h: "라디오 알람",
			p: "정해 둔 시각에 알림이 오고, 누르면 그 방송이 바로 시작됩니다. 요일별로 따로 맞출 수 있습니다.",
		},
		{
			ic: "06",
			h: "청취 기록",
			p: "무엇을 얼마나 들었는지 달마다 정리해 보여 줍니다. 이 기록은 기기 안에만 남고 서버로 가지 않습니다.",
		},
	],

	howBadge: "쓰는 법",
	howTitle: "세 번 누르면 끝납니다",
	howSub: "처음 열었을 때 프리셋 다섯 개가 이미 들어 있습니다. 그대로 써도 되고 고쳐도 됩니다.",
	rows: [
		{ k: "1. 상황을 고른다", v: "프리셋 탭에서 취침·운전·공부·작업·기상 가운데 하나를 누릅니다. 소스를 미리 정해 두지 않았다면 앱이 지금 시각에 맞는 방송을 골라 바로 틉니다." },
		{ k: "2. 주머니에 넣는다", v: "화면을 꺼도 재생이 이어집니다. 잠금화면과 제어 센터에서 멈추고 다시 틀 수 있고, 전화를 받고 끊으면 듣던 자리로 돌아옵니다." },
		{ k: "3. 잊는다", v: "타이머가 끝나면 소리가 서서히 줄며 꺼집니다. 다음 날 같은 프리셋을 누르면 자주 넘긴 채널은 아래로 내려가 있습니다." },
	],

	privBadge: "개인정보",
	privTitle: "무엇을 들었는지는 기기 밖으로 나가지 않습니다",
	privSub:
		"계정도 로그인도 없습니다. 프리셋·즐겨찾기·청취 기록은 전부 기기 안에 저장되고 서버로 보내지 않습니다. 추천을 내 기록에 맞춰 다시 세우는 계산도 기기 안에서 합니다.",

	faqBadge: "자주 묻는 것",
	faqTitle: "먼저 물어보신 것들",
	faqs: [
		{
			q: "무료인가요?",
			a: "무료입니다. 목록과 기록 화면에 배너 광고가 있고, 재생 화면과 알람이 울려 열린 화면에는 광고를 두지 않습니다. 광고를 봐야 열리는 기능도 없습니다.",
		},
		{
			q: "어떤 방송국이 나오나요?",
			a: "radio-browser 에 등록된 전 세계 인터넷 라디오를 씁니다. 한국은 백여 곳이고 주요 나라의 인기 방송을 함께 담아 수천 곳 규모입니다. 목록은 여섯 시간마다 갱신됩니다.",
		},
		{
			q: "화면을 끄면 멈추나요?",
			a: "이어집니다. 잠금화면과 제어 센터에 지금 나오는 채널과 곡명이 표시되고 거기서 멈추고 다시 틀 수 있습니다.",
		},
		{
			q: "인터넷 없이 들을 수 있나요?",
			a: "들을 수는 없습니다. 인터넷 라디오는 실시간으로 받는 소리라 연결이 필요합니다. 다만 방송국 목록은 저장해 두기 때문에 연결이 끊겨도 목록은 그대로 보입니다.",
		},
		{
			q: "곡명이 안 보이는 방송이 있습니다",
			a: "방송국이 곡 정보를 함께 보내는 경우에만 표시됩니다. 보내지 않는 곳이 꽤 있어서 그럴 때는 채널 이름만 나옵니다.",
		},
		{
			q: "알람이 무음 모드에서도 울리나요?",
			a: "울리지 않습니다. iOS 알림은 무음 스위치와 벨소리 볼륨을 따릅니다. 알람으로 쓰실 때는 무음을 풀어 두셔야 합니다.",
		},
	],

	ctaTitle: "오늘 밤에 틀 것부터 정해 두세요",
	ctaSub: "취침 프리셋 하나면 나머지는 앱이 합니다.",

	footerNote: "만든 사람",
	footerPrivacy: "개인정보처리방침",
	footerSupport: "문의",
	footerContact: "메일",
	footerMore: "같은 사람이 만든 다른 것",

	privacyTitle: "개인정보처리방침",
	privacyUpdated: "2026년 9월 24일",

	supportTitle: "문의와 도움말",
	supportUpdated: "2026년 9월 24일",
};

const EN: Copy = {
	htmlLang: "en",
	title: "zeroPlayer — internet radio and podcasts that match what you are doing",
	desc:
		"Sleep, driving, study, work, wake up. Pick the situation and a fitting internet radio station or podcast starts right away, then fades out and stops when your timer runs down. Free for iPhone and iPad.",
	keywords:
		"internet radio,radio app,podcast player,sleep timer,fade out,radio alarm,iphone radio,zeroPlayer",

	navFeatures: "Features",
	navHow: "How it works",
	navPrivacy: "Privacy",
	navFaq: "FAQ",
	navSupport: "Support",
	langSwitchLabel: "KO",

	badgeAria: "Download zeroPlayer on the App Store",
	badgeSmall: "Download on the",
	badgeBig: "App Store",

	heroTitle: "Choose what you are doing, not what to listen to",
	heroSub:
		"Tap Sleep and a quiet station starts, then fades out and stops 45 minutes later. Tap Driving and you get news and upbeat music on a connection picked for not dropping out. The app does the digging through station lists.",
	heroMeta: "iPhone · iPad · iOS 17.0 or later · Free",

	moodsBadge: "Five situations",
	moodsTitle: "One tap and sound starts",
	moodsSub:
		"Each situation already holds what to play and when to stop. The time of day and the day of the week count too, so Sleep at 11pm and Sleep at 3am give you different stations.",
	moods: [
		{ name: "Sleep", time: "stops in 45 min" },
		{ name: "Driving", time: "no timer" },
		{ name: "Study", time: "stops in 90 min" },
		{ name: "Work", time: "no timer" },
		{ name: "Wake up", time: "stops in 30 min" },
	],

	featBadge: "Features",
	featTitle: "Only what a radio really needs",
	featSub: "The aim is that you never have to look at the screen again while listening.",
	features: [
		{
			ic: "01",
			h: "Internet radio worldwide",
			p: "Browse by country, genre and language, or search by name. Stations that stop responding drop out of the list on their own, so fewer taps end in silence.",
		},
		{
			ic: "02",
			h: "Podcasts",
			p: "Charts, search and episode playback. Skip back 15 seconds, change the speed, and pick up where you left off after closing the app.",
		},
		{
			ic: "03",
			h: "Sleep timer",
			p: "15, 30, 45, 60 or 90 minutes, or type your own. Instead of cutting off, the volume slides down over the last 30 seconds.",
		},
		{
			ic: "04",
			h: "Situation presets",
			p: "A station, a timer and a fade-out saved together under a name. Leave the source on automatic and the app picks something fitting each time.",
		},
		{
			ic: "05",
			h: "Radio alarm",
			p: "A notification arrives at the time you set, and tapping it starts that station. Each weekday can be set separately.",
		},
		{
			ic: "06",
			h: "Listening history",
			p: "A monthly summary of what you listened to and for how long. It stays on the device and is never sent to a server.",
		},
	],

	howBadge: "How it works",
	howTitle: "Three taps and you are done",
	howSub: "Five presets are already there the first time you open the app. Use them as they are or change them.",
	rows: [
		{ k: "1. Pick a situation", v: "On the Presets tab, tap Sleep, Driving, Study, Work or Wake up. If you have not chosen a station yourself, the app picks one that suits the current hour and starts it." },
		{ k: "2. Put the phone away", v: "Playback continues with the screen off. You can pause and resume from the lock screen and Control Center, and after a phone call it returns to where it was." },
		{ k: "3. Forget about it", v: "When the timer ends the volume slides down and playback stops. Tap the same preset tomorrow and the stations you keep skipping have moved down the list." },
	],

	privBadge: "Privacy",
	privTitle: "What you listen to never leaves your device",
	privSub:
		"No account, no sign-in. Presets, favourites and listening history are stored on the device and never sent to a server. Even the reordering that adapts recommendations to your history is computed on the device.",

	faqBadge: "FAQ",
	faqTitle: "Questions people asked first",
	faqs: [
		{
			q: "Is it free?",
			a: "Yes. There are banner ads on the list and history screens, and none on the playback screen or on the screen an alarm opens. No feature is locked behind watching an ad.",
		},
		{
			q: "Which stations are available?",
			a: "Internet radio stations registered with radio-browser. Around a hundred in Korea plus the popular stations of major countries, a few thousand in total. The list refreshes every six hours.",
		},
		{
			q: "Does it stop when the screen turns off?",
			a: "No. The current station and track title appear on the lock screen and in Control Center, and you can pause and resume from there.",
		},
		{
			q: "Can I listen offline?",
			a: "Not listen, no. Internet radio is sound received in real time, so it needs a connection. Station lists are cached, though, so the list still appears when you are offline.",
		},
		{
			q: "Some stations show no track title",
			a: "The title only shows when the station sends it along with the audio. A fair number do not, and then you see the station name alone.",
		},
		{
			q: "Will the alarm sound in silent mode?",
			a: "No. iOS notifications follow the silent switch and the ringer volume. Turn silent mode off if you rely on the alarm.",
		},
	],

	ctaTitle: "Decide tonight's listening now",
	ctaSub: "One Sleep preset, and the app handles the rest.",

	footerNote: "About the developer",
	footerPrivacy: "Privacy Policy",
	footerSupport: "Support",
	footerContact: "Email",
	footerMore: "Other things by the same person",

	privacyTitle: "Privacy Policy",
	privacyUpdated: "24 September 2026",

	supportTitle: "Support",
	supportUpdated: "24 September 2026",
};

export const COPY: Record<Lang, Copy> = { ko: KO, en: EN };
