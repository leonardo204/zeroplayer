# -*- coding: utf-8 -*-
"""기상용 멜로디 악보. 곡은 모두 저작권이 끝난 것이고 연주는 우리가 한다."""
import os, sys

STEP = {'C':0,'D':2,'E':4,'F':5,'G':7,'A':9,'B':11}
def m(name):
    p = 0; i = 1
    while i < len(name) and name[i] in '#b':
        p += 1 if name[i] == '#' else -1; i += 1
    return 12 * (int(name[i:]) + 1) + STEP[name[0]] + p

def seq(spb, notes, t0=0.0, slot=0, vel=96, legato=0.92, transpose=0):
    """notes: [(음이름 또는 None, 박)]. 되돌려주는 것은 (note 줄 목록, 끝난 시각)."""
    out, t = [], t0
    for n, beats in notes:
        d = beats * spb
        if n:
            for nm in (n if isinstance(n, (list, tuple)) else [n]):
                out.append((slot, t, d * legato, m(nm) + transpose, vel))
        t += d
    return out, t

def chords(spb, items, t0=0.0, slot=1, vel=52, legato=0.98):
    return seq(spb, items, t0, slot, vel, legato)

# ─────────────────────────────────────────────────────────── 곡별 악보
def grieg_morning():
    """Grieg, Peer Gynt 조곡 1번 '아침' (1875). E장조, 플루트."""
    spb = 60.0 / 108          # 8분음 기준
    A = [('G#5',1),('F#5',1),('E5',1),('C#5',1),('B4',1),('C#5',1),('E5',1),('F#5',1)]
    B = [('G#5',1),('B5',1),('A5',1),('F#5',1),('G#5',1),('E5',1),('F#5',1),('D#5',1)]
    C = [('E5',3),(None,1)]
    mel = A + A + B + C
    n1, end = seq(spb, mel, slot=0, vel=104)
    pad = [(['E3','B3','E4'],8),(['E3','B3','E4'],8),(['A3','C#4','E4'],4),(['B3','D#4','F#4'],4),
           (['E3','B3','E4'],4),(['E3','G#3','B3'],4)]
    n2, _ = chords(spb, pad, slot=1, vel=44)
    return dict(tempo_len=end, inst={0:(73,1.0,-0.12,6), 1:(48,0.48,0.12,9)}, notes=n1+n2, rev=26)

def bach_minuet():
    """Bach, 미뉴에트 G장조 BWV Anh.114 (1725). 오르골."""
    spb = 60.0 / 132
    mel = [('D5',1),('G4',.5),('A4',.5),('B4',.5),('C5',.5),
           ('D5',1),('G4',1),('G4',1),
           ('E5',1),('C5',.5),('D5',.5),('E5',.5),('F#5',.5),
           ('G5',1),('G4',1),('G4',1),
           ('C5',1),('D5',.5),('C5',.5),('B4',.5),('A4',.5),
           ('B4',1),('C5',.5),('B4',.5),('A4',.5),('G4',.5),
           ('F#4',1),('G4',.5),('A4',.5),('B4',.5),('G4',.5),
           ('B4',1),('A4',2)]
    n1, end = seq(spb, mel, slot=0, vel=100)
    bass = [(['G3','B3'],3),(['G3','D4'],3),(['C3','E3'],3),(['G3','B3'],3),
            (['C3','E3'],3),(['G3','B3'],3),(['D3','A3'],3),(['G3','D4'],3)]
    n2, _ = chords(spb, bass, slot=1, vel=50)
    return dict(tempo_len=end, inst={0:(10,1.0,0.0), 1:(8,0.40,0.0)}, notes=n1+n2, rev=18)

