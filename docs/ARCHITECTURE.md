# Westford — Technical Architecture Analysis

Written against `docs/SPEC.md` v0.1, before any game code exists. Godot
4.x (latest stable), GDScript. This is analysis and a plan, not an
implementation — no `.gd`/`.tscn` files are created by this document.

---

## 1–2. Architecture review: contradictions, risks, unnecessary complexity

**The SIMULATION → WORLD → PRESENTATION diagram (spec §3) is drawn as a
pipeline but isn't one.** WORLD (roads/buildings/districts/locations) is
mostly static authored data that *both* SIMULATION and PRESENTATION read
from — it doesn't sit "between" them. Districts also appear twice in the
spec: as a SIMULATION manager (`DistrictManager`, dynamic ASB/tension/etc.)
and as a WORLD entity (geography). Resolution: split every district into a
**static `DistrictDefinition`** (id, boundary, contained locations,
neighbours) and a **dynamic `DistrictState`** (the 0–100 variables),
correlated by id. WorldData becomes a shared read-only resource layer, not
a pipeline stage. See §3 below.

**Godot `Resource` objects are shared-by-reference by default** — a classic
footgun. If district/officer/incident *definitions* are authored as
`.tres` Resources (correct, per spec §59's data-driven design), and a
runtime instance is created by holding a reference to that same Resource
instead of copying values out of it, two districts can end up silently
sharing one object. Rule: **Resources are for static definitions only.**
Runtime mutable state (`DistrictState`, `Officer`, `PoliceUnit`, `Incident`)
must be plain `RefCounted` classes constructed fresh per instance, never
`Resource` subclasses.

**Simplifications the spec already permits but is worth being explicit
about, to avoid over-building the MVP:**
- §28 "pathfinding should use a navigation system" — Godot's
  `NavigationServer2D`/navmesh is built for freeform walkable-area agents.
  Vehicles here are constrained to a small, fixed road graph. `AStar2D`
  over that graph is the correct-sized tool and far cheaper to build and
  reason about; NavigationServer2D would be solving a harder problem than
  the one that exists.
- §41 overlays: implement as simple per-district colour tinting keyed to
  the district's variable value, not a generated heatmap texture.
- §36 zoom levels: a single `Camera2D` with a zoom range is sufficient;
  no separate LOD scenes per zoom tier for the MVP.
- §34 weather: a single value chosen at shift start (rarely changes mid
  shift), not a simulated weather system with transitions.
- §31 secondary incidents: explicit scripted trigger rules on
  `EventDefinition`/`IncidentTypeDefinition` (data-driven), not a general
  causality graph engine.

**Genuine ambiguity worth flagging (architecture-affecting):** §47 says the
town must "remember" between shifts, and gives district-variable drift as
the example. It doesn't say whether an incident that's still active when
the shift clock runs out literally continues as a live `Incident` object
into the next shift, or is administratively closed out and only its
*effect* (a bump to `incident_pressure`/district variables) persists.
**Default I'm building to:** incidents do not survive across the shift
boundary as live objects — every open incident is closed out at shift-end
with a "carried over" outcome that feeds district state, and the next
shift starts with a clean incident list. This keeps `Incident` lifecycle
and the save-file schema far simpler, and still satisfies "the town
remembers" via district state. Flag if you want literal incident
continuity instead — it's a bigger change (save format, `ShiftManager`,
debrief logic) so better to settle it now than mid-build.

---

## 3. Godot project architecture

