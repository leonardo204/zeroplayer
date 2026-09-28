/**
 * 랜딩과 정책 문서에 들어가는 글. 한국어가 기준이고 영어는 같은 내용을 옮긴 것이다.
 * 화면 구조는 render.ts, 스타일은 styles.ts 가 맡는다.
 *
 * 여기 적힌 숫자와 동작은 앱·서버 코드에서 확인한 값이다. 앱을 고치면 이 파일도 함께
 * 고친다. 출처를 옆에 적어 두었다.
 *
 *   프리셋 다섯 개와 타이머 값   Sources/Core/Persistence/Models/Preset.swift (defaults)
 *   타이머 선택값 15·30·45·60·90 Sources/Features/Player/SleepTimerSheet.swift
 *   페이드아웃 30초              Preset.defaults() 의 fadeOutSeconds
 *   되감기 15초·건너뛰기 30초    Sources/Core/Player/AudioPlayerService.swift
 *   재생 속도 1.0·1.2·1.5·2.0    같은 파일 rateChoices
 *   알람음 20곡                  Sources/Core/Notifications/AlarmSound.swift
 *   알람 2분 간격 4번            Sources/Core/Notifications/AlarmKitScheduler.swift
 *   방송국·팟캐스트 수           GET https://ai.zerolive.co.kr/zp/v1/health
 *   목록 갱신 6시간·점검 매시    server/wrangler.toml 의 crons
 *
 * 지상파 채널은 여기에 적지 않는다. 앱 안에서 따로 열어야 보이는 것이라, 소개 페이지에
 * 올려 두면 열지 않은 사람에게도 목록을 알리는 셈이 된다.
 */
export type Lang = "ko" | "en";

/** 상황 한 줄. 아이콘 키는 render.ts 의 GLYPH 와 맞춘다. */
export interface Mood {
	glyph: "moon" | "car" | "book" | "laptop" | "sunrise";
	name: string;
	desc: string;
	timer: string;
}
export interface Def {
	k: string;
	v: string;
	sub?: string;
}
export interface Shot {
	file: string;
	title: string;
	caption: string;
}
export interface Tone {
	name: string;
	by: string;
}
export interface Faq {
	q: string;
	a: string;
}
export interface Spec {
	k: string;
	v: string;
}

export interface Copy {
	htmlLang: string;
	title: string;
	desc: string;
	keywords: string;

	navFeatures: string;
	navAlarm: string;
	navPrivacy: string;
	navFaq: string;
	navSupport: string;
	langSwitch: string;

	badgeAria: string;
	badgeSmall: string;
	badgeBig: string;

	heroTitle: string;
	heroLede: string;
	heroSpec: string[];
	heroShotAlt: string;

	moodsTitle: string;
	moodsLede: string;
	moods: Mood[];
	moodsNote: string;

	shotsTitle: string;
	shotsLede: string;
	shots: Shot[];

	featTitle: string;
	featLede: string;
	defs: Def[];

	alarmTitle: string;
	alarmLede: string;
	alarmNote: string;
	tonesLabel: string;
	tones: Tone[];
	alarmShotAlt: string;

	privTitle: string;
	privLede: string;
	privLink: string;

	specTitle: string;
	specs: Spec[];

	faqTitle: string;
	faqs: Faq[];

	getTitle: string;
	getLede: string;

	footerAbout: string;
	footerPrivacy: string;
	footerSupport: string;
	footerContact: string;
	footerMore: string;
	backHome: string;

	privacyTitle: string;
	privacyUpdated: string;
	supportTitle: string;
	supportUpdated: string;
}