def bach_prelude():
    """Bach, 평균율 1권 전주곡 C장조 BWV 846 (1722). 첼레스타."""
    spb = 60.0 / 76 / 4      # 16분음
    bars = [(['C3','E3'],['G3','C4','E4']), (['C3','D3'],['A3','D4','F4']),
            (['B2','D3'],['G3','D4','F4']), (['C3','E3'],['G3','C4','E4']),
            (['C3','E3'],['A3','E4','A4']), (['C3','D3'],['F#3','A3','D4']),
            (['B2','D3'],['G3','D4','G4']), (['B2','C3'],['E3','G3','C4'])]
    notes, t = [], 0.0
    for lo, hi in bars:
        for nm in lo + hi:      # 첫 5개
            pass
        for half in range(2):
            tt = t + half * 8 * spb
            if half == 0:
                for i, nm in enumerate(lo):
                    notes.append((1, tt + i*spb, spb*14, m(nm), 62))
                base = tt + 2*spb
            else:
                base = tt
            for rep in range(2 if half else 1):
                for i, nm in enumerate(hi):
                    notes.append((0, base + (rep*3+i)*spb, spb*2.6, m(nm), 88))
        t += 16 * spb
    return dict(tempo_len=t, inst={0:(8,1.0,0.0), 1:(46,0.62,0.0)}, notes=notes, rev=30)

def beethoven_joy():
    """Beethoven, 교향곡 9번 '환희의 송가' (1824). 현과 호른."""
    spb = 60.0 / 112
    mel = [('F#5',1),('F#5',1),('G5',1),('A5',1),('A5',1),('G5',1),('F#5',1),('E5',1),
           ('D5',1),('D5',1),('E5',1),('F#5',1),('F#5',1.5),('E5',.5),('E5',2),
           ('F#5',1),('F#5',1),('G5',1),('A5',1),('A5',1),('G5',1),('F#5',1),('E5',1),
           ('D5',1),('D5',1),('E5',1),('F#5',1),('E5',1.5),('D5',.5),('D5',2)]
    n1, end = seq(spb, mel, slot=0, vel=100)
    harm = [(['D3','A3','D4'],4),(['A3','C#4','E4'],4),(['D3','F#3','A3'],4),(['A3','D4','F#4'],4),
            (['D3','A3','D4'],4),(['A3','C#4','E4'],4),(['G3','B3','D4'],2),(['A3','C#4','E4'],2),(['D3','A3','D4'],4)]
    n2, _ = chords(spb, harm, slot=1, vel=48)
    return dict(tempo_len=end, inst={0:(48,1.0,0.0,12), 1:(60,0.5,0.0,8)}, notes=n1+n2, rev=22)

def pachelbel_canon():
    """Pachelbel, 카논 D장조 (1700년경). 하프와 바이올린."""
    spb = 60.0 / 64
    bass_roots = ['D3','A2','B2','F#2','G2','D3','G2','A2']
    arp = {'D3':['D3','A3','D4'],'A2':['A2','E3','A3'],'B2':['B2','F#3','B3'],
           'F#2':['F#2','C#3','F#3'],'G2':['G2','D3','G3'],}
    notes, t = [], 0.0
    for cyc in range(2):
        for r in bass_roots:
            for i, nm in enumerate(arp[r]):
                notes.append((1, t + i*spb*0.5, spb*1.6, m(nm), 58))
            notes.append((1, t + spb*1.5, spb*0.5, m(arp[r][1]), 50))
            t += 2 * spb
    mel = [('F#5',2),('E5',2),('D5',2),('C#5',2),('B4',2),('A4',2),('B4',2),('C#5',2),
           ('D5',2),('C#5',2),('B4',2),('A4',2),('G4',2),('F#4',2),('G4',2),('E4',2)]
    n1, _ = seq(spb, mel, t0=4*spb, slot=0, vel=92)
    return dict(tempo_len=t, inst={0:(40,1.0,-0.1,10), 1:(46,0.78,0.1,4)}, notes=notes+n1, rev=28)

def vivaldi_spring():
    """Vivaldi, 사계 '봄' 1악장 (1725). 바이올린과 현."""
    spb = 60.0 / 108
    A = [('E5',.5),('E5',.5),('E5',1),('G#5',.5),('F#5',.5),('E5',1)]
    B = [('E5',.5),('F#5',.5),('G#5',.5),('F#5',.5),('E5',1),('B4',1)]
    C = [('E5',.5),('D#5',.5),('E5',.5),('F#5',.5),('G#5',1),('B5',1)]
    mel = A + A + B + C + A + [('E5',2),(None,2)]
    n1, end = seq(spb, mel, slot=0, vel=102)
    harm = [(['E3','B3','E4'],4),(['E3','B3','E4'],4),(['B3','D#4','F#4'],4),
            (['E3','G#3','B3'],4),(['E3','B3','E4'],4),(['E3','B3','E4'],4)]
    n2, _ = chords(spb, harm, slot=1, vel=46)
    return dict(tempo_len=end, inst={0:(40,1.0,0.0,12), 1:(48,0.5,0.0,10)}, notes=n1+n2, rev=24)

