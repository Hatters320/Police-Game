# Running this project

**None of this has been run against the real engine yet.** The sandbox
this was written in has no Godot binary installed, and its network egress
policy blocks fetching one from GitHub releases, so no GDScript here has
been checked by the actual engine — no syntax validation, no runtime
testing. It's written carefully (typed GDScript throughout, cross-checked
by hand for the usual gotchas — Resource reference-sharing, typed-array/
export edge cases, `String.join()` argument typing, scene resource format,
etc.) but "written carefully" is not the same as "verified." Treat the
first run as the real first test of this code, on both paths below.

## The visual scene (Milestone 2) — the normal way to look at this

With Godot 4.3+ installed, just open the project (`project.godot`) in the
editor and press **Run** (F5, or the Play button). `run/main_scene` is set
to `scenes/main/main.tscn`, so this starts a shift on the small test map
directly: roads, locations, district outlines, moving police units,
colour-coded incident markers, a top HUD, pause/1x/2x/4x, and an event
feed.

**Controls**: scroll wheel to zoom. Click an available (blue) unit to
select it, then click an incident marker to dispatch it — that's the only
way incidents get handled right now (no auto-dispatch), so watching one
queue up and escalate because nothing was sent is expected behaviour, not
a bug.

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
