#!/usr/bin/env python3
"""Makes the development media library: original, generated from code (no third-party art,
music or footage), laid out exactly like Supabase Storage (docs/architecture/11-media-storage.md):

    kids_app/assets/dev_media/public-assets/thumbs/<slug>/1/{256,512}.webp   thumbnails / covers
    kids_app/assets/dev_media/video/<slug>/mp4/540p.mp4                      H.264 + AAC, faststart
    kids_app/assets/dev_media/video/<slug>/subs/en.vtt                       captions
    kids_app/assets/dev_media/content/songs/<slug>/en.m4a                    songs (AAC)
    kids_app/assets/dev_media/content/<slug>/1/pages/<n>.webp                story pages

and writes the registry the seed and demo mode read:

    kids_app/assets/dev_media/manifest.json      every file: bucket, path, kind, mime, bytes, sha256, size, duration
    kids_app/lib/demo/demo_media.g.dart          the same, plus story text and captions, as Dart

    python3 content/dev-media/make_dev_media.py            # everything (≈ 1 min)
    python3 content/dev-media/make_dev_media.py --only songs

Characters are the app's own (Pip, Bolt, Nova), redrawn as simple shapes. Songs are original
tunes written here, instrumental (no lyrics are sung). Videos have music and on-screen words;
their captions carry those words plus sound descriptions.

Needs: Python 3 with Pillow and numpy, ffmpeg with libx264, aac and libwebp.
"""
import hashlib
import json
import math
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "kids_app"
OUT = APP / "assets" / "dev_media"
FONT = str(APP / "assets" / "fonts" / "Fredoka.ttf")
RATE = 44100
W, H, FPS = 640, 360, 24

# Palette: the design tokens (docs/design/tokens/tokens.json), so media matches the app.
C = {
    "bg": (255, 248, 238), "sky": (216, 238, 255), "grass": (123, 216, 143), "ink": (31, 42, 68),
    "pip": (123, 216, 143), "pipdark": (31, 107, 51), "bolt": (106, 166, 255), "boltdark": (30, 79, 184),
    "nova": (255, 201, 77), "star": (255, 176, 32), "play": (255, 138, 101), "red": (229, 72, 77),
    "blue": (62, 99, 221), "yellow": (255, 197, 61), "green": (48, 164, 108), "purple": (142, 78, 198),
    "orange": (247, 107, 21), "white": (255, 255, 255), "cloud": (245, 247, 252), "night": (31, 42, 68),
    "soil": (176, 120, 80), "snail": (232, 160, 100), "shell": (160, 100, 200),
}


def font(size):
    f = ImageFont.truetype(FONT, size)
    try:
        f.set_variation_by_axes([600])  # Fredoka is a variable font: semibold, like the app
    except Exception:
        pass
    return f


# ----------------------------------------------------------------------------- drawing
def circle(d, cx, cy, r, fill, outline=None, width=0):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill, outline=outline, width=width)


def face(d, cx, cy, r, mood="happy"):
    e = r * 0.28
    for sx in (-1, 1):
        if mood == "sleepy":
            d.arc([cx + sx * e - r * 0.12, cy - r * 0.15, cx + sx * e + r * 0.12, cy + r * 0.05], 0, 180, fill=C["ink"], width=max(2, int(r * 0.06)))
        else:
            circle(d, cx + sx * e, cy - r * 0.08, r * 0.09, C["ink"])
            circle(d, cx + sx * e + r * 0.03, cy - r * 0.11, r * 0.03, C["white"])
    d.arc([cx - r * 0.25, cy - r * 0.05, cx + r * 0.25, cy + r * 0.3], 20, 160, fill=C["ink"], width=max(2, int(r * 0.07)))


def pip(d, cx, cy, r, mood="happy", bob=0.0):
    cy += bob
    d.ellipse([cx - r * 0.9, cy - r * 1.45, cx - r * 0.05, cy - r * 0.95], fill=C["pipdark"])
    d.ellipse([cx + r * 0.05, cy - r * 1.45, cx + r * 0.9, cy - r * 0.95], fill=C["pip"])
    d.rectangle([cx - r * 0.06, cy - r * 1.25, cx + r * 0.06, cy - r * 0.85], fill=C["pipdark"])
    circle(d, cx, cy, r, C["pip"])
    d.ellipse([cx - r * 0.6, cy - r * 0.35, cx + r * 0.6, cy + r * 0.75], fill=(225, 248, 230))
    face(d, cx, cy + r * 0.15, r, mood)


def bolt(d, cx, cy, r, bob=0.0):
    cy += bob
    d.line([cx, cy - r * 1.3, cx, cy - r * 0.9], fill=C["ink"], width=max(2, int(r * 0.1)))
    circle(d, cx, cy - r * 1.35, r * 0.16, C["play"])
    d.rounded_rectangle([cx - r, cy - r * 0.9, cx + r, cy + r * 0.9], radius=r * 0.35, fill=C["bolt"])
    d.rounded_rectangle([cx - r * 1.15, cy - r * 0.3, cx - r * 0.95, cy + r * 0.3], radius=r * 0.1, fill=C["boltdark"])
    d.rounded_rectangle([cx + r * 0.95, cy - r * 0.3, cx + r * 1.15, cy + r * 0.3], radius=r * 0.1, fill=C["boltdark"])
    d.rounded_rectangle([cx - r * 0.7, cy - r * 0.6, cx + r * 0.7, cy + r * 0.5], radius=r * 0.25, fill=(226, 238, 255))
    face(d, cx, cy, r * 0.9)


def star_points(cx, cy, r, inner=0.45, rot=0.0):
    return [(cx + (r if i % 2 == 0 else r * inner) * math.cos(-math.pi / 2 + rot + i * math.pi / 5),
             cy + (r if i % 2 == 0 else r * inner) * math.sin(-math.pi / 2 + rot + i * math.pi / 5)) for i in range(10)]


def nova(d, cx, cy, r, mood="happy", bob=0.0):
    cy += bob
    d.polygon(star_points(cx, cy, r, 0.5), fill=C["nova"])
    face(d, cx, cy + r * 0.12, r * 0.75, mood)


def snail(d, x, y, r):
    d.rounded_rectangle([x - r * 1.4, y + r * 0.4, x + r * 1.1, y + r * 0.95], radius=r * 0.3, fill=C["snail"])
    circle(d, x + r * 1.05, y + r * 0.35, r * 0.35, C["snail"])
    for k in (-0.15, 0.15):
        d.line([x + r * 1.05 + k * r, y + r * 0.1, x + r * 1.2 + k * r * 2, y - r * 0.45], fill=C["ink"], width=3)
        circle(d, x + r * 1.2 + k * r * 2, y - r * 0.45, r * 0.08, C["ink"])
    circle(d, x - r * 0.25, y, r * 0.8, C["shell"])
    for i in range(3):
        d.arc([x - r * 0.25 - r * (0.6 - i * 0.18), y - r * (0.6 - i * 0.18), x - r * 0.25 + r * (0.6 - i * 0.18), y + r * (0.6 - i * 0.18)], 0, 300, fill=(120, 70, 160), width=3)


