# Westford — Police Command Simulator

A police command/management simulation game. The player is a UK police
Inspector commanding a frontline response team through 10–12 hour shifts —
briefing, allocating scarce resources, responding to incidents, and managing
the consequences, in a fictional town called Westford.

This is a separate project from `predictor` (the KYG/Pundit sports app) —
different codebase, different engine, different backend. Nothing here shares
a repo, branch, or Supabase project with that app.

## Status

**Milestones 1-3 built and verified against the real engine (Godot 4.7.1).**
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
- **Milestone 2 — minimal map + live visuals.** The small test map (roads,
  locations, district outlines), police units moving between them,
  colour-coded incident markers, a top HUD, pause/1x/2x/4x, an event feed.
- **Milestone 3 — briefing, incident panel, debrief.** The full loop now
  plays: a pre-shift briefing (staffing, intelligence, community issues,
  planned events, priorities, per-unit patrol tasking, reserve target) ->
  confirm -> live play, where clicking an incident marker opens a full
  panel (known/unknown facts + Request Information, command intent,
  assigned units + Recall, every other unit + Send/Reassign) -> a debrief
  at shift end (what resolved, what's still open and carried into the
  next shift, district snapshot) -> Start Next Shift, looping back to a
  fresh briefing with the same persistent district/incident state. Every
  stage of this loop has been run against the real engine and
  screenshotted, including confirming a still-open incident survives the
  shift boundary as the same object (reset to queued, not discarded).

`scenes/main/main.tscn` is the project's main scene — open the project in
the Godot editor and press Run/F5 to play it. See
[`tests/README.md`](tests/README.md) for how to run both the visual scene
and the headless Milestone 1 harness yourself.

**One open finding from Milestone 1's verification, not yet acted on:**
natural incident generation over a 12h shift came out lower than a rough
estimate suggested (~5 incidents vs. ~18 expected), likely because several
district starting values sit below the neutral midpoint the probability
weighting is centred on, systematically damping rates. Worth tuning after
real playtesting rather than guessing further from one seeded run — a
quiet start is arguably consistent with spec section 7 anyway.

No specialist units (traffic/dog/firearms), neighbourhood team, or map
overlays yet (Milestone 4+). Debrief scoring is raw counters and a
district snapshot, not the full 5-dimension Poor/Developing/Good/Strong/
Excellent rating (Milestone 5).

## Engine

Godot 4.x (written against 4.3+ syntax), 2D with isometric/angled
presentation, built mobile/touch-first.

## Project layout

```
autoload/simulation.gd     Thin Node wrapper around one SimulationCore instance
scripts/core/               Shared enums, time formatting
scripts/world/               Static map data (Resource): districts, locations, road graph
scripts/runtime/             Mutable simulation state (RefCounted): officers, units, incidents...
scripts/incidents/           Incident type definitions + probability/outcome engines
scripts/simulation/          Managers + SimulationCore (the composition root)
scripts/ui/                  MapView/HudView/BriefingView/IncidentPanelView/DebriefView/markers --
                              Presentation, built via code not .tscn
scripts/main.gd              Scene entry point: owns the briefing->play->debrief->briefing loop
scenes/main/main.tscn        The only hand-authored scene file -- a bare root + script
data/                         Small-test-map + starter content, built in code (see tests/README.md)
tests/                        Headless debug harness + how-to-run notes
docs/                         Spec + architecture analysis
```

See `docs/ARCHITECTURE.md` section 3 for the reasoning behind this
structure, and section 9 for what Milestones 2+ (map, UI, full Westford
town) still need to add.
