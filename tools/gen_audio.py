#!/usr/bin/env python3
"""Synthesises every sound used by PixelWhisper (stdlib only, deterministic).

    python3 tools/gen_audio.py

Writes 16-bit mono WAVs to assets/audio/. All sounds are generated from scratch, so
there is nothing to license. Re-run after tweaking a recipe, then re-import in Godot.
"""
import array
import math
import os
import random
import wave

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")


def write_wav(name, samples, sr=SR, peak=0.89):
    m = max(1e-9, max(abs(s) for s in samples))
    gain = peak / m
    fade = int(sr * 0.006)
    data = array.array("h")
    n = len(samples)
    for i, s in enumerate(samples):
        if i >= n - fade:
            s *= (n - i) / fade
        data.append(int(max(-1.0, min(1.0, s * gain)) * 32767))
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(data.tobytes())
    print(f"  {name:<16} {n / sr:5.2f}s  {os.path.getsize(path) // 1024:4d} KB")


def mix(dst, src, offset, gain=1.0):
    need = offset + len(src) - len(dst)
    if need > 0:
        dst.extend([0.0] * need)
    for i, s in enumerate(src):
        dst[offset + i] += s * gain


def pop(f0, f1, dur=0.17, decay=0.032, body=0.35, click=0.22, seed=1):
    """Soft bubble pop: pitch-dropping sine + a whisper of noise transient."""
    rnd = random.Random(seed)
    out, phase, lp = [], 0.0, 0.0
    for i in range(int(SR * dur)):
        t = i / SR
        f = f1 + (f0 - f1) * math.exp(-t / 0.022)
        phase += 2 * math.pi * f / SR
        env = math.exp(-t / decay) * (1 - math.exp(-t / 0.0006))
        s = (math.sin(phase) + body * math.sin(2 * phase + 0.5)) * env
        s += (rnd.random() * 2 - 1) * math.exp(-t / 0.0025) * click
        lp += 0.55 * (s - lp)  # one-pole low-pass keeps it soft, never harsh
        out.append(lp)
    return out


def bell(freq, dur=1.0, decay=0.35, amp=1.0):
    parts = [(1.0, 1.0), (2.01, 0.38), (3.02, 0.16), (4.17, 0.07)]
    out = []
    for i in range(int(SR * dur)):
        t = i / SR
        env = math.exp(-t / decay) * (1 - math.exp(-t / 0.002))
        s = sum(a * math.sin(2 * math.pi * freq * m * t) * math.exp(-t * (m - 1) * 2.2)
                for m, a in parts)
        out.append(s * env * amp)
    return out


def tick():
    out, phase = [], 0.0
    for i in range(int(SR * 0.05)):
        t = i / SR
        phase += 2 * math.pi * (1500 - 600 * min(1, t / 0.03)) / SR
        out.append(math.sin(phase) * math.exp(-t / 0.009) * (1 - math.exp(-t / 0.0005)))
    return out


def wrong():
    out, phase = [], 0.0
    for i in range(int(SR * 0.13)):
        t = i / SR
        phase += 2 * math.pi * (240 - 70 * min(1, t / 0.1)) / SR
        out.append(math.sin(phase) * math.exp(-t / 0.045) * (1 - math.exp(-t / 0.001)))
    return out


def hint():
    out, phase = [], 0.0
    for i in range(int(SR * 0.45)):
        t = i / SR
        phase += 2 * math.pi * (620 + 900 * (1 - math.exp(-t / 0.12))) / SR
        env = math.sin(math.pi * min(1, t / 0.45)) ** 1.5
        out.append(math.sin(phase) * env * (0.75 + 0.25 * math.sin(2 * math.pi * 14 * t)))
    mix(out, bell(1568, 0.5, 0.18, 0.6), int(SR * 0.16))
    return out


def sparkle_cascade(seed=7):
    rnd = random.Random(seed)
    out = []
    scale = [1046.5, 1174.7, 1318.5, 1568.0, 1760.0, 2093.0, 2349.3]
    for k in range(9):
        mix(out, bell(rnd.choice(scale), 0.45, 0.16, 0.7 - k * 0.04), int(SR * k * 0.045))
    return out


def color_done():
    out = []
    mix(out, bell(783.99, 0.9, 0.28), 0)               # G5
    mix(out, bell(1174.66, 1.0, 0.34), int(SR * 0.09))  # D6
    return out


def win():
    out = []
    notes = [523.25, 659.25, 783.99, 1046.5, 1318.5, 1567.98]
    for i, f in enumerate(notes):
        mix(out, bell(f, 1.8, 0.55, 0.9), int(SR * i * 0.11))
    mix(out, bell(261.63, 2.4, 0.9, 0.6), 0)
    mix(out, sparkle_cascade(3), int(SR * 0.55), 0.55)
    return out


def ambient(seconds=24, sr=22050):
    """Slow pad loop. Every partial is snapped to a multiple of 1/seconds Hz, so it
    completes whole cycles and the loop point is phase-continuous (no click)."""
    chords = [
        [130.81, 196.00, 246.94, 329.63],   # Cmaj7
        [110.00, 164.81, 261.63, 329.63],   # Am7
        [87.31, 174.61, 261.63, 349.23],    # Fmaj
        [98.00, 196.00, 293.66, 329.63],    # G6
    ]
    n = int(sr * seconds)
    out = [0.0] * n
    seg = seconds / len(chords)
    for ci, chord in enumerate(chords):
        centre = (ci + 0.5) * seg
        for note in chord:
            for detune, amp in ((0.0, 1.0), (0.37, 0.6), (-0.41, 0.6)):
                f = round((note + detune) * seconds) / seconds
                w = 2 * math.pi * f / sr
                for i in range(n):
                    t = i / sr
                    d = abs(t - centre)
                    d = min(d, seconds - d)  # circular distance: wraps around the loop
                    if d >= seg:
                        continue
                    env = 0.5 + 0.5 * math.cos(math.pi * d / seg)
                    out[i] += math.sin(w * i) * env * env * amp
    # slow breathing tremolo (integer cycles over the loop as well)
    for i in range(n):
        out[i] *= 0.82 + 0.18 * math.sin(2 * math.pi * 6 * i / n)
    return out, sr


def main():
    os.makedirs(OUT, exist_ok=True)
    print("Generating audio ->", os.path.normpath(OUT))
    write_wav("pop_1.wav", pop(760, 230, seed=11))
    write_wav("pop_2.wav", pop(660, 205, dur=0.19, decay=0.036, body=0.5, seed=22))
    write_wav("pop_3.wav", pop(860, 260, dur=0.15, decay=0.028, body=0.25, click=0.3, seed=33))
    write_wav("tick.wav", tick(), peak=0.7)
    write_wav("wrong.wav", wrong(), peak=0.55)
    write_wav("hint.wav", hint(), peak=0.75)
    write_wav("wand.wav", sparkle_cascade(), peak=0.8)
    write_wav("color_done.wav", color_done(), peak=0.8)
    write_wav("win.wav", win(), peak=0.9)
    amb, sr = ambient()
    write_wav("ambient.wav", amb, sr=sr, peak=0.6)


if __name__ == "__main__":
    main()