```
res://
  autoload/
    Simulation.gd            <- single autoload, owns all managers + tick loop
  data/                       <- authored .tres Resource definitions
    world/                    <- WorldMapData, DistrictDefinition, LocationDefinition, RoadNode/RoadEdge
    incidents/                <- IncidentTypeDefinition x N
    events/                   <- EventDefinition x N
  scripts/
    simulation/               <- RefCounted runtime classes + manager logic (zero Node/scene deps)
      game_clock.gd
      shift_manager.gd
      district_manager.gd
      officer_manager.gd
      resource_manager.gd     <- crew formation (officers -> deployable units)
      incident_manager.gd
      incident_state_machine.gd
      event_manager.gd
      intelligence_manager.gd
      fatigue_manager.gd
      community_manager.gd
      commands.gd              <- validated command entry points
      debug_commands.gd
    world/
      world_map_data.gd        <- Resource: districts, locations, road graph
      district_definition.gd
      location_definition.gd
      road_graph.gd            <- builds/owns the AStar2D
    runtime/                   <- RefCounted mutable state, never Resource
      district_state.gd
      officer.gd
      police_unit.gd
      incident.gd
      shift_state.gd
    incidents/
      incident_type_definition.gd
      incident_probability_engine.gd
      incident_outcome_engine.gd
    ui/
      briefing_ui.gd / .tscn
      incident_panel.gd / .tscn
      event_feed.gd / .tscn
      debrief_ui.gd / .tscn
      hud.gd / .tscn
  scenes/
    main/main.tscn
    map/map.tscn, police_unit_view.tscn, incident_marker.tscn
    ui/ (scenes matching scripts/ui above)
  tests/
```

**Why one autoload, not many.** A single `Simulation` autoload (a `Node`)
owns instances of every manager as plain fields — the managers themselves
are `RefCounted`, not autoloads, not Nodes. This avoids autoload-ordering
issues and keeps every manager constructible and testable in isolation
(`ShiftManagerTest.new(...)` with no scene tree at all) while still giving
Presentation one well-known place (`Simulation`) to reach the whole
simulation from.

**WorldData resolves the §3 diagram issue.** `WorldMapData` is a `Resource`
loaded once at boot (`.tres`), holding `DistrictDefinition[]`,
`LocationDefinition[]`, and the road graph's raw node/edge data. Both
`Simulation` (for district ids, pathfinding, location lookups) and the
`Map` scene (for drawing) hold a reference to the same loaded instance.
It's read-only at runtime — the debug tool that "changes district values"
(spec §65) mutates the *runtime* `DistrictState`, never `WorldMapData`.

**Scene-to-simulation boundary.** `PoliceUnit`, `Incident`, `Officer` etc.
are plain data objects with no Node presence. `PoliceUnitView` (a
`Node2D` scene) is spawned by the Map only for units currently worth
drawing (all of them, at this scale — no pooling needed for ~6 units) and
reads the unit's state each frame; it never owns or mutates simulation
state itself.

---

## 4. Core data structures

Two families, deliberately kept distinct per the Resource-sharing risk
above:

**Definitions — `Resource` subclasses, authored as `.tres`, static:**
- `DistrictDefinition`: id, display_name, boundary polygon, location_ids,
  neighbour_district_ids, baseline crime-rate weights.
- `LocationDefinition`: id, display_name, district_id, position,
  nearest_road_node_id, tags (e.g. `night_economy`, `retail`, `residential`).
- `RoadNode` / `RoadEdge`: id/position and from/to/length for the AStar2D graph.
- `IncidentTypeDefinition`: id, display_name, priority-input weights,
  probability weight table (keyed by district variable / time-of-day /
  event flags), possible outcomes with base weights and modifiers,
  escalation rule thresholds, known/unknown fact templates.
- `EventDefinition`: id, schedule, duration, district(s) affected, the
  modifiers it applies to district variables and incident probability
  while active.

**Runtime state — `RefCounted` subclasses, mutable, one instance per
entity, never shared:**
- `DistrictState`: the twelve 0–100 variables from spec §6 +
  `community_confidence`, keyed by district id.
- `Officer`: id, name, rank, experience (enum Low/Med/High),
  driver_qualified: bool, skills (Dictionary of the six spec §13 skills →
  Low/Med/High), fatigue: float, morale: float, status (enum), current
  unit id.
