#!/usr/bin/env python3
"""Screenshot every mockup frame to ../screens/<ID>.png with headless Chrome.
    python3 shoot.py kids.html [parent.html admin.html components.html]
Frames are found by: id="<ID>" style="width:<W>px;height:<H>px"  (single-frame mode via #ID)."""
import pathlib, re, subprocess, sys
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
HERE = pathlib.Path(__file__).resolve().parent
OUT = HERE.parent / "screens"; OUT.mkdir(exist_ok=True)
pat = re.compile(r'id="([A-Z][A-Za-z0-9-]*)"[^>]*?style="width:(\d+)px;height:(\d+)px')
for page in sys.argv[1:]:
    html = (HERE / page).read_text()
    for fid, w, h in pat.findall(html):
        png = OUT / f"{fid}.png"
        subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
                        f"--window-size={w},{h}", "--virtual-time-budget=6000", f"--screenshot={png}",
                        f"file://{HERE / page}#{fid}"], capture_output=True, timeout=90)
        print(("ok  " if png.exists() else "FAIL") + f" {fid} {w}x{h}")
