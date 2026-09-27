"""Code-generated music bed for the trailer (placeholder until a licensed track is chosen).

City-pop feel at 96 BPM: electric piano on the IV-V-iii-vi progression (Fmaj7 G6 Em7 Am7), bass, light
drums and a high arpeggio, ending on a held Cmaj9 under the end card. Deterministic; writes 44.1 kHz
stereo 16-bit WAV.   python3 tools/media/make_music.py out.wav [seconds]
"""
import sys
import wave

import numpy as np
from scipy.signal import fftconvolve, butter, lfilter

SR = 44100
BPM = 96.0
BEAT = 60.0 / BPM
BAR = 4 * BEAT
rng = np.random.default_rng(3)


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12.0)


CHORDS = [  # (root midi, chord tones midi) voiced around middle C
    (53, [57, 60, 64, 65]),   # Fmaj7: A3 C4 E4 F4
    (55, [59, 62, 64, 67]),   # G6:    B3 D4 E4 G4
    (52, [55, 59, 62, 64]),   # Em7:   G3 B3 D4 E4
    (57, [60, 64, 67, 69]),   # Am7:   C4 E4 G4 A4
]
FINAL = (48, [55, 59, 62, 64, 67])  # Cmaj9: G3 B3 D4 E4 G4


def env(n, attack=0.005, tau=1.0):
    t = np.arange(n) / SR
    e = np.exp(-t / tau)
    a = int(attack * SR)
    if a > 0:
        e[:a] *= np.linspace(0, 1, a)
    return e


def ep_note(freq, dur, vel=0.18, tau=1.1):
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for cents in (-4, 4):
        f = freq * 2 ** (cents / 1200)
        tone = (np.sin(2 * np.pi * f * t) + 0.32 * np.sin(4 * np.pi * f * t) * np.exp(-t / 0.4)
                + 0.1 * np.sin(6 * np.pi * f * t) * np.exp(-t / 0.2))
        out += tone
    trem = 1 + 0.08 * np.sin(2 * np.pi * 5.2 * t)
    return out * env(n, 0.004, tau) * trem * vel * 0.5


def bass_note(freq, dur, vel=0.34):
    n = int(dur * SR)
    t = np.arange(n) / SR
    tone = np.sin(2 * np.pi * freq * t) + 0.25 * np.sin(4 * np.pi * freq * t)
    e = env(n, 0.006, 0.9)
    e[-int(0.02 * SR):] *= np.linspace(1, 0, int(0.02 * SR))
    return tone * e * vel


def kick():
    n = int(0.28 * SR)
    t = np.arange(n) / SR
    f = 45 + 80 * np.exp(-t / 0.04)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-t / 0.12) * 0.55


def snare():
    n = int(0.16 * SR)
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    b, a = butter(2, [1200 / (SR / 2), 7000 / (SR / 2)], btype="band")
    return lfilter(b, a, noise) * np.exp(-t / 0.05) * 0.22 + np.sin(2 * np.pi * 190 * t) * np.exp(-t / 0.03) * 0.12


def hat():
    n = int(0.04 * SR)
    t = np.arange(n) / SR
    b, a = butter(2, 7000 / (SR / 2), btype="high")
    return lfilter(b, a, rng.standard_normal(n)) * np.exp(-t / 0.012) * 0.07


def pluck(freq, dur=0.3, vel=0.06):
    n = int(dur * SR)
    t = np.arange(n) / SR
    tri = 2 / np.pi * np.arcsin(np.sin(2 * np.pi * freq * t))
    return tri * env(n, 0.002, 0.12) * vel


def place(track, sig, t0, pan=0.0):
    i = int(t0 * SR)
    if i >= track.shape[0]:
        return
    sig = sig[: track.shape[0] - i]
    l, r = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
    track[i:i + len(sig), 0] += sig * l * 1.414
    track[i:i + len(sig), 1] += sig * r * 1.414


def render(seconds=32.0):
    total = int((seconds + 2.0) * SR)
    mix = np.zeros((total, 2))
    bars = int(np.ceil(seconds / BAR))
    for b in range(bars):
        t0 = b * BAR
        last = b == bars - 1
        root, tones = FINAL if last else CHORDS[b % 4]
        # electric piano: downbeat + the "and" of 2 (city-pop push)
        for k, off in enumerate([0.0] if last else [0.0, 1.5 * BEAT, 3.0 * BEAT]):
            for j, n in enumerate(tones):
                v = 0.16 if off == 0 else 0.11
                place(mix, ep_note(midi(n), BAR * (1.6 if last else 0.9), v, 1.8 if last else 1.0),
                      t0 + off + j * 0.008, pan=(j - 1.5) * 0.18)
        # bass
        if b >= 1:
            pattern = [(0.0, 0, 1.4), (1.5, 12, 0.5), (2.0, 0, 0.9), (3.0, 7, 0.9)] if not last else [(0.0, 0, 3.5)]
            for off, iv, d in pattern:
                place(mix, bass_note(midi(root - 12 + iv), d * BEAT), t0 + off * BEAT)
        # drums from bar 2, out on the last bar except the final hit
        if 1 <= b < bars - 1:
            for beat in range(4):
                if beat in (0, 2):
                    place(mix, kick(), t0 + beat * BEAT)
                if beat in (1, 3):
                    place(mix, snare(), t0 + beat * BEAT, 0.05)
                for e8 in range(2):
                    place(mix, hat(), t0 + (beat + e8 * 0.5) * BEAT, 0.35)
        if last:
            place(mix, kick(), t0)
        # sparkle arpeggio from bar 3
        if 2 <= b < bars - 1:
            arp = tones + [tones[1] + 12]
            for s in range(8):
                n = arp[(s * 2) % len(arp)] + 12
                place(mix, pluck(midi(n)), t0 + s * 0.5 * BEAT, -0.5 if s % 2 == 0 else 0.5)
    # small room: exponentially decaying noise impulse response
    ir_n = int(0.9 * SR)
    t = np.arange(ir_n) / SR
    ir = rng.standard_normal((ir_n, 2)) * np.exp(-t / 0.28)[:, None]
    b, a = butter(1, 5000 / (SR / 2))
    ir = lfilter(b, a, ir, axis=0)
    ir /= np.sqrt((ir ** 2).sum(axis=0))
    wet = np.stack([fftconvolve(mix[:, c], ir[:, c])[:total] for c in range(2)], axis=1)
    out = mix + 0.22 * wet
    out = out[: int(seconds * SR)]
    # fades + gentle limiter + normalise to -1 dBFS peak
    fi, fo = int(0.25 * SR), int(1.6 * SR)
    out[:fi] *= np.linspace(0, 1, fi)[:, None]
    out[-fo:] *= np.linspace(1, 0, fo)[:, None] ** 1.5
    out = np.tanh(out * 1.2) / np.tanh(1.2)
    out *= 10 ** (-1 / 20) / max(1e-9, np.abs(out).max())
    return out


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else "trailer_music.wav"
    seconds = float(sys.argv[2]) if len(sys.argv) > 2 else 32.0
    pcm = (render(seconds) * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print("music ->", path, "%.1fs" % seconds)


if __name__ == "__main__":
    main()
