"""BOMB MATH — original procedural audio assets.

Generates every sound effect and the ambient music loop as 16-bit mono WAV
files. Pure standard library: no samples, no licensing, no network.

Run:  python tool/synth_audio.py
"""

from __future__ import annotations

import math
import os
import random
import struct
import wave

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = random.Random(20261018)


def secs(n: int) -> float:
    return n / SR


def buffer(dur: float):
    return [0.0] * max(1, int(SR * dur))


def add(dst, src, at=0.0, gain=1.0):
    start = int(at * SR)
    for i, v in enumerate(src):
        j = start + i
        if 0 <= j < len(dst):
            dst[j] += v * gain


def env_ad(n: int, attack=0.004, curve=3.0):
    a = max(1, int(attack * SR))
    out = [0.0] * n
    for i in range(n):
        if i < a:
            out[i] = i / a
        else:
            out[i] = (1.0 - (i - a) / max(1, n - a)) ** curve
    return out


def sine(freq, dur, amp=0.5, attack=0.004, curve=3.0, phase=0.0):
    n = int(SR * dur)
    out = [0.0] * n
    e = env_ad(n, attack, curve)
    ph = phase
    for i in range(n):
        out[i] = amp * e[i] * math.sin(ph)
        ph += 2 * math.pi * freq / SR
    return out


def glide(f0, f1, dur, amp=0.5, attack=0.003, curve=3.0, kind="sine"):
    n = int(SR * dur)
    out = [0.0] * n
    e = env_ad(n, attack, curve)
    ph = 0.0
    for i in range(n):
        f = f0 + (f1 - f0) * (i / n)
        ph += 2 * math.pi * f / SR
        s = math.sin(ph)
        if kind == "square":
            s = 1.0 if s >= 0 else -1.0
        out[i] = amp * e[i] * s
    return out


def noise(dur, amp=0.5, attack=0.001, curve=3.0):
    n = int(SR * dur)
    e = env_ad(n, attack, curve)
    return [amp * e[i] * rng.uniform(-1.0, 1.0) for i in range(n)]


def lowpass(x, cutoff=1200.0, resonance=0.2):
    dt = 1.0 / SR
    rc = 1.0 / (2 * math.pi * cutoff)
    alpha = dt / (rc + dt)
    y = 0.0
    out = []
    for v in x:
        y += alpha * (v - y)
        out.append(y)
    return out


def highpass(x, cutoff=800.0):
    lp = lowpass(x, cutoff)
    return [v - l for v, l in zip(x, lp)]


def drive(x, amount=2.0):
    return [math.tanh(v * amount) / math.tanh(amount) for v in x]


def echo(x, delay=0.14, feedback=0.35, mix=0.35):
    d = int(delay * SR)
    out = list(x) + [0.0] * d
    for i in range(len(x)):
        out[i + d] += out[i] * feedback * mix
    return out


def normalize(x, peak=0.92):
    hi = max(1e-9, max(abs(v) for v in x))
    return [v * peak / hi for v in x]


def write(name, samples, peak=0.92):
    samples = normalize(samples, peak)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples
        )
        w.writeframes(frames)
    print(f"  {name}.wav  {os.path.getsize(path) / 1024:.1f} KB")


def click():
    b = buffer(0.07)
    add(b, sine(1180, 0.045, 0.35, curve=5))
    add(b, noise(0.02, 0.18, curve=6))
    return b


def cut():
    b = buffer(0.30)
    add(b, noise(0.05, 0.5, curve=4))
    add(b, glide(420, 90, 0.22, 0.42, curve=2.5), at=0.01)
    add(b, sine(2200, 0.05, 0.2, curve=6), at=0.0)
    return echo(b, 0.05, 0.2, 0.25)


def wrong():
    b = buffer(0.38)
    add(b, glide(190, 120, 0.32, 0.36, curve=1.6, kind="square"))
    add(b, glide(97, 70, 0.34, 0.22, curve=1.6))
    add(b, noise(0.16, 0.2, curve=2.0))
    return drive(b, 1.6)


def tick():
    b = buffer(0.05)
    add(b, sine(1600, 0.028, 0.32, curve=7))
    add(b, noise(0.012, 0.12, curve=7))
    return b


def defuse():
    b = buffer(1.0)
    notes = [523.25, 659.25, 783.99, 1046.5]
    for i, f in enumerate(notes):
        add(b, sine(f, 0.5, 0.24, curve=2.4), at=i * 0.085)
        add(b, sine(f * 2, 0.28, 0.06, curve=3.0), at=i * 0.085)
    shimmer = noise(0.7, 0.05, attack=0.2, curve=1.5)
    add(b, highpass(shimmer, 3800), at=0.12)
    return echo(b, 0.16, 0.25, 0.3)


