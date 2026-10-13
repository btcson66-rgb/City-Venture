"""Code-generated music beds for the three ~60 s ads (placeholders until licensed tracks are chosen).

Same instruments as the trailer bed (make_music.py), with an ad structure: a sparse hook, a riser into the
full groove, and a held chord under the end card.
  tycoon   116 BPM, bright major (C G Am F), four-on-the-floor
  city     100 BPM, city-pop (Fmaj7 G6 Em7 Am7), laid back
  choices  104 BPM, minor and tense (Am F C G), lifting to major for the end card
Deterministic; writes 44.1 kHz stereo 16-bit WAV.
  python3 tools/media/make_ad_music.py out.wav <tycoon|city|choices> <seconds>
"""
import os
import sys
import wave

import numpy as np
from scipy.signal import fftconvolve, butter, lfilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_music import SR, midi, ep_note, bass_note, kick, snare, hat, pluck, place  # noqa: E402

rng = np.random.default_rng(11)

MOODS = {
    "tycoon": {"bpm": 116, "four": True, "chords": [
        (48, [55, 60, 64, 67]), (55, [55, 59, 62, 67]), (57, [57, 60, 64, 69]), (53, [57, 60, 65, 69])],
        "final": (48, [55, 59, 62, 64, 67])},
    "city": {"bpm": 100, "four": False, "chords": [
        (53, [57, 60, 64, 65]), (55, [59, 62, 64, 67]), (52, [55, 59, 62, 64]), (57, [60, 64, 67, 69])],
        "final": (48, [55, 59, 62, 64, 67])},
    "choices": {"bpm": 104, "four": False, "chords": [
        (57, [57, 60, 64, 67]), (53, [57, 60, 65, 69]), (48, [55, 60, 64, 67]), (55, [55, 59, 62, 67])],
        "final": (53, [57, 60, 64, 67, 72])},   # Fmaj7(add 9th up): the lift for the end card
}


def riser(dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    b, a = butter(2, [800 / (SR / 2), 9000 / (SR / 2)], btype="band")
    noise = lfilter(b, a, rng.standard_normal(n))
    return noise * (t / dur) ** 2.2 * 0.16


def impact():
    n = int(1.6 * SR)
    t = np.arange(n) / SR
    f = 38 + 60 * np.exp(-t / 0.06)
    boom = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.5) * 0.7
    b, a = butter(2, 3000 / (SR / 2))
    crash = lfilter(b, a, rng.standard_normal(n)) * np.exp(-t / 0.35) * 0.12
    return boom + crash


def render(mood, seconds, end_card=6.0):
    m = MOODS[mood]
    beat = 60.0 / m["bpm"]
    bar = 4 * beat
    total = int((seconds + 2.0) * SR)
    mix = np.zeros((total, 2))
    end_at = max(bar * 2, seconds - end_card)
    full_bars = int(end_at // bar)          # groove bars before the end card
    hook_bars = 2                            # sparse intro under the hook card
    for b in range(full_bars):
        t0 = b * bar
        root, tones = m["chords"][b % 4]
        hook = b < hook_bars
        offs = [0.0] if hook else [0.0, 1.5 * beat, 3.0 * beat]
        for off in offs:
            for j, n in enumerate(tones):
                place(mix, ep_note(midi(n), bar * 0.9, 0.15 if off == 0 else 0.1, 1.0),
                      t0 + off + j * 0.008, pan=(j - 1.5) * 0.18)
        if not hook:
            pattern = [(0.0, 0, 1.4), (1.5, 12, 0.5), (2.0, 0, 0.9), (3.0, 7, 0.9)]
            if m["four"]:
                pattern = [(0.0, 0, 0.45), (0.5, 12, 0.4), (1.0, 0, 0.45), (1.5, 12, 0.4),
                           (2.0, 0, 0.45), (2.5, 12, 0.4), (3.0, 7, 0.45), (3.5, 12, 0.4)]
            for off, iv, d in pattern:
                place(mix, bass_note(midi(root - 12 + iv), d * beat), t0 + off * beat)
            for bt in range(4):
                if m["four"] or bt in (0, 2):
                    place(mix, kick(), t0 + bt * beat)
                if bt in (1, 3):
                    place(mix, snare(), t0 + bt * beat, 0.05)
                for e8 in range(2):
                    place(mix, hat(), t0 + (bt + e8 * 0.5) * beat, 0.35)
            arp = tones + [tones[1] + 12]
            for s in range(8):
                n = arp[(s * 2) % len(arp)] + 12
                place(mix, pluck(midi(n), vel=0.07 if mood != "city" else 0.05), t0 + s * 0.5 * beat,
                      -0.5 if s % 2 == 0 else 0.5)
        else:
            # the hook: a ticking pulse and a riser into the groove
            for s in range(8):
                place(mix, hat(), t0 + s * 0.5 * beat, 0.2)
            if b == hook_bars - 1:
                place(mix, riser(bar), t0)
    # end card: impact + held final chord
    t_end = full_bars * bar
    root, tones = m["final"]
    place(mix, impact(), t_end)
    place(mix, kick(), t_end)
    for j, n in enumerate(tones):
        place(mix, ep_note(midi(n), seconds - t_end + 1.0, 0.17, 2.4), t_end + j * 0.012, pan=(j - 2) * 0.15)
    place(mix, bass_note(midi(root - 12), min(4.0, seconds - t_end)), t_end)
    arp = tones + [tones[2] + 12]
    for s in range(6):
        place(mix, pluck(midi(arp[s % len(arp)] + 12), 0.5, 0.05), t_end + 0.3 + s * 0.25, -0.4 if s % 2 else 0.4)
    # room
    ir_n = int(0.9 * SR)
    t = np.arange(ir_n) / SR
    ir = rng.standard_normal((ir_n, 2)) * np.exp(-t / 0.28)[:, None]
    bb, aa = butter(1, 5000 / (SR / 2))
    ir = lfilter(bb, aa, ir, axis=0)
    ir /= np.sqrt((ir ** 2).sum(axis=0))
    wet = np.stack([fftconvolve(mix[:, c], ir[:, c])[:total] for c in range(2)], axis=1)
    out = (mix + 0.2 * wet)[: int(seconds * SR)]
    fi, fo = int(0.1 * SR), int(1.4 * SR)
    out[:fi] *= np.linspace(0, 1, fi)[:, None]
    out[-fo:] *= np.linspace(1, 0, fo)[:, None] ** 1.5
    out = np.tanh(out * 1.3) / np.tanh(1.3)
    out *= 10 ** (-1 / 20) / max(1e-9, np.abs(out).max())
    return out


def main():
    path = sys.argv[1]
    mood = sys.argv[2] if len(sys.argv) > 2 else "tycoon"
    seconds = float(sys.argv[3]) if len(sys.argv) > 3 else 60.0
    end_card = float(sys.argv[4]) if len(sys.argv) > 4 else 6.0
    pcm = (render(mood, seconds, end_card) * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print("ad music ->", path, mood, "%.1fs" % seconds)


if __name__ == "__main__":
    main()
