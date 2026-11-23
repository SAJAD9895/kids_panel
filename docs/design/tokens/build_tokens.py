#!/usr/bin/env python3
"""Generate platform outputs from tokens.json (the single source of truth).

    cd docs/design/tokens && python3 build_tokens.py

Writes:
  tokens.css            CSS custom properties (Next.js apps + mockups)
  tailwind.preset.cjs   Tailwind theme mapped onto the CSS variables
  flutter_tokens.json   values for the generated Dart ThemeExtensions (kl_design)

Design tooling only (standard library). Re-run after any value change, then re-run contrast.py.
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
fonts = {k: v for k, v in T["font"].items() if not k.startswith("_")}
rem = lambda px: f"{px / 16:.4g}rem"

# ---------------- tokens.css ----------------
css = ["/* GENERATED from tokens.json by build_tokens.py. Do not edit by hand. */", ":root {"]
css += [f"  --color-{k}: {v};" for k, v in colors.items()]
css += [f"  --font-{k}: {v};" for k, v in fonts.items()]
for group, styles in T["type"].items():
    for name, s in styles.items():
        p = f"--type-{group}-{name}"
        css += [f"  {p}-font: var(--font-{s['font']});", f"  {p}-size: {rem(s['size'])};",
                f"  {p}-line: {rem(s['line'])};", f"  {p}-weight: {s['weight']};"]
css += [f"  --space-{i}: {rem(v)};" for i, v in enumerate(T["space"])]
css += [f"  --radius-{k}: {v}px;" for k, v in T["radius"].items()]
css += [f"  --shadow-{k}: {v};" for k, v in T["shadow"].items()]
css += [f"  --motion-{k}: {v};" for k, v in T["motion"].items()]
css += [f"  --size-{k}: {v}px;" for k, v in T["size"].items()]
css += ["}", "",
        "@media (prefers-reduced-motion: reduce) {",
        "  :root { " + " ".join(f"--motion-{k}: 0ms;" for k, v in T["motion"].items() if v.endswith("ms")) + " }",
        "}", ""]
# one utility class per type style, so mockups and apps use the same names
for group, styles in T["type"].items():
    for name in styles:
        p = f"--type-{group}-{name}"
        css.append(f".t-{group}-{name}{{font-family:var({p}-font);font-size:var({p}-size);"
                   f"line-height:var({p}-line);font-weight:var({p}-weight)}}")
(HERE / "tokens.css").write_text("\n".join(css) + "\n")

# ---------------- tailwind.preset.cjs ----------------
font_size = {}
for group, styles in T["type"].items():
    for name in styles:
        p = f"--type-{group}-{name}"
        font_size[f"{group}-{name}"] = [f"var({p}-size)", {"lineHeight": f"var({p}-line)", "fontWeight": f"var({p}-weight)"}]
space_key = lambda v: str(v // 4) if v % 4 == 0 else str(v / 4)
preset = {"theme": {
    "colors": {"transparent": "transparent", "current": "currentColor", **{k: f"var(--color-{k})" for k in colors}},
    "fontFamily": {k: [f"var(--font-{k})"] for k in fonts},
    "fontSize": font_size,
    "spacing": {space_key(v): f"var(--space-{i})" for i, v in enumerate(T["space"])},
    "borderRadius": {"none": "0", **{k: f"var(--radius-{k})" for k in T["radius"]}},
    "boxShadow": {"none": "none", **{k: f"var(--shadow-{k})" for k in T["shadow"]}},
    "screens": {k: f"{v}px" for k, v in T["breakpoints"].items() if v > 0},
    "extend": {
        "transitionDuration": {k: f"var(--motion-{k})" for k, v in T["motion"].items() if v.endswith("ms")},
        "transitionTimingFunction": {k.replace("ease-", ""): f"var(--motion-{k})" for k in T["motion"] if k.startswith("ease-")},
        "minHeight": {"tap-kids": "var(--size-tap-kids)", "tap": "var(--size-tap-ui)"},
        "minWidth": {"tap-kids": "var(--size-tap-kids)", "tap": "var(--size-tap-ui)"},
        "maxWidth": {"content": "var(--size-ui-content-max)"},
        "width": {"sidebar": "var(--size-ui-sidebar-w)", "rail": "var(--size-kids-rail-w)"},
    }}}
(HERE / "tailwind.preset.cjs").write_text(
    "/* GENERATED from tokens.json by build_tokens.py. Do not edit by hand.\n"
    "   Next.js: presets: [require('<repo>/docs/design/tokens/tailwind.preset.cjs')] and import tokens.css once.\n"
    "   Use roles only: bg-ui-surface text-ui-text-muted, text-ui-h1 ... never raw hex. */\n"
    "module.exports = " + json.dumps(preset, indent=2) + ";\n")

# ---------------- flutter_tokens.json ----------------
argb = lambda h: "0xFF" + h.lstrip("#").upper()
ms = lambda v: int(v[:-2])
flutter = {
    "_about": "GENERATED. Input for the Dart ThemeExtension generator in packages/dart/kl_design. Colours ARGB, sizes in logical pixels.",
    "colors": {k: argb(v) for k, v in colors.items()},
    "fontFamilies": {"display": "Fredoka", "kids": "Nunito", "reading": "Andika", "sans": "Inter"},
    "type": T["type"],
    "space": T["space"], "radius": T["radius"], "size": T["size"], "breakpoints": T["breakpoints"],
    "motionMs": {k: ms(v) for k, v in T["motion"].items() if v.endswith("ms")},
    "curves": {k: v for k, v in T["motion"].items() if k.startswith("ease-")},
}
(HERE / "flutter_tokens.json").write_text(json.dumps(flutter, indent=2) + "\n")
print(f"{len(colors)} colours, {sum(len(s) for s in T['type'].values())} type styles -> tokens.css, tailwind.preset.cjs, flutter_tokens.json")
