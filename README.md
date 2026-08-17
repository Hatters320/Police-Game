# Westford — Police Command Simulator

A police command/management simulation game. The player is a UK police
Inspector commanding a frontline response team through 10–12 hour shifts —
briefing, allocating scarce resources, responding to incidents, and managing
the consequences, in a fictional town called Westford.

This is a separate project from `predictor` (the KYG/Pundit sports app) —
different codebase, different engine, different backend. Nothing here shares
a repo, branch, or Supabase project with that app.

## Status

**Milestone 1 (headless simulation core) written, not yet run.** See
[`docs/SPEC.md`](docs/SPEC.md) for the full MVP design and
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the technical analysis
and phased plan this was built against.

The simulation layer (game clock, shift/district/officer/resource/incident/
event/fatigue/community/intelligence managers, incident state machine,
probability/outcome engines, cross-shift incident persistence) exists and
is wired together in `SimulationCore`, driven by a small 3-district test
map and 5 incident types, with a headless debug harness that runs a full
12h shift and prints a shift log. **This has not been executed** — Godot
isn't installed in the sandbox this was written in, and the sandbox's
network policy blocks fetching the engine binary. See
[`tests/README.md`](tests/README.md) for how to run it and what to check.
No scenes, map, or UI exist yet (Milestone 2+).

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
data/                         Small-test-map + starter content, built in code (see tests/README.md)
tests/                        Headless debug harness
docs/                         Spec + architecture analysis
```

See `docs/ARCHITECTURE.md` section 3 for the reasoning behind this
structure, and section 9 for what Milestones 2+ (map, UI, full Westford
town) still need to add.
