#!/usr/bin/env python3
"""Renames the Web export's index.pck to a content-hashed filename and
patches index.html's GODOT_CONFIG (mainPack + fileSizes) to match.

Why: GitHub Pages sets Cache-Control: max-age=600 on these files, and a
fixed filename means a browser that already has index.pck cached simply
never re-fetches it for up to 10 minutes -- confirmed as the actual cause
of a real user seeing three consecutive shipped fixes all appear to do
nothing, because they kept reloading a stale-cached .pck inside that
window. A content-hashed filename is a genuinely new URL on every deploy
that changes the .pck's bytes, so the browser has no cached copy to
(incorrectly) reuse regardless of Cache-Control lifetime. index.wasm/
index.js are the stable Emscripten/Godot runtime -- untouched by any
GDScript change -- so they're deliberately left alone; only the file that
actually varies between deploys needs busting.

Usage: python3 cachebust_web_export.py <path-to-build/web-dir>
"""

import hashlib
import re
import sys
from pathlib import Path


def main() -> None:
    if len(sys.argv) != 2:
        print("usage: cachebust_web_export.py <web-export-dir>", file=sys.stderr)
        sys.exit(1)

    web_dir = Path(sys.argv[1])
    pck_path = web_dir / "index.pck"
    html_path = web_dir / "index.html"
    if not pck_path.exists() or not html_path.exists():
        print(f"expected index.pck and index.html in {web_dir}", file=sys.stderr)
        sys.exit(1)

    digest = hashlib.sha256(pck_path.read_bytes()).hexdigest()[:12]
    new_name = f"index-{digest}.pck"
    new_path = web_dir / new_name
    pck_path.rename(new_path)

    html = html_path.read_text()
    match = re.search(r'"fileSizes":\{"index\.pck":(\d+)', html)
    if not match:
        print("could not find fileSizes.index.pck in index.html -- Godot's export format may have changed", file=sys.stderr)
        sys.exit(1)
    size = match.group(1)

    html = html.replace('"executable":"index"', f'"executable":"index","mainPack":"{new_name}"', 1)
    html = html.replace(f'"fileSizes":{{"index.pck":{size}', f'"fileSizes":{{"{new_name}":{size}', 1)
    html_path.write_text(html)

    print(f"Cache-busted: index.pck -> {new_name}")


if __name__ == "__main__":
    main()