def mozart_turca():
    """Mozart, 피아노 소나타 11번 3악장 '터키 행진곡' (1783). 피아노."""
    spb = 60.0 / 120 / 2     # 16분음
    mel = [('B4',1),('A4',1),('G#4',1),('A4',1),('C5',2),('E5',2),
           ('D5',1),('C5',1),('B4',1),('C5',1),('E5',2),('A5',2),
           ('F5',1),('E5',1),('D#5',1),('E5',1),('B5',2),('E5',2),
           ('A5',1),('G5',1),('F5',1),('E5',1),('D5',1),('C5',1),('B4',1),('A4',1),
           ('G#4',2),('A4',2),('B4',2),('C5',2),('A4',4)]
    n1, end = seq(spb, mel, slot=0, vel=104, legato=0.85)
    bass = [(['A2','E3'],4),(['A2','E3'],4),(['A2','E3'],4),(['A2','E3'],4),
            (['E2','B2'],4),(['E2','B2'],4),(['A2','E3'],8),(['E2','E3'],4),(['A2','A3'],4)]
    n2, _ = chords(spb, bass, slot=1, vel=58, legato=0.8)
    return dict(tempo_len=end, inst={0:(0,1.0,0.0), 1:(0,0.66,0.0)}, notes=n1+n2, rev=16)

def mozart_nacht():
    """Mozart, 세레나데 13번 '아이네 클라이네 나흐트무지크' (1787). 현악 합주."""
    spb = 60.0 / 132
    mel = [('G4',1),('D4',1),('G4',.5),('D4',.5),('G4',.5),('D4',.5),
           ('G4',.5),('B4',.5),('D5',1),(None,1),
           ('D5',1),('A4',1),('D5',.5),('A4',.5),('D5',.5),('A4',.5),
           ('D5',.5),('F#5',.5),('A5',1),(None,1),
           ('A5',.5),('G5',.5),('F#5',.5),('G5',.5),('A5',1),('B5',1),('A5',2)]
    n1, end = seq(spb, mel, slot=0, vel=102, legato=0.82)
    harm = [(['G3','D4'],4),(['G3','B3'],4),(['D3','A3'],4),(['D3','F#3'],4),(['G3','D4'],4),(['G3','B3'],4)]
    n2, _ = chords(spb, harm, slot=1, vel=46)
    return dict(tempo_len=end, inst={0:(48,1.0,0.0,11), 1:(49,0.52,0.0,8)}, notes=n1+n2, rev=22)

# ══════════════════════════════════════════════ 09~20 (두 번째 묶음)

def bach_cello1():
    """Bach, 무반주 첼로 조곡 1번 전주곡 BWV 1007 (1720년경). 첼로 한 대."""
    u = 60.0 / 76 / 4                      # 16분
    bars = [
        ['G2','D3','B3','A3','B3','D3','B3','D3'],   # G
        ['G2','E3','C4','B3','C4','E3','C4','E3'],   # C/G
        ['G2','F#3','C4','B3','C4','F#3','C4','F#3'],# D7/G
        ['G2','D3','B3','A3','B3','D3','B3','D3'],   # G
    ]
    notes, t = [], 0.0
    for cyc in range(2):                   # 두 바퀴. 두 번째는 조금 세게
        for bar in bars:
            for _ in range(2):             # 한 마디 안에서 같은 꼴을 두 번
                for i, nm in enumerate(bar):
                    vel = 86 + cyc * 8 + (12 if i == 0 else 0)
                    notes.append((0, t, u * 0.94, m(nm), vel))
                    t += u
    return dict(tempo_len=t, inst={0: (42, 1.0, 0.0, 8)}, notes=notes, rev=34)


