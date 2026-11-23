#!/usr/bin/env python3
"""Generate tokens.css, tailwind.preset.cjs and flutter-tokens.json from tokens.json.

    python3 build_tokens.py            # from replica/design/

Design tooling only (standard library). Re-run after /replica-brand changes values.
"""
import json
import pathlib

HERE = pathlib.Path(__file__).parent
T = json.loads((HERE / "tokens.json").read_text())


def flat(d, prefix=""):
    out = {}
    for k, v in d.items():
        if k.startswith("_"):
            continue
        key = f"{prefix}-{k}" if prefix else k
        out.update(flat(v, key) if isinstance(v, dict) else {key: v})
    return out


colors = flat(T["color"])

# ---- tokens.css ------------------------------------------------------------
css = ["/* GENERATED from tokens.json by build_tokens.py. Do not edit by hand. */", ":root {"]
css += [f"  --color-{k}: {v};" for k, v in colors.items()]
for name, f in T["font"].items():
    if not name.startswith("_"):
        css.append(f"  --font-{name}: {f};")
for group in ("type", "type-kids"):
    pre = "text" if group == "type" else "kids-text"
    for name, t in T[group].items():
        css += [f"  --{pre}-{name}-size: {t['size']/16:.4g}rem;",
                f"  --{pre}-{name}-line: {t['line']/16:.4g}rem;",
                f"  --{pre}-{name}-weight: {t['weight']};"]
css += [f"  --space-{i}: {v/16:.4g}rem;" for i, v in enumerate(T["space"])]
css += [f"  --radius-{k}: {v}px;" for k, v in T["radius"].items()]
css += [f"  --shadow-{k}: {v};" for k, v in T["shadow"].items()]
css += [f"  --motion-{k}: {v};" for k, v in T["motion"].items() if not k.startswith("_")]
css += [f"  --size-{k}: {v}px;" for k, v in T["size"].items()]
css += ["}", "",
        "@media (prefers-reduced-motion: reduce) {",
        "  :root { --motion-fast: 0ms; --motion-base: 0ms; --motion-playful: 0ms; }",
        "}", ""]
(HERE / "tokens.css").write_text("\n".join(css))

# ---- tailwind.preset.cjs ------------------------------------------------------
tw_colors = {k: f"var(--color-{k})" for k in colors}
font_size = {}
for group in ("type", "type-kids"):
    pre = "" if group == "type" else "kids-"
    cssp = "text" if group == "type" else "kids-text"
    for name, t in T[group].items():
        font_size[f"{pre}{name}"] = [f"var(--{cssp}-{name}-size)",
                                    {"lineHeight": f"var(--{cssp}-{name}-line)",
                                     "fontWeight": f"var(--{cssp}-{name}-weight)"}]
preset = {
    "theme": {
        "colors": {"transparent": "transparent", "current": "currentColor", **tw_colors},
        "fontFamily": {k: [f"var(--font-{k})"] for k in T["font"] if not k.startswith("_")},
        "fontSize": font_size,
        "spacing": {str(v // 4 if v % 4 == 0 else v / 4): f"var(--space-{i})" for i, v in enumerate(T["space"])},
        "borderRadius": {**{k: f"var(--radius-{k})" for k in T["radius"]}, "none": "0"},
        "boxShadow": {**{k: f"var(--shadow-{k})" for k in T["shadow"]}, "none": "none"},
        "screens": {k: f"{v}px" for k, v in T["breakpoints"].items()},
        "extend": {
            "transitionDuration": {k: f"var(--motion-{k})" for k in ("fast", "base", "playful")},
            "transitionTimingFunction": {"standard": "var(--motion-ease)", "spring": "var(--motion-spring)"},
            "minHeight": {"tap": "var(--size-tap-min-parent)", "tap-kids": "var(--size-tap-min-kids)"},
            "minWidth": {"tap": "var(--size-tap-min-parent)", "tap-kids": "var(--size-tap-min-kids)"},
            "maxWidth": {"content": "var(--size-web-content-max)", "parent": "var(--size-parent-content-max)"},
            "width": {"sidebar": "var(--size-web-sidebar-w)"},
        },
    }
}
(HERE / "tailwind.preset.cjs").write_text(
    "/* GENERATED from tokens.json by build_tokens.py. Do not edit by hand.\n"
    "   Use in apps/*-web: presets: [require('<path>/tailwind.preset.cjs')], and import tokens.css once.\n"
    "   Components use roles (bg-surface text-text-muted), never raw hex. */\n"
    "module.exports = " + json.dumps(preset, indent=2) + ";\n")

# ---- flutter-tokens.json (input for a generated Dart ThemeExtension later) ----
def argb(h):
    return "0xFF" + h.lstrip("#").upper()

flutter = {
    "_about": "GENERATED. Values for the Flutter theme (kl_design). Colours as ARGB ints, sizes in logical pixels (dp).",
    "colors": {k: argb(v) for k, v in colors.items()},
    "fonts": {"kids": "Nunito", "heading": "Nunito", "body": "Inter"},
    "type": T["type"], "typeKids": T["type-kids"],
    "space": T["space"], "radius": T["radius"], "size": T["size"],
    "motionMs": {k: int(v.rstrip("ms")) for k, v in T["motion"].items() if v.endswith("ms")},
}
(HERE / "flutter-tokens.json").write_text(json.dumps(flutter, indent=2) + "\n")
print(f"{len(colors)} colours -> tokens.css, tailwind.preset.cjs, flutter-tokens.json")