def flower(d, x, y, r, col):
    d.line([x, y, x, y + r * 3], fill=C["pipdark"], width=4)
    for i in range(5):
        a = i * 2 * math.pi / 5
        circle(d, x + r * math.cos(a), y + r * math.sin(a), r * 0.6, col)
    circle(d, x, y, r * 0.5, C["yellow"])


def cloud(d, x, y, r, col=None, mood=None):
    col = col or C["cloud"]
    for dx, dy, rr in ((-1.0, 0.2, 0.7), (-0.3, -0.25, 0.9), (0.5, 0.0, 0.8), (1.1, 0.25, 0.6)):
        circle(d, x + dx * r, y + dy * r, rr * r, col)
    d.rounded_rectangle([x - r * 1.5, y + r * 0.1, x + r * 1.6, y + r * 0.85], radius=r * 0.35, fill=col)
    if mood:
        face(d, x + r * 0.05, y + r * 0.25, r * 0.8, mood)


def sun(d, x, y, r, t=0.0):
    for i in range(10):
        a = i * math.pi / 5 + t
        d.line([x + r * 1.2 * math.cos(a), y + r * 1.2 * math.sin(a), x + r * 1.6 * math.cos(a), y + r * 1.6 * math.sin(a)], fill=C["star"], width=5)
    circle(d, x, y, r, C["yellow"])


def drop(d, x, y, r, col=None):
    col = col or C["blue"]
    d.polygon([(x, y - r * 1.6), (x - r * 0.85, y), (x + r * 0.85, y)], fill=col)
    circle(d, x, y, r * 0.86, col)


def sheep(d, x, y, r):
    for dx, dy in ((-0.5, 0), (0, -0.3), (0.5, 0), (0, 0.25), (-0.3, -0.15), (0.3, -0.15)):
        circle(d, x + dx * r, y + dy * r, r * 0.55, C["white"], outline=(220, 220, 225), width=2)
    circle(d, x + r * 0.95, y - r * 0.05, r * 0.35, C["ink"])
    for dx in (-0.4, 0.35):
        d.rectangle([x + dx * r - 3, y + r * 0.6, x + dx * r + 3, y + r * 1.05], fill=C["ink"])


def shape(d, kind, x, y, r, col):
    if kind == "circle":
        circle(d, x, y, r, col)
    elif kind == "square":
        d.rounded_rectangle([x - r, y - r, x + r, y + r], radius=r * 0.15, fill=col)
    elif kind == "triangle":
        d.polygon([(x, y - r), (x + r * 1.1, y + r * 0.85), (x - r * 1.1, y + r * 0.85)], fill=col)
    elif kind == "star":
        d.polygon(star_points(x, y, r * 1.1), fill=col)
    elif kind == "heart":
        d.pieslice([x - r, y - r * 0.8, x, y + r * 0.2], 180, 360, fill=col)
        d.pieslice([x, y - r * 0.8, x + r, y + r * 0.2], 180, 360, fill=col)
        d.polygon([(x - r, y - r * 0.3), (x + r, y - r * 0.3), (x, y + r)], fill=col)


def label(d, text, x, y, size, col=None, anchor="mm"):
    col = col or C["ink"]
    f = font(size)
    # a soft white outline keeps words readable on any background
    for ox, oy in ((-2, 0), (2, 0), (0, -2), (0, 2)):
        d.text((x + ox, y + oy), text, font=f, fill=C["white"], anchor=anchor)
    d.text((x, y), text, font=f, fill=col, anchor=anchor)


def ease(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def garden_bg(d, w, h):
    d.rectangle([0, 0, w, h], fill=C["sky"])
    d.ellipse([-w * 0.2, h * 0.68, w * 1.2, h * 1.5], fill=C["grass"])


# ----------------------------------------------------------------------------- audio
NOTE = {n: i for i, n in enumerate(["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"])}


def freq(name):
    n, o = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((NOTE[n] + 12 * (o + 1) - 69) / 12)


def tone(f, dur, vol=0.3, kind="soft", attack=0.01, release=0.08):
    n = int(RATE * dur)
    t = np.arange(n) / RATE
    if kind == "soft":
        w = np.sin(2 * np.pi * f * t) + 0.3 * np.sin(4 * np.pi * f * t) + 0.1 * np.sin(6 * np.pi * f * t)
    elif kind == "bell":
        w = np.sin(2 * np.pi * f * t) + 0.5 * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t * 6)
    elif kind == "pluck":
        w = np.sin(2 * np.pi * f * t) * np.exp(-t * 5) + 0.4 * np.sin(4 * np.pi * f * t) * np.exp(-t * 8)
    else:  # bass
        w = np.sin(2 * np.pi * f * t) + 0.2 * np.sin(4 * np.pi * f * t)
    env = np.minimum(1, t / attack) * np.minimum(1, (dur - t) / release).clip(0, 1)
    return vol * w * env


def noise(dur, vol=0.15, decay=30):
    n = int(RATE * dur)
    t = np.arange(n) / RATE
    rng = np.random.default_rng(int(dur * 1000))
    return vol * rng.uniform(-1, 1, n) * np.exp(-t * decay)


def mix_into(buf, sig, at):
    i = int(at * RATE)
    if i >= len(buf):
        return
    j = min(len(buf), i + len(sig))
    buf[i:j] += sig[: j - i]


def song(spec):
    """spec: bpm, bars of (melody notes [(note|None, beats)], chord root note), kinds."""
    beat = 60.0 / spec["bpm"]
    total = sum(sum(b for _, b in bar[0]) for bar in spec["bars"]) * beat * spec.get("repeat", 1) + 1.5
    buf = np.zeros(int(total * RATE))
    t = 0.0
    for _ in range(spec.get("repeat", 1)):
        for melody, root in spec["bars"]:
            bar_len = sum(b for _, b in melody) * beat
            # chord pad: root + third + fifth (major unless the root ends with 'm')
            minor = root.endswith("m")
            r = root[:-1] if minor else root
            for k, semis in enumerate((0, 3 if minor else 4, 7)):
                f = freq(r + "3") * 2 ** (semis / 12)
                mix_into(buf, tone(f, bar_len, 0.05, "soft", 0.08, 0.3), t)
            mix_into(buf, tone(freq(r + "2"), bar_len * 0.5, 0.18, "bass"), t)
            mix_into(buf, tone(freq(r + "2") * 1.5, bar_len * 0.5, 0.12, "bass"), t + bar_len * 0.5)
            # percussion on each beat
            nb = int(round(bar_len / beat))
            for b in range(nb):
                mix_into(buf, noise(0.08, spec.get("perc", 0.08), 40), t + b * beat)
            mt = t
            for note, beats in melody:
                if note:
                    mix_into(buf, tone(freq(note), beats * beat * 0.95, 0.22, spec.get("lead", "pluck")), mt)
                mt += beats * beat
            t += bar_len
    # gentle ending chime
    mix_into(buf, tone(freq(spec["end"]), 1.4, 0.2, "bell", 0.01, 0.6), t)
    return buf