- `PoliceUnit`: id, callsign, officer_ids (1–2), status (enum per spec
  §36), current path (`PackedVector2Array` + progress float), destination,
  current incident id, command intent.
- `Incident`: id, type id, district id, location, priority (1–5), threat/
  harm/vulnerability/immediacy/opportunity floats, state (enum per §22),
  `escalation_level: int` (see below), known/unknown fact lists, assigned
  unit ids, command intent, timestamps, outcome id once resolved.
- `ShiftState`: current time, shift start/end, priorities (≤3), speed
  multiplier, paused, reserve target.

**Resolving §22/§29's ESCALATED ambiguity:** modelling escalation as a
literal state node doesn't work cleanly since an incident can escalate
from several different base states without changing what it's
fundamentally waiting on. Instead `Incident.state` stays a single linear
enum (`CREATED → … → RESOLVED → OUTCOME`), and `escalation_level: int`
(0, 1, 2…) is an orthogonal counter that `IncidentManager` increments per
the type's escalation rules, feeding back into priority/threat/harm and
into the outcome roll. `incident_escalated` still fires as a distinct
signal each time the counter increments, so the player-facing behaviour
spec §29 asks for ("notify when it materially changes") is unaffected.

---

## 5. Simulation ↔ UI/Map communication

Strict one-directional data flow, enforced by convention (not by the
engine, so this is a discipline point for whoever writes the code, myself
included):

- **Simulation → Presentation: signals, pushed on meaningful change only.**
  `incident_created`, `incident_state_changed`, `incident_escalated`,
  `incident_resolved`, `unit_status_changed`, `district_state_changed`
  (coalesced — fired when a variable crosses a meaningful band, not every
  tick it drifts), `officer_fatigue_warning`, `community_confidence_changed`,
  `shift_briefing_ready`, `shift_started`, `shift_ended`.
- **High-frequency data (unit position) is pulled, not pushed.** Emitting a
  signal every tick per moving unit is wasteful. Instead `Simulation`
  exposes `get_unit_render_state(unit_id) -> {position, heading}` and the
  fixed-tick loop keeps last-tick/next-tick positions so
  `PoliceUnitView._process(delta)` can interpolate smoothly between
  discrete sim ticks on its own, independent of tick rate. Standard
  fixed-update-plus-render-interpolation pattern.
- **Presentation → Simulation: validated commands, never direct state
  writes.** `Simulation.commands.assign_unit_to_incident(unit_id,
  incident_id)`, `set_command_intent(...)`, `request_information(...)`,
  `set_patrol_tasking(...)`, `set_reserve(...)`, `send_for_break(...)`,
  `set_speed(...)`, plus a separate `debug_commands` object for §65's
  tools. Every command returns an explicit result (`OK` or
  `REJECTED(reason)`) — nothing silently no-ops.
- **Spec §27 requires showing consequences before confirming a
  reassignment.** That needs a preview step, not just a command:
  `Simulation.commands.preview_reassign(unit_id, target) ->
  ReassignmentPreview` (what's lost, what's gained) computed without
  mutating anything, then a separate `confirm_reassign(...)` applies it.
  Same two-phase shape works for any other "show me what happens first"
  interaction the UI needs later.

This keeps Presentation code with zero simulation logic in it (it only
ever renders what a signal or getter told it, and only ever asks to
change something via a command) — which is also what makes the whole
simulation layer runnable and testable headlessly, per spec §66.

---

## 6. Incident state machine

Table-driven, one shared driver class, not a subclass per incident type
(per spec §59's data-driven principle — new incident types should mean new
`.tres` data, not new code).

- `IncidentStateMachine` (owned by each `Incident`) exposes `advance(dt)`,
  `can_transition_to(state)`, `transition_to(state)`. State *durations*
  and any type-specific overrides live on `IncidentTypeDefinition`, not in
  the driver.
- `IncidentManager` is the single place that calls `advance(dt)` on every
  active incident each tick, and the single emitter of
  `incident_state_changed` — Presentation connects once, not per-incident.
