"""Synthesises Sand Burst Magic's original sound effects (sand grains,
bursts, glass sparkles).

The game's music comes from tool/generate_music.py (chosen by the studio).
This script also keeps an alternative "magic" music set, written only with
--magic-music, which was offered and not chosen.

Everything is generated here from physical models and oscillators, so the
audio is fully original and needs no licence:

* liquid: the Minnaert bubble model (a damped sine whose pitch rises as the
  bubble rises, after van den Doel, "Physically-based models for liquid
  sounds", 2005), many small bubbles over a filtered-noise stream, with the
  pitch of the "glug" climbing as the tube fills;
* glass: inharmonic partials of a struck glass (ratios close to a wine
  glass), each with its own decay and a slight beating, plus a short strike
  click;
* room: a synthetic reverb (convolution with decaying, darkening noise);
* music: warm detuned pads, a soft felt-piano voice, a sub bass and water
  drops, in loops that wrap around seamlessly.

Run from the project root:  python3 tool/generate_audio.py
(needs numpy, scipy and ffmpeg with libvorbis). Add --preview DIR to also
write MP3 copies for listening, and --magic-music to replace the music loops
with the alternative set.
"""
import argparse
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np
from scipy import signal

ROOT = Path(__file__).resolve().parent.parent
SFX = ROOT / 'assets/audio/sfx'
MUSIC = ROOT / 'assets/audio/music'
SR = 44100
rng = np.random.default_rng(20261021)


# ------------------------------------------------------------------ basics

def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def silence(dur):
    return np.zeros(int(SR * dur))


def place(buf, sig, start, gain=1.0):
    i = int(start * SR)
    if i >= len(buf):
        return
    end = min(len(buf), i + len(sig))
    buf[i:end] += gain * sig[: end - i]


def adsr(n, attack, release, total=None):
    """Linear attack, cosine release, as an array of length n."""
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-5), 0, 1)
    dur = n / SR if total is None else total
    r = np.clip((dur - t) / max(release, 1e-5), 0, 1)
    r = 0.5 - 0.5 * np.cos(np.pi * r)
    return a * r


def lowpass(x, hz, order=2):
    sos = signal.butter(order, hz, 'low', fs=SR, output='sos')
    return signal.sosfilt(sos, x)


def highpass(x, hz, order=2):
    sos = signal.butter(order, hz, 'high', fs=SR, output='sos')
    return signal.sosfilt(sos, x)


def bandpass(x, lo, hi, order=2):
    sos = signal.butter(order, [lo, hi], 'band', fs=SR, output='sos')
    return signal.sosfilt(sos, x)


def normalise(x, peak):
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak


def note(n):
    """MIDI note number to Hz."""
    return 440.0 * 2 ** ((n - 69) / 12)


# ------------------------------------------------------------------ room

def reverb_ir(seconds=1.6, damping=3500, predelay=0.012):
    """A small, soft room: decaying noise that darkens over time."""
    n = int(SR * seconds)
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    # Darken the tail: blend a bright and a dark copy over time.
    bright = lowpass(noise, 9000)
    dark = lowpass(noise, damping)
    mix = np.clip(t / (seconds * 0.5), 0, 1)
    tail = (bright * (1 - mix) + dark * mix) * np.exp(-t * 6.9 / seconds)
    ir = np.zeros(int(SR * predelay) + n)
    ir[int(SR * predelay):] = tail
    # A few early reflections.
    for d, g in [(0.007, 0.5), (0.013, 0.35), (0.021, 0.25), (0.034, 0.18)]:
        ir[int(SR * d)] += g
    return ir / np.sqrt(np.sum(ir ** 2))


IR_SMALL = None
IR_HALL = None


def with_room(x, wet=0.22, ir=None):
    ir = IR_SMALL if ir is None else ir
    tail = signal.fftconvolve(x, ir)[: len(x) + len(ir) - 1]
    dry = np.concatenate([x, np.zeros(len(tail) - len(x))])
    return dry * (1 - wet) + tail * wet * 0.6


