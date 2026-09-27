# -*- coding: utf-8 -*-
"""렌더 결과를 검사하고, 정규화·페이드를 걸어 미리듣기(스테레오)와 앱용(22.05k 모노)을 만든다."""
import os, math, struct, wave, array, sys

SRC, PREV, APP = 'out', 'preview', 'app'
for d in (PREV, APP): os.makedirs(d, exist_ok=True)

def read16(path):
    """WAVE_FORMAT_EXTENSIBLE 도 읽는다. (표본배열, 채널, 샘플레이트)"""
    raw = open(path, 'rb').read()
    assert raw[:4] == b'RIFF' and raw[8:12] == b'WAVE', path
    i, fmt, data = 12, None, None
    while i + 8 <= len(raw):
        cid, sz = raw[i:i+4], struct.unpack('<I', raw[i+4:i+8])[0]
        body = raw[i+8:i+8+sz]
        if cid == b'fmt ': fmt = body
        elif cid == b'data': data = body
        i += 8 + sz + (sz & 1)
    ch, sr, bits = struct.unpack('<H', fmt[2:4])[0], struct.unpack('<I', fmt[4:8])[0], struct.unpack('<H', fmt[14:16])[0]
    assert bits == 16, bits
    a = array.array('h'); a.frombytes(data[:len(data) // 2 * 2])
    return a, ch, sr

def mono(a, ch):
    if ch == 1: return list(a)
    return [(a[i] + a[i+1]) * 0.5 for i in range(0, len(a) - 1, 2)]

def stats(xs):
    if not xs: return 0.0, -180.0
    pk = max(abs(x) for x in xs) / 32767.0
    ms = sum(x * x for x in xs) / len(xs)
    rms = 10 * math.log10(ms / (32767.0 ** 2) + 1e-20)
    return pk, rms

def shape(xs, drive, target_peak=0.985):
    """게인을 올리고 tanh 로 눌러 포화시킨 뒤 피크를 맞춘다."""
    pk = max(abs(x) for x in xs) or 1
    g = (0.9 * 32767.0 / pk) * drive
    out = [math.tanh(x * g / 32767.0 * 1.15) for x in xs]
    m2 = max(abs(v) for v in out) or 1
    k = target_peak / m2
    return [v * k for v in out]


def rms_db(xs):
    ms = sum(v * v for v in xs) / max(1, len(xs))
    return 10 * math.log10(ms + 1e-20)


def limit_norm(xs, target_rms=-8.0, dmin=0.8, dmax=14.0):
    """목표 크기에 닿을 만큼만 눌러 키운다. 곡마다 알맞은 양이 달라서 찾아서 쓴다."""
    lo, hi, best = dmin, dmax, None
    for _ in range(18):
        mid = (lo + hi) / 2
        y = shape(xs, mid)
        r = rms_db(y)
        best = (mid, y, r)
        if r < target_rms:
            lo = mid
        else:
            hi = mid
    return best[1], best[0], best[2]


def fade(xs, sr, tail=1.2, head=0.02):
    n, h = len(xs), int(sr * head)
    t = int(sr * tail)
    for i in range(min(h, n)): xs[i] *= i / h
    for i in range(min(t, n)):
        xs[n - 1 - i] *= (i / t) ** 0.6
    return xs

def resample(xs, sr_in, sr_out):
    ratio = sr_in / sr_out
    n = int(len(xs) / ratio)
    out = []
    for i in range(n):
        p = i * ratio
        j = int(p); f = p - j
        a = xs[j] if j < len(xs) else 0.0
        b = xs[j + 1] if j + 1 < len(xs) else a
        out.append(a + (b - a) * f)
    return out

def write16(path, xs, sr, ch=1):
    w = wave.open(path, 'wb'); w.setnchannels(ch); w.setsampwidth(2); w.setframerate(sr)
    a = array.array('h', [max(-32768, min(32767, int(round(v * 32767)))) for v in xs])
    w.writeframes(a.tobytes()); w.close()

print('%-30s %6s %8s | %8s %8s %7s %7s' % ('곡', '초', '원본RMS', '피크', 'RMS', '무음%', '눌림'))
rows = []
for name in sorted(os.listdir(SRC)):
    if not name.endswith('.wav'): continue
    a, ch, sr = read16(os.path.join(SRC, name))
    mo = mono(a, ch)
    secs = len(mo) / sr
    pk0, rms0 = stats(mo)
    nrm, drv, _ = limit_norm(mo[:])
    # 앱용: 22.05k 모노 + 페이드
    app = fade(resample(nrm[:], sr, 22050), 22050)
    pk1, rms1 = stats([v * 32767 for v in app])
    # 무음 비율(−45dBFS 아래)
    win = 220
    quiet = sum(1 for i in range(0, len(app) - win, win)
                if max(abs(v) for v in app[i:i+win]) < 10 ** (-45 / 20))
    tot = max(1, len(app) // win)
    write16(os.path.join(APP, name), app, 22050, 1)
    # 미리듣기: 원래 채널 유지 + 같은 정규화
    if ch == 2:
        st = fade(shape(list(a), drv), sr)
        write16(os.path.join(PREV, name), st, sr, 2)
    else:
        write16(os.path.join(PREV, name), fade(nrm[:], sr), sr, 1)
    rows.append((name, secs, rms0, pk1, rms1, quiet * 100.0 / tot, drv))
    print('%-30s %6.1f %8.1f | %7.0f%% %8.1f %6.0f%% %6.1fx' % (
        name[:-4], secs, rms0, pk1 * 100, rms1, quiet * 100.0 / tot, drv))

bad = [r for r in rows if r[4] > -5.5 or r[4] < -11.0]
print()
print('점검 필요:', [r[0][:-4] for r in bad] or '없음')
