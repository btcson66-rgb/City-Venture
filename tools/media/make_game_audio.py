"""Code-generated audio for the game: five seamless music loops and the UI / world sound effects.

Placeholder until licensed or commissioned audio replaces it (docs/ROADMAP.md, commercial track), but made
to be pleasant rather than beepy: electric piano, soft bass, brushed drums, gentle reverb.

  python3 tools/media/make_game_audio.py            # writes game/assets/audio/{music,sfx}/*.ogg

Deterministic (fixed seeds), so re-running reproduces the same files.
"""
from __future__ import annotations

import os
import subprocess
import tempfile
import wave

import numpy as np
from scipy.signal import fftconvolve, butter, lfilter

SR = 44100
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "audio")


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12.0)


def env(n, attack=0.005, tau=1.0):
    t = np.arange(n) / SR
    e = np.exp(-t / tau)
    a = max(1, int(attack * SR))
    e[:a] *= np.linspace(0, 1, a)
    return e


def lowpass(x, hz):
    b, a = butter(2, hz / (SR / 2), "low")
    return lfilter(b, a, x)


def highpass(x, hz):
    b, a = butter(2, hz / (SR / 2), "high")
    return lfilter(b, a, x)


# ---------------------------------------------------------------- instruments
def epiano(freq, dur, vel=0.2, tau=1.2):
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for cents in (-5, 5):
        f = freq * 2 ** (cents / 1200)
        out += np.sin(2 * np.pi * f * t) + 0.3 * np.sin(4 * np.pi * f * t) * np.exp(-t / 0.35) \
            + 0.08 * np.sin(6 * np.pi * f * t) * np.exp(-t / 0.15)
    trem = 1 + 0.07 * np.sin(2 * np.pi * 4.8 * t)
    e = env(n, 0.004, tau)
    e[-int(0.03 * SR):] *= np.linspace(1, 0, int(0.03 * SR))
    return out * e * trem * vel * 0.5


def pluck(freq, dur, vel=0.18):
    # Karplus-Strong guitar-ish pluck
    n = int(dur * SR)
    p = max(2, int(SR / freq))
    rng = np.random.default_rng(int(freq * 10))
    buf = rng.uniform(-1, 1, p)
    out = np.zeros(n)
    for i in range(n):
        out[i] = buf[i % p]
        buf[i % p] = 0.5 * (buf[i % p] + buf[(i + 1) % p]) * 0.996
    return lowpass(out, 3500) * vel


def bass(freq, dur, vel=0.32):
    n = int(dur * SR)
    t = np.arange(n) / SR
    tone = np.sin(2 * np.pi * freq * t) + 0.22 * np.sin(4 * np.pi * freq * t)
    e = env(n, 0.006, 0.8)
    e[-int(0.02 * SR):] *= np.linspace(1, 0, int(0.02 * SR))
    return tone * e * vel


def pad(freqs, dur, vel=0.05):
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for f in freqs:
        for cents in (-7, 0, 7):
            out += np.sin(2 * np.pi * f * 2 ** (cents / 1200) * t)
    a = int(min(dur * 0.3, 0.8) * SR)
    e = np.ones(n)
    e[:a] = np.linspace(0, 1, a)
    e[-a:] = np.linspace(1, 0, a)
    return lowpass(out * e, 1800) * vel / max(1, len(freqs))


def kick(vel=0.5):
    n = int(0.35 * SR)
    t = np.arange(n) / SR
    f = 50 + 70 * np.exp(-t / 0.04)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.12) * vel


def hat(rng, vel=0.06, open_=False):
    n = int((0.22 if open_ else 0.06) * SR)
    x = highpass(rng.uniform(-1, 1, n), 7000)
    return x * np.exp(-np.arange(n) / SR / (0.08 if open_ else 0.015)) * vel


def brush(rng, vel=0.07):
    n = int(0.18 * SR)
    x = lowpass(highpass(rng.uniform(-1, 1, n), 1500), 6000)
    e = np.exp(-np.arange(n) / SR / 0.06)
    return x * e * vel


def reverb(x, seconds=1.6, mix=0.22, seed=1):
    rng = np.random.default_rng(seed)
    n = int(seconds * SR)
    ir = rng.standard_normal(n) * np.exp(-np.arange(n) / SR / (seconds / 5))
    ir = lowpass(ir, 5000)
    ir /= np.sqrt(np.sum(ir ** 2))
    wet = fftconvolve(x, ir)[: len(x)]
    return x * (1 - mix) + wet * mix


def add(buf, sig, at):
    i = int(at * SR)
    j = min(len(buf), i + len(sig))
    if i < len(buf):
        buf[i:j] += sig[: j - i]


