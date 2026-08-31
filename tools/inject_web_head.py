#!/usr/bin/env python3
"""Injects web/head_include.html into an exported index.html's <head>.

Why a post-export step rather than the export preset's own
html/head_include field: export_presets.cfg is gitignored (Godot's
default, since it can carry signing credentials), so anything configured
only there lives on one machine and silently disappears from a fresh
clone -- taking the browser-chrome fix with it. Keeping the snippet as a
committed file and injecting it here makes the export reproducible from
the repository alone.

Idempotent: if the marker is already present (because the export preset
also carries the snippet on this machine), it does nothing, so running it
either way is safe.

Usage: python3 inject_web_head.py <path-to-web-export-dir>
"""

import sys
from pathlib import Path

MARKER = "__westfordInsets"


def main() -> None:
    if len(sys.argv) != 2:
        print("usage: inject_web_head.py <web-export-dir>", file=sys.stderr)
        sys.exit(1)

    web_dir = Path(sys.argv[1])
    html_path = web_dir / "index.html"
    snippet_path = Path(__file__).resolve().parent.parent / "web" / "head_include.html"
    if not html_path.exists():
        print(f"expected index.html in {web_dir}", file=sys.stderr)
        sys.exit(1)
    if not snippet_path.exists():
        print(f"missing {snippet_path}", file=sys.stderr)
        sys.exit(1)

    html = html_path.read_text()
    if MARKER in html:
        print("head include already present, nothing to inject")
        return
    if "</head>" not in html:
        print("no </head> in index.html -- cannot inject", file=sys.stderr)
        sys.exit(1)

    html = html.replace("</head>", snippet_path.read_text() + "</head>", 1)
    html_path.write_text(html)
    print(f"injected {snippet_path.name} into {html_path}")


if __name__ == "__main__":
    main()
