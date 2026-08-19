# Westford — Police Command Simulator

A police command/management simulation game. The player is a UK police
Inspector commanding a frontline response team through 10–12 hour shifts —
briefing, allocating scarce resources, responding to incidents, and managing
the consequences, in a fictional town called Westford.

This is a separate project from `predictor` (the KYG/Pundit sports app) —
different codebase, different engine, different backend. Nothing here shares
a repo, branch, or Supabase project with that app.

## Play it in a browser

**https://hatters320.github.io/Police-Game/** (live once GitHub Pages is
switched on for this repo -- see below, it isn't automatic).

Note the capitalisation: the repo is named `Police-Game`, and GitHub Pages
project-site URLs are case-sensitive -- the lowercase
`hatters320.github.io/police-game/` hard-404s even though `git clone`/`git
push` against the lowercase remote URL still work fine (GitHub redirects
git operations by hostname, but not static Pages hosting). If you land on
a 404, or your phone seems to be showing an old version of the game after
an update, check you're on the correctly-cased URL above and try a hard
refresh -- browsers cache the 39MB `.wasm`/`.pck` aggressively and this
export doesn't cache-bust them.

The `gh-pages` branch holds a built Web export of the game (Godot's
Compatibility renderer, no-threads variant so it needs no special server
headers) -- verified working end-to-end in a real headless Chromium
browser: boots with no console errors, the full briefing screen renders
and scrolls, CONFIRM SHIFT PLAN works, and the live map/HUD/simulation
clock runs correctly. A phone held in portrait gets a "rotate your
device" prompt rather than a broken, overflowing layout -- the Web
export can't lock device orientation the way a native build can, and
this game's UI is built for landscape (spec section 3/56).

Tuned against real playtesting on an actual phone: the default camera
view starts zoomed in on the player's own station rather than the whole
six-district town, HUD/panel text and buttons are sized to stay legible
and tappable on a small screen, and the map supports drag-to-pan (mouse
or one-finger touch) and pinch-to-zoom (two-finger touch, plus the
existing scroll-wheel/on-screen +/- buttons) so the whole town is
reachable from any starting position -- verified against the real engine
by injecting drag and pinch input events and confirming the camera's
position and zoom change correctly, and that a plain tap still opens an
incident/unit panel instead of being swallowed as a drag.

That round of fixes still looked wrong on a real phone, though: text stayed
small, panning flew off-screen, and pinch barely worked. Root cause turned
out to be two separate Godot Web export defaults, not the gesture code
itself. `project.godot` had no `display/window/stretch` settings, so the
canvas rendered 1:1 into the browser's raw devicePixelRatio-scaled pixel
buffer -- on a real phone (DPR 2-3) every font size and touch-event delta
was reported in that inflated pixel space, making text look 2-3x smaller
and drag panning 2-3x too fast. Separately, Godot's Web export emulates
mouse events from touch by default, so a single finger drag fired both a
real touch-drag event and a synthetic mouse-drag event for the same
physical movement, double-applying every pan and fighting with pinch.
Fixed with `window/stretch/mode="canvas_items"` + `aspect="expand"` and a
small mobile-sized base viewport (640x360) in `project.godot`, plus
`Input.set_emulate_mouse_from_touch(false)` in `main.gd`. Verified this
time with real multi-touch input dispatched through Chromium's DevTools
protocol against a phone-realistic browser context (844x390, device pixel
ratio 3, touch-enabled) -- not just synthetic in-engine event calls -- and
confirmed text renders proportionally large, a one-finger drag pans by
roughly the same distance the finger moved, and a real two-finger spread
gesture zooms in cleanly.

Real playtesting kept reporting incidents were impossible to tap, even
after several rounds of fixes that verified clean in testing -- the same
complaint, worded almost identically, after three substantive, verified
code changes in a row. That pattern -- a fix that's genuinely shipped and
tested producing zero change in a user's reported symptom -- pointed at
the fixes never actually reaching the browser, not at the fixes being
wrong, and that's what it was: GitHub Pages serves `index.pck`/
`index.wasm` with `Cache-Control: max-age=600`, and every deploy reused
the same filename, so a browser that had already loaded the page simply
kept its 10-minute-old cached copy on every reload within that window --
this had already happened once before, with a stale copy from before the
repo's `Police-Game` rename. Fixed for good with
`tools/cachebust_web_export.py`, which renames `index.pck` to a content
hash of its own bytes and points Godot's Web loader at the new name via
its `mainPack` config override -- a genuinely new URL on every deploy
that actually changed, which no cache lifetime can serve stale. Verified
against the real engine: the renamed pck loads and runs correctly
end-to-end (zero console errors, full briefing screen renders) via that
override.