def beethoven_elise():
    """Beethoven, 엘리제를 위하여 WoO 59 (1810). 피아노."""
    u = 60.0 / 72 / 4
    run = [('E5',1),('D#5',1),('E5',1),('D#5',1),('E5',1),('B4',1),('D5',1),('C5',1)]
    rh = run + [('A4',6)] \
       + [('C4',1),('E4',1),('A4',1),('B4',6)] \
       + [('E4',1),('G#4',1),('B4',1),('C5',6)] \
       + run + [('A4',6)]
    n1, end = seq(u, rh, slot=0, vel=98, legato=0.9)
    lh = []
    for start, ch in ((8, ['A2','E3','A3']), (17, ['E2','E3','G#3']),
                      (26, ['A2','E3','A3']), (40, ['A2','E3','A3'])):
        for i, nm in enumerate(ch):
            lh.append((1, (start + i * 2) * u, u * 2.3, m(nm), 54))
    return dict(tempo_len=end, inst={0:(0,1.0,0.0), 1:(0,0.72,0.0)}, notes=n1+lh, rev=20)


def mozart_twinkle():
    """Mozart, '아, 어머니께 말씀드리죠' 주제 K.265 (1781). 오르골."""
    spb = 60.0 / 112
    P = lambda a, b, c, d: [(a,1),(a,1),(b,1),(b,1),(c,1),(c,1),(d,2)]
    mel = P('C5','G5','A5','G5') + P('F5','E5','D5','C5') \
        + P('G5','F5','E5','D5') + P('G5','F5','E5','D5') \
        + P('C5','G5','A5','G5') + P('F5','E5','D5','C5')
    n1, end = seq(spb, mel, slot=0, vel=100)
    C = ['C3','E3','G3']; F = ['F3','A3','C4']; G = ['G3','B3','D4']
    harm = [(C,4),(C,4),(F,4),(C,4),(G,4),(C,4),(G,4),(C,4),(C,4),(C,4),(F,4),(C,4)]
    n2, _ = chords(spb, harm, slot=1, vel=44)
    return dict(tempo_len=end, inst={0:(10,1.0,0.0), 1:(46,0.52,0.0)}, notes=n1+n2, rev=26)


def mozart_k545():
    """Mozart, 피아노 소나타 16번 1악장 K.545 (1788). 피아노, 알베르티 베이스."""
    spb = 60.0 / 126
    mel = [('C5',1),('E5',1),('G5',1),('B5',.5),('C6',.5),
           ('D6',1),('C6',3),
           ('C6',.5),('B5',.5),('A5',.5),('G5',.5),('F5',.5),('E5',.5),('D5',.5),('C5',.5),
           ('B4',1),('C5',3)]
    n1, end = seq(spb, mel, slot=0, vel=100, legato=0.9)
    SH = {'C': ['C3','G3','E3','G3'], 'G': ['G2','G3','D3','G3']}
    plan = ['C','C','C','C', 'C','C','C','C', 'C','C','C','C', 'G','G','C','C']
    alb = []
    for b, key in enumerate(plan):
        for i, nm in enumerate(SH[key]):
            alb.append((1, b * spb + i * spb / 4, spb / 4 * 1.7, m(nm), 50))
    return dict(tempo_len=end, inst={0:(0,1.0,0.0), 1:(0,0.64,0.0)}, notes=n1+alb, rev=18)


def bach_invention1():
    """Bach, 인벤션 1번 BWV 772 (1723). 주제는 원곡, 뒤는 그 주제를 이어 붙였다. 하프시코드."""
    u = 60.0 / 84 / 4                      # 16분
    def subj(root_octave_names):
        return [(n, 1) for n in root_octave_names]
    S_C  = ['C5','D5','E5','F5','D5','E5','C5','G5']
    S_G  = ['G5','A5','B5','C6','A5','B5','G5','D6']
    S_C3 = ['C3','D3','E3','F3','D3','E3','C3','G3']
    S_G3 = ['G3','A3','B3','C4','A3','B3','G3','D4']
    rh = subj(S_C) + subj(S_G) \
       + [('C6',2),('B5',2),('C6',2),('A5',2),('G5',2),('F5',2),('E5',2),('D5',2)] \
       + subj(['G5','A5','B5','C6','A5','B5','G5','D6']) \
       + subj(['D5','E5','F#5','G5','E5','F#5','D5','A5']) \
       + [('F5',2),('E5',2),('D5',2),('C5',2),('B4',2),('C5',6)]
    n1, end = seq(u, rh, slot=0, vel=96, legato=0.88)
    lh = subj(S_C3) + subj(S_G3) \
       + [('C3',2),('B2',2),('C3',2),('A2',2),('G2',2),('F2',2),('E2',2),('D2',2)] \
       + [('G2',4),('D3',4),('G2',4),('D3',4),('C3',8),('G2',8)]
    n2, _ = seq(u, [(None, 16)] + lh, slot=1, vel=62, legato=0.88)
    return dict(tempo_len=end, inst={0:(6,1.0,-0.08), 1:(6,0.78,0.08)}, notes=n1+n2, rev=22)