def trim_silence(x, threshold=0.004, pad=0.05):
    idx = np.nonzero(np.abs(x) > threshold)[0]
    if len(idx) == 0:
        return x
    end = min(len(x), idx[-1] + int(SR * pad))
    out = x[:end].copy()
    n = min(len(out), int(SR * 0.03))
    out[-n:] *= np.linspace(1, 0, n)
    return out


# ------------------------------------------------------------------ liquid

def bubble(f0, gain=1.0, xi=0.1, length=None):
    """One Minnaert bubble: damped sine, pitch rising as it rises."""
    d = 0.043 * f0 + 0.0014 * f0 ** 1.5          # damping (1/s)
    dur = length or min(0.25, 6.0 / d)
    t = t_axis(dur)
    f = f0 * (1 + xi * d * t)
    phase = 2 * np.pi * np.cumsum(f) / SR
    a = np.exp(-d * t)
    a *= np.clip(t / 0.0015, 0, 1)                # no click
    m = int(len(a) * 0.2)
    a[len(a) - m:] *= np.linspace(1, 0, m)
    return gain * np.sin(phase) * a


def pour_sound(dur=0.52, start_hz=210, end_hz=420):
    """Liquid pouring into a tube: a soft stream, small bubbles, and a few
    low 'glugs' whose pitch climbs as the tube fills."""
    buf = silence(dur + 0.3)
    # Stream: band-limited noise with a gentle flutter.
    n = int(SR * dur)
    stream = bandpass(rng.standard_normal(n), 350, 2400)
    flutter = 1 + 0.35 * lowpass(rng.standard_normal(n), 18)
    stream *= flutter * adsr(n, 0.03, 0.12)
    place(buf, stream, 0, 0.09)
    # Low glugs, climbing with the level.
    glugs = 5
    for k in range(glugs):
        pos = 0.03 + k * (dur - 0.12) / (glugs - 1) + rng.uniform(-0.012, 0.012)
        f = start_hz + (end_hz - start_hz) * k / (glugs - 1)
        place(buf, bubble(f * rng.uniform(0.96, 1.04), xi=0.18), pos,
              0.55 - 0.05 * k)
    # Fine bubbles.
    t = 0.02
    while t < dur - 0.05:
        f = rng.uniform(700, 1700)
        place(buf, bubble(f, xi=rng.uniform(0.06, 0.16)), t, rng.uniform(0.05, 0.16))
        t += rng.uniform(0.012, 0.04)
    return buf


def drop(f0=1300, gain=1.0):
    """A water drop: a 'plink' (fast rising bubble) with a tiny splash."""
    buf = silence(0.4)
    place(buf, bubble(f0, xi=0.55), 0.0, gain)
    splash = highpass(rng.standard_normal(int(SR * 0.03)), 2500)
    splash *= np.exp(-np.arange(len(splash)) / (SR * 0.006))
    place(buf, splash, 0.0, 0.05 * gain)
    return buf


# ------------------------------------------------------------------ glass

GLASS_RATIOS = [1.0, 2.32, 4.25, 6.63, 9.38]


def glass(f0, dur=1.2, decay=0.55, bright=1.0, strike=0.25):
    """A struck glass: inharmonic partials with their own decays and a
    slight beating, plus a short click."""
    t = t_axis(dur)
    out = np.zeros_like(t)
    for k, r in enumerate(GLASS_RATIOS):
        f = f0 * r
        if f > SR * 0.45:
            break
        amp = (0.55 ** k) * (bright if k else 1.0)
        tau = decay / (1 + 1.4 * k)
        beat = 1 + 0.0015 * (k + 1)
        part = np.sin(2 * np.pi * f * t) + 0.6 * np.sin(2 * np.pi * f * beat * t + 1.3)
        out += amp * part * np.exp(-t / tau)
    out *= np.clip(t / 0.0008, 0, 1)
    click = bandpass(rng.standard_normal(int(SR * 0.01)), 2500, 9000)
    k = np.arange(len(click))
    click *= np.exp(-k / (SR * 0.0015)) * np.clip(k / (SR * 0.0004), 0, 1)
    out[: len(click)] += strike * click * np.max(np.abs(out[:2000]) + 1e-9)
    # Fade out the last part so a note never ends with a click.
    n = len(out)
    m = int(n * 0.35)
    out[n - m:] *= 0.5 + 0.5 * np.cos(np.linspace(0, np.pi, m))
    return out / 1.6