That still left two real, independent bugs once a genuinely fresh build
was confirmed reaching the browser, neither related to any mobile-sizing
work: MapView's tap-hit-test radius was a flat 40 *world-space* units,
which is zoom-dependent in screen terms -- at the default 0.18x zoom
that was only ~7-8 real screen pixels, shrinking further the more a
player zoomed out to see multiple stacked-up incidents at once, which is
exactly when they most needed a forgiving tap target. Replaced with a
radius derived from a real 44-screen-pixel target divided by the current
zoom, so the actual on-screen hit area stays constant regardless of zoom
level, plus closest-marker-wins selection since the now-larger radius at
low zoom can let a unit and incident marker both qualify. Separately, the
event feed capped at 4 entries with no way to scroll, so once several
incidents existed the older ones were simply deleted with nothing to
scroll back to -- now a real `ScrollContainer` holding the last 20
entries, with every incident-related line directly tappable to open that
incident's panel, giving a second, more reliable way to reach an incident
than finding its marker on a busy map at all. Verified against the real
engine: a tap 30 screen pixels off a marker's centre at near-minimum zoom
now still selects it (the old flat-radius code would have missed
entirely at that zoom), and tapping a feed entry opens the correct
incident's panel.

A real player mockup asked for a permanent 3-column desktop layout --
incidents always visible full-length on the right, a resources roster
always visible on the left, a radio log always visible along the bottom.
Confirmed with the player that a permanently-docked 3-column layout
doesn't fit a phone screen alongside a usable map, so this shipped as an
open-on-demand, mobile-adapted equivalent instead: two new HUD buttons
(`Resources`, `Incidents`) open `ResourcesPanelView`/
`IncidentsListPanelView`, reusing the same scrollable side-panel scaffold
every other panel this session already uses, extended with a
`_panel_anchor()` override so `ResourcesPanelView` docks left instead of
the existing default right. Tapping any unit/incident row pans the map
camera to it and opens that entry's existing detail panel (spec: selecting
an entry "should take the map to the location"); closing
`IncidentsListPanelView`'s detail view returns to the list rather than
requiring it to be reopened. All five panels (incident/unit/neighbourhood/
resources/incidents-list) are mutually exclusive via one
`MapView.close_other_panels()` helper now used by every panel-opening path.
The mockup's police station illustration is now the real station marker on
the map too -- its checkerboard placeholder background removed via a
from-scratch connected-component flood fill (no matting tool was
available) and cut in as a `Sprite2D` at a tuned in-world scale.

Adding two more HUD buttons pushed the overlay row's real content width to
709px against the 640px design canvas -- a genuine overflow, caught by
measuring `HBoxContainer` content width against the canvas in a headless
run rather than assuming it fit. Fixed by splitting the "open a panel"
buttons (`Neighbourhood`/`Resources`/`Incidents`) onto their own row below
the map-filter toggle row, each row re-measured afterward at 404px/297px --
comfortably clear. Building the new panels also surfaced a real, unrelated
bug: four of `MapView`'s reactive signal connections (incident
created/state-changed/resolved, tick-completed) had ended up inside
`pan_camera_to()` instead of `setup()`, so incident markers would never
have spawned or refreshed on the map until a player happened to open a
list panel and tap a row at least once -- moved to `setup()`, where
they run exactly once per game.

