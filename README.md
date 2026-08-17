# Westford — Police Command Simulator

A police command/management simulation game. The player is a UK police
Inspector commanding a frontline response team through 10–12 hour shifts —
briefing, allocating scarce resources, responding to incidents, and managing
the consequences, in a fictional town called Westford.

This is a separate project from `predictor` (the KYG/Pundit sports app) —
different codebase, different engine, different backend. Nothing here shares
a repo, branch, or Supabase project with that app.

## Status

**Milestones 1-2 written, not yet run.** See [`docs/SPEC.md`](docs/SPEC.md)
for the full MVP design and [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
for the technical analysis and phased plan this was built against.

- **Milestone 1 — headless simulation core.** Game clock, shift/district/
  officer/resource/incident/event/fatigue/community/intelligence managers,
  incident state machine, probability/outcome engines, cross-shift
  incident persistence — all wired together in `SimulationCore`, driven by
  a small 3-district test map and 5 incident types.
- **Milestone 2 — minimal map + live visuals.** `scenes/main/main.tscn` is
  now the project's main scene — open the project in the Godot editor and
  press Run/F5 to see the small test map (roads, locations, district
  outlines), police units moving between them, colour-coded incident
  markers, a top HUD, pause/1x/2x/4x, and an event feed. Click an
  available unit then an actionable incident marker to dispatch it — that
  replaces Milestone 1's auto-dispatch entirely, so undispatched incidents
  now genuinely queue and can escalate.

**None of this has been executed against the real engine yet** — Godot
isn't installed in the sandbox this was written in, and its network policy
blocks fetching the engine binary. Written carefully (typed GDScript
throughout, hand-checked for the usual gotchas) but not verified. See
[`tests/README.md`](tests/README.md) for how to run both the headless
Milestone 1 harness and the visual Milestone 2 scene, and what to check.

No briefing screen, incident info panel, or debrief UI yet (Milestone 3+).

## Engine

Godot 4.x (written against 4.3+ syntax), 2D with isometric/angled
presentation, built mobile/touch-first.

## Project layout

```
autoload/simulation.gd     Thin Node wrapper around one SimulationCore instance
scripts/core/               Shared enums
scripts/world/               Static map data (Resource): districts, locations, road graph
scripts/runtime/             Mutable simulation state (RefCounted): officers, units, incidents...
scripts/incidents/           Incident type definitions + probability/outcome engines
scripts/simulation/          Managers + SimulationCore (the composition root)
scripts/ui/                  MapView/HudView/markers -- Presentation, built via code not .tscn
scripts/main.gd              Scene entry point (wires the real SimulationCore to MapView/HudView)
scenes/main/main.tscn        The only hand-authored scene file -- a bare root + script
data/                         Small-test-map + starter content, built in code (see tests/README.md)
tests/                        Headless debug harness + how-to-run notes
docs/                         Spec + architecture analysis
```

See `docs/ARCHITECTURE.md` section 3 for the reasoning behind this
structure, and section 9 for what Milestones 2+ (map, UI, full Westford
town) still need to add.