# ---------------------------------------------------------------- songs
def song(bpm, chords, bars, style, seed, key_shift=0):
    beat = 60.0 / bpm
    bar = 4 * beat
    length = bars * bar
    tail = 3.0
    L = np.zeros(int((length + tail) * SR))
    R = np.zeros_like(L)
    rng = np.random.default_rng(seed)
    for b in range(bars):
        root, tones = chords[b % len(chords)]
        root += key_shift
        tones = [t + key_shift for t in tones]
        t0 = b * bar
        # chord comping
        if style in ("day", "menu", "office"):
            hits = [0, 1.5, 2.5] if style == "day" else ([0, 2] if style == "menu" else [0, 0.75, 2, 2.75])
            for h in hits:
                for k, n in enumerate(tones):
                    s = epiano(midi(n), beat * (1.4 if style != "office" else 0.6), vel=0.16 if style != "office" else 0.11)
                    add(L if k % 2 == 0 else R, s, t0 + h * beat + k * 0.004)
                    add(R if k % 2 == 0 else L, s * 0.55, t0 + h * beat + k * 0.004)
        elif style == "night":
            for k, n in enumerate(tones):
                s = epiano(midi(n), bar * 0.95, vel=0.13, tau=2.2)
                add(L, s, t0 + k * 0.03)
                add(R, s * 0.8, t0 + k * 0.03 + 0.01)
            p = pad([midi(n) for n in tones], bar, 0.06)
            add(L, p, t0)
            add(R, p, t0)
        elif style == "cafe":
            pattern = [0, 1, 2, 3, 2, 1, 0, 3]
            for i in range(8):
                n = tones[pattern[i] % len(tones)] + 12
                s = pluck(midi(n), beat * 0.9, vel=0.13)
                add(L if i % 2 else R, s, t0 + i * beat / 2)
                add(R if i % 2 else L, s * 0.5, t0 + i * beat / 2 + 0.012)
        # bass
        bpat = {"day": [(0, 1.5), (1.5, 0.5), (2, 1.5), (3.5, 0.5)], "menu": [(0, 2), (2, 2)],
                "night": [(0, 3), (3, 1)], "cafe": [(0, 2), (2, 2)], "office": [(0, 0.5), (1, 0.5), (2, 0.5), (3, 0.5)]}[style]
        for i, (h, d) in enumerate(bpat):
            n = root - 12 if (i % 2 == 0 or style == "office") else root - 5
            s = bass(midi(n), beat * d * 0.95, vel=0.28 if style != "night" else 0.22)
            add(L, s, t0 + h * beat)
            add(R, s, t0 + h * beat)
        # drums
        for q in range(8):
            tq = t0 + q * beat / 2
            if style == "day":
                if q in (0, 4):
                    add(L, kick(0.45), tq); add(R, kick(0.45), tq)
                if q in (2, 6):
                    s = brush(rng, 0.12); add(L, s, tq); add(R, s, tq)
                s = hat(rng, 0.05, q == 7); add(L if q % 2 else R, s, tq)
            elif style == "office":
                if q % 2 == 0:
                    add(L, kick(0.3), tq); add(R, kick(0.3), tq)
                s = hat(rng, 0.035); add(R if q % 2 else L, s, tq)
            elif style in ("menu", "cafe"):
                if q == 0:
                    add(L, kick(0.3), tq); add(R, kick(0.3), tq)
                if q in (2, 6):
                    s = brush(rng, 0.07); add(L, s, tq); add(R, s, tq)
            elif style == "night":
                if q in (2, 6):
                    s = brush(rng, 0.05); add(L, s, tq); add(R, s, tq)
    # vinyl hiss for night / menu
    if style in ("night", "menu"):
        hiss = lowpass(rng.standard_normal(len(L)), 4000) * 0.004
        L += hiss
        R += hiss
    L = reverb(L, 1.8, 0.25, seed)
    R = reverb(R, 1.8, 0.25, seed + 1)
    # seamless loop: fold the tail back over the start
    n = int(length * SR)
    Lo, Ro = L[:n].copy(), R[:n].copy()
    t = len(L) - n
    Lo[:t] += L[n:]
    Ro[:t] += R[n:]
    st = np.stack([Lo, Ro], 1)
    st /= max(1e-6, np.max(np.abs(st))) / 0.7
    return st