The mockup's other ask -- radio communication from the control room to
units on the ground -- reuses the existing event feed's on-screen
footprint rather than adding a fourth always-on panel, styled as actual
radio traffic: `CONTROL to all units: new call, P5 shoplifting, ...` on a
new incident, `CONTROL to <callsign>: proceed to <location> for ...` the
moment a unit is dispatched, and `<callsign> to Control: on scene, ...`
the moment they arrive, colour-coded control-room-white vs unit-green.
The dispatch line needed one small backend fix: `Commands.
assign_unit_to_incident` changes an incident's state directly rather than
through `IncidentManager`'s own tick loop, so it was the one state
transition that never emitted `incident_state_changed` at all -- now it
does, matching every other transition. Verified against the real engine:
opening each new panel lists every real unit/incident, tapping a row pans
the camera and opens the correct detail panel with the other panel closed,
and dispatching + a unit arriving produces the expected two radio lines
in the feed.

The player then compared the open-on-demand version above against their
mockup directly and said it wasn't close enough -- same position, sized
for a phone, was the actual ask, not a collapsed-by-default toggle.
Reworked to match: `ResourcesPanelView`/`IncidentsListPanelView` now open
automatically the moment a shift starts and stay docked, narrowed from
360px to a 180px strip (`_panel_width()`, a new `SidePanelView` override
alongside the existing anchor/height ones) so the map remains visible
between them. Since they no longer close, `MapView.close_other_panels()`
now only arbitrates the three detail overlays (Incident/Unit/
Neighbourhood) -- those draw on a higher `CanvasLayer` (`_panel_layer()`,
another new override) so opening one visibly sits on top of the docked
panels instead of hiding them. Restyled both with the mockup's visual
language as closely as static vector drawing allows without real icon
art: a dark header bar per panel, and a colour-accented card per row
(`SidePanelView.add_card()`) -- green/amber/red/blue by unit status,
priority colour by incident, in place of plain text lines. The event feed
got the same treatment: a bordered, titled "COMMUNICATIONS" box, resized
and repositioned into the gap between the two docked panels rather than
spanning underneath them. The `Resources`/`Incidents` HUD buttons still
exist, now as an off/on toggle for a player who wants to reclaim map space
rather than an open trigger. Docking them permanently also meant they
had to become genuinely live, which opening-on-demand had made a non-issue
(every open() call refreshed automatically) -- both now also refresh on
the same incident signals as the map, plus `tick_completed`, plus (for
Resources) `UnitPanelView.closed`, so a new incident, a dispatch, or a
break/recall are all reflected without needing to close and reopen.
Verified against the real engine: both panels are open immediately after
briefing confirmation, a detail panel drawing over them doesn't close
them, and reopens/refreshes correctly once closed again.

This does trade away map real estate a permanent phone layout can't avoid
losing somewhere -- the visible map area between the two docked panels
and above the comms box is meaningfully smaller than before. The
`Resources`/`Incidents` toggle buttons are the escape valve: either can be
hidden to get that space back without losing the other.