def write_wav(path, buf):
    peak = max(1e-9, float(np.max(np.abs(buf))))
    data = (buf / peak * 0.85 * 32767).astype("<i2")
    import wave
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())


def run(cmd):
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


# ----------------------------------------------------------------------------- registry
REGISTRY = []  # files written this run


def register(bucket, rel, kind, mime, **extra):
    p = OUT / bucket / rel
    data = p.read_bytes()
    entry = {"bucket": bucket, "path": rel, "kind": kind, "mime": mime, "bytes": len(data),
             "sha256": hashlib.sha256(data).hexdigest(), **extra}
    REGISTRY.append(entry)
    return entry


def save_thumbs(img, slug, square=False):
    base = OUT / "public-assets" / "thumbs" / slug / "1"
    base.mkdir(parents=True, exist_ok=True)
    for size in (256, 512):
        h = size if square else round(size * img.height / img.width)
        im = img.resize((size, h), Image.LANCZOS)
        im.save(base / f"{size}.webp", "WEBP", quality=78, method=6)
        register("public-assets", f"thumbs/{slug}/1/{size}.webp", "image", "image/webp", width=size, height=h)


def cover_canvas(w, h, bg):
    img = Image.new("RGB", (w, h), bg)
    return img, ImageDraw.Draw(img)



# ----------------------------------------------------------------------------- badges (Phase 12)
# Original medal artwork: a scalloped rosette in the badge's colour, a white disc, ribbon tails
# and an emblem drawn here. Transparent background; 256 and 512 px. The app shows locked badges
# in grey (a colour filter), so there is one file per badge.
BADGES = {
    # slug: (colour, ribbon, emblem)
    "first-game":   ("play",   "orange", "dice"),
    "first-island": ("pip",    "green",  "island"),
    "first-course": ("star",   "orange", "trophy"),
    "goal-1":       ("red",    "blue",   "target"),
    "goal-10":      ("blue",   "red",    "target10"),
    "week-1":       ("bolt",   "blue",   "calendar"),
    "week-4":       ("green",  "pip",    "sprout"),
    "streak-3":     ("orange", "yellow", "stones"),
    "streak-7":     ("purple", "bolt",   "rainbow"),
    "streak-30":    ("pipdark","green",  "tree"),
    "numbers":      ("blue",   "yellow", "t:123"),
    "letters":      ("red",    "bolt",   "t:Abc"),
    "shapes":       ("purple", "yellow", "shapes"),
    "thinking":     ("yellow", "purple", "bulb"),
    "stars-25":     ("star",   "blue",   "star25"),
    "stars-100":    ("orange", "purple", "star100"),
}


def badge_emblem(d, kind, cx, cy, r):
    ink = C["ink"]
    if kind == "dice":
        d.rounded_rectangle([cx - r * .8, cy - r * .8, cx + r * .8, cy + r * .8], radius=r * .25, fill=C["white"], outline=ink, width=int(r * .09))
        for (x, y) in ((-.4, -.4), (.4, -.4), (0, 0), (-.4, .4), (.4, .4)):
            circle(d, cx + r * x, cy + r * y, r * .13, C["play"])
    elif kind == "island":
        d.ellipse([cx - r, cy + r * .25, cx + r, cy + r * .85], fill=C["bolt"])
        d.ellipse([cx - r * .7, cy + r * .05, cx + r * .7, cy + r * .6], fill=C["yellow"])
        d.line([(cx, cy + r * .3), (cx + r * .1, cy - r * .55)], fill=C["soil"], width=int(r * .14))
        for a in (-2.6, -1.9, -1.2, -0.5):
            d.chord([cx + r * .1 - r * .55, cy - r * .55 - r * .3, cx + r * .1 + r * .55, cy - r * .55 + r * .3],
                    math.degrees(a) - 40, math.degrees(a) + 40, fill=C["green"])
        circle(d, cx + r * .1, cy - r * .55, r * .2, C["pip"])
    elif kind == "trophy":
        d.pieslice([cx - r * .7, cy - r * .95, cx + r * .7, cy + r * .35], 0, 180, fill=C["star"])
        d.rectangle([cx - r * .7, cy - r * .7, cx + r * .7, cy - r * .3], fill=C["star"])
        d.arc([cx - r * 1.0, cy - r * .7, cx - r * .45, cy - r * .05], 90, 270, fill=C["star"], width=int(r * .12))
        d.arc([cx + r * .45, cy - r * .7, cx + r * 1.0, cy - r * .05], 270, 90, fill=C["star"], width=int(r * .12))
        d.rectangle([cx - r * .12, cy + r * .3, cx + r * .12, cy + r * .6], fill=C["star"])
        d.rounded_rectangle([cx - r * .5, cy + r * .58, cx + r * .5, cy + r * .82], radius=r * .08, fill=C["orange"])
        d.polygon(star_points(cx, cy - r * .35, r * .3), fill=C["white"])
    elif kind in ("target", "target10"):
        for i, col in enumerate((C["red"], C["white"], C["red"], C["white"])):
            circle(d, cx, cy, r * (1 - i * .24), col)
        if kind == "target":
            d.polygon(star_points(cx, cy, r * .3), fill=C["star"])
        else:
            label(d, "10", cx, cy, int(r * .55), C["ink"])
    elif kind == "calendar":
        d.rounded_rectangle([cx - r * .85, cy - r * .7, cx + r * .85, cy + r * .85], radius=r * .16, fill=C["white"], outline=ink, width=int(r * .07))
        d.rounded_rectangle([cx - r * .85, cy - r * .7, cx + r * .85, cy - r * .28], radius=r * .16, fill=C["bolt"])
        for x in (-.45, .45):
            d.rounded_rectangle([cx + r * x - r * .07, cy - r * .9, cx + r * x + r * .07, cy - r * .5], radius=r * .05, fill=ink)
        d.line([(cx - r * .42, cy + r * .28), (cx - r * .1, cy + r * .58), (cx + r * .48, cy - r * .05)], fill=C["green"], width=int(r * .16), joint="curve")
    elif kind == "sprout":
        d.rounded_rectangle([cx - r * .55, cy + r * .35, cx + r * .55, cy + r * .9], radius=r * .1, fill=C["soil"])
        d.line([(cx, cy + r * .4), (cx, cy - r * .75)], fill=C["pipdark"], width=int(r * .12))
        for i, (dx, y) in enumerate(((-1, .15), (1, -.1), (-1, -.35), (1, -.6))):
            x0 = cx + dx * r * .05
            box = [x0, cy + r * y - r * .18, x0 + dx * r * .6, cy + r * y + r * .18]
            d.ellipse([min(box[0], box[2]), box[1], max(box[0], box[2]), box[3]], fill=C["pip"] if i % 2 else C["green"])
    elif kind == "stones":
        for i, (x, y) in enumerate(((-.62, .45), (0, 0), (.62, -.45))):
            d.ellipse([cx + r * x - r * .36, cy + r * y - r * .22, cx + r * x + r * .36, cy + r * y + r * .22], fill=(150, 160, 175))
            d.polygon(star_points(cx + r * x, cy + r * y - r * .05, r * .14), fill=C["star"])
    elif kind == "rainbow":
        for i, col in enumerate((C["red"], C["orange"], C["yellow"], C["green"], C["blue"], C["purple"])):
            rr = r * (1 - i * .12)
            d.pieslice([cx - rr, cy - rr + r * .3, cx + rr, cy + rr + r * .3], 180, 360, fill=col)
        d.pieslice([cx - r * .28, cy - r * .28 + r * .3, cx + r * .28, cy + r * .28 + r * .3], 180, 360, fill=C["white"])
        cloud(d, cx - r * .8, cy + r * .35, r * .3, C["cloud"])
        cloud(d, cx + r * .8, cy + r * .35, r * .3, C["cloud"])
    elif kind == "tree":
        d.rectangle([cx - r * .14, cy + r * .1, cx + r * .14, cy + r * .9], fill=C["soil"])
        for (x, y, rr) in ((0, -.35, .55), (-.42, -.05, .4), (.42, -.05, .4), (0, -.75, .35)):
            circle(d, cx + r * x, cy + r * y, r * rr, C["green"])
        for (x, y) in ((-.3, -.3), (.25, -.5), (.35, .0)):
            circle(d, cx + r * x, cy + r * y, r * .08, C["red"])
    elif kind.startswith("t:"):
        label(d, kind[2:], cx, cy, int(r * .82), C["ink"])
    elif kind == "shapes":
        circle(d, cx - r * .45, cy + r * .35, r * .38, C["red"])
        d.rectangle([cx + r * .08, cy + r * .0, cx + r * .82, cy + r * .72], fill=C["blue"])
        d.polygon([(cx, cy - r * .9), (cx - r * .5, cy - r * .05), (cx + r * .5, cy - r * .05)], fill=C["yellow"])
    elif kind == "bulb":
        circle(d, cx, cy - r * .2, r * .62, C["yellow"])
        d.rounded_rectangle([cx - r * .3, cy + r * .3, cx + r * .3, cy + r * .78], radius=r * .1, fill=(150, 160, 175))
        for a in range(-60, 61, 30):
            t = math.radians(a - 90)
            d.line([(cx + math.cos(t) * r * .78, cy - r * .2 + math.sin(t) * r * .78),
                    (cx + math.cos(t) * r * .98, cy - r * .2 + math.sin(t) * r * .98)], fill=C["orange"], width=int(r * .09))
    elif kind in ("star25", "star100"):
        d.polygon(star_points(cx, cy, r * 1.0, inner=.5), fill=C["star"])
        label(d, "25" if kind == "star25" else "100", cx, cy + r * .08, int(r * (.42 if kind == "star25" else .34)), C["ink"])


