# Westford — Police Command Simulator

A police command/management simulation game. The player is a UK police
Inspector commanding a frontline response team through 10–12 hour shifts —
briefing, allocating scarce resources, responding to incidents, and managing
the consequences, in a fictional town called Westford.

This is a separate project from `predictor` (the KYG/Pundit sports app) —
different codebase, different engine, different backend. Nothing here shares
a repo, branch, or Supabase project with that app.

## Status

**Milestones 1-2 built and verified against the real engine (Godot 4.7.1).**
See [`docs/SPEC.md`](docs/SPEC.md) for the full MVP design and
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the technical analysis
and phased plan this was built against.

- **Milestone 1 — headless simulation core.** Game clock, shift/district/
  officer/resource/incident/event/fatigue/community/intelligence managers,
  incident state machine, probability/outcome engines, cross-shift
  incident persistence — all wired together in `SimulationCore`, driven by
  a small 3-district test map and 5 incident types. Confirmed running a
  full 12h shift end to end with no errors: correct crew formation (12
  officers → 6 units), incident generation/dispatch/resolution,
  intelligence capture, shift debrief compilation.
- **Milestone 2 — minimal map + live visuals.** `scenes/main/main.tscn` is
  the project's main scene — open it in the Godot editor and press Run/F5
  to see the small test map (roads, locations, district outlines), police
  units moving between them, colour-coded incident markers, a top HUD,
  pause/1x/2x/4x, and an event feed. Click an available unit then an
  actionable incident marker to dispatch it — that's the only dispatch
  path now (no auto-dispatch), so undispatched incidents genuinely queue
  and can escalate. Confirmed rendering correctly and the full
  dispatch-through-Commands path working, screenshotted at each stage.

See [`tests/README.md`](tests/README.md) for how to run both the headless
Milestone 1 harness and the visual Milestone 2 scene yourself.

**One open finding from the verification run, not yet acted on:** natural
incident generation over a 12h shift came out lower than a rough estimate
suggested (~5 incidents vs. ~18 expected), likely because several
district starting values sit below the neutral midpoint the probability
weighting is centred on, systematically damping rates. Worth tuning after
real playtesting rather than guessing further from one seeded run — a
quiet start is arguably consistent with spec section 7 anyway.

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