const KO: Copy = {
	htmlLang: "ko",
	title: "zeroPlayer — 상황을 고르면 방송이 정해지는 라디오",
	desc:
		"취침·운전·공부·작업·기상 가운데 하나를 누르면 그 시각에 맞는 인터넷 라디오나 팟캐스트가 바로 재생되고, 정해 둔 시간이 지나면 소리가 서서히 줄며 꺼집니다. 아이폰·아이패드 무료 앱.",
	keywords:
		"인터넷 라디오,라디오 앱,팟캐스트,수면 타이머,취침 타이머,자동 종료,라디오 알람,클래식 알람음,아이폰 라디오,zeroPlayer",

	navFeatures: "기능",
	navAlarm: "알람",
	navPrivacy: "개인정보",
	navFaq: "자주 묻는 것",
	navSupport: "문의",
	langSwitch: "English",

	badgeAria: "App Store 에서 zeroPlayer 내려받기",
	badgeSmall: "Download on the",
	badgeBig: "App Store",

	heroTitle: "무엇을 들을지 고르는 대신,\n지금 무엇을 하는지만 고릅니다",
	heroLede:
		"방송국이 오천 곳 가까이 있어도 고르다 지쳐 앱을 닫게 됩니다. zeroPlayer 는 고르는 단계를 없앴습니다. ‘취침’을 누르면 잔잔한 채널이 흐르고 45분 뒤 소리가 서서히 줄며 꺼집니다.",
	heroSpec: ["아이폰 · 아이패드", "iOS 17 이상", "무료", "한국어 · English"],
	heroShotAlt: "프리셋 화면. 취침·운전·공부·작업·기상 카드가 놓여 있다",

	moodsTitle: "상황 다섯 개가 처음부터 들어 있습니다",
	moodsLede:
		"카드를 한 번 누르면 방송이 정해지고, 재생이 시작되고, 타이머까지 함께 걸립니다. 방송국을 직접 지정해 두어도 되고, 그때그때 골라 오게 두어도 됩니다.",
	moods: [
		{ glyph: "moon", name: "취침", desc: "잔잔한 채널을 틀고 페이드아웃으로 끝냅니다", timer: "45분" },
		{ glyph: "car", name: "운전", desc: "뉴스와 밝은 음악. 끊기지 않는 회선을 먼저 봅니다", timer: "타이머 없음" },
		{ glyph: "book", name: "공부", desc: "가사 없는 음악 쪽으로 기울여 고릅니다", timer: "90분" },
		{ glyph: "laptop", name: "작업", desc: "길게 틀어 두기 좋은 채널", timer: "타이머 없음" },
		{ glyph: "sunrise", name: "기상", desc: "아침 뉴스와 밝은 채널", timer: "30분" },
	],
	moodsNote:
		"같은 ‘취침’이라도 밤 열한 시와 새벽 세 시에 다른 방송이 나옵니다. 시각·요일·나라를 함께 보고 고르기 때문입니다. 들은 기록이 쌓이면 순서가 내 쪽으로 옮겨 옵니다 — 자주 듣던 방송은 위로, 삼십 초 안에 넘긴 방송은 아래로. 이 계산은 기기 안에서 합니다.",

	shotsTitle: "화면",
	shotsLede: "실제 앱 화면입니다. 꾸미거나 다시 그린 것이 아닙니다.",
	shots: [
		{
			file: "recommend",
			title: "추천",
			caption: "상황을 고르면 지금 시각에 맞는 목록이 섭니다. 내 기록 때문에 위로 올라온 항목에는 표시가 붙습니다.",
		},
		{
			file: "player",
			title: "재생",
			caption: "방송국이 곡 정보를 함께 보내면 곡 이름과 앨범 그림이 나옵니다. 잠금화면과 제어 센터에도 같은 것이 보입니다.",
		},
		{
			file: "timer",
			title: "자동 종료",
			caption: "15·30·45·60·90분 가운데 고르거나 직접 적습니다. 남은 시간이 보이고 10분씩 늘릴 수 있습니다.",
		},
	],

	featTitle: "듣는 동안 화면을 다시 볼 일이 없게",
	featLede: "라디오 앱에 정말 필요한 것만 담았습니다. 잠긴 기능도, 구독도 없습니다.",
	defs: [
		{
			k: "전 세계 인터넷 라디오",
			v: "나라·장르·언어로 찾고 이름으로 검색합니다. 사천구백여 곳이 목록에 올라 있습니다.",
			sub: "응답하지 않는 방송은 서버가 매시 점검해 목록에서 빼고, 같은 방송이 여러 줄로 올라와 있으면 하나로 묶어 대표 한 줄만 보여 줍니다. 목록은 여섯 시간마다 갱신됩니다.",
		},
		{
			k: "팟캐스트",
			v: "인기 목록과 검색이 있고 이백여 개 채널의 에피소드 만 편 넘게 들을 수 있습니다.",
			sub: "진행 바, 15초 되감기, 30초 건너뛰기, 1.0·1.2·1.5·2.0배 속도. 앱을 껐다 켜도 듣던 자리에서 이어집니다.",
		},
		{
			k: "자동 종료 타이머",
			v: "끝나기 전 30초 동안 소리가 서서히 줄어듭니다. 뚝 끊기지 않습니다.",
			sub: "잠든 뒤 방송이 밤새 켜져 있는 일이 없습니다. 남은 시간에 10분을 더하거나 그 자리에서 취소할 수 있습니다.",
		},
		{
			k: "프리셋",
			v: "방송국·타이머·페이드아웃을 한 장에 담아 이름과 아이콘을 붙입니다.",
			sub: "처음부터 다섯 장이 들어 있습니다. 그대로 써도 되고 고쳐도 되고 새로 만들어도 됩니다.",
		},
		{
			k: "청취 기록",
			v: "이번 달에 몇 시간을 들었고 무엇을 가장 많이 들었는지 월간 리포트로 봅니다.",
			sub: "이 기록은 기기 안에만 남습니다. 서버로 보내지 않고 광고에도 쓰지 않습니다. 설정에서 언제든 지울 수 있습니다.",
		},
		{
			k: "화면을 꺼도 이어집니다",
			v: "잠금화면과 제어 센터에서 멈추고 다시 틀 수 있습니다.",
			sub: "전화를 받고 끊으면 재생이 이어집니다. 통화가 길어 방송이 끊겼으면 연결을 새로 엽니다. 이어폰이 빠지면 멈춥니다.",
		},
	],

	alarmTitle: "아침에는 라디오로 깨웁니다",
	alarmLede:
		"iOS 26 이상에서는 시스템 알람으로 걸립니다. 무음 모드와 집중 모드를 뚫고 울리고, 알람 화면에서 ‘방송 켜기’ 를 누르면 앱이 열리지 않은 채로 방송이 시작됩니다. 못 듣고 지나치지 않게 2분 간격으로 네 번 걸리고, 끄면 남은 것까지 함께 치웁니다.",
	alarmNote:
		"iOS 25 이하에서는 정해 둔 시각에 알림이 오고, 그것을 누르면 방송이 시작됩니다. 이때는 무음 모드를 풀어 두셔야 소리가 납니다.",
	tonesLabel: "알람음 스무 곡",
	tones: [
		{ name: "아침", by: "그리그" },
		{ name: "무반주 첼로 1번", by: "바흐" },
		{ name: "터키 행진곡", by: "모차르트" },
		{ name: "카논", by: "파헬벨" },
		{ name: "환희의 송가", by: "베토벤" },
		{ name: "사계 ‘봄’", by: "비발디" },
		{ name: "놀람 교향곡", by: "하이든" },
		{ name: "사랑의 인사", by: "엘가" },
	],
	alarmShotAlt: "알람 화면. 시각과 요일, 알람음과 음량을 정하고 있다",

	privTitle: "무엇을 들었는지는 기기 밖으로 나가지 않습니다",
	privLede:
		"계정도 로그인도 없습니다. 프리셋·즐겨찾기·청취 기록·팟캐스트를 듣던 위치는 전부 기기 안에 저장됩니다. 서버가 하는 일은 방송국과 팟캐스트 목록을 내려 주는 것뿐이고, 소리는 방송국 서버에서 곧바로 옵니다 — 개발자 서버를 거치지 않습니다.",
	privLink: "개인정보처리방침 읽기",

	specTitle: "사양",
	specs: [
		{ k: "기기", v: "아이폰, 아이패드" },
		{ k: "필요한 버전", v: "iOS 17.0 이상 · iPadOS 17.0 이상" },
		{ k: "가격", v: "무료. 구독·인앱 결제·보상형 광고가 없습니다" },
		{ k: "광고", v: "목록과 기록 화면에 배너. 재생 화면과 알람이 울려 열린 화면에는 없습니다" },
		{ k: "언어", v: "한국어, English" },
		{ k: "화면 테마", v: "시스템 설정에 따르거나 라이트·다크로 고정" },
		{ k: "계정", v: "없음. 로그인 화면도 없습니다" },
		{ k: "판", v: "2.1" },
	],

	faqTitle: "자주 묻는 것",
	faqs: [
		{
			q: "무료인가요?",
			a: "무료입니다. 목록과 기록 화면에 배너 광고가 있고, 재생 화면과 알람이 울려 열린 화면에는 광고를 두지 않습니다. 광고를 봐야 열리는 기능도 없고 구독이나 인앱 결제도 없습니다.",
		},
		{
			q: "알람이 무음 모드에서도 울리나요?",
			a: "iOS 26 이상이면 울립니다. 시스템 알람으로 걸리기 때문에 무음 스위치와 집중 모드를 뚫습니다. iOS 25 이하에서는 알림으로 오기 때문에 무음이면 소리가 나지 않습니다 — 그때는 무음을 풀어 두셔야 합니다.",
		},
		{
			q: "알람 소리는 고를 수 있나요?",
			a: "기본 알람음과 고전 멜로디 스무 곡 가운데 고릅니다. 바흐 무반주 첼로, 그리그 아침, 모차르트 터키 행진곡 같은 곡이고, 저작권이 끝난 악곡을 직접 연주해 담은 것입니다. 음량과 ‘점점 크게’ 도 알람마다 따로 맞춥니다.",
		},
		{
			q: "어떤 방송국이 나오나요?",
			a: "radio-browser 에 등록된 전 세계 인터넷 라디오를 씁니다. 지금 사천구백여 곳이 목록에 올라 있고, 나라·장르·언어로 좁혀 볼 수 있습니다. 응답하지 않는 방송은 매시 점검해서 빼기 때문에 눌렀는데 아무 소리도 안 나는 일이 줄어듭니다.",
		},
		{
			q: "화면을 끄면 멈추나요?",
			a: "이어집니다. 잠금화면과 제어 센터에 지금 나오는 채널과 곡 이름이 보이고 거기서 멈추고 다시 틀 수 있습니다. 전화를 받고 끊으면 재생이 이어집니다.",
		},
		{
			q: "인터넷 없이 들을 수 있나요?",
			a: "들을 수는 없습니다. 인터넷 라디오는 실시간으로 받는 소리라 연결이 필요합니다. 다만 방송국 목록은 기기에 저장해 두기 때문에 연결이 끊겨도 목록은 그대로 보입니다.",
		},
		{
			q: "곡 이름이 안 보이는 방송이 있습니다",
			a: "방송국이 곡 정보를 소리와 함께 보내는 경우에만 표시됩니다. 보내지 않는 곳이 꽤 있어서 그럴 때는 채널 이름만 나옵니다. 앱이 알아낼 방법이 없는 부분입니다.",
		},
		{
			q: "들은 기록이 서버로 갑니까?",
			a: "가지 않습니다. 무엇을 얼마나 들었는지는 기기 안에만 남고, 추천 순서를 내 기록에 맞춰 다시 세우는 계산도 기기에서 합니다. 서버로 가는 값은 앱을 처음 열 때 만드는 무작위 식별자, 앱 판 번호, 찾는 조건, 그리고 재생이 실패한 방송국 번호뿐입니다.",
		},
	],

	getTitle: "오늘 밤에 틀 것부터 정해 두세요",
	getLede: "취침 프리셋 하나를 눌러 두면 나머지는 앱이 합니다.",

	footerAbout: "만든 사람",
	footerPrivacy: "개인정보처리방침",
	footerSupport: "문의",
	footerContact: "메일",
	footerMore: "같은 사람이 만든 다른 것",
	backHome: "← 소개 페이지로",

	privacyTitle: "개인정보처리방침",
	privacyUpdated: "2026년 9월 28일",
	supportTitle: "문의와 도움말",
	supportUpdated: "2026년 9월 28일",
};