def cork_pop(gain=1.0):
    """A soft stopper going in: a short falling 'tuk' with a little air."""
    t = t_axis(0.09)
    f = 520 * np.exp(-t * 18) + 180
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.018)
    air = lowpass(rng.standard_normal(len(t)), 2200) * np.exp(-t / 0.01) * 0.25
    return gain * (body + air) * np.clip(t / 0.001, 0, 1)


# ------------------------------------------------------------------ effects

def grains(dur, density=1200, hz=(2000, 7000)):
    """Falling sand: many tiny, randomly timed clicks through a band-pass,
    thinning out towards the end."""
    n = int(SR * dur)
    x = np.zeros(n)
    count = int(density * dur)
    times = np.sort(rng.random(count) ** 1.6) * (n - 40)
    for i in times.astype(int):
        x[i:i + 3] += rng.uniform(-1, 1) * np.array([1.0, -0.6, 0.25])
    x = bandpass(x, hz[0], hz[1])
    env = np.exp(-np.linspace(0, 3.0, n))
    return x * env


def whoosh(dur, lo, hi):
    """Filtered noise sweeping up in brightness."""
    n = int(SR * dur)
    noise = rng.standard_normal(n)
    out = np.zeros(n)
    steps = 12
    for k in range(steps):
        a, b = k * n // steps, (k + 1) * n // steps
        f = lo * (hi / lo) ** (k / (steps - 1))
        out[a:b] = lowpass(noise, f)[a:b]
    t = np.linspace(0, 1, n)
    return out * np.sin(np.pi * t) ** 1.5


