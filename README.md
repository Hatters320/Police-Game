# Westford — Police Command Simulator

A police command/management simulation game. The player is a UK police
Inspector commanding a frontline response team through 10–12 hour shifts —
briefing, allocating scarce resources, responding to incidents, and managing
the consequences, in a fictional town called Westford.

This is a separate project from `predictor` (the KYG/Pundit sports app) —
different codebase, different engine, different backend. Nothing here shares
a repo, branch, or Supabase project with that app.

## Status

**The full spec -- Milestones 1-6, Phase 8 polish, and every previously
deferred system -- is built and verified against the real engine (Godot
4.7.1).** The MVP loop from `docs/SPEC.md` is playable end to end on the
real 6-district Westford town, including local persistence across separate
play sessions. See [`docs/SPEC.md`](docs/SPEC.md) for the full MVP design
and [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the technical
analysis and phased plan this was built against.

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

### Beyond the MVP milestones

Everything below was built after Milestone 6, closing out the spec's
Phase 8 polish plus every system the original build had explicitly
deferred.

**Incident-rate bug fixed.** `IncidentProbabilityEngine` was weighting
every district variable's effect on incident rate against a hardcoded
midpoint of 50, but `DistrictState`'s honest quiet-town defaults (asb=20,
violence=10, burglary_risk=15, etc.) sit well below that, so every
district was permanently read as "far below normal" and rates were
damped to ~20-60% of their nominal `base_rate_per_hour`. Fixed by
weighting off each district's own captured baseline instead (the same
baseline `decay_toward_baseline`/`apply_patrol_presence` already used) --
confirmed via the headless harness: a 12h shift on the small test map
went from ~5 incidents to 31, back in the expected range.

- **Phase 8 — polish.** A day/night visual cycle (full-screen tint, clear
  07:00-18:00, fading to a night tint 20:00-05:00, spec section 33 -- the
  gameplay half, night-time incident weighting, already existed since
  Milestone 1) and touch-friendly controls (on-screen zoom +/- buttons
  since scroll-wheel has no touch equivalent, and larger minimum tap
  targets on every HUD button, spec section 56). Verified against the real
  engine by forcing the clock to midday/midnight and confirming the tint
  alpha (0.00 / 0.42) and by driving the zoom buttons' underlying callable
  and confirming camera zoom actually changes.

- **Specialist units (spec section 11).** 1 traffic, 1 dog, 1 firearms
  unit -- external resources represented with simplified behaviour, not
  guaranteed. Each rolls a fresh availability (available/nearby/far
  away/unavailable) once per shift; requesting one from the incident panel
  shows its status and travel time up front, commits it for a simulated
  task duration, and automatically frees it back to available afterwards.
