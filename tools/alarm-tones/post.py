# -*- coding: utf-8 -*-
"""A/B 비교용. 표본율·포화 한도·고역 프리젠스를 인자로 받아 한 곡을 굽는다."""
import os, sys, math, struct, wave, array

def read16(path):
    raw = open(path,'rb').read()
    assert raw[:4]==b'RIFF' and raw[8:12]==b'WAVE', path
    i,fmt,data = 12,None,None
    while i+8 <= len(raw):
        cid,sz = raw[i:i+4], struct.unpack('<I',raw[i+4:i+8])[0]
        body = raw[i+8:i+8+sz]
        if cid==b'fmt ': fmt=body
        elif cid==b'data': data=body
        i += 8+sz+(sz&1)
    ch = struct.unpack('<H',fmt[2:4])[0]; sr = struct.unpack('<I',fmt[4:8])[0]
    a = array.array('h'); a.frombytes(data[:len(data)//2*2])
    return a, ch, sr

def mono(a, ch):
    if ch==1: return [x/32768.0 for x in a]
    return [(a[i]+a[i+1])/65536.0 for i in range(0,len(a)-1,2)]

def rms_db(xs, step=4):
    s = xs[::step]
    ms = sum(v*v for v in s)/max(1,len(s))
    return 10*math.log10(ms+1e-20)

def shape(xs, drive, peak=0.985):
    pk = max(abs(x) for x in xs) or 1
    g = (0.9/pk)*drive
    out = [math.tanh(v*g*1.15) for v in xs]
    m = max(abs(v) for v in out) or 1
    k = peak/m
    return [v*k for v in out]

def limit_norm(xs, target=-8.0, dmax=14.0):
    """목표 크기까지 눌러 키운다. dmax 를 낮추면 트랜지언트가 덜 뭉갠다."""
    lo,hi,best = 0.8,dmax,None
    for _ in range(12):
        mid=(lo+hi)/2
        y=shape(xs,mid); r=rms_db(y)
        best=(mid,y,r)
        if r<target: lo=mid
        else: hi=mid
    return best[1], best[0], best[2]

def presence(xs, sr, fc=3500.0, gain=0.0):
    """고역 셸프. lowpass 를 빼서 얻은 고역을 gain 만큼 더한다."""
    if gain <= 0: return xs
    a = math.exp(-2*math.pi*fc/sr)
    lp = 0.0; out=[]
    for x in xs:
        lp = a*lp + (1-a)*x
        out.append(x + gain*(x-lp))
    return out

def lowpass_for_decimate(xs, sr, target_sr):
    """다운샘플 전 저역통과. 이게 없으면 잘릴 고역이 접혀 들어와 탁해진다."""
    fc = target_sr*0.45
    a = math.exp(-2*math.pi*fc/sr)
    # 2차로 두 번 건다
    for _ in range(2):
        lp=0.0; o=[]
        for x in xs:
            lp = a*lp+(1-a)*x; o.append(lp)
        xs=o
    return xs

def resample(xs, sr_in, sr_out):
    if sr_in==sr_out: return xs
    xs = lowpass_for_decimate(xs, sr_in, sr_out)
    ratio = sr_in/sr_out; n=int(len(xs)/ratio); out=[]
    for i in range(n):
        p=i*ratio; j=int(p); f=p-j
        A=xs[j] if j<len(xs) else 0.0
        B=xs[j+1] if j+1<len(xs) else A
        out.append(A+(B-A)*f)
    return out

def fade(xs, sr, tail=1.2, head=0.02):
    n=len(xs); h=int(sr*head); t=int(sr*tail)
    for i in range(min(h,n)): xs[i]*=i/max(1,h)
    for i in range(min(t,n)): xs[n-1-i]*=(i/t)**0.6
    return xs

def write16(path, xs, sr):
    w=wave.open(path,'wb'); w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr)
    a=array.array('h',[max(-32768,min(32767,int(round(v*32767)))) for v in xs])
    w.writeframes(a.tobytes()); w.close()

def spectrum(xs, sr):
    """대역별 에너지. 11k 위가 비었는지 본다."""
    N=4096; bands=[(0,2000),(2000,5000),(5000,8000),(8000,11000),(11000,16000),(16000,22050)]
    acc=[0.0]*len(bands); frames=0
    step=N*8
    for off in range(0, max(1,len(xs)-N), step):
        seg=xs[off:off+N]
        if len(seg)<N: break
        # 간단 Goertzel 대신 대역 대표 주파수 몇 개로 에너지 추정
        for bi,(lo,hi) in enumerate(bands):
            if lo>=sr/2: continue
            e=0.0; picks=0
            f=lo+ (hi-lo)*0.2
            while f < min(hi, sr/2*0.98):
                w=2*math.pi*f/sr; c=2*math.cos(w); s1=s2=0.0
                for x in seg:
                    s0=x+c*s1-s2; s2=s1; s1=s0
                e += s1*s1+s2*s2-c*s1*s2; picks+=1
                f += (hi-lo)/3.0
            if picks: acc[bi]+=e/picks
        frames+=1
    tot=sum(acc) or 1
    return [(10*math.log10(v/tot+1e-20)) for v in acc]

if __name__=='__main__':
    src, out, sr_out, dmax, pres = sys.argv[1], sys.argv[2], int(sys.argv[3]), float(sys.argv[4]), float(sys.argv[5])
    a,ch,sr = read16(src)
    xs = mono(a,ch)
    xs = presence(xs, sr, gain=pres)
    nrm, drv, _ = limit_norm(xs, dmax=dmax)
    y = resample(nrm, sr, sr_out)
    y = fade(y, sr_out)
    write16(out, y, sr_out)
    pk = max(abs(v) for v in y)
    print('%-10s sr=%5d 눌림=%4.1fx 프리젠스=%.1f  피크=%3.0f%% RMS=%5.1f dBFS' % (
        os.path.basename(out), sr_out, drv, pres, pk*100, rms_db(y,1)))


# ─────────────────────────────────────────── 20곡 일괄
# 기본 눌림 상한은 2.5 다. 더 누르면 어택이 뭉개져 소리가 막힌다.
# 아래 곡만 예외로 조금 더 허용한다 — 악보로는 더 못 키우는 것들이다.
DRIVE_MAX = {'16-윌리엄텔-로시니': 3.5}
DEFAULT_DRIVE = 2.5
PRESENCE = 0.35        # 고역 셸프(+3.5kHz). 44.1k 로 살아난 고역을 조금 더 세운다
SR_OUT = 44100         # 22.05k 로 내리면 11kHz 위가 통째로 사라진다

def run_all(src_dir='out2', dst_dir='app2'):
    import glob
    os.makedirs(dst_dir, exist_ok=True)
    for p in sorted(glob.glob(os.path.join(src_dir, '*.wav'))):
        b = os.path.basename(p)
        d = DRIVE_MAX.get(b[:-4], DEFAULT_DRIVE)
        os.system('python3 %s %s %s %d %s %s' % (
            __file__, repr(p), repr(os.path.join(dst_dir, b)), SR_OUT, d, PRESENCE))