def sfx():
    out = {}
    # Select: a light, short tap on glass.
    s = glass(2350, 0.35, 0.09, bright=0.5, strike=0.35)
    out['select'] = normalise(with_room(s, 0.12), 0.42)

    # Button: a soft, dry click.
    t = t_axis(0.06)
    click = np.sin(2 * np.pi * 1250 * t) * np.exp(-t / 0.008)
    click += 0.4 * lowpass(rng.standard_normal(len(t)), 4000) * np.exp(-t / 0.003)
    out['button'] = normalise(click, 0.38)

    # Place: a soft thud as the block lands, then a short sand hiss.
    buf = silence(0.4)
    t = t_axis(0.12)
    thud = np.sin(2 * np.pi * 140 * t) * np.exp(-t / 0.03)
    thud += 0.5 * lowpass(rng.standard_normal(len(t)), 900) * np.exp(-t / 0.02)
    place(buf, thud, 0.0, 0.8)
    place(buf, grains(0.28, density=900, hz=(2500, 7000)), 0.03, 0.5)
    out['place'] = normalise(with_room(buf, 0.1), 0.55)

    # Sand: a granular trickle that thins out as the sand settles.
    out['sand'] = normalise(with_room(grains(0.6, density=1400, hz=(1800, 6500)), 0.12), 0.4)

    # Invalid: a muffled knock, twice, low and gentle.
    buf = silence(0.32)
    knock = lowpass(glass(520, 0.2, 0.05, bright=0.3, strike=0.25), 1500)
    place(buf, knock, 0.0)
    place(buf, knock, 0.1, 0.7)
    out['invalid'] = normalise(with_room(buf, 0.1), 0.5)

    # Burst: a rising whoosh, a scatter of grains and a bright sparkle.
    buf = silence(1.4)
    place(buf, whoosh(0.35, 400, 5000), 0.0, 0.6)
    place(buf, grains(0.7, density=2600, hz=(2000, 9000)), 0.18, 0.55)
    for k, n in enumerate([84, 88, 91]):
        place(buf, glass(note(n), 0.8, 0.3, bright=0.8), 0.2 + k * 0.05, 0.45)
    out['burst'] = normalise(with_room(buf, 0.25), 0.72)

    # Combo: a bigger burst with a quick rising arpeggio.
    buf = silence(1.8)
    place(buf, whoosh(0.4, 300, 7000), 0.0, 0.7)
    place(buf, grains(0.9, density=3600, hz=(2000, 10000)), 0.2, 0.6)
    for k, n in enumerate([79, 84, 88, 91, 96]):
        place(buf, glass(note(n), 0.9, 0.35, bright=0.9), 0.18 + k * 0.055, 0.5)
    out['combo'] = normalise(with_room(buf, 0.32, IR_HALL), 0.8)

    # Power-up: a magical upward shimmer.
    buf = silence(1.3)
    place(buf, whoosh(0.5, 600, 6000), 0.0, 0.4)
    for k in range(8):
        place(buf, glass(note(76 + k * 3), 0.5, 0.18, bright=0.7, strike=0.05),
              0.04 + k * 0.045, 0.32)
    out['power'] = normalise(with_room(buf, 0.3), 0.6)

    # Game over: three soft notes falling, then sand running out.
    buf = silence(2.0)
    for k, n in enumerate([79, 74, 67]):
        place(buf, glass(note(n), 1.1, 0.5, bright=0.4, strike=0.1), k * 0.22, 0.6)
    place(buf, grains(0.9, density=700, hz=(1500, 5000)), 0.6, 0.3)
    out['over'] = normalise(with_room(buf, 0.3, IR_HALL), 0.6)

    # Win: a glass-marimba run up a pentatonic scale, then a shimmering
    # chord in a bigger room.
    buf = silence(2.6)
    run = [72, 76, 79, 84, 88]
    for k, n in enumerate(run):
        place(buf, glass(note(n), 0.8, 0.35, bright=0.7), k * 0.085, 0.75)
    for n in [79, 84, 88, 91]:
        place(buf, glass(note(n), 2.0, 0.9, bright=0.5, strike=0.1), 0.48, 0.5)
    place(buf, drop(1500), 0.62, 0.25)
    out['win'] = normalise(with_room(buf, 0.35, IR_HALL), 0.8)

    # Undo: a little reversed bubble ("bloop" going back) with air.
    t = t_axis(0.2)
    f = 760 - 360 * (t / 0.2) ** 0.7
    bloop = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * np.clip(t / 0.2, 0, 1)) ** 1.5
    air = bandpass(rng.standard_normal(len(t)), 500, 3000) * np.sin(np.pi * t / 0.2) * 0.08
    out['undo'] = normalise(with_room(bloop + air, 0.15), 0.42)

    # Hint: two soft glass notes, a fifth apart, like a gentle "look here".
    buf = silence(1.0)
    place(buf, glass(note(84), 0.9, 0.4, bright=0.5, strike=0.1), 0.0, 0.7)
    place(buf, glass(note(91), 0.9, 0.45, bright=0.5, strike=0.1), 0.09, 0.6)
    out['hint'] = normalise(with_room(buf, 0.3), 0.5)

    # Achievement: a brighter arpeggio with high sparkles.
    buf = silence(2.2)
    for k, n in enumerate([79, 83, 86, 91, 95]):
        place(buf, glass(note(n), 1.0, 0.45, bright=0.9), k * 0.07, 0.7)
    for k in range(6):
        place(buf, glass(note(98 + (k % 3) * 2), 0.5, 0.15, bright=0.4, strike=0),
              0.42 + k * 0.06, 0.18)
    out['achievement'] = normalise(with_room(buf, 0.35, IR_HALL), 0.74)

    return {k: trim_silence(v) for k, v in out.items()}