def write_ogg(path, data, stereo=True, q=3):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tf:
        tmp = tf.name
    pcm = (np.clip(data, -1, 1) * 32767).astype(np.int16)
    with wave.open(tmp, "wb") as w:
        w.setnchannels(2 if stereo else 1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", str(q), path], check=True)
    os.unlink(tmp)


# ---------------------------------------------------------------- sfx
def sfx():
    rng = np.random.default_rng(7)
    out = {}

    def mix(*parts):
        n = max(len(p) for p in parts)
        o = np.zeros(n)
        for p in parts:
            o[: len(p)] += p
        return o

    def tone(f, dur, vel=0.4, tau=0.12, shape="sine"):
        n = int(dur * SR)
        t = np.arange(n) / SR
        w = np.sin(2 * np.pi * f * t) if shape == "sine" else np.sign(np.sin(2 * np.pi * f * t)) * 0.4
        return w * env(n, 0.002, tau) * vel

    out["click"] = lowpass(mix(tone(1800, 0.05, 0.25, 0.012), tone(900, 0.05, 0.12, 0.01)), 5000)
    up = np.zeros(int(0.18 * SR))
    for i, f in enumerate([660, 880]):
        add(up, tone(f, 0.12, 0.22, 0.05), i * 0.05)
    out["open"] = up
    dn = np.zeros(int(0.18 * SR))
    for i, f in enumerate([700, 520]):
        add(dn, tone(f, 0.12, 0.18, 0.05), i * 0.05)
    out["close"] = dn
    ch = np.zeros(int(0.6 * SR))
    for i, f in enumerate([midi(76), midi(83)]):
        add(ch, epiano(f, 0.5, 0.5, 0.35), i * 0.09)
    out["notify"] = ch
    coin = np.zeros(int(0.5 * SR))
    for i, f in enumerate([midi(88), midi(95)]):
        add(coin, mix(tone(f, 0.35, 0.35, 0.09), tone(f * 2.01, 0.2, 0.08, 0.05)), i * 0.07)
    out["cash"] = coin
    out["spend"] = lowpass(mix(tone(330, 0.16, 0.25, 0.05), tone(247, 0.2, 0.18, 0.06)), 2500)
    ok = np.zeros(int(0.9 * SR))
    for i, n in enumerate([72, 76, 79, 84]):
        add(ok, epiano(midi(n), 0.7, 0.42, 0.5), i * 0.08)
    out["success"] = ok
    fan = np.zeros(int(1.6 * SR))
    for i, n in enumerate([67, 72, 76, 79, 84, 88]):
        add(fan, epiano(midi(n), 1.2, 0.35, 0.8), i * 0.1)
    add(fan, pad([midi(60), midi(64), midi(67)], 1.4, 0.2), 0.3)
    out["fanfare"] = fan
    out["error"] = lowpass(mix(tone(180, 0.22, 0.3, 0.1, "square"), tone(170, 0.22, 0.2, 0.1)), 1500)
    n = int(0.5 * SR)
    t = np.arange(n) / SR
    buzz = np.sin(2 * np.pi * 150 * t) * (np.sin(2 * np.pi * 22 * t) > 0) * 0.25
    buzz[: n // 2] *= 1
    buzz[int(0.2 * SR):int(0.28 * SR)] = 0
    out["phone"] = lowpass(buzz, 900) * env(n, 0.005, 0.6)
    # door: soft thump + little shop bell
    d = np.zeros(int(0.8 * SR))
    add(d, lowpass(rng.uniform(-1, 1, int(0.12 * SR)), 300) * np.exp(-np.arange(int(0.12 * SR)) / SR / 0.03) * 0.5, 0)
    for i, f in enumerate([midi(93), midi(96)]):
        add(d, mix(tone(f, 0.5, 0.12, 0.2), tone(f * 2.76, 0.3, 0.03, 0.08)), 0.05 + i * 0.06)
    out["door"] = d
    pg = lowpass(highpass(rng.uniform(-1, 1, int(0.15 * SR)), 2000), 7000)
    out["page"] = pg * np.sin(np.linspace(0, np.pi, len(pg))) * 0.12
    return out


def main():
    progs = {
        "menu": (84, [(53, [57, 60, 64, 65]), (55, [59, 62, 64, 67]), (52, [55, 59, 62, 64]), (57, [60, 64, 67, 69])], 16),
        "day": (100, [(50, [53, 57, 60, 64]), (55, [59, 64, 65, 69]), (48, [52, 55, 59, 62]), (57, [61, 64, 67, 71])], 16),
        "night": (70, [(51, [55, 58, 62, 65]), (56, [60, 63, 67, 70]), (58, [62, 65, 68, 72]), (51, [55, 58, 62, 67])], 12),
        "cafe": (88, [(48, [52, 55, 59, 62]), (57, [60, 64, 67, 71]), (53, [57, 60, 64, 67]), (55, [59, 62, 65, 69])], 16),
        "office": (104, [(57, [60, 64, 67, 71]), (53, [57, 60, 64, 67]), (48, [52, 55, 59, 62]), (55, [59, 62, 65, 67])], 16),
    }
    for i, (name, (bpm, chords, bars)) in enumerate(progs.items()):
        write_ogg(os.path.join(OUT, "music", name + ".ogg"), song(bpm, chords, bars, name, 10 + i))
        print("music", name)
    fx = sfx()
    for name, x in fx.items():
        x = x / max(1e-6, np.max(np.abs(x))) * 0.8
        write_ogg(os.path.join(OUT, "sfx", name + ".ogg"), x, stereo=False, q=4)
    print("sfx", len(fx))


if __name__ == "__main__":
    main()