def explosion():
    b = buffer(1.5)
    rumble = lowpass(noise(1.4, 0.85, curve=1.6), 220)
    add(b, rumble)
    add(b, glide(90, 32, 1.0, 0.7, curve=1.8))
    add(b, lowpass(noise(0.4, 0.5, curve=2.5), 1800), at=0.0)
    tail = lowpass(noise(0.6, 0.18, attack=0.1, curve=1.2), 500)
    add(b, tail, at=0.55)
    return drive(b, 1.25)


def medal():
    b = buffer(0.9)
    notes = [659.25, 783.99, 987.77, 1318.51]
    for i, f in enumerate(notes):
        add(b, sine(f, 0.42, 0.2, curve=2.6), at=i * 0.075)
        add(b, sine(f * 1.5, 0.25, 0.05, curve=3.2), at=i * 0.075)
    return echo(b, 0.12, 0.3, 0.35)


def win():
    b = buffer(1.3)
    seq = [(392.0, 0.14), (523.25, 0.14), (659.25, 0.14), (783.99, 0.5)]
    t = 0.0
    for f, d in seq:
        add(b, sine(f, d + 0.25, 0.26, curve=1.8), at=t)
        add(b, sine(f * 2, d + 0.1, 0.07, curve=2.4), at=t)
        t += d
    add(b, highpass(noise(0.7, 0.05, attack=0.15, curve=1.4), 4200), at=0.1)
    return echo(b, 0.15, 0.3, 0.3)


def lose():
    b = buffer(1.1)
    seq = [(329.63, 0.18), (277.18, 0.18), (220.0, 0.55)]
    t = 0.0
    for f, d in seq:
        add(b, sine(f, d + 0.2, 0.24, curve=2.0), at=t)
        add(b, sine(f * 0.5, d + 0.2, 0.12, curve=2.0), at=t)
        t += d
    return b


def music_loop():
    """8.0 s seamless industrial pulse in A minor: 2 bars at 60 BPM."""
    dur = 8.0
    b = buffer(dur)
    beats = 8
    # Sub pulse on every beat, accent on 1 and 5.
    for i in range(beats):
        t = i * (dur / beats)
        accent = 1.0 if i % 4 == 0 else 0.6
        add(b, sine(55, 0.42, 0.30 * accent, curve=2.4), at=t)
        add(b, sine(110, 0.25, 0.10 * accent, curve=3.0), at=t)
    # Off-beat hats.
    for i in range(beats):
        t = i * (dur / beats) + (dur / beats) / 2
        add(b, highpass(noise(0.06, 0.10, curve=5.0), 6000), at=t)
    # Dark pad: A2 / C3 / E3, LFO completes exactly 2 cycles over the loop.
    n = len(b)
    for f, amp in ((110.0, 0.05), (130.81, 0.04), (164.81, 0.035)):
        ph = 0.0
        for i in range(n):
            lfo = 0.55 + 0.45 * math.sin(2 * math.pi * 0.25 * (i / SR) - math.pi / 2)
            v = amp * lfo * math.sin(ph)
            # fade the loop seam with a tiny equal-gain crossfade
            b[i] += v
            ph += 2 * math.pi * f / SR
    # Sparse arpeggio (A3, C4, E4, G4) with long decays, fully damped by 8 s.
    arp = [220.0, 261.63, 329.63, 392.0, 329.63, 261.63, 220.0, 196.0]
    for i, f in enumerate(arp):
        add(b, sine(f, 0.55, 0.055, curve=3.0), at=i * 0.95)
    # Seam smooth: force the last 12 ms toward the first sample value.
    fade = int(0.012 * SR)
    first = b[0]
    for i in range(fade):
        w = i / fade
        b[len(b) - fade + i] = b[len(b) - fade + i] * (1 - w) + first * w
    # Keep headroom so it sits under SFX.
    return [v * 0.62 for v in b]


def main():
    print(f"Writing to {os.path.abspath(OUT)}")
    write("click", click(), 0.55)
    write("cut", cut(), 0.9)
    write("wrong", wrong(), 0.85)
    write("tick", tick(), 0.5)
    write("defuse", defuse(), 0.8)
    write("explosion", explosion(), 0.95)
    write("medal", medal(), 0.7)
    write("win", win(), 0.8)
    write("lose", lose(), 0.75)
    write("music_loop", music_loop(), 0.9)
    print("Done.")


if __name__ == "__main__":
    main()