A real player screenshot at actual device width showed why that tradeoff
was worse than it needed to be: the previous 4-row HUD (stats, speed
controls, 6 overlay toggles, 3 panel toggles), each row built from 40-52px
buttons at the project's 22px default font, was consuming most of the
screen on its own, before the docked panels even entered into it --
"the sizes of all the menus and panel boxes needs to be reduced... top
menu should be long and thin along the top... side panels should be
thinner and stretch from bottom to top". Reworked around that shape
directly: the top HUD collapsed from 4 rows to 2 -- one stats line, one
control line holding Pause/1x/2x/4x/zoom, the neighbourhood/resources/
incidents toggles, and the 6 overlay filters folded into a single
`OptionButton` dropdown (`HudView.wire_overlays()`) rather than 6 separate
buttons, which was most of what let the row collapse at all. Every control
shrank with it: button height 42px -> 22px, font 15-22px -> 10-12px
throughout the HUD and both docked panels (`SidePanelView.add_card()`/
`add_header_bar()`). The comms feed moved from a boxed panel wedged into
the centre gap to a genuinely thin strip spanning the full width along
the very bottom, mirroring the thin top bar -- still a real vertical
`ScrollContainer`, not a single-line ticker, since a real user's fix
earlier this session was specifically about not losing feed scroll-back
history, and a single line would have undone that. `ResourcesPanelView`/
`IncidentsListPanelView` now genuinely stretch the full height between the
new thin top bar and thin bottom bar (`SidePanelView.PANEL_TOP_Y`, derived
directly from `HudView.HUD_BOTTOM` so the two can't drift apart) rather
than stopping partway down. Net
effect: roughly twice as much of a real unit/incident list is visible at
once without scrolling, and the map's visible centre strip is
meaningfully larger despite the side panels staying permanently docked.
Verified against the real engine: every control row's real content width
measures well under the 640px design canvas, both docked panels still
open by default and stay live, and a detail panel still layers correctly
above them at the new geometry.

A further round of the same player feedback, against the live rebuild:
the docked panels' text still only filled about half their width (narrowed
180px -> 110px, `ResourcesPanelView`/`IncidentsListPanelView._panel_width()`),
the comms bar needed a bit more side padding and height and to keep the
newest line on screen rather than requiring a manual scroll down
(`HudView._scroll_feed_to_bottom()`, deferred so it applies after the new
line's layout settles, called after every `_append_feed()` -- still a real
scroll position, not a lock, so scrolling back through history still
works), and the incident detail popup specifically was "way too big" --
the one panel whose own content, as opposed to the shared `SidePanelView`
helpers every other panel already used, had never been touched: every ad-
hoc `Label`/`Button` inside `IncidentPanelView` (and, for consistency,
`UnitPanelView`/`NeighbourhoodPanelView`) was still sized against the
project's 22px default font and 48-52px buttons. Shrunk throughout (11-
13px font, 30-32px buttons) plus a dedicated, smaller `_panel_width()`/
`_panel_height()` override (220x190, down from the shared detail-panel
default of 240x200) so it now reads as overlaying the incident it's
attached to rather than dominating the screen. `SidePanelView.add_line()`/
`add_dim_line()` had the same 22px-default gap -- every panel using them
(most of them) picked up the fix too.