# ------------------------------------------------------------------ music

def pad_voice(freqs, dur, attack=1.8, release=2.2, cutoff=1400, voices=3):
    """Warm, slowly moving pad: detuned, softened saw-like tones."""
    n = int(SR * dur)
    t = np.arange(n) / SR
    sig = np.zeros(n)
    for f in freqs:
        for v in range(voices):
            det = (v - (voices - 1) / 2) * 0.09          # semitones
            ff = f * 2 ** (det / 12)
            # Slow vibrato-like drift so the pad breathes.
            drift = 1 + 0.0012 * np.sin(2 * np.pi * (0.13 + 0.05 * v) * t + v)
            ph = 2 * np.pi * np.cumsum(ff * drift) / SR
            for h in range(1, 9):
                sig += np.sin(h * ph) / (h ** 1.6)
    sig = lowpass(sig, cutoff, 2)
    sig *= adsr(n, attack, release)
    return sig / (len(freqs) * voices * 2.2)


def felt_piano(f, dur=2.4, gain=1.0):
    """A soft, rounded piano-like note (felt hammer)."""
    t = t_axis(dur)
    out = np.zeros_like(t)
    for h, (a, tau) in enumerate([(1.0, 1.6), (0.35, 0.8), (0.12, 0.45), (0.05, 0.3)], 1):
        inharm = 1 + 0.0004 * h * h
        out += a * np.sin(2 * np.pi * f * h * inharm * t) * np.exp(-t / tau)
    out *= np.clip(t / 0.006, 0, 1)
    m = int(len(out) * 0.3)
    out[-m:] *= 0.5 + 0.5 * np.cos(np.linspace(0, np.pi, m))
    out = lowpass(out, 2600)
    return gain * out


def sub_bass(f, dur, gain=1.0):
    t = t_axis(dur)
    s = np.sin(2 * np.pi * f * t) + 0.15 * np.sin(4 * np.pi * f * t)
    return gain * s * adsr(len(t), 0.4, 0.8)


def render_loop(bars, bar_len, chords, melody, drops, out_peak=0.5,
                pad_cut=1400, pad_gain=0.55, piano_gain=0.22, bass_gain=0.16,
                drop_gain=0.07, room=None, wet=0.4):
    """Renders [bars] bars as a seamless loop: sound that starts before the
    loop (pads fade in early) is added to its end, and the tail after the
    end (reverb, ringing notes) to its start."""
    total = bars * bar_len
    lead, tail = 1.0, 7.0
    buf = silence(lead + total + tail)

    def at(sig, when, gain):
        place(buf, sig, lead + when, gain)

    for i in range(bars):
        ch = chords[i % len(chords)]
        start = i * bar_len
        at(pad_voice([note(n) for n in ch[1:]], bar_len + 2.0, cutoff=pad_cut),
           start - 0.4, pad_gain)
        at(sub_bass(note(ch[0]), bar_len + 0.6), start, bass_gain)
    for (beat, n, vel) in melody:
        at(felt_piano(note(n), 3.0), beat * bar_len / 4, piano_gain * vel)
    for (beat, hz) in drops:
        at(drop(hz), beat * bar_len / 4, drop_gain)
    wet_buf = with_room(buf, wet, room or IR_HALL)
    n_lead, n_total = int(SR * lead), int(SR * total)
    loop = wet_buf[n_lead:n_lead + n_total].copy()
    loop[-n_lead:] += wet_buf[:n_lead]
    rest = wet_buf[n_lead + n_total:]
    while len(rest):
        k = min(len(rest), n_total)
        loop[:k] += rest[:k]
        rest = rest[k:]
    # Gentle level: music sits under the effects.
    return normalise(loop, out_peak)