def make_badges():
    base_px = 1024
    for slug, (colour, ribbon, emblem) in BADGES.items():
        img = Image.new("RGBA", (base_px, base_px), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        cx, cy, R = base_px / 2, base_px * .44, base_px * .36
        # ribbon tails
        for sx in (-1, 1):
            x0 = cx + sx * R * .25
            d.polygon([(x0 - R * .2, cy + R * .4), (x0 + R * .2, cy + R * .4),
                       (x0 + sx * R * .35 + R * .2, cy + R * 1.35), (x0 + sx * R * .35, cy + R * 1.18),
                       (x0 + sx * R * .35 - R * .2, cy + R * 1.35)], fill=C[ribbon])
        # scalloped rosette
        for i in range(18):
            a = i * 2 * math.pi / 18
            circle(d, cx + math.cos(a) * R * .9, cy + math.sin(a) * R * .9, R * .2, C[colour])
        circle(d, cx, cy, R * .92, C[colour])
        circle(d, cx, cy, R * .74, C["white"])
        badge_emblem(d, emblem, cx, cy, R * .52)
        out = OUT / "public-assets" / "badges" / slug / "1"
        out.mkdir(parents=True, exist_ok=True)
        for size in (256, 512):
            img.resize((size, size), Image.LANCZOS).save(out / f"{size}.webp", "WEBP", quality=82, method=6)
            register("public-assets", f"badges/{slug}/1/{size}.webp", "image", "image/webp", width=size, height=size)

# ----------------------------------------------------------------------------- videos
def vtt(cues):
    def ts(s):
        return f"{int(s // 3600):02d}:{int(s % 3600 // 60):02d}:{s % 60:06.3f}"
    return "WEBVTT\n\n" + "\n\n".join(f"{ts(a)} --> {ts(b)}\n{text}" for a, b, text in cues) + "\n"


def make_video(slug, duration, draw_frame, cues, music, chimes):
    vdir = OUT / "video" / slug
    (vdir / "mp4").mkdir(parents=True, exist_ok=True)
    (vdir / "subs").mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        audio = np.zeros(int((duration + 0.5) * RATE))
        bg = song(music)
        for start in np.arange(0, duration, len(bg) / RATE):
            mix_into(audio, bg * 0.55, start)
        for at, note in chimes:
            mix_into(audio, tone(freq(note), 0.9, 0.35, "bell", 0.005, 0.4), at)
        audio = audio[: int(duration * RATE)]
        fade = int(RATE * 1.0)
        audio[-fade:] *= np.linspace(1, 0, fade)
        wav = Path(tmp) / "a.wav"
        write_wav(wav, audio)
        out = vdir / "mp4" / "540p.mp4"
        p = subprocess.Popen(["ffmpeg", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS),
                              "-i", "-", "-i", str(wav), "-c:v", "libx264", "-preset", "slow", "-crf", "30",
                              "-profile:v", "main", "-pix_fmt", "yuv420p", "-movflags", "+faststart",
                              "-c:a", "aac", "-b:a", "64k", "-shortest", str(out)],
                             stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        thumb = None
        for i in range(int(duration * FPS)):
            t = i / FPS
            img = Image.new("RGB", (W, H), C["bg"])
            draw_frame(ImageDraw.Draw(img), t)
            if thumb is None and t >= duration * 0.35:
                thumb = img.copy()
            p.stdin.write(img.tobytes())
        p.stdin.close()
        p.wait()
    (vdir / "subs" / "en.vtt").write_text(vtt(cues))
    register("video", f"{slug}/mp4/540p.mp4", "video_mp4", "video/mp4", width=W, height=H, durationMs=int(duration * 1000))
    register("video", f"{slug}/subs/en.vtt", "subtitle", "text/vtt", locale="en")
    save_thumbs(thumb.resize((512, 288), Image.LANCZOS), slug)


def video_snail():
    def frame(d, t):
        garden_bg(d, W, H)
        sun(d, 560, 70, 32, t * 0.4)
        for i, x in enumerate((70, 170, 470, 590)):
            flower(d, x, 230 + (i % 2) * 15, 13, (C["red"], C["purple"], C["orange"], C["blue"])[i])
        sx = -60 + ease((t - 4) / 24) * 470
        snail(d, sx, 270, 30)
        bob = math.sin(t * 3) * 4
        if t < 30:
            pip(d, 520 - ease((t - 2) / 6) * 60, 240, 46, bob=bob)
        else:
            pip(d, 460 + ease((t - 30) / 2) * 0, 240, 46, "happy", bob)
        words = [(1, 5, "Hello! I'm Pip."), (6, 11, "Who is that?"), (12, 17, "A snail!"), (18, 23, "Snails go slowly..."),
                 (24, 29, "...and carry their homes."), (30, 34, "Bye-bye, snail!")]
        for a, b, w in words:
            if a <= t < b:
                label(d, w, W / 2, 46, 34)
    cues = [(0, 1, "[cheerful music]"), (1, 5, "Hello! I'm Pip."), (6, 11, "Who is that?"), (12, 17, "A snail!"),
            (18, 23, "Snails go slowly..."), (24, 29, "...and carry their homes."), (30, 34, "Bye-bye, snail!"),
            (34, 36, "[music ends]")]
    music = {"bpm": 104, "end": "C5", "bars": [([("E4", 1), ("G4", 1), ("C5", 2)], "C"), ([("A4", 1), ("G4", 1), ("E4", 2)], "Am"),
                                                ([("F4", 1), ("A4", 1), ("G4", 2)], "F"), ([("D4", 1), ("E4", 1), ("C4", 2)], "G")]}
    make_video("pip-meets-a-snail", 36, frame, cues, music, [(12, "E5"), (30, "G5")])


def video_farm():
    def frame(d, t):
        garden_bg(d, W, H)
        d.rectangle([0, 250, W, 256], fill=C["soil"])
        n = min(5, max(0, int((t - 4) / 5) + 1)) if t >= 4 else 0
        for i in range(n):
            sheep(d, 90 + i * 115, 215, 34)
        if 4 <= t < 30 and n:
            label(d, str(n), W / 2, 60, 64, C["boltdark"])
            label(d, ["one sheep", "two sheep", "three sheep", "four sheep", "five sheep"][n - 1], W / 2, 112, 28)
        if t < 4:
            bolt(d, W / 2, 140, 46, math.sin(t * 3) * 4)
            label(d, "Let's count the sheep!", W / 2, 46, 32)
        if t >= 30:
            label(d, "Five sheep on the farm!", W / 2, 60, 34)
    cues = [(0, 4, "Let's count the sheep!")] + [(4 + i * 5, 9 + i * 5, f"{i + 1} - {w} sheep") for i, w in
                                                  enumerate(["one", "two", "three", "four", "five"])] + [(30, 34, "Five sheep on the farm!"), (34, 36, "[music ends]")]
    music = {"bpm": 112, "end": "G5", "bars": [([("G4", 1), ("G4", 1), ("A4", 1), ("B4", 1)], "G"), ([("C5", 2), ("B4", 2)], "C"),
                                                ([("A4", 1), ("B4", 1), ("A4", 1), ("G4", 1)], "D"), ([("G4", 4)], "G")]}
    make_video("numbers-on-the-farm", 36, frame, cues, music, [(4 + i * 5, n) for i, n in enumerate(["C5", "D5", "E5", "F5", "G5"])])


def video_rain():
    def frame(d, t):
        d.rectangle([0, 0, W, H], fill=C["sky"])
        d.rectangle([0, 290, W, H], fill=(106, 166, 255))
        sun(d, 90, 80, 34, t * 0.4)
        # stage 1: water warms and rises; 2: cloud grows; 3: rain falls
        if t < 12:
            for i in range(6):
                y = 290 - ((t * 25 + i * 40) % 180)
                circle(d, 220 + i * 40, y, 5, (255, 255, 255))
            label(d, "The sun warms the water.", W / 2, 40, 30)
        cr = 20 + ease((t - 8) / 10) * 40
        cloud(d, 420, 100, cr, (235, 240, 250) if t < 20 else (200, 210, 230), "happy" if t < 24 else "sleepy")
        nova(d, 560, 230, 30, bob=math.sin(t * 2) * 4)
        if 12 <= t < 20:
            label(d, "Tiny drops make a cloud.", W / 2, 40, 30)
        if t >= 20:
            for i in range(14):
                x = 360 + (i * 37) % 130
                y = 140 + ((t - 20) * 120 + i * 53) % 150
                drop(d, x, y, 6)
            label(d, "When the cloud is full... it rains!" if t < 30 else "And it starts again!", W / 2, 40, 30)
    cues = [(0, 12, "The sun warms the water."), (12, 20, "Tiny drops make a cloud."), (20, 30, "When the cloud is full... it rains!"),
            (30, 34, "And it starts again!"), (34, 36, "[music ends]")]
    music = {"bpm": 92, "end": "D5", "bars": [([("D4", 1), ("F4", 1), ("A4", 2)], "Dm"), ([("G4", 2), ("F4", 2)], "Gm"),
                                               ([("A4", 1), ("C5", 1), ("A4", 2)], "F"), ([("E4", 2), ("D4", 2)], "Am")]}
    make_video("why-does-it-rain", 36, frame, cues, music, [(20, "A5"), (30, "D5")])


def video_shapes():
    order = [("circle", "red", "A circle is round."), ("square", "blue", "A square has 4 sides."),
             ("triangle", "green", "A triangle has 3 sides."), ("star", "yellow", "A star has 5 points."),
             ("heart", "purple", "A heart, for love!")]

    def frame(d, t):
        d.rectangle([0, 0, W, H], fill=C["bg"])
        k = min(len(order) - 1, int(t // 6))
        for i in range(k + 1):
            kind, col, _ = order[i]
            grow = ease((t - i * 6) / 1.0)
            x = 80 + i * 120
            shape(d, kind, x, 230, 40 * grow, C[col])
            if grow > 0.9:
                label(d, kind, x, 300, 22)
        label(d, order[k][2] if t < 30 else "Shapes are all around!", W / 2, 70, 34)
        pip(d, W - 60, 100, 26, bob=math.sin(t * 3) * 3)
    cues = [(i * 6, i * 6 + 6, o[2]) for i, o in enumerate(order)] + [(30, 32, "Shapes are all around!")]
    music = {"bpm": 120, "end": "C5", "bars": [([("C5", 1), ("E5", 1), ("G5", 1), ("E5", 1)], "C"), ([("F5", 2), ("D5", 2)], "F"),
                                                ([("E5", 1), ("C5", 1), ("D5", 1), ("B4", 1)], "G"), ([("C5", 4)], "C")]}
    make_video("shapes-all-around", 32, frame, cues, music, [(i * 6, n) for i, n in enumerate(["C5", "E5", "G5", "A5", "C6"])])


def video_rainbow():
    bands = [("red", "red"), ("orange", "orange"), ("yellow", "yellow"), ("green", "green"), ("blue", "blue"), ("purple", "purple")]

    def frame(d, t):
        d.rectangle([0, 0, W, H], fill=C["sky"])
        k = min(len(bands), int(t // 4.5) + 1)
        for i in range(k):
            r = 250 - i * 26
            d.pieslice([W / 2 - r, 330 - r, W / 2 + r, 330 + r], 180, 360, fill=C[bands[i][1]])
        d.pieslice([W / 2 - 92, 330 - 92, W / 2 + 92, 330 + 92], 180, 360, fill=C["sky"])
        cloud(d, 95, 320, 34)
        cloud(d, W - 95, 320, 34)
        nova(d, W / 2, 290, 28, bob=math.sin(t * 2.5) * 3)
        word = bands[k - 1][0] if t < 27 else "a rainbow!"
        label(d, word.capitalize() if t < 27 else "Six colours make a rainbow!", W / 2, 40, 34, C[bands[k - 1][1]] if t < 27 else C["ink"])
    cues = [(i * 4.5, i * 4.5 + 4.5, b[0].capitalize()) for i, b in enumerate(bands)] + [(27, 32, "Six colours make a rainbow!")]
    music = {"bpm": 96, "end": "F5", "bars": [([("F4", 1), ("A4", 1), ("C5", 2)], "F"), ([("D5", 2), ("C5", 2)], "Bb"),
                                               ([("A4", 1), ("G4", 1), ("F4", 2)], "F"), ([("G4", 2), ("C5", 2)], "C")]}
    make_video("rainbow-colours", 32, frame, cues, music, [(i * 4.5, n) for i, n in enumerate(["F5", "G5", "A5", "C6", "D6", "F6"])])


# ----------------------------------------------------------------------------- songs
SONGS = {
    "counting-train": ("C", {"bpm": 132, "repeat": 3, "perc": 0.12, "end": "C5", "bars": [
        ([("C4", 1), ("D4", 1), ("E4", 1), ("F4", 1)], "C"), ([("G4", 2), ("G4", 2)], "C"),
        ([("A4", 1), ("G4", 1), ("F4", 1), ("E4", 1)], "F"), ([("D4", 2), ("G4", 2)], "G"),
        ([("E4", 1), ("G4", 1), ("C5", 2)], "C"), ([("B4", 1), ("A4", 1), ("G4", 2)], "G"),
        ([("F4", 1), ("A4", 1), ("G4", 1), ("B4", 1)], "G"), ([("C5", 4)], "C")]}),
    "ten-little-seeds": ("G", {"bpm": 108, "repeat": 3, "end": "G5", "lead": "bell", "bars": [
        ([("G4", 1), ("B4", 1), ("D5", 1), ("B4", 1)], "G"), ([("C5", 1), ("E5", 1), ("D5", 2)], "C"),
        ([("B4", 1), ("A4", 1), ("G4", 1), ("A4", 1)], "D"), ([("B4", 2), ("G4", 2)], "G"),
        ([("E5", 1), ("D5", 1), ("C5", 1), ("B4", 1)], "Em"), ([("A4", 2), ("D5", 2)], "D"),
        ([("G4", 1), ("A4", 1), ("B4", 1), ("C5", 1)], "C"), ([("G4", 4)], "G")]}),
    "feelings-song": ("A", {"bpm": 96, "repeat": 3, "end": "A4", "bars": [
        ([("A4", 1), ("C5", 1), ("E5", 2)], "Am"), ([("D5", 1), ("C5", 1), ("B4", 2)], "Dm"),
        ([("C5", 1), ("D5", 1), ("E5", 1), ("G5", 1)], "C"), ([("E5", 4)], "E"),
        ([("F5", 1), ("E5", 1), ("D5", 2)], "F"), ([("C5", 1), ("B4", 1), ("A4", 2)], "Am"),
        ([("B4", 1), ("C5", 1), ("D5", 1), ("B4", 1)], "E"), ([("A4", 4)], "Am")]}),
    "tidy-up-tune": ("D", {"bpm": 126, "repeat": 3, "perc": 0.1, "end": "D5", "bars": [
        ([("D4", 1), ("F#4", 1), ("A4", 1), ("F#4", 1)], "D"), ([("G4", 1), ("B4", 1), ("A4", 2)], "G"),
        ([("F#4", 1), ("E4", 1), ("D4", 1), ("E4", 1)], "D"), ([("F#4", 2), ("E4", 2)], "A"),
        ([("A4", 1), ("A4", 1), ("B4", 1), ("C#5", 1)], "A"), ([("D5", 2), ("A4", 2)], "D"),
        ([("G4", 1), ("F#4", 1), ("E4", 1), ("C#4", 1)], "A"), ([("D4", 4)], "D")]}),
    "moon-lullaby": ("F", {"bpm": 72, "repeat": 3, "perc": 0.02, "lead": "bell", "end": "F4", "bars": [
        ([("C5", 2), ("A4", 1)], "F"), ([("Bb4", 2), ("G4", 1)], "Bb"), ([("A4", 1), ("G4", 1), ("F4", 1)], "F"),
        ([("G4", 3)], "C"), ([("A4", 2), ("C5", 1)], "F"), ([("D5", 2), ("C5", 1)], "Dm"),
        ([("Bb4", 1), ("A4", 1), ("G4", 1)], "C"), ([("F4", 3)], "F")]}),
}
NOTE.update({"Bb": 10})

SONG_ART = {
    "counting-train": "train", "ten-little-seeds": "seeds", "feelings-song": "feelings",
    "tidy-up-tune": "tidy", "moon-lullaby": "moon",
}


def song_cover(slug):
    img, d = cover_canvas(512, 512, C["bg"])
    kind = SONG_ART[slug]
    if kind == "train":
        d.rectangle([0, 0, 512, 512], fill=(226, 238, 255))
        d.rectangle([0, 380, 512, 392], fill=C["ink"])
        for i, col in enumerate(("red", "blue", "yellow", "green")):
            x = 40 + i * 115
            d.rounded_rectangle([x, 280, x + 100, 370], radius=14, fill=C[col])
            label(d, str(i + 1), x + 50, 325, 46, C["white"])
            for wx in (x + 25, x + 75):
                circle(d, wx, 378, 16, C["ink"])
        bolt(d, 256, 150, 70)
    elif kind == "seeds":
        d.rectangle([0, 0, 512, 512], fill=C["sky"])
        d.rectangle([0, 360, 512, 512], fill=C["soil"])
        for i in range(10):
            x = 40 + i * 48
            h = 40 + (i % 5) * 22
            d.line([x, 360, x, 360 - h], fill=C["pipdark"], width=6)
            d.ellipse([x, 350 - h, x + 22, 362 - h], fill=C["pip"])
        pip(d, 256, 170, 70)
    elif kind == "feelings":
        d.rectangle([0, 0, 512, 512], fill=(255, 242, 201))
        for i, mood in enumerate(("happy", "sleepy", "happy", "happy")):
            x, y = 128 + (i % 2) * 256, 150 + (i // 2) * 220
            circle(d, x, y, 80, (C["nova"], C["bolt"], C["play"], C["pip"])[i])
            face(d, x, y + 10, 80, mood)
    elif kind == "tidy":
        d.rectangle([0, 0, 512, 512], fill=(225, 248, 230))
        d.rounded_rectangle([150, 300, 362, 450], radius=20, fill=C["play"])
        for i, (k, col) in enumerate((("star", "yellow"), ("circle", "blue"), ("square", "red"))):
            shape(d, k, 200 + i * 56, 270 - (i % 2) * 30, 30, C[col])
        bolt(d, 380, 160, 60)
    else:
        d.rectangle([0, 0, 512, 512], fill=C["night"])
        for i in range(24):
            x, y = (i * 97) % 512, (i * 53) % 300
            d.polygon(star_points(x, y, 7), fill=C["yellow"])
        circle(d, 340, 170, 90, (255, 242, 201))
        circle(d, 380, 150, 80, C["night"])
        cloud(d, 200, 380, 70, (226, 238, 255), "sleepy")
    return img


def make_songs():
    for slug, (_, spec) in SONGS.items():
        d = OUT / "content" / "songs" / slug
        d.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory() as tmp:
            wav = Path(tmp) / "s.wav"
            buf = song(spec)
            write_wav(wav, buf)
            run(["ffmpeg", "-y", "-i", str(wav), "-c:a", "aac", "-b:a", "64k", "-movflags", "+faststart", str(d / "en.m4a")])
        register("content", f"songs/{slug}/en.m4a", "audio", "audio/mp4", locale="en", durationMs=int(len(buf) / RATE * 1000))
        save_thumbs(song_cover(slug), slug, square=True)


# ----------------------------------------------------------------------------- stories
STORIES = {
    "the-sleepy-cloud": [
        ("A little cloud floated over the hill. She yawned a big, fluffy yawn.", "cloud_yawn"),
        ("The sun was going down, and the sky turned pink and orange.", "sunset"),
        ("Bird flew past. \"Goodnight, little cloud!\" she sang.", "bird"),
        ("The cloud looked for a soft place to rest. The hill was too pointy.", "hill"),
        ("The moon came up and made a silver bed in the sky.", "moon"),
        ("The little cloud curled up, closed her eyes, and drifted off to sleep. Goodnight!", "cloud_sleep"),
    ],
    "calm-breathing": [
        ("Bolt's tower of blocks fell down. Crash! Bolt felt cross.", "blocks_fall"),
        ("His face went hot and his hands went tight.", "bolt_cross"),
        ("Pip said, \"Let's smell a flower and blow out a candle.\"", "pip_help"),
        ("Breathe in through your nose... like smelling a flower.", "flower"),
        ("Breathe out slowly... like blowing out a candle. Whoosh.", "candle"),
        ("Bolt felt calm again. Together, they built an even taller tower!", "tower"),
    ],
    "pip-and-the-lost-seed": [
        ("Pip had one tiny seed. \"Where shall I plant you?\" asked Pip.", "seed"),
        ("Whoosh! The wind blew the seed away.", "wind"),
        ("Pip looked under a leaf. No seed. Pip looked in a flower. No seed.", "search"),
        ("A snail pointed with its feelers. \"Over there, in the soft soil!\"", "snail"),
        ("Rain came, and sun came. A little green shoot popped up.", "shoot"),
        ("The lost seed had found the perfect home. It grew into a flower!", "bloom"),
    ],
    "nova-counts-the-stars": [
        ("When the sky was dark, Nova liked to count the stars.", "night"),
        ("One star, two stars, three stars, twinkling high.", "three"),
        ("Four stars, five stars, a little line of light.", "five"),
        ("A cloud drifted by and hid some stars. \"Come back!\" said Nova.", "cloud"),
        ("The cloud moved on. Six, seven, eight, nine, ten!", "ten"),
        ("\"Goodnight, stars,\" whispered Nova. \"I'll count you again tomorrow.\"", "goodnight"),
    ],
}


def story_page(scene, size=(960, 600)):
    w, h = size
    img = Image.new("RGB", size, C["bg"])
    d = ImageDraw.Draw(img)
    night = scene in ("moon", "cloud_sleep", "night", "three", "five", "cloud", "ten", "goodnight")
    d.rectangle([0, 0, w, h], fill=C["night"] if night else C["sky"])
    if night:
        n = {"three": 3, "five": 5, "ten": 10}.get(scene, 18)
        for i in range(n):
            x, y = 90 + (i * 83) % (w - 180), 70 + (i * 61) % 220
            d.polygon(star_points(x, y, 16 if scene in ("three", "five", "ten") else 8), fill=C["yellow"])
            if scene in ("three", "five", "ten"):
                label(d, str(i + 1), x, y + 34, 22, C["white"])
    if scene not in ("night", "three", "five", "ten", "goodnight", "moon", "cloud", "cloud_sleep"):
        d.ellipse([-w * 0.2, h * 0.72, w * 1.2, h * 1.5], fill=C["grass"])
    if scene == "cloud_yawn":
        d.ellipse([w * 0.1, h * 0.5, w * 0.9, h * 1.3], fill=C["grass"])
        cloud(d, w / 2, 200, 90, mood="happy")
        d.ellipse([w / 2 - 20, 240, w / 2 + 20, 280], fill=C["ink"])
    elif scene == "sunset":
        d.rectangle([0, 0, w, h * 0.72], fill=(255, 200, 160))
        circle(d, w * 0.7, h * 0.7, 70, C["orange"])
        cloud(d, 260, 170, 70, mood="happy")
    elif scene == "bird":
        cloud(d, 300, 180, 70, mood="happy")
        d.polygon([(640, 200), (700, 170), (690, 215)], fill=C["blue"])
        circle(d, 650, 215, 30, C["blue"])
        d.polygon([(678, 210), (700, 216), (678, 222)], fill=C["orange"])
    elif scene == "hill":
        d.polygon([(200, h * 0.75), (480, 160), (760, h * 0.75)], fill=C["pipdark"])
        cloud(d, 480, 120, 60, mood="happy")
    elif scene == "moon":
        circle(d, 720, 150, 70, (255, 242, 201))
        circle(d, 750, 135, 62, C["night"])
        cloud(d, 380, 330, 80, (226, 238, 255), "happy")
    elif scene == "cloud_sleep":
        circle(d, 760, 130, 60, (255, 242, 201))
        cloud(d, 450, 330, 100, (226, 238, 255), "sleepy")
        label(d, "z z z", 610, 230, 40, C["white"])
    elif scene in ("blocks_fall", "tower"):
        cols = ("red", "blue", "yellow", "green", "purple", "orange", "red")
        if scene == "blocks_fall":
            for i, col in enumerate(cols[:5]):
                d.rounded_rectangle([420 + i * 70, 420 + (i % 2) * 25, 480 + i * 70, 470 + (i % 2) * 25], radius=8, fill=C[col])
            bolt(d, 240, 300, 80)
        else:
            for i, col in enumerate(cols):
                d.rounded_rectangle([560, 420 - i * 50, 640, 468 - i * 50], radius=8, fill=C[col])
            bolt(d, 260, 320, 80)
            pip(d, 420, 360, 60)
    elif scene == "bolt_cross":
        bolt(d, w / 2, 290, 120)
        d.line([w / 2 - 70, 220, w / 2 - 25, 240], fill=C["ink"], width=8)
        d.line([w / 2 + 70, 220, w / 2 + 25, 240], fill=C["ink"], width=8)
    elif scene == "pip_help":
        bolt(d, 300, 320, 85)
        pip(d, 640, 340, 80)
    elif scene == "flower":
        flower(d, 480, 250, 50, C["red"])
        bolt(d, 260, 330, 80)
    elif scene == "candle":
        d.rectangle([450, 300, 510, 460], fill=C["white"])
        d.polygon([(480, 240), (465, 290), (495, 290)], fill=C["orange"])
        bolt(d, 260, 330, 80)
        for i in range(3):
            d.arc([330 + i * 30, 260, 420 + i * 30, 340], 300, 60, fill=C["white"], width=5)
    elif scene == "seed":
        pip(d, 380, 330, 90)
        circle(d, 560, 360, 16, C["soil"])
    elif scene == "wind":
        pip(d, 300, 340, 80)
        for i in range(4):
            d.arc([450 + i * 40, 180 + i * 30, 700 + i * 40, 280 + i * 30], 200, 340, fill=C["white"], width=6)
        circle(d, 800, 200, 14, C["soil"])
    elif scene == "search":
        pip(d, 300, 350, 80)
        flower(d, 620, 260, 40, C["purple"])
        d.ellipse([720, 400, 860, 450], fill=C["pipdark"])
    elif scene == "snail":
        snail(d, 620, 400, 60)
        pip(d, 280, 340, 80)
        d.rectangle([700, 455, 900, 480], fill=C["soil"])
    elif scene == "shoot":
        sun(d, 160, 110, 50)
        for i in range(10):
            drop(d, 600 + (i * 47) % 200, 100 + (i * 31) % 160, 9)
        d.rectangle([380, 470, 580, 490], fill=C["soil"])
        d.line([480, 470, 480, 400], fill=C["pipdark"], width=8)
        d.ellipse([480, 380, 530, 410], fill=C["pip"])
    elif scene == "bloom":
        flower(d, 560, 260, 60, C["red"])
        pip(d, 300, 340, 80)
    if scene in ("night", "three", "five", "ten", "goodnight"):
        nova(d, w * 0.5, h * 0.78, 80, "sleepy" if scene == "goodnight" else "happy")
    if scene == "cloud":
        for i in range(5):
            d.polygon(star_points(120 + i * 70, 120, 14), fill=C["yellow"])
        cloud(d, 600, 150, 90, (200, 210, 230))
        nova(d, 320, 450, 80)
    return img


def make_stories():
    for slug, pages in STORIES.items():
        base = OUT / "content" / slug / "1" / "pages"
        base.mkdir(parents=True, exist_ok=True)
        for n, (_, scene) in enumerate(pages, start=1):
            story_page(scene).save(base / f"{n}.webp", "WEBP", quality=80, method=6)
            register("content", f"{slug}/1/pages/{n}.webp", "image", "image/webp", width=960, height=600, position=n - 1)
        save_thumbs(story_page(pages[0][1]).resize((768, 480)), slug)


# ----------------------------------------------------------------------------- output
STORY_TEXT = {slug: [text for text, _ in pages] for slug, pages in STORIES.items()}


def dart_string(s):
    return "'" + s.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$") + "'"


def write_outputs():
    manifest = {"generatedBy": "content/dev-media/make_dev_media.py", "files": REGISTRY, "storyText": STORY_TEXT}
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=1) + "\n")
    lines = [
        "// GENERATED by content/dev-media/make_dev_media.py. Do not edit by hand.",
        "// The development media library: every file under assets/dev_media/<bucket>/<path>, with",
        "// the facts media_assets stores, and the story text. Original content (see the script).",
        "// ignore_for_file: lines_longer_than_80_chars",
        "library;",
        "",
        "class DevMediaFile {",
        "  const DevMediaFile(this.bucket, this.path, this.kind, this.mime, this.bytes, this.sha256,",
        "      {this.width, this.height, this.durationMs, this.locale, this.position});",
        "  final String bucket, path, kind, mime, sha256;",
        "  final int bytes;",
        "  final int? width, height, durationMs, position;",
        "  final String? locale;",
        "}",
        "",
        "const devMediaFiles = <DevMediaFile>[",
    ]
    for f in REGISTRY:
        extra = []
        for k in ("width", "height", "durationMs", "position"):
            if f.get(k) is not None:
                extra.append(f"{k}: {f[k]}")
        if f.get("locale"):
            extra.append(f"locale: {dart_string(f['locale'])}")
        lines.append(f"  DevMediaFile({dart_string(f['bucket'])}, {dart_string(f['path'])}, {dart_string(f['kind'])}, "
                     f"{dart_string(f['mime'])}, {f['bytes']}, {dart_string(f['sha256'])}{', ' if extra else ''}{', '.join(extra)}),")
    lines += ["];", "", "/// Story text, one entry per page (the app shows it and the voice reads it).",
              "const devStoryText = <String, List<String>>{"]
    for slug, texts in STORY_TEXT.items():
        lines.append(f"  {dart_string(slug)}: [")
        lines += [f"    {dart_string(t)}," for t in texts]
        lines.append("  ],")
    lines += ["};", ""]
    (APP / "lib" / "demo" / "demo_media.g.dart").write_text("\n".join(lines))


def main():
    only = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else None
    if only not in (None, "videos", "songs", "stories", "badges"):
        sys.exit("--only videos|songs|stories|badges")
    if only:
        # keep the other kinds' entries from the last manifest
        old = json.loads((OUT / "manifest.json").read_text())["files"]
        keep = {"videos": ("video",), "songs": ("songs/",), "stories": ("/pages/",), "badges": ("badges/",)}[only]
        REGISTRY.extend(f for f in old if not any(k in f["path"] or f["bucket"] == k for k in keep))
    if only in (None, "videos"):
        for v in (video_snail, video_farm, video_rain, video_shapes, video_rainbow):
            v()
    if only in (None, "songs"):
        make_songs()
    if only in (None, "stories"):
        make_stories()
    if only in (None, "badges"):
        make_badges()
    # a partial run re-registers some files: keep the newest entry per path
    latest = {(f["bucket"], f["path"]): f for f in REGISTRY}
    REGISTRY[:] = sorted(latest.values(), key=lambda f: (f["bucket"], f["path"]))
    write_outputs()
    total = sum(f["bytes"] for f in REGISTRY)
    print(f"{len(REGISTRY)} files, {total / 1024:.0f} KB -> {OUT}")


if __name__ == "__main__":
    main()