- **Escalation** is evaluated by `IncidentManager` each tick for incidents
  in ASSIGNED/TRAVELLING/ON_SCENE/DEVELOPING, as a function of the type's
  escalation rules against: time unassigned, response delay vs. priority,
  resource-type mismatch, and district tension. On trigger it bumps
  `escalation_level` and emits `incident_escalated` (see §4 above for why
  this isn't a literal graph state).
- **Outcome resolution** happens on entering RESOLVED: a weighted pick from
  `IncidentTypeDefinition.possible_outcomes`, with weights adjusted by
  assigned-officer skill average, response time, officer fatigue, chosen
  command intent, and district conditions — one documented formula, one
  function (`incident_outcome_engine.gd`), fed by the seeded RNG (see §9).
  This is the direct implementation of spec §48/§49: outcomes are
  influenced, not coin-flipped.
- Zero Node dependency anywhere in this path, so a test can construct an
  `Incident` + `IncidentManager`, call `advance()` in a loop, and assert on
  state transitions with no scene tree involved at all.

---

## 7. Police-unit movement and travel time

- **Road graph**: `WorldMapData` holds raw `RoadNode`/`RoadEdge` data;
  `RoadGraph` builds an `AStar2D` from it once at boot (`add_point` per
  node, `connect_points` per edge). Locations reference a
  `nearest_road_node_id` so incidents/patrol points snap onto the graph
  deterministically rather than via runtime nearest-neighbour search.
- **Path computation happens once per dispatch, not per frame**:
  `astar.get_point_path(from, to)` on assignment, cached on the
  `PoliceUnit` as a `PackedVector2Array` with precomputed cumulative
  segment lengths (for ETA math).
- **Speed and ETA**: `speed = base_unit_speed * traffic_modifier(district)
  * weather_modifier * event_congestion_modifier` — all simple multipliers
  around 1.0, recalculated once per tick (not per frame, since these
  inputs change slowly). `eta = remaining_path_length / speed`.
- **Advancing**: each tick, `PoliceUnit.advance_along_path(speed * tick_dt)`
  walks the cached polyline — O(1) amortised per unit per tick, no
  re-pathfinding.
- **Why `AStar2D` over `NavigationServer2D`**: the road network is a small
  fixed graph (tens of nodes for the prototype, well under a few hundred
  for full Westford) and vehicles are graph-constrained, not freeform
  agents — exactly `AStar2D`'s design case, and much cheaper than
  baking/querying a navmesh for a problem that isn't freeform movement.

---

## 8. Performance

At MVP scale (≤13 officers, ~6 deployable units, 6 districts, rarely more
than 5–6 concurrent incidents per spec's own demand profile), no manager
loop is ever iterating more than a few dozen items — algorithmic
complexity isn't the risk. The actual levers:

1. **Decoupled tick rate.** `Simulation._process(delta)` accumulates
   `delta * speed_multiplier` and fires fixed-size simulation ticks from
   the accumulator (classic fixed-timestep pattern) — proposed default:
   1 tick = 1 simulated minute, 1 tick per real second at 1×, so a 12-hour
   shift plays in 12 real minutes at 1× and 3 at 4×. Pause = multiplier 0.
   This bounds *all* manager work to a fixed, low rate regardless of
   device frame rate, independent of visual smoothness (handled by
   interpolation, §5/§7).
2. **Aggregate simulation only** — no per-citizen agents ever, per spec
   §64. Ambient pedestrians/traffic on the map are a purely decorative
   layer sized off a district's traffic/night-economy value with a small
   capped count, entirely decoupled from gameplay state — cheap to reduce
   or disable on low-end devices without touching simulation.
3. **Signals fire on meaningful change, not every tick** (§5) — this is
   the main discipline point, since the failure mode at this scale isn't
   "too much simulation," it's UI/map redraw work re-running every frame
   when it should only run when its underlying data actually changed
   (district overlay tinting, event feed list, HUD counters).
4. **Node count discipline** — only currently-relevant entities (deployed
   units, active incident markers) get scene nodes; no pooling needed yet
   at this scale, but the design leaves room for it later if the full
   Westford map's ambient layer needs it.
5. **Determinism**: one seeded `RandomNumberGenerator` owned by
   `Simulation`, threaded explicitly into anything that rolls randomness
   (incident generation, outcome resolution) — never bare `randi()`.
   Primarily for the reproducibility spec §64 asks for, but also makes
   performance/behaviour bugs reproducible during development.

---

## 9. Phased development plan

Spec §61/§62 already lay out the right shape — this sharpens it into
concrete milestones, each ending in something runnable, built against a
**small test map** (3 districts, ~10–15 locations, 5 units, ~5 incident
types, 1 event) before any full-Westford content is authored, per §62.

| Milestone | Scope | Exit criteria |
|---|---|---|
| **0 — Scaffold** | Repo, spec, this doc. | Done. |
| **1 — Headless sim core** (spec Phase 1+2) | `GameClock`, `ShiftManager`, `WorldMapData` (small map), `OfficerManager` + crew formation, `DistrictManager`, `IncidentManager` + state machine + ~5 incident types + probability/outcome engines, `EventManager` + 1 event, command layer, debug harness. No scenes, no rendering. | A debug script runs a full simulated 12h shift headlessly (fast-forwarded) and prints a shift log / debrief-shaped summary to console. Proves the loop end-to-end in text. |
| **2 — Minimal map + live visuals** (Phase 3) | Map scene for the small test map, `PoliceUnitView` moving along `AStar2D` paths, colour-coded incident markers, pause/1×/2×/4×, top HUD. | Milestone 1's shift is now watchable and controllable with a mouse. |
| **3 — Briefing + incident interaction** (Phase 4+5) | Pre-shift briefing (staffing/intel/priorities/patrol/reserve/events), incident panel (known/unknown, SEND/HOLD/REQUEST INFO/SET INTENT/reassign-with-preview), event feed. | All 21 items in spec §63's acceptance test are checkable on the small map. |
| **4 — Fatigue / community / intelligence** (Phase 6) | Breaks, fatigue warnings, confidence/tension effects, simple overlay tinting, intel-quality-gated overlay accuracy. | |
| **5 — Debrief + persistence** (Phase 7) | End-of-shift debrief (5 dimensions + narrative), local JSON save/load of town state, next-shift continuity. | Full MVP loop, small map, "press Start Next Shift" works. |
| **— Fun checkpoint —** | Stop. Play it. Per spec §62, this is the point that answers "is the command gameplay fun?" before any further investment. | |
| **6 — Full Westford map** | Author the real 6-district, 500–800-building, 50–100-location town per §53, swapped in as a new `WorldMapData`. Because everything through Milestone 5 was built against `WorldMapData` generically, this should be content authoring, not new systems code. | |
| **7 — Polish** (Phase 8) | Per spec, not detailed further yet. | |

**Testing approach**: recommend the GUT (Godot Unit Test) addon — it's the
de facto standard for Godot, gives assert-based syntax and headless/CI
runs, and the whole point of keeping simulation classes Node-free is to
make them trivially testable by something like this. A hand-rolled
assert runner would also work and avoids the dependency if preferred; not
a decision that changes the architecture either way, so defaulting to GUT
unless you'd rather not.

---

## Open question worth your call before Milestone 1 starts

The persistence-boundary assumption in §1–2 (incidents don't survive the
shift boundary as live objects; only their effect on district state
does) shapes `Incident` lifecycle and the save schema. I'm building to
that default. Say so if you want literal cross-shift incident continuity
instead — worth deciding now rather than mid-build.

Everything else above is either directly specified already or a minor
implementation call within spec §73's "simplest reasonable default" rule.