def music():
    tracks = {}
    # Main menu: calm and warm, a little hopeful. 66 bpm, 4/4, 16 bars.
    bar = 4 * 60 / 66
    chords = [
        [36, 48, 55, 59, 64],   # Cmaj7
        [40, 47, 55, 59, 62],   # Em7
        [45, 52, 59, 60, 64],   # Am(add9)
        [41, 48, 57, 60, 67],   # Fmaj7/9
    ]
    pent = [72, 74, 76, 79, 81, 84]
    melody = []
    phrase = [(0, 4), (1, 3), (2, 2), (3.5, 3), (6, 1), (7, 0)]
    for b in range(0, 16, 2):
        if b % 8 == 6:
            continue          # breathing space
        shift = [0, 1, -1, 0][(b // 2) % 4]
        for (beat, k) in phrase:
            melody.append((b * 4 + beat, pent[max(0, min(5, k + shift))],
                           rng.uniform(0.75, 1.0)))
    drops = [(b * 4 + rng.uniform(0, 4), rng.uniform(1100, 1900))
             for b in range(16) if rng.random() < 0.45]
    tracks['main'] = render_loop(16, bar, chords, melody, drops, out_peak=0.5)

    # Relax: slower and sparser, more water. 54 bpm, 16 bars.
    bar = 4 * 60 / 54
    chords = [
        [33, 45, 52, 59, 64],   # Am9
        [29, 45, 48, 55, 64],   # Fmaj7
        [36, 48, 55, 62, 64],   # Cadd9
        [31, 47, 50, 57, 62],   # G6/9
    ]
    pent = [69, 72, 74, 76, 79, 81]
    melody = []
    for b in range(0, 16, 4):
        for (beat, k) in [(0, 4), (2, 3), (5, 1), (9, 2)]:
            melody.append((b * 4 + beat, pent[k], rng.uniform(0.6, 0.9)))
    drops = [(b * 4 + rng.uniform(0, 4), rng.uniform(900, 1700))
             for b in range(16) for _ in range(2) if rng.random() < 0.55]
    tracks['relax'] = render_loop(16, bar, chords, melody, drops, out_peak=0.48,
                                  pad_cut=1100, piano_gain=0.16, drop_gain=0.09,
                                  wet=0.5)
    return tracks


# ------------------------------------------------------------------ output

def write(path, x, quality, fmt='ogg'):
    x = np.clip(x, -1, 1)
    pcm = (x * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp:
        with wave.open(tmp.name, 'wb') as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        codec = ['-c:a', 'libvorbis', '-q:a', str(quality)] if fmt == 'ogg' \
            else ['-c:a', 'libmp3lame', '-q:a', '2']
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', tmp.name,
                        *codec, str(path)], check=True)
        Path(tmp.name).unlink()


def main():
    global IR_SMALL, IR_HALL
    ap = argparse.ArgumentParser()
    ap.add_argument('--preview', help='also write MP3 copies to this folder')
    ap.add_argument('--magic-music', action='store_true',
                    help='also replace the music with the alternative set')
    args = ap.parse_args()
    IR_SMALL = reverb_ir(0.9, 4200)
    IR_HALL = reverb_ir(2.6, 3000, predelay=0.02)
    SFX.mkdir(parents=True, exist_ok=True)
    MUSIC.mkdir(parents=True, exist_ok=True)
    effects = sfx()
    tracks = music() if args.magic_music else {}
    prev = Path(args.preview) if args.preview else None
    if prev:
        prev.mkdir(parents=True, exist_ok=True)
    for name, x in effects.items():
        write(SFX / f'{name}.ogg', x, 5)
        if prev:
            write(prev / f'sfx-{name}.mp3', x, 0, 'mp3')
    for name, x in tracks.items():
        write(MUSIC / f'{name}.ogg', x, 3)
        if prev:
            write(prev / f'music-{name}.mp3', x, 0, 'mp3')
    print('Effects written to', SFX, *(['and music to', MUSIC] if tracks else []))


if __name__ == '__main__':
    main()
