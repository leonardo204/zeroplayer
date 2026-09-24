/**
 * 앱에 그대로 보여 주는 문구의 언어별 표.
 *
 * 앱 화면 문구는 앱의 문자열 카탈로그가 맡고, 여기서는 **서버가 만드는 문구**만 다룬다 —
 * 추천 이유, 태그 이름, 알람 알림 본문이다.
 * 방송국 이름과 한국 지상파 편성표는 고유명사라 원문을 그대로 내보낸다.
 */

export type Lang = 'ko' | 'en'

export function readLang(raw: string | null | undefined): Lang {
  return (raw || '').trim().toLowerCase().startsWith('en') ? 'en' : 'ko'
}

/** 표준 태그를 사람이 읽는 이름으로. 표에 없으면 태그를 그대로 쓴다. */
const TAG_LABEL: Record<Lang, Record<string, string>> = {
  ko: {
    ambient: '앰비언트', chillout: '칠아웃', lounge: '라운지', newage: '뉴에이지',
    classical: '클래식', jazz: '재즈', instrumental: '연주곡', soundtrack: '사운드트랙',
    blues: '블루스', soul: '소울', news: '뉴스', talk: '토크', pop: '팝', rock: '록',
    top40: '최신 인기곡', dance: '댄스', kpop: '케이팝', jpop: '제이팝', cpop: '중국 음악',
    hiphop: '힙합', culture: '교양', oldies: '옛 노래', electronic: '일렉트로닉',
    house: '하우스', techno: '테크노', funk: '펑크', indie: '인디', latin: '라틴',
    world: '월드뮤직', country: '컨트리', metal: '메탈', reggae: '레게', folk: '포크',
    rnb: '알앤비', ballad: '발라드', gospel: '가스펠', christian: '기독교', religion: '종교',
    comedy: '코미디', anime: '애니메이션', sports: '스포츠', punk: '펑크록',
    traditional: '전통음악', education: '교육', live: '라이브', trot: '트로트',
  },
  en: {
    ambient: 'ambient', chillout: 'chillout', lounge: 'lounge', newage: 'new age',
    classical: 'classical', jazz: 'jazz', instrumental: 'instrumental', soundtrack: 'soundtrack',
    blues: 'blues', soul: 'soul', news: 'news', talk: 'talk', pop: 'pop', rock: 'rock',
    top40: 'top 40', dance: 'dance', kpop: 'K-pop', jpop: 'J-pop', cpop: 'C-pop',
    hiphop: 'hip hop', culture: 'culture', oldies: 'oldies', electronic: 'electronic',
    house: 'house', techno: 'techno', funk: 'funk', indie: 'indie', latin: 'latin',
    world: 'world', country: 'country', metal: 'metal', reggae: 'reggae', folk: 'folk',
    rnb: 'R&B', ballad: 'ballad', gospel: 'gospel', christian: 'christian', religion: 'religion',
    comedy: 'comedy', anime: 'anime', sports: 'sports', punk: 'punk',
    traditional: 'traditional', education: 'education', live: 'live', trot: 'trot',
  },
}

export function tagLabel(tag: string, lang: Lang): string {
  return TAG_LABEL[lang][tag] ?? tag
}

/** 상황 이름과, 규칙이 무엇으로 걸렀는지 적는 한 줄. */
export const SITUATION_TEXT: Record<Lang, Record<string, { label: string; note: string }>> = {
  ko: {
    sleep: { label: '취침', note: '잔잔한 음악만 남기고 뉴스·토크는 뺐다' },
    commute: { label: '운전', note: '말과 활기 있는 음악을 함께 두고 끊김이 적은 쪽을 앞에 놨다' },
    study: { label: '공부', note: '가사와 말이 적은 채널만 남겼다' },
    work: { label: '작업', note: '배경으로 깔아 두기 좋은 쪽을 골랐다' },
    wake: { label: '기상', note: '아침에 정신이 드는 쪽으로 뉴스와 밝은 음악을 골랐다' },
  },
  en: {
    sleep: { label: 'Sleep', note: 'quiet music only, with news and talk left out' },
    commute: { label: 'Driving', note: 'talk and upbeat music together, steadier streams first' },
    study: { label: 'Study', note: 'channels with few lyrics and little talk' },
    work: { label: 'Work', note: 'channels that sit well in the background' },
    wake: { label: 'Wake up', note: 'news and bright music to wake up to' },
  },
}

export const DAYPART_LABEL: Record<Lang, Record<string, string>> = {
  ko: { '06-09': '이른 아침', '09-12': '오전', '12-18': '낮', '18-22': '저녁', '22-02': '밤', '02-06': '새벽' },
  en: { '06-09': 'early morning', '09-12': 'morning', '12-18': 'afternoon', '18-22': 'evening', '22-02': 'night', '02-06': 'late night' },
}

export const DAY_TYPE_LABEL: Record<Lang, Record<string, string>> = {
  ko: { weekday: '평일', weekend: '주말' },
  en: { weekday: 'a weekday', weekend: 'a weekend' },
}

/** 규칙만으로 뽑았을 때 붙이는 문구를 만든다. */
export function ruleReasonText(
  lang: Lang,
  situation: string,
  matchedTags: string[],
  global: boolean,
): string {
  const t = SITUATION_TEXT[lang][situation]
  const names = matchedTags.map((tag) => tagLabel(tag, lang))
  if (lang === 'en') {
    const joined = names.join(' and ')
    // 'a' 와 'an' 은 뒤에 오는 소리로 갈린다. 태그 이름이 모음으로 시작하면 an 이다.
    const article = /^[aeiou]/i.test(joined) ? 'An' : 'A'
    const head = names.length ? `${article} ${joined} channel.` : `Nothing rules this out for ${t.label}.`
    const tail = global
      ? ` Picked ${t.note}. Widened to other countries because there were few local ones.`
      : ` Picked ${t.note}.`
    return head + tail
  }
  const head = names.length ? names.join('·') + ' 채널이다.' : t.label + '에서 뺄 이유가 없는 채널이다.'
  const tail = global ? ' ' + t.note + '. 국내 후보가 적어 다른 나라까지 넓혔다.' : ' ' + t.note + '.'
  return head + tail
}

/** 타이머 길이에 맞춰 고른 에피소드에 붙이는 문구. */
export function timerEpisodeReason(lang: Lang, timerMinutes: number, runtimeMinutes: number): string {
  return lang === 'en'
    ? `A ${runtimeMinutes}-minute episode that fits the ${timerMinutes}-minute sleep timer.`
    : `자동 종료 ${timerMinutes}분에 맞는 ${runtimeMinutes}분 에피소드다.`
}

/** 알람 알림에 쓰는 고정 문구. */
export const ALARM_TEXT: Record<Lang, { title: string; savedStation: string; body: (what: string) => string }> = {
  ko: {
    title: '알람',
    savedStation: '저장해 둔 방송',
    body: (what) => `${what} 을(를) 재생할 준비가 됐습니다. 눌러서 시작하세요.`,
  },
  en: {
    title: 'Alarm',
    savedStation: 'a saved station',
    body: (what) => `${what} is ready to play. Tap to start.`,
  },
}
