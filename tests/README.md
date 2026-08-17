# Running the Milestone 1 debug harness

`run_shift_debug.gd` is a headless script (extends `SceneTree`) that builds
the small test map, starts a 12-hour shift, fast-forwards through it with a
trivial auto-dispatch stand-in for the player, and prints a shift log plus
a raw debrief-shaped summary. It's the exit criterion for Milestone 1 (spec
section 61 Phase 1): proof the simulation loop runs end-to-end with no
scene, map, or UI involved.

**This has not been run yet.** The sandbox this was written in has no
Godot binary installed, and its network egress policy blocks fetching one
from GitHub releases, so none of this GDScript has been checked by the
actual engine — no syntax validation, no runtime testing. It's written
carefully (typed GDScript throughout, cross-checked by hand for the usual
GDScript gotchas — Resource reference-sharing, typed-array/export edge
cases, `String.join()` argument typing, etc.) but "written carefully" is
not the same as "verified." Treat the first run as the real first test of
this code.

## How to run it

From the project root, with Godot 4.3+ installed:

```bash
godot4 --headless --script res://tests/run_shift_debug.gd
```

(or `godot` / `Godot_v4.x-stable_linux.x86_64`, whatever your install is
called — any Godot 4.3+ binary works, `--headless` just skips opening a
window.)

## What to check

1. **Does it run at all?** The most likely failure mode is a GDScript
   parse/type error somewhere — the engine will print a file:line and
   error message pointing at it directly.
2. **Does it print a shift log** (`NEW ...`, `ESCALATED ...`,
   `RESOLVED ...` lines) and finish with a `SHIFT DEBRIEF` block, ending
   in `SIMULATION STATE` district readouts?
3. **Do the numbers look sane?** Roughly a dozen-ish incidents over a 12h
   shift on the small map, some escalations, most resolved by shift end,
   maybe a few still open (which is correct — see docs/ARCHITECTURE.md's
   cross-shift incident history decision, they're meant to carry into the
   next shift, not vanish).
4. **Fatigue warnings** should appear for at least a few officers by the
   end of a 12h shift with no breaks taken (the harness doesn't call
   `send_for_break` — that's a player decision, exercised once there's a
   UI in Milestone 3).

## If it doesn't run

Paste the error back — file, line, and message. Most likely causes, in
order of probability: a typo in a cross-file type reference (every class
here uses global `class_name`, so Godot resolves them project-wide, but a
misspelled name would only surface at parse time), a signal
connect/`.bind()` argument-order mismatch, or a typed-array assignment
that needs an explicit cast the engine didn't infer. All fixable without
touching the architecture.