def haydn_surprise():
    """Haydn, 교향곡 94번 '놀람' 2악장 주제 (1791). 현, 짧게 끊어."""
    u = 60.0 / 80 / 2                      # 8분
    P = lambda a, b, c, d: [(a,1),(a,1),(b,1),(b,1),(c,1),(c,1),(d,2)]
    mel = P('C5','E5','G5','E5') + P('F5','D5','B4','G4') \
        + P('E5','G5','C6','A5') + P('F5','D5','G4','C5')
    n1, end = seq(u, mel, slot=0, vel=108, legato=0.8)
    C = ['C3','E3','G3']; G = ['G2','D3','G3']
    harm = [(C,8),(G,8),(C,8),(G,4),(C,4)]
    n2, _ = chords(u, harm, slot=1, vel=58, legato=0.75)
    # 현은 짧게 끊으면 소리가 거의 안 난다. 길이를 늘리고 악기를 올려 둔다.
    return dict(tempo_len=end, inst={0:(48,1.0,0.0,16), 1:(45,0.8,0.0,12)}, notes=n1+n2, rev=24)


def dvorak_newworld():
    """Dvorak, 교향곡 9번 '신세계' 2악장 (1893). 잉글리시 호른과 현."""
    spb = 60.0 / 72
    A = [('E5',1.5),('G5',.5),('G5',2),('E5',1.5),('D5',.5),('C5',2),
         ('D5',1),('E5',1),('G5',1),('E5',1),('D5',4)]
    B = [('E5',1.5),('G5',.5),('G5',2),('E5',1.5),('D5',.5),('C5',2),
         ('A4',1),('C5',1),('D5',1),('C5',1),('C5',4)]
    n1, end = seq(spb, A + B, slot=0, vel=98, legato=0.96)
    C = ['C3','E3','G3']; F = ['F3','A3','C4']; G = ['G2','D3','G3']; Am = ['A2','E3','A3']
    harm = [(C,4),(C,4),(F,4),(C,4),(C,4),(Am,4),(G,4),(C,4)]
    n2, _ = chords(spb, harm, slot=1, vel=42)
    return dict(tempo_len=end, inst={0:(69,1.0,0.0,6), 1:(49,0.52,0.0,10)}, notes=n1+n2, rev=30)


def rossini_tell():
    """Rossini, 윌리엄 텔 서곡 피날레 (1829). 트럼펫과 현. 확실히 깨우는 쪽."""
    u = 60.0 / 132 / 2                     # 8분
    call = lambda top: [('B4',1),('B4',1),(top,2)]
    A = call('E5') * 3 + [('E5',1),('E5',1),('E5',1),('E5',1)]
    B = [('E5',1),('E5',1),('A5',2)] * 3 + [('A5',1),('A5',1),('A5',1),('A5',1)]
    C = call('E5') * 2 + [('B4',1),('B4',1),('F#5',1),('E5',1)] + [('E5',2),(None,2)]
    n1, end = seq(u, A + B + A + C, slot=0, vel=106, legato=0.7)
    E = ['E3','B3','E4']; A_ = ['A3','E4','A4']; B_ = ['B3','F#4','B4']
    harm = [(E,16),(A_,16),(E,16),(E,8),(B_,4),(E,4)]
    n2, _ = chords(u, harm, slot=1, vel=50, legato=0.9)
    return dict(tempo_len=end, inst={0:(56,1.0,0.0,4), 1:(48,0.6,0.0,10)}, notes=n1+n2, rev=22)


