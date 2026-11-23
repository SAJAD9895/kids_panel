#!/usr/bin/env python3
"""Generates the game sound effects in assets/sfx/ (original, synthesised: no licensed audio).

    python3 tool/gen_sfx.py           # writes the .wav files
    python3 tool/gen_sfx.py --check   # exits 1 if a file is missing or different

Soft sine tones with quick fades, mono 22.05 kHz, 16-bit. Kept gentle on purpose: the "try
again" sound is a soft falling pair, never a buzzer.
"""
import io, math, struct, sys, wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parent.parent / "assets" / "sfx"

def note(freq, ms, vol=0.35, sweep_to=None, harm=0.25):
    n = int(RATE * ms / 1000)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / n
        f = freq if sweep_to is None else freq + (sweep_to - freq) * t
        phase += 2 * math.pi * f / RATE
        env = min(1.0, i / (RATE * 0.004)) * (1 - t) ** 2      # 4 ms attack, smooth decay
        out.append(vol * env * (math.sin(phase) + harm * math.sin(2 * phase)))
    return out

def mix(*parts):
    n = max(len(p) for p in parts)
    return [sum(p[i] for p in parts if i < len(p)) for i in range(n)]

def seq(*parts):
    return [x for p in parts for x in p]

C5, E5, G5, C6, E6, E4, C4 = 523.25, 659.25, 783.99, 1046.5, 1318.5, 329.63, 261.63

SOUNDS = {
    "tap": note(880, 45, 0.25),
    "flip": note(500, 90, 0.22, sweep_to=1100, harm=0.1),
    "snap": note(1400, 60, 0.25, harm=0.4),
    "match": seq(note(C6, 80, 0.28), note(E6, 140, 0.28)),
    "correct": seq(note(C5, 90), note(E5, 90), note(G5, 220)),
    "try_again": seq(note(E4, 140, 0.25, harm=0.1), note(C4, 220, 0.22, harm=0.1)),
    "complete": seq(note(C5, 110), note(E5, 110), note(G5, 110),
                    mix(note(C6, 600, 0.22), note(G5, 600, 0.18), note(E5, 600, 0.18))),
}

def render(samples):
    peak = max(1e-9, max(abs(x) for x in samples))
    scale = min(1.0, 0.9 / peak)
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(32767 * x * scale)) for x in samples))
    return buf.getvalue()

def main():
    check = "--check" in sys.argv
    bad = 0
    OUT.mkdir(parents=True, exist_ok=True)
    for name, samples in SOUNDS.items():
        data, path = render(samples), OUT / f"{name}.wav"
        if check:
            if not path.exists() or path.read_bytes() != data:
                print(f"out of date: {path.name}"); bad = 1
        else:
            path.write_bytes(data)
    if check:
        print("sfx up to date" if not bad else "run: python3 tool/gen_sfx.py")
    sys.exit(bad)

if __name__ == "__main__":
    main()
