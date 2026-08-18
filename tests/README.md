# Running this project

**All paths below have been run against the real engine (Godot 4.7.1)
and confirmed working** — a full 12h shift completes cleanly headless,
the visual scene renders and handles dispatch correctly under software
rendering, and the Web export runs correctly in a real browser (see
below). Run them yourself with the steps below. See the main README's
"Status" section for what's built (everything in `docs/SPEC.md` at this
point) and what's genuinely still open.

## The visual scene (Milestone 2) — the normal way to look at this

With Godot 4.3+ installed, just open the project (`project.godot`) in the
editor and press **Run** (F5, or the Play button). `run/main_scene` is set
to `scenes/main/main.tscn`, so this starts a shift on the small test map
directly: roads, locations, district outlines, moving police units,
colour-coded incident markers, a top HUD, pause/1x/2x/4x, and an event
feed.

**Controls**: scroll wheel (or the on-screen -/+ buttons) to zoom. Click
an incident marker to open its panel — REQUEST INFORMATION, set command
intent, SEND a unit, request a specialist, or task a neighbourhood
officer. Click a unit marker for its welfare panel (fatigue/morale, send
for break). There is no auto-dispatch — the Inspector's decisions are the
whole point (spec section 49) — so an incident queuing up and escalating
because nothing was sent yet is expected behaviour, not a bug.

**What to check**: does it open without an error dialog; do you see the
map and moving units; does clicking a unit then an incident marker
actually send it (marker should turn orange/travelling, then red/on-scene
once it arrives); do the HUD numbers and event feed update.

## The headless debug harness (Milestone 1) — console-only, no visuals

`run_shift_debug.gd` is a separate entry point (extends `SceneTree`) that
builds its own instance of the simulation (not the one the visual scene
uses), fast-forwards a full 12-hour shift with a trivial auto-dispatch
stand-in for the player, and prints a shift log plus a raw debrief-shaped
summary straight to the console. It exists to prove the simulation loop
runs correctly with zero scene/map/UI involved (spec section 61 Phase 1) —
useful mainly if the visual scene has a problem and it's unclear whether
the bug is in the simulation layer or the presentation layer built on top
of it.

From the project root:

```bash
godot4 --headless --script res://tests/run_shift_debug.gd
```

(or `godot` / `Godot_v4.x-stable_linux.x86_64`, whatever your install is
called — any Godot 4.3+ binary works, `--headless` just skips opening a
window.)

Expect a shift log (`NEW ...`, `ESCALATED ...`, `RESOLVED ...` lines),
ending in a `SHIFT DEBRIEF` block and a `SIMULATION STATE` district
readout. Roughly a dozen-ish incidents over the 12h shift, some
escalations, most resolved by shift end, maybe a few still open (correct
— see docs/ARCHITECTURE.md's cross-shift incident history decision, they
carry into the next shift rather than vanishing). Fatigue warnings should
appear for at least a few officers by the end, since this harness never
calls `send_for_break`.

## Web export (playing in a browser)

The main README's "Play it in a browser" section has the live link and
the one-time GitHub Pages toggle. To rebuild the site yourself:

1. **Export templates**: download `Godot_v4.7.1-stable_export_templates.tpz`
   (matching whatever Godot version you're building with) and unzip
   `web_release.zip`/`web_debug.zip`/`web_nothreads_release.zip`/
   `web_nothreads_debug.zip` plus `version.txt` into
   `~/.local/share/godot/export_templates/4.7.1.stable/`.
2. **Export preset**: `export_presets.cfg` isn't committed (gitignored,
   matching Godot's default project template), so create one at the repo
   root with this content -- `variant/thread_support=false` matters: it
   uses the no-threads template variant, which needs no COOP/COEP server
   headers, so it works on plain static hosting like GitHub Pages:

   ```ini
   [preset.0]

   name="Web"
   platform="Web"
   runnable=true
   advanced_options=false
   dedicated_server=false
   custom_features=""
   export_filter="all_resources"
   include_filter=""
   exclude_filter=""
   export_path="build/web/index.html"
   encryption_include_filters=""
   encryption_exclude_filters=""
   encrypt_pck=false
   encrypt_directory=false
   script_export_mode=2

   [preset.0.options]

   custom_template/debug=""
   custom_template/release=""
   variant/extensions_support=false
   variant/thread_support=false
   vram_texture_compression/for_desktop=true
   vram_texture_compression/for_mobile=false
   html/export_icon=true
   html/custom_html_shell=""
   html/head_include=""
   html/canvas_resize_policy=2
   html/focus_canvas_on_start=true
   html/experimental_virtual_keyboard=false
   progressive_web_app/enabled=false
   progressive_web_app/offline_page=""
   progressive_web_app/display=1
   progressive_web_app/orientation=0
   progressive_web_app/icon_144x144=""
   progressive_web_app/icon_180x180=""
   progressive_web_app/icon_512x512=""
   progressive_web_app/background_color=Color(0, 0, 0, 1)
   ```

3. **Build**: `godot4 --headless --export-release "Web" build/web/index.html`
4. **Publish**: replace the contents of the `gh-pages` branch with the new
   `build/web/` output (plus an empty `.nojekyll` file so GitHub Pages
   doesn't run the build through Jekyll) and push. GitHub Pages picks up
   the change automatically within about a minute.

Verified against the real engine: exported, served locally, and driven
with a real headless Chromium browser (Playwright) -- boots with zero
console errors, the briefing screen renders and scrolls, CONFIRM SHIFT
PLAN works, and the live map/HUD/simulation clock runs correctly
(watched the clock advance in real time after confirming).

## If either one doesn't run

Paste the error back — file, line, and message (the visual scene's errors
show in the editor's Output/Debugger panel; the headless one prints
straight to the terminal). Most likely causes, in order of probability: a
typo in a cross-file type reference (every class here uses global
`class_name`, so Godot resolves them project-wide, but a misspelled name
only surfaces at parse time), a signal connect/`.bind()` argument-order
mismatch, a typed-array assignment needing an explicit cast the engine
didn't infer, or — for the visual scene specifically — something in
`scenes/main/main.tscn`'s hand-written resource-file syntax. All fixable
without touching the architecture.
