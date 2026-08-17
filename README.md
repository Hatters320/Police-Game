# Westford — Police Command Simulator

A police command/management simulation game. The player is a UK police
Inspector commanding a frontline response team through 10–12 hour shifts —
briefing, allocating scarce resources, responding to incidents, and managing
the consequences, in a fictional town called Westford.

This is a separate project from `predictor` (the KYG/Pundit sports app) —
different codebase, different engine, different backend. Nothing here shares
a repo, branch, or Supabase project with that app.

## Status

**Milestones 1-6 built and verified against the real engine (Godot 4.7.1).**
The full MVP loop from `docs/SPEC.md` is playable end to end, on the real
6-district Westford town, including local persistence across separate play
sessions. See [`docs/SPEC.md`](docs/SPEC.md) for the full MVP design and
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the technical analysis
and phased plan this was built against.

- **Milestone 1 — headless simulation core.** Game clock, shift/district/
  officer/resource/incident/event/fatigue/community/intelligence managers,
  incident state machine, probability/outcome engines, cross-shift
  incident persistence — all wired together in `SimulationCore`, driven by
  a small 3-district test map and 5 incident types.
- **Milestone 2 — minimal map + live visuals.** The small test map (roads,
  locations, district outlines), police units moving between them,
  colour-coded incident markers, a top HUD, pause/1x/2x/4x, an event feed.
- **Milestone 3 — briefing, incident panel, debrief.** Pre-shift briefing
  (staffing, intelligence, community issues, planned events, priorities,
  per-unit patrol tasking, reserve target) -> confirm -> live play, where
  clicking an incident marker opens a full panel (known/unknown facts +
  Request Information, command intent, assigned units + Recall, every
  other unit + Send/Reassign) -> a debrief at shift end -> Start Next
  Shift, looping back to a fresh briefing with the same persistent
  district/incident state.
- **Milestone 4 — unit welfare + map overlays.** Click a unit marker to
  see each crew member's fatigue/morale and send it for a break or recall
  it from patrol. ASB/Violence/Burglary/Visibility/Demand overlay toggles
  tint the districts, with low intelligence quality blurring the displayed
  value so uncertainty is visible, not just told.
- **Milestone 5 — save/load + real debrief scoring.** Local JSON save of
  district state, incident history, and still-open incidents (no online
  accounts, per spec section 67) -- confirmed loading correctly in a
  completely separate process launch. The debrief now shows a real
  5-dimension Response/Prevention/Intelligence/Community/Workforce rating
  (Poor through Excellent) and a short narrative summary, not just raw
  counters.
- **Milestone 6 — the full Westford town.** The real 6-district town from
  spec section 5 (Town Centre, Northside, East Estate, South Residential,
  West Industrial, Rural/Outskirts): 73 gameplay locations (police
  station, high street, railway station, football stadium, shops, pubs,
  restaurants, estates, schools, hospital, fire station, community
  centres, industrial units, farms) laid out around a 31-node/33-edge road
  network, plus ~650 decorative buildings for visual density -- generated
  procedurally from a compact per-district data table rather than hand
  authored point-by-point, since there's no art yet to make exact
  placement meaningful. This replaced the small 3-district test map as
  what the real game plays on; the small map lives on only for the fast
  headless test harness.

Every milestone above has been run against the real engine and
screenshotted at each stage, not shipped on the strength of the code
reading right — including forcing a save, killing the process, and
launching a fresh one to confirm the load path actually works, and
dispatching a unit clear across the full town to confirm pathfinding holds
up at the larger scale.

`scenes/main/main.tscn` is the project's main scene — open the project in
the Godot editor and press Run/F5 to play it. See
[`tests/README.md`](tests/README.md) for how to run both the visual scene
and the headless Milestone 1 harness yourself.

**One open finding, not yet acted on:** natural incident generation over a
12h shift came out lower than a rough estimate suggested (~5 incidents vs.
~18 expected), likely because several district starting values sit below
the neutral midpoint the probability weighting is centred on,
systematically damping rates. Worth tuning after real playtesting rather
than guessing further from one seeded run — a quiet start is arguably
consistent with spec section 7 anyway.

Not built: specialist units (traffic/dog/firearms), a separate
neighbourhood team, audio, and any visual polish beyond flat coloured
shapes (spec's "SimCity-style" target art direction is still a placeholder
-- see spec section 2's explicit MVP exclusions and section 61's Phase 8).

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
scripts/simulation/          Managers + SimulationCore (composition root) + SaveManager + DebriefScorer
scripts/ui/                  MapView/HudView/BriefingView/(Incident|Unit)PanelView/DebriefView/markers --
                              Presentation, built via code not .tscn
scripts/main.gd              Scene entry point: owns the briefing->play->debrief->briefing loop
scenes/main/main.tscn        The only hand-authored scene file -- a bare root + script
data/                         Map factories (small test map + full Westford) and starter content,
                              all built in code (see tests/README.md)
tests/                        Headless debug harness (small map) + how-to-run notes
docs/                         Spec + architecture analysis
```

See `docs/ARCHITECTURE.md` section 3 for the reasoning behind this
structure, and section 9 for the original phased plan (Milestones 1-6 are
now complete; what's left is spec section 61's Phase 8 polish and the
explicitly-deferred systems listed above).