- **Neighbourhood team (spec section 10).** 3 PCSOs, modelled separately
  from the response team with their own states (available/community
  engagement/proactive task/existing task/unavailable). On duty
  07:00-21:00 only -- forced off duty outside that window regardless of
  what they were doing, which matters since the game's one shift runs
  17:00-05:00 and mostly falls outside it. Tasked to a specific incident
  for intelligence gathering from the incident panel, or to general
  district community engagement/reassurance from a new roster panel
  (HUD's "Neighbourhood" button) -- engagement gently raises police
  visibility and community confidence in that district for as long as
  they're tasked.

Verified against the real engine: forced a specialist to NEARBY and
confirmed a request returns the correct ETA and commits it, forced
another to UNAVAILABLE and confirmed a request is rejected; tasked a
neighbourhood officer to an incident and confirmed it reaches AVAILABLE
again and reveals a fact once the task duration elapses, and confirmed
every officer is forced UNAVAILABLE once the clock passes 21:00.

- **Supervision (spec section 9).** Sergeants existed only as an officer
  rank with no mechanical effect anywhere -- fixed. `IncidentOutcomeEngine
  .needs_supervisor()` flags an incident as wanting a sergeant's attention
  once it's escalated, DEVELOPING, or crewed by an inexperienced officer
  (spec's exact conditions); the incident panel surfaces this ("Supervisor
  recommended" / "A sergeant is supervising this incident") and tags
  sergeant-crewed units in both the assigned and available-units lists so
  the player can act on it without opening each unit individually. A
  sergeant's presence on a incident that needs one now measurably shifts
  outcome resolution (folded into the same skill-competence term
  `IncidentOutcomeEngine` already uses for officer skill/fatigue, not a
  separate flat multiplier, since a uniform scaling of every outcome's
  weight has no effect once the roll normalises by the total). Verified
  against the real engine: `needs_supervisor` confirmed false before and
  true after forcing an escalation, and `has_supervisor` confirmed once a
  sergeant-crewed unit is dispatched.

- **Audio (spec section 55).** Minimal by design, per spec: two short
  synthesized tones (no licensed/recorded assets, no voice acting, no
  radio dialogue) -- an incident alert on every new incident, and a
  softer notification tone on incident resolution, fatigue warnings,
  specialist requests being accepted, and neighbourhood tasks completing.
  Ambient town noise and vehicle sound are explicitly optional in the
  spec and were skipped to keep this genuinely minimal. Verified against
  the real engine: every trigger signal fires `AudioStreamPlayer.play()`
  without error.

- **Visual polish pass toward the SimCity-style target.** Still no art
  assets -- everything below is code-drawn primitives, but arranged to
  read as a landscape rather than schematic shapes on void black: a
  ground backdrop sized to the map's real bounding box; each district
  tinted by land use (warm tan town centre, green-brown residential,
  cool blue-grey industrial, richer green farmland) with a thin zone
  outline instead of one flat uniform tint; roads drawn as a dark base
  stroke plus a lighter centreline instead of one flat grey band; and
  every decorative building given a land-use-matched wall colour plus a
  smaller offset darker rect that reads as a pitched-roof shadow -- a
  cheap pseudo-3D cue toward the isometric/angled presentation target.
  Map overlays (spec section 41) still work on top of the new per-district
  base colours. Verified against the real engine at both the full-town
  zoom and a close-up, and with an overlay active.

- **Weather (spec section 34).** Clear or rain, rolled once per shift
  (30% rain) -- deliberately shallow per spec's "do not build detailed
  weather simulation." Rain suppresses ASB's rate (people don't loiter
  outdoors in the wet) via a new per-type `rain_multiplier` on
  `IncidentTypeDefinition`, and slows unit travel ~15% (a stand-in for
  wet-road congestion, spec's "traffic" influence, without simulating
  actual traffic). A subtle screen tint plus the HUD's time readout
  ("-- RAIN"/"-- CLEAR") cover the visual half. Verified against the real
  engine: tint alpha and HUD text confirmed correct in both states, and
  the ASB multiplier confirmed wired through.
- **Secondary incidents -- controlled chain (spec section 31).** The
  spec's literal example ("football match -> ... -> police resources
  committed -> reduced town-centre coverage -> shoplifting opportunity")
  implemented as a scripted chain on the football match event: while the
  event is active and town-wide available units drop to the coverage
  threshold, `EventManager` rolls a chance to spawn one `shoplifting`
  incident, capped at one per event activation so it stays a controlled
  chain rather than a spam generator (spec: "does NOT need to be fully
  emergent... use controlled chains"). The spawned incident carries a
  known fact explaining why it appeared. Verified against the real
  engine: forced thin coverage during the event window and confirmed the
  chain fires and the incident carries the expected cause note.

Every system in this section was verified against the real engine the
same way as the milestones above -- fresh screenshots and printed state
checks each time, not shipped on the strength of the code reading right.
Along the way, fixing weather's HUD readout surfaced a real (if minor)
pre-existing layout issue -- the top stat bar could crowd the speed
controls at default viewport width -- fixed by tightening the row's
spacing and font size rather than just moving the new label elsewhere.

Not built: real art assets. Everything drawn above is still flat-colour
primitives, just arranged more deliberately toward the spec's
"SimCity-style" target (section 2) than the original placeholder shapes
were. One open item from real playtesting rather than more guessing: the
full-town incident rate hasn't been tuned against actual play sessions
yet, just confirmed to be back in a sane order of magnitude after the
baseline-weighting fix above.

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
structure, and section 9 for the original phased plan -- Milestones 1-6,
Phase 8 polish, and every system that plan explicitly deferred are all
now complete; what remains is real art assets and incident-rate tuning
against actual playtesting, both noted above.