def strauss_danube():
    """Strauss II, 아름답고 푸른 도나우 Op.314 (1867). 현 왈츠."""
    spb = 60.0 / 174                       # 3/4 왈츠
    def rise(a, b, c):
        return [(a,1),(b,1),(c,1),(c,3),(c,1),(None,1),(c,1),(c,1),(None,1),(c,1)]
    mel = rise('D4','F#4','A4') + rise('F#4','A4','D5') + rise('A4','D5','F#5') \
        + [('E5',1),('D5',1),('C#5',1),('D5',3),('A4',1),(None,1),('A4',1),('D5',3)] \
        + rise('D4','F#4','A4') + rise('F#4','A4','D5')
    n1, end = seq(spb, mel, slot=0, vel=98, legato=0.9)
    D = ['D3','F#3','A3']; A7 = ['A2','C#3','G3']
    oom = []
    t, bar = 0.0, 0
    plan = ['D'] * 12 + ['D','A7','D','A7'] + ['D'] * 8
    while bar < len(plan):
        ch = D if plan[bar] == 'D' else A7
        oom.append((1, t, spb * 0.8, m(ch[0]) - 12, 58))
        for beat in (1, 2):
            for nm in ch[1:]:
                oom.append((1, t + beat * spb, spb * 0.7, m(nm), 44))
        t += 3 * spb
        bar += 1
    return dict(tempo_len=end, inst={0:(48,1.0,-0.05,10), 1:(45,0.8,0.05,6)}, notes=n1+oom, rev=26)


def bach_air():
    """Bach, 관현악 조곡 3번 '에어'(G선상의 아리아) BWV 1068 (1731). 현과 오보에."""
    spb = 60.0 / 60
    mel = [('F#5',3),('G5',.5),('A5',.5),('B5',2),('A5',1),('G5',1),
           ('F#5',2),('E5',1),('F#5',1),('G5',2),('F#5',2),('E5',2),('D5',4)]
    n1, end = seq(spb, mel, slot=0, vel=96, legato=0.97)
    walk = ['D3','E3','F#3','G3','A3','B3','C#4','D4',
            'B3','C#4','D4','E4','F#4','E4','D4','C#4',
            'B3','A3','G3','F#3','E3','F#3','G3','A3',
            'D4','C#4','B3','A3','G3','F#3','E3','D3',
            'A3','B3','C#4','D4','E4','D4','C#4','B3',
            'A3','G3','F#3','E3']
    bass = []
    for i, nm in enumerate(walk):
        tt = i * spb / 2
        if tt >= end: break
        bass.append((1, tt, spb / 2 * 0.95, m(nm) - 12, 56))
    return dict(tempo_len=end, inst={0:(68,1.0,-0.1,6), 1:(42,0.82,0.1,8)}, notes=n1+bass, rev=32)


def beethoven_fate():
    """Beethoven, 교향곡 5번 1악장 머리 동기 (1808). 현과 저현. 깊이 자는 사람용."""
    u = 60.0 / 108 / 2                     # 8분
    def cell(tr):
        return [(None,1),('G4',1),('G4',1),('G4',1),('Eb4',6),
                (None,1),('F4',1),('F4',1),('F4',1),('D4',6)], tr
    base = [(None,1),('G4',1),('G4',1),('G4',1),('Eb4',6),
            (None,1),('F4',1),('F4',1),('F4',1),('D4',6)]
    notes, t = [], 0.0
    for i, tr in enumerate((0, 12, 0, 12)):
        n, t = seq(u, base, t0=t, slot=0, vel=104 + (4 if i % 2 else 0),
                   legato=0.9, transpose=tr)
        notes += n
    low, t2 = [], 0.0
    for i, tr in enumerate((0, 0, 0, 0)):
        n, t2 = seq(u, base, t0=t2, slot=1, vel=86, legato=0.92, transpose=-12)
        low += n
    return dict(tempo_len=t, inst={0:(48,1.0,0.0,11), 1:(43,0.7,0.0,8)}, notes=notes+low, rev=26)


