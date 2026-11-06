"""Generates the placeholder music loops (seamless, mono, 22.05 kHz WAV).

    python3 tools/audio/gen_music.py      # writes assets/audio/music_camp.wav and music_delve.wav

Pure synthesis (sine pads, bell melody, soft bass and percussion), so there is
no licensing risk. Replace with real music later by keeping the file names.
"""
import os
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio")
NOTE = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}


def freq(name: str, octave: int) -> float:
    return 440.0 * 2 ** ((NOTE[name] + 12 * (octave + 1) - 69) / 12)


def env(n: int, attack: float, decay: float) -> np.ndarray:
    t = np.arange(n) / SR
    a = np.minimum(1.0, t / max(attack, 1e-4))
    return a * np.exp(-t * decay)


def add(buf: np.ndarray, start: float, sig: np.ndarray) -> None:
    """Adds a signal at a time offset, wrapping past the end (seamless loop)."""
    i = int(start * SR) % len(buf)
    end = i + len(sig)
    if end <= len(buf):
        buf[i:end] += sig
    else:
        cut = len(buf) - i
        buf[i:] += sig[:cut]
        buf[: end - len(buf)] += sig[cut:]


def tone(f: float, dur: float, partials, attack: float, decay: float, amp: float) -> np.ndarray:
    n = int(dur * SR)
    t = np.arange(n) / SR
    s = sum(w * np.sin(2 * np.pi * f * m * t) for m, w in partials)
    return amp * s * env(n, attack, decay)


def pad(f: float, dur: float, amp: float) -> np.ndarray:
    n = int(dur * SR)
    t = np.arange(n) / SR
    s = np.sin(2 * np.pi * f * t) + 0.6 * np.sin(2 * np.pi * f * 1.003 * t) + 0.15 * np.sin(4 * np.pi * f * t)
    shape = np.minimum(1.0, t / 0.35) * np.minimum(1.0, (dur - t) / 0.5).clip(0)
    return amp * s * shape * (0.85 + 0.15 * np.sin(2 * np.pi * 0.5 * t))


def noise_tick(dur: float, decay: float, amp: float, rng) -> np.ndarray:
    n = int(dur * SR)
    s = np.diff(rng.standard_normal(n + 1))
    return amp * s * env(n, 0.001, decay)


def kick(amp: float) -> np.ndarray:
    n = int(0.3 * SR)
    t = np.arange(n) / SR
    f = 50 + 70 * np.exp(-t * 30)
    return amp * np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 12)


def chord_notes(chord: str):
    minor = chord.endswith("m")
    root = chord[:-1] if minor else chord
    r = NOTE[root]
    third = (r + (3 if minor else 4)) % 12
    fifth = (r + 7) % 12
    names = {v: k for k, v in NOTE.items() if "#" not in k or k in ("G#", "C#", "F#")}
    return root, [names.get(third, "G#"), names[fifth]]


def render(bpm: float, chords, scale, octave_mel: int, drums: bool, seed: int, mel_density: float) -> np.ndarray:
    rng = np.random.default_rng(seed)
    beat = 60.0 / bpm
    bar = 4 * beat
    buf = np.zeros(int(len(chords) * bar * SR))
    mel_idx = 2
    for b, chord in enumerate(chords):
        t0 = b * bar
        root, others = chord_notes(chord)
        for name in [root] + others:
            add(buf, t0, pad(freq(name, 4), bar + 0.4, 0.045))
        for beat_i in (0, 2):
            add(buf, t0 + beat_i * beat, tone(freq(root, 2), beat * 1.6, [(1, 1.0), (2, 0.25)], 0.01, 3.0, 0.22))
        for e in range(8):
            t = t0 + e * beat / 2
            if e % 2 == 1:
                add(buf, t, noise_tick(0.06, 60, 0.025, rng))
            if drums:
                if e in (0, 4):
                    add(buf, t, kick(0.35))
                if e in (2, 6):
                    add(buf, t, noise_tick(0.18, 18, 0.06, rng))
            if rng.random() < mel_density or e == 0:
                # Random walk over the pentatonic scale, pulled towards chord tones.
                step = rng.choice([-2, -1, -1, 0, 1, 1, 2])
                mel_idx = int(np.clip(mel_idx + step, 0, len(scale) * 2 - 1))
                name = scale[mel_idx % len(scale)]
                if e == 0 and name not in [root] + others:
                    name = root
                octave = octave_mel + mel_idx // len(scale)
                add(buf, t, tone(freq(name, octave), 1.2, [(1, 1.0), (2.76, 0.25), (5.4, 0.06)], 0.004, 4.5, 0.11))
    buf = np.tanh(buf * 1.2)
    return buf / np.max(np.abs(buf)) * 0.8


def write(name: str, data: np.ndarray) -> None:
    path = os.path.abspath(os.path.join(OUT, name))
    pcm = (data * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print(path, "%.1f s" % (len(data) / SR))


if __name__ == "__main__":
    write("music_camp.wav", render(84, ["C", "Am", "F", "G", "C", "Em", "F", "G"], ["C", "D", "E", "G", "A"], 5, False, 7, 0.45))
    write("music_delve.wav", render(100, ["Am", "F", "C", "G", "Am", "F", "G", "E"], ["A", "C", "D", "E", "G"], 4, True, 11, 0.55))