const EN: Copy = {
	htmlLang: "en",
	title: "zeroPlayer — pick the moment, the station follows",
	desc:
		"Tap one of five moments — sleep, driving, study, work, waking up — and a fitting internet radio station or podcast starts right away, then fades out and stops when your timer runs down. Free for iPhone and iPad.",
	keywords:
		"internet radio,radio app,podcast player,sleep timer,fade out,radio alarm,classical alarm sounds,iphone radio,zeroPlayer",

	navFeatures: "Features",
	navAlarm: "Alarm",
	navPrivacy: "Privacy",
	navFaq: "FAQ",
	navSupport: "Support",
	langSwitch: "한국어",

	badgeAria: "Download zeroPlayer on the App Store",
	badgeSmall: "Download on the",
	badgeBig: "App Store",

	heroTitle: "Choose what you are doing,\nnot what to listen to",
	heroLede:
		"With close to five thousand stations on the list, the usual outcome is that you scroll, fail to decide, and close the app. zeroPlayer removes the choosing step. Tap Sleep and a quiet station starts, then fades out and stops 45 minutes later.",
	heroSpec: ["iPhone · iPad", "iOS 17 or later", "Free", "한국어 · English"],
	heroShotAlt: "The presets screen, showing cards for sleep, driving, study, work and waking up",

	moodsTitle: "Five moments are there from the start",
	moodsLede:
		"One tap on a card settles the station, starts playback and sets the timer. You can pin a station to a preset yourself, or leave it for the app to pick each time.",
	moods: [
		{ glyph: "moon", name: "Sleep", desc: "A quiet station, ended by a fade-out", timer: "45 min" },
		{ glyph: "car", name: "Driving", desc: "News and upbeat music, weighted towards connections that hold", timer: "no timer" },
		{ glyph: "book", name: "Study", desc: "Leans towards music without lyrics", timer: "90 min" },
		{ glyph: "laptop", name: "Work", desc: "Stations that hold up for hours", timer: "no timer" },
		{ glyph: "sunrise", name: "Wake up", desc: "Morning news and bright stations", timer: "30 min" },
	],
	moodsNote:
		"Sleep at 11pm and Sleep at 3am give you different stations, because the pick takes the hour, the weekday and your country into account. As listening adds up the order shifts towards you — stations you return to move up, ones you skipped inside thirty seconds move down. That reordering is computed on the device.",

	shotsTitle: "Screens",
	shotsLede: "Actual screenshots from the app, not mock-ups.",
	shots: [
		{
			file: "recommend",
			title: "For you",
			caption: "Pick a moment and the list is built for the current hour. Items pushed up by your own history are marked.",
		},
		{
			file: "player",
			title: "Playback",
			caption: "When a station sends track information, the title and cover art appear — on the lock screen and in Control Center too.",
		},
		{
			file: "timer",
			title: "Sleep timer",
			caption: "15, 30, 45, 60 or 90 minutes, or type your own. The remaining time shows, and you can add ten minutes at a time.",
		},
	],

	featTitle: "So you never look at the screen again while listening",
	featLede: "Only what a radio app really needs. Nothing locked, nothing to subscribe to.",
	defs: [
		{
			k: "Internet radio worldwide",
			v: "Browse by country, genre and language, or search by name. Around 4,900 stations are on the list.",
			sub: "Stations that stop responding are checked hourly and dropped, and where the same station appears several times it is folded into one entry. The list refreshes every six hours.",
		},
		{
			k: "Podcasts",
			v: "Charts and search, with more than ten thousand episodes across a couple of hundred shows.",
			sub: "Progress bar, skip back 15 seconds, skip forward 30, and 1.0×, 1.2×, 1.5× or 2.0× speed. Close the app and it picks up where you left off.",
		},
		{
			k: "Sleep timer",
			v: "The volume slides down over the last 30 seconds instead of cutting off.",
			sub: "Nothing is left playing all night after you fall asleep. You can add ten minutes to what is left, or cancel it on the spot.",
		},
		{
			k: "Presets",
			v: "A station, a timer and a fade-out saved together under a name and an icon.",
			sub: "Five are there when you first open the app. Use them as they are, change them, or make your own.",
		},
		{
			k: "Listening history",
			v: "A monthly report of how many hours you listened and what you played most.",
			sub: "It stays on the device. It is never sent to a server and never used for advertising. You can erase it from Settings at any time.",
		},
		{
			k: "Keeps playing with the screen off",
			v: "Pause and resume from the lock screen and Control Center.",
			sub: "After a phone call playback continues. If the call ran long enough to drop the stream, the connection is opened again. Unplugging headphones stops playback.",
		},
	],

	alarmTitle: "Wake up to the radio",
	alarmLede:
		"On iOS 26 and later it is scheduled as a system alarm. It rings through Silent mode and Focus, and tapping “Play radio” on the alarm screen starts the station without opening the app. So you don't sleep through it, the alarm is set four times two minutes apart; stopping it clears the rest.",
	alarmNote:
		"On iOS 25 and earlier a notification arrives at the time you set and tapping it starts the station. Silent mode has to be off for that one to make a sound.",
	tonesLabel: "Twenty alarm melodies",
	tones: [
		{ name: "Morning Mood", by: "Grieg" },
		{ name: "Cello Suite No. 1", by: "Bach" },
		{ name: "Turkish March", by: "Mozart" },
		{ name: "Canon", by: "Pachelbel" },
		{ name: "Ode to Joy", by: "Beethoven" },
		{ name: "Spring", by: "Vivaldi" },
		{ name: "Surprise Symphony", by: "Haydn" },
		{ name: "Salut d’Amour", by: "Elgar" },
	],
	alarmShotAlt: "The alarm screen, setting a time, the weekdays, the melody and its volume",

	privTitle: "What you listen to never leaves your device",
	privLede:
		"No account, no sign-in. Presets, favourites, listening history and your position in a podcast are all stored on the device. The server only supplies station and podcast lists; the audio comes straight from the broadcaster and never passes through the developer's server.",
	privLink: "Read the privacy policy",

	specTitle: "Details",
	specs: [
		{ k: "Devices", v: "iPhone, iPad" },
		{ k: "Requires", v: "iOS 17.0 or later · iPadOS 17.0 or later" },
		{ k: "Price", v: "Free. No subscription, no in-app purchase, no rewarded ads" },
		{ k: "Ads", v: "Banners on list and history screens. None on playback, none on a screen an alarm opened" },
		{ k: "Languages", v: "Korean, English" },
		{ k: "Appearance", v: "Follows the system, or pinned to light or dark" },
		{ k: "Account", v: "None. There is no sign-in screen" },
		{ k: "Version", v: "2.1" },
	],

	faqTitle: "Questions people ask",
	faqs: [
		{
			q: "Is it free?",
			a: "Yes. There are banner ads on the list and history screens, and none on the playback screen or on the screen an alarm opens. No feature is locked behind watching an ad, and there is no subscription or in-app purchase.",
		},
		{
			q: "Will the alarm sound in Silent mode?",
			a: "On iOS 26 and later, yes — it is scheduled as a system alarm, so it breaks through the silent switch and Focus. On iOS 25 and earlier it arrives as a notification, which follows Silent mode, so you need to turn Silent off for that one.",
		},
		{
			q: "Can I choose the alarm sound?",
			a: "You pick between the default alarm sound and twenty classical melodies — Bach's Cello Suite No. 1, Grieg's Morning Mood, Mozart's Turkish March and others. The compositions are in the public domain and the recordings were made for this app. Volume and a gradual fade-in are set per alarm.",
		},
		{
			q: "Which stations are available?",
			a: "Internet radio stations registered with radio-browser. Around 4,900 are on the list right now, and you can narrow by country, genre and language. Stations that stop responding are checked hourly and removed, so fewer taps end in silence.",
		},
		{
			q: "Does it stop when the screen turns off?",
			a: "No. The current station and track title appear on the lock screen and in Control Center, and you can pause and resume from there. After a phone call playback continues.",
		},
		{
			q: "Can I listen offline?",
			a: "Not listen, no. Internet radio is sound received in real time, so it needs a connection. Station lists are cached on the device, though, so the list still appears when you are offline.",
		},
		{
			q: "Some stations show no track title",
			a: "The title only appears when the station sends it along with the audio. A fair number do not, and then you see the station name alone. There is nothing the app can do to find it.",
		},
		{
			q: "Does my listening go to a server?",
			a: "No. What you played and for how long stays on the device, and the reordering that adapts recommendations to your history is computed there too. What does go to the server is a random identifier created when you first open the app, the app version, the query, and the id of a station that failed to play.",
		},
	],

	getTitle: "Start by deciding tonight's listening",
	getLede: "Set the Sleep preset once and the app handles the rest.",

	footerAbout: "About the developer",
	footerPrivacy: "Privacy Policy",
	footerSupport: "Support",
	footerContact: "Email",
	footerMore: "Other things by the same person",
	backHome: "← Back to the overview",

	privacyTitle: "Privacy Policy",
	privacyUpdated: "28 September 2026",
	supportTitle: "Support",
	supportUpdated: "28 September 2026",
};

export const COPY: Record<Lang, Copy> = { ko: KO, en: EN };