Two small pieces of real dispatch guidance went in alongside the shrink,
since a smaller panel makes "which unit do I actually send" a more
pointed question, not a less important one: `IncidentPanelView`'s SEND A
UNIT list now tags whichever available unit is geographically closest to
the incident (straight-line distance to the location -- a real pathfind
per unit wasn't worth it just to rank a hint) as "(nearest)", and REQUEST
SPECIALIST tags whichever of Traffic/Dog/Firearms actually suits the
incident type as "(fits this incident)", driven by a new
`IncidentTypeDefinition.recommended_specialist` data field (spec section
59: a new fact about an incident type is data, not code) set for burglary
(Dog -- tracking a suspect who's fled) and assault (Firearms -- officer
safety). `ResourcesPanelView`'s travelling status also now reads "en route
to incident" instead of the terser "travelling", which was already
refreshing live on dispatch (from the `incident_state_changed` fix
earlier in this pass) but wasn't saying so as plainly as the player asked
for.

Two of the player's next round of feedback traced back to the same root
cause: the comms feed was wrapping every message into a stack of tiny
few-word fragments instead of reading as one line, and the incidents list
had grown a pointless horizontal scrollbar. Both come from Godot's
`ScrollContainer` defaulting to horizontal scroll *enabled* -- which lets
its child size itself down to its own content-minimum width instead of
filling the container, and an autowrap-enabled `Label`/`Button` reports a
near-zero minimum since it can wrap to any width, so the child collapsed
to a sliver and everything inside it wrapped accordingly. Disabled
(`horizontal_scroll_mode = SCROLL_MODE_DISABLED`) on both `SidePanelView`'s
shared scroll and the comms bar's, which forces the content column to
actually fill the panel's real width -- confirmed against the real engine
that a full dispatch message now renders as one line in the comms bar with
no stray scrollbar anywhere.

The rest of that round, all in `IncidentsListPanelView`: sorted newest-
first by `created_at_minute` instead of by priority (priority is still
visible per-row via the accent colour/text); a dispatched incident
(`assigned_unit_ids` non-empty) now gets a distinct blue accent instead of
its priority colour, so "in hand" and "needs a decision" read apart at a
glance; and a real timing bug meant a just-resolved incident didn't
disappear immediately -- `IncidentManager.incident_resolved` fires *before*
`active_incidents.erase()` actually runs (a few lines later, in a separate
cleanup pass), so a naive refresh right off that signal still saw it in
the dict. Fixed by filtering to `incident.is_open()` in `refresh()`
instead of trusting the dict's timing.

The comms feed itself got a full wording pass to match a player-supplied
example ("Dispatcher: ...", "Unit 1: ..."), replacing the previous
"CONTROL to Unit 1: proceed to..." radio-procedure phrasing with plainer
dispatcher/unit dialogue, and a unit now acknowledges a dispatch
("Copy, I'm en route.") as its own line rather than only speaking once, on
arrival.

**One-time setup to make the link live** (repo owner only, ~30 seconds):
1. Go to the repo's **Settings -> Pages**.
2. Under "Build and deployment" -> "Source", choose **Deploy from a
   branch**.
3. Under "Branch", choose **gh-pages** and folder **/ (root)**, then
   **Save**.
4. Wait about a minute for the first deploy; the link above then works.

To rebuild and republish the site after making changes: export a Web
build (`godot4 --headless --export-release "Web" build/web/index.html`,
using the `export_presets.cfg` described in `tests/README.md` since that
file isn't committed), run `python3 tools/cachebust_web_export.py
build/web` (renames `index.pck` to a content-hashed filename and patches
`index.html` to match -- see that script's header for why this step
isn't optional: GitHub Pages caches these files for 10 minutes, and
without a hashed filename a browser that already loaded the page simply
won't see a new build until that cache expires), then replace the
contents of the `gh-pages` branch with the new `build/web/` output and
push.

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

- **Location markers by land use, plus a river.** Every gameplay location
  used to render as the same grey dot regardless of what it was --
  replaced with a per-tag look (`MapView.LOCATION_STYLES`): a red/white
  cross for the hospital, a wide green oval for the football stadium, a
  small house glyph for residential streets, distinct colours for shops/
  pubs/community centres/schools/industrial units/car parks, and parks
  rendered as a loose cluster of green tree-canopy dots instead of a
  building-shaped marker. The police station and fire station (both
  tagged "station") are told apart by checking which one is actually
  `WorldMapData.police_station_location_id`. A purely decorative river
  now runs between South Residential and Rural/Outskirts, tying into the
  "Riverside Walk"/"Riverside Gardens" location names already in
  `WestfordMapFactory` -- computed from those two districts' real
  centroids so it lines up with actual geometry rather than guessed
  coordinates, and skipped entirely on maps that don't have both
  districts (e.g. the small test map). Verified against the real engine
  with screenshots of Town Centre, Northside, and the river/rural area.

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

**Incident-rate tuning, validated against real automated play.** Built a
temporary multi-shift playtest harness (real full Westford town, the same
trivial auto-dispatch stand-in `run_shift_debug.gd` uses, 3 different
seeds x 4 shifts, plus one 10-consecutive-shift run to check for slow
drift) rather than tuning from a single shift's numbers. First pass
surfaced what looked like a serious bug: the backlog of still-open
incidents grew without bound shift over shift (2 -> 52 -> 100 -> 146).
Root cause turned out to be in the *harness*, not the game -- it was
reusing the same `Officer` objects across shifts instead of rebuilding a
fresh roster each shift the way `main.gd` actually does, so officers
carried over an `ON_UNIT` status that starved the crew count on every
shift after the first. Fixed the harness to match real gameplay and
reran: still-open incidents stay bounded (1-5) across all 10 consecutive
shifts with no drift, average unit utilisation sits around 35-40%
(healthy headroom for a real player who won't dispatch as instantly or
perfectly as the bot), incident volume is steady at ~46-49 per 12h shift
across all 6 districts fairly evenly, and priority distribution stays
mostly routine/non-urgent with rare P3s and no P1/P2s in ~120 simulated
hours -- consistent with spec section 7's "do not begin with extreme
crime... major incidents should be rare." No incident-rate code changes
were needed; the earlier baseline-weighting fix already had this right,
and this confirms it holds up at full-town scale under sustained play.

Not built: real art assets. Everything drawn above is still flat-colour
primitives, just arranged more deliberately toward the spec's
"SimCity-style" target (section 2) than the original placeholder shapes
were.

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
