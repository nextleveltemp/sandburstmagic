"""Generates Sand Burst Magic's music loops (main and relax).

The game's music: warm detuned pads and soft bell arpeggios, rendered as
seamless loops. This is the original music recipe, kept when the sound
effects were remade (see tool/generate_audio.py, which also has an
alternative "--magic-music" set that was not chosen). Fully synthesised:
no samples, nothing to license.

Run from the project root:  python3 tool/generate_music.py
(needs numpy and ffmpeg with libvorbis)
"""
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
MUSIC = ROOT / 'assets/audio/music'
SR = 32000


def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def env(dur, attack=0.004, decay=0.2):
    t = t_axis(dur)
    a = np.clip(t / max(attack, 1e-6), 0, 1)
    d = np.exp(-t / max(decay, 1e-6))
    return a * d


def bell(freq, dur, decay=0.35, bright=0.25):
    t = t_axis(dur)
    sig = np.sin(2 * np.pi * freq * t)
    sig += bright * np.sin(2 * np.pi * freq * 2.0 * t) * np.exp(-t / (decay * 0.5))
    sig += 0.12 * bright * np.sin(2 * np.pi * freq * 3.01 * t) * np.exp(-t / (decay * 0.3))
    return sig * env(dur, 0.003, decay)


def place_at(buf, sig, start):
    i = int(start * SR)
    end = min(len(buf), i + len(sig))
    buf[i:end] += sig[: end - i]


def normalise(sig, peak=0.8):
    m = np.max(np.abs(sig)) or 1.0
    return sig / m * peak


def write_ogg(path, sig, quality=4):
    sig = np.clip(sig, -1, 1)
    pcm = (sig * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp:
        with wave.open(tmp.name, 'wb') as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        subprocess.run(
            ['ffmpeg', '-y', '-loglevel', 'error', '-i', tmp.name,
             '-c:a', 'libvorbis', '-q:a', str(quality), str(path)],
            check=True,
        )
        Path(tmp.name).unlink()


def note(n):
    """MIDI note number to Hz."""
    return 440.0 * 2 ** ((n - 69) / 12)


def pad(freqs, dur, attack=1.2, release=1.6):
    t = t_axis(dur)
    sig = np.zeros_like(t)
    for f in freqs:
        for detune in (-0.12, 0.12):
            ff = f * 2 ** (detune / 12)
            sig += np.sin(2 * np.pi * ff * t) + 0.18 * np.sin(2 * np.pi * 2 * ff * t)
    a = np.clip(t / attack, 0, 1)
    r = np.clip((dur - t) / release, 0, 1)
    return sig * a * r / (len(freqs) * 2)


def loop(chords, bar, arp_pattern, arp_gain, pad_gain, path, tail=4.0):
    total = bar * len(chords)
    buf = np.zeros(int(SR * (total + tail)))
    for i, ch in enumerate(chords):
        start = i * bar
        place_at(buf, pad([note(n) for n in ch], bar + 1.5) * pad_gain, start)
        if arp_pattern:
            step = bar / len(arp_pattern)
            for k, idx in enumerate(arp_pattern):
                if idx is None:
                    continue
                n = ch[idx % len(ch)] + 12
                place_at(buf, bell(note(n), 1.6, 0.7, 0.15) * arp_gain, start + k * step)
    # Wrap the tail into the start so the loop is seamless.
    n_total = int(SR * total)
    head = buf[:n_total].copy()
    head[: len(buf) - n_total] += buf[n_total:]
    sig = normalise(head, 0.55)
    write_ogg(path, sig, quality=3)


def music():
    # Main: calm, slightly uplifting (Cmaj9 - Am7 - Fmaj7 - G6sus), 2.8 s bars.
    main_chords = [
        [48, 55, 64, 67, 71], [45, 52, 60, 64, 67],
        [41, 48, 57, 60, 64], [43, 50, 59, 62, 64],
    ] * 3
    loop(main_chords, 2.8, [0, 2, 4, None, 3, None, 2, None], 0.16, 0.5, MUSIC / 'main.ogg')
    # Relax: slower, sparse, mostly pads.
    relax_chords = [
        [45, 52, 59, 64], [41, 48, 55, 60, 64],
        [48, 55, 62, 64], [43, 50, 57, 62],
    ] * 2
    loop(relax_chords, 4.6, [2, None, None, 4, None, None], 0.12, 0.55, MUSIC / 'relax.ogg')



if __name__ == '__main__':
    MUSIC.mkdir(parents=True, exist_ok=True)
    music()
    print('Music written to', MUSIC)