def elgar_salut():
    """Elgar, 사랑의 인사 Op.12 (1888). 바이올린과 하프."""
    spb = 60.0 / 88
    mel = [('B4',1),('E5',2),('D#5',1),('E5',1),('F#5',1),('G#5',2),('F#5',1),('E5',3),
           ('B4',1),('C#5',1),('B4',1),('A4',1),('G#4',1),('F#4',2),('E4',2)]
    n1, end = seq(spb, mel, slot=0, vel=96, legato=0.96)
    E = ['E3','G#3','B3']; B7 = ['B2','D#3','F#3']; A = ['A2','C#3','E3']
    harm = [(E,4),(E,4),(B7,4),(E,4),(A,4),(B7,2),(E,2)]
    n2, _ = chords(spb, harm, slot=1, vel=44)
    return dict(tempo_len=end, inst={0:(40,1.0,-0.08,8), 1:(46,0.6,0.08)}, notes=n1+n2, rev=30)


PIECES = [
    ('01-아침-그리그',            grieg_morning,     '상쾌·플루트'),
    ('02-미뉴에트-바흐',          bach_minuet,       '경쾌·오르골'),
    ('03-전주곡-바흐',            bach_prelude,      '맑음·첼레스타'),
    ('04-환희의송가-베토벤',      beethoven_joy,     '밝음·현'),
    ('05-카논-파헬벨',            pachelbel_canon,   '차분·하프'),
    ('06-봄-비발디',              vivaldi_spring,    '상쾌·바이올린'),
    ('07-터키행진곡-모차르트',    mozart_turca,      '경쾌·피아노'),
    ('08-나흐트무지크-모차르트',  mozart_nacht,      '경쾌·현'),
    ('09-첼로1번전주곡-바흐',     bach_cello1,       '차분·첼로 홀로'),
    ('10-엘리제를위하여-베토벤',  beethoven_elise,   '익숙함·피아노'),
    ('11-작은별-모차르트',        mozart_twinkle,    '밝음·오르골'),
    ('12-소나타K545-모차르트',    mozart_k545,       '맑음·피아노'),
    ('13-인벤션1번-바흐',         bach_invention1,   '또랑또랑·하프시코드'),
    ('14-놀람교향곡-하이든',      haydn_surprise,    '경쾌·현 스타카토'),
    ('15-신세계2악장-드보르자크', dvorak_newworld,   '느림·잉글리시호른'),
    ('16-윌리엄텔-로시니',        rossini_tell,      '확실히깨움·트럼펫'),
    ('17-도나우-슈트라우스',      strauss_danube,    '상쾌·왈츠'),
    ('18-에어-바흐',              bach_air,          '차분·오보에와 첼로'),
    ('19-교향곡5번-베토벤',       beethoven_fate,    '확실히깨움·현'),
    ('20-사랑의인사-엘가',        elgar_salut,       '따뜻함·바이올린'),
]


def write_score(path, spec, limit=29.0, tail=0.7):
    """한 바퀴가 짧으면 되풀이해 채운다. 마디 중간에서 끊기지 않게 바퀴 수로 맞춘다."""
    one = spec['tempo_len']
    reps = 1
    if one > 0:
        while (reps + 1) * one <= limit:
            reps += 1
        # 20초가 안 되면 한 바퀴 더 돌리고 뒤를 자른다. 자른 자리는 페이드로 덮는다.
        if reps * one < 20.0 and one < limit:
            reps += 1
    total = min(limit, reps * one + tail)
    lines = ['sr 44100', 'dur %.2f' % total, 'rev %d' % spec.get('rev', 18)]
    for slot, conf in sorted(spec['inst'].items()):
        prog, vol, pan = conf[0], conf[1], conf[2]
        gain = conf[3] if len(conf) > 3 else 0
        lines.append('inst %d %d %.3f %.3f %.1f' % (slot, prog, vol, pan, gain))
    for r in range(reps):
        off = r * one
        for slot, t, d, note, vel in spec['notes']:
            tt = t + off
            if tt >= total:
                continue
            lines.append('note %d %.4f %.4f %d %d' % (slot, tt, min(d, total - tt), note, vel))
    open(path, 'w').write('\n'.join(lines) + '\n')
    return one, reps, total


if __name__ == '__main__':
    import os, sys
    outdir = sys.argv[1] if len(sys.argv) > 1 else '/tmp/zp-mel/scores'
    os.makedirs(outdir, exist_ok=True)
    for name, fn, tag in PIECES:
        one, reps, total = write_score(os.path.join(outdir, name + '.txt'), fn())
        print('%-28s 한바퀴 %5.1f초 × %d = %5.1f초  %s' % (name, one, reps, total, tag))
