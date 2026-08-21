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

The player then asked for something bigger than UI polish: several 3D
low-poly city/building/car kits (Kenney.nl, CC0) added to a shared Google
Drive, to replace the flat 2D map with a real 3D view. After confirming
Drive access to all six kits and checking with the player on how big a
change to make (a full 3D rebuild touches camera, lighting, and every 2D
marker/overlay -- confirmed explicitly before starting), the migration
kept a hard boundary: all of `WorldMapData`/`RoadGraph`/district/incident/
unit simulation logic stays completely untouched, and a new presentation-
only layer reads the same data through a `WORLD_SCALE` (0.045) conversion.
`City3DView` builds Westford once from that data: the ground as a single
`PlaneMesh`, the entire road network as one combined ribbon mesh via
`SurfaceTool` (one draw call for the whole graph, since Kenney's modular
snap-together road tiles don't fit this project's organic, non-grid-aligned
procedural road layout), named Locations as individually instanced building
GLBs (a few dozen, so per-instance overhead is fine and keeps them
tap-identifiable later), and purely decorative filler buildings batched via
`MultiMeshInstance3D` per district/variant -- hundreds of individual scene
instances would be hundreds of extra draw calls, a real cost on the mobile
Web `gl_compatibility` target that MultiMesh avoids. An early full-town
render showed a field of thin spindly slivers instead of believable
buildings; measuring actual model AABBs found the cause -- Kenney's non-
"wide" `low-detail-building-*` models are tall 0.5x2.0x0.5 towers (their
distant-LOD silhouette shape, not a close-up building), fixed by using the
full `building-a..n` set plus only the "-wide" low-detail variants
everywhere else.

`MapView`'s existing hit-testing and panel-opening logic -- `_handle_click`,
`open_incident_panel`, `_select_unit`, and every marker-lifecycle method --
turned out to need zero changes for 3D, since all of it already operated
purely on `UnitMarker`/`IncidentMarker` Node2D positions in the original 2D
world-coordinate space, never on screen pixels directly. `main.gd` replaced
its Camera2D-driven pan/pinch/tap-to-select with a `Camera3D` equivalent
instead: an orthogonal projection at a fixed downward tilt
(`MapView.CAMERA_PITCH_DEG`/`CAMERA_DISTANCE`, the single source of truth
both files share for the camera's ground-offset math) so `camera.size` maps
cleanly onto the old "zoom" concept, drag-pan moves the camera along the
ground plane with a foreshortening correction for the tilt (equal ground
distance along the view direction covers less screen space than the same
distance sideways), and a tap converts to a world position via a ray/Y=0-
plane intersection before handing off to the same unchanged
`MapView.handle_tap`. `MapView` itself is now explicitly hidden
(`visible = false`) rather than deleted -- it still owns real, ticking
marker data and every panel-opening signal connection, it just never gets a
camera to render through any more, since `City3DView` owns 100% of what's
actually on screen.

Two real bugs surfaced only once tested against an actual Web export
screenshot, not just headless script-compile checks: `City3DView` had no
light source or `WorldEnvironment` at all, so every surface received zero
light and rendered pure black, indistinguishable from the project's
near-black default clear colour; and the first camera framing guess
(`camera.size = 90`, extrapolated from the old 2D zoom's screen-pixel math
without accounting for how small Kenney's building models actually are)
shrank every building to a 2-4px dot regardless of zoom level. Both
diagnosed the same way: an extreme test value (a bright red background,
then an absurdly tight `camera.size = 2`) isolated whether code changes
were reaching the browser at all versus a genuine scale/lighting problem,
which confirmed the latter and gave real numbers to retune against --
buildings read as clearly recognisable low-poly shapes from `camera.size`
~2-3, so the shipped default (8) and zoom bounds (3-220) are picked from
that, not guessed. Verified end-to-end against a real Web export via
Playwright: briefing through CONFIRM SHIFT PLAN, drag-pan and scroll-wheel
zoom both visibly move/scale the rendered city, clicking a unit in the
docked Resources list pans the camera and opens its welfare panel, and
roughly 30 seconds of real 4x-speed play produced multiple incidents
(including a priority escalation) with zero console or page errors
throughout. Frame rate wasn't independently benchmarked beyond that: the
sandbox this was tested in has no GPU device, so Chromium falls back to
software WebGL rendering, and any FPS number measured there reflects that
fallback rather than the `gl_compatibility` renderer running on a real
device's GPU -- the draw-call-conscious choices above (one merged road
mesh, MultiMesh-batched filler buildings, a low individually-instanced
building count) are the same mobile-perf pattern this project has used
throughout, but a real numbers-based check needs an actual device.

The player's first real playtest of the 3D build reported two things: the
drag-pan felt backwards, and the town looked too sparse compared to a real
city. Both got fixed.

The pan direction bug was real and isolated to one axis: `main.gd`'s
`_pan_by_screen_delta` derives two ground-plane basis vectors from the
tilted `Camera3D`'s own transform (screen-right and screen-forward), and
the screen-right term was correct but the screen-forward term had the
wrong sign, moving the camera the opposite way along its tilt axis to
what dragging up/down should do -- sideways panning felt fine, vertical
panning felt inverted, exactly matching the report. Confirmed the exact
direction of the bug, then the fix, the same way as everything else this
session: comparing a landmark's screen position in real Web export
screenshots before and after a controlled drag in each direction, not
just re-deriving the trig by hand a second time.

The sparseness complaint led somewhere bigger than a tuning number,
though -- the player asked for Godot's own grid system, and named it
correctly: measuring Kenney's building and road tile AABBs confirmed
they're all exactly 1x1x1 units, i.e. built for snapping to a `GridMap`,
which the previous scattered-`MultiMesh` filler approach never used.
`City3DView` now carves each district into a real street lattice --
`road-straight`/`road-crossroad` tiles spaced by a per-land-use block
size (town centre tightest, rural sparsest, so the same mechanism doesn't
flatten every district to one density) -- and fills every remaining
in-polygon cell with a building, all through one shared `GridMap` (which
batches per unique mesh internally regardless of cell count, the reason
to use it over hand-rolled `MultiMesh` bucketing). Real Locations keep
their own individually instanced building for tap-identifiability, but
now snap onto the same grid and reserve their cell first so the block
fill can't double-place on top of one. The organic `RoadGraph` ribbon
mesh from the original migration stays as-is, now read as the
inter-district arterial network threading between these tighter local
grids rather than the only road visual in the scene.

A first pass at cluster sizing (town centre ~300+ buildings) looked
right but measured a real ~3x frame-time regression sampled via
`requestAnimationFrame` against a real Web export, before vs after, in
the same sandbox -- not a real-device number on its own, but a valid
relative comparison since both builds ran under the same software-WebGL
fallback. Pulled back to smaller cluster sizes that still land at several
times the old scatter version's per-district building counts without
that regression. Verified end-to-end against a real Web export:
dragging up/down now moves the camera the same direction as the
player's own device previously showed backwards, the pan/dispatch/panel
flow from the original migration still works unchanged against the new
grid town, and the town itself now reads as a real tightly-packed grid
of streets and buildings instead of scattered dots.

The player then sent a mockup of a proper SimCity-style isometric view and
asked for two things: match that camera angle, and make the districts sit
next to each other as one real town rather than the spread-out layout the
3D migration inherited from the original 2D map's own scale. `Camera3D`
now yaws 45 degrees in addition to its downward tilt (shallowed from -55
to -32 degrees to match the mockup) -- streets run diagonally across the
screen instead of a flat top-down grid. `map_view.gd`'s shared
`camera_ground_offset()` generalises to a full yaw+pitch `Basis` so
`main.gd` and `pan_camera_to` stay in lockstep regardless of rotation, the
same pattern the pitch-only version used.

The "districts are too far apart" complaint traced back to
`City3DView.WORLD_SCALE`: measuring the real district boundary polygons
(rather than guessing) showed each district's own footprint was already a
sensible size once gridded, but `WORLD_SCALE` (carried over from the
original 2D map's much larger coordinate space) put hundreds of 3D-units
of empty ground between them, even though every `DistrictDefinition`
already lists its real neighbours and genuinely borders them in the
underlying data. Dropping `WORLD_SCALE` from 0.045 to 0.01 compresses the
whole town (six districts, ~7650x9900 old-2D-units) into roughly a
76x99 3D-unit span -- small enough that adjacent districts' grids now
meet or nearly meet, reading as one continuous town. Since buildings AND
roads both convert through this one shared scale factor, shrinking it
kept everything in lockstep automatically, with no second coordinate
system needed. The district block-fill's old fixed-size "cluster window"
centred on each centroid (needed when a full-polygon fill would have
meant tens of thousands of cells at the old scale) is gone too -- at the
new scale a district's own real polygon is already an appropriately-sized
area, so the grid just fills it directly.

Retuning the camera's zoom bounds for the new scale surfaced a real
"how big does camera.size 8 actually look" surprise: building-apparent
size on screen depends only on `camera.size` and the viewport, never on
`WORLD_SCALE` (a Kenney building is always ~1 native unit regardless of
how far apart the world positions it), but *how much of a district* a
fixed `camera.size` shows very much does, since a district's own
footprint shrank along with everything else. The old default (8) that
used to show "several buildings with room to breathe" now showed under
half of a single district -- confirmed against a real Web export
screenshot, then retuned by the same method (real screenshots, not
formulas) against the actual compact town: 75 comfortably frames all six
districts at once, so `MAX_CAMERA_SIZE` is set just above that (85) --
capping zoom-out at roughly the whole town plus a small margin, replacing
an old value (220) left over from the since-shrunk, far more spread-out
town that let zooming out continue for many times longer than the town
actually needed.

Chasing what first looked like a *second* zoom bug (the default view
occasionally looked far more zoomed-in or -out than intended depending on
how the test reached the CONFIRM SHIFT PLAN button) turned up a real,
if minor, quirk: wheel/drag input meant for the briefing screen's own
`ScrollContainer` could still reach the game camera -- which already
exists at that point, just isn't visible yet -- once that Control stopped
consuming further scroll at its own top or bottom. `main.gd` now gates
all camera gesture handling behind a `_gameplay_active` flag, true only
between shift confirmation and the shift ending, so nothing on the
briefing or debrief screen can ever touch the camera regardless of how a
player interacts with those screens. Verified end-to-end against a real
Web export, isolating scrollbar-handle drag (which cannot possibly
interact with wheel/zoom handling) from wheel-based scrolling to confirm
the fix: the default view now reliably shows all six districts as one
connected town, MAX zoom-out stops at the town plus a small margin
instead of a tiny cluster in a sea of empty green, MIN zoom-in still
reads individual buildings and streets clearly, and pan/dispatch/panel
flows are unaffected.

The player then added a large batch of further Kenney kits to the shared
Google Drive -- houses, cars, people, roads, green spaces -- and asked
for two things: use them to make the town look like a real town, and
space individual buildings apart from each other (roads, pathways, green
areas) so it stopped feeling so uniformly packed.

Three of the new kits went in directly: `kenney_city-kit-suburban` gives
RESIDENTIAL/RURAL districts real houses (21 variants) instead of reusing
the same commercial shop/office shapes every other district already used
-- confirmed on a real incident location (Ashford Row, in east_estate)
as a proper green-roofed neighbourhood on a real street grid, not a wall
of shops. `kenney_mini-forest` supplies standalone decorative trees.
`kenney_car-kit` adds civilian traffic (hatchback, taxi, van, delivery)
scattered along street cells alongside the existing ambulance/police.
The "space buildings out" ask became `City3DView.OPEN_CELL_CHANCE`:
roughly a fifth of otherwise-buildable cells are now deliberately left
as bare ground instead of getting a building -- since the ground plane
is already a park green, an open cell reads as a real gap/garden/paved
area without needing a separate "path" mesh for it, and about a quarter
of those open cells get a standalone tree so the openness reads as real
greenery rather than just absence.

A fourth kit -- `kenney_animated-characters-protagonists`, for people --
was tried and pulled back out. The shared character rig has no baked
idle pose; instantiating it without wiring up real animation import
(a separate idle.fbx clip driven through an AnimationPlayer, genuine
work disproportionate to background scenery) rendered its raw bind
pose -- a T-pose, arms straight out -- at a scale that towered over
multi-storey buildings. Confirmed as actually broken, not merely
unpolished, against a real Web export screenshot, so it was removed
rather than shipped; the raw FBX/skin files stay in
`data/models/people/`, unused, in case a later round wants to do the
animation import properly.

Giving cars and trees their own individually instanced scene node each
(the same pattern already used for named buildings) measured a real
frame-time regression against a real Web export once there were enough
of them scattered through town -- both now go through the same shared
`GridMap` as buildings and roads instead, which batches per unique mesh
internally regardless of cell count. That recovered some of the
regression but not all of it; the remainder traces to the suburban
houses themselves being genuinely more detailed geometry than the
simple boxes RESIDENTIAL/RURAL filler used before, which is the real
content upgrade the player actually asked for, not something to trade
away by reverting to plainer shapes. Reported honestly rather than
chased further: the sandbox this was measured in has no GPU (software
WebGL fallback, the same caveat noted throughout this project's Web
performance checks), so its absolute FPS numbers aren't a real-device
result, only a same-sandbox before/after comparison -- a genuine
real-device check is still open.

A follow-up report against that live build was blunt and correct on both
counts: "the cars have definitely not worked, they are too big and are
just static," and separately, the districts still had "massive gaps"
between them despite the earlier compaction pass -- with a screenshot
showing a taxi visibly bigger than the houses next to it, sitting still
in the middle of a street.

Re-measuring the car-kit's models directly (`hatchback-sports`, `taxi`,
`van`, `delivery`, plus the already-integrated `police`/`ambulance`)
confirmed it: every one of them is 2.75-3.25 units long against ~1-1.4
unit-wide suburban houses and a 1-unit GridMap cell, all from the same
kit, all equally oversized -- not a one-off bad model. And a `GridMap`
cell, which is what "parked" cars were, structurally cannot move
regardless of scale; fixing the scale alone was never going to produce
moving traffic. So parked GridMap cars were dropped entirely in favour of
individually instanced `RoadWalker` actors (`scripts/ui/road_walker.gd`)
that continuously traverse the same `road_nodes`/`road_edges` graph the
2D map and gameplay layer already use -- picking a random adjacent edge
on arrival, forever, no destination or pathfinding needed for ambient
traffic. A small fixed count (10 cars) keeps this from reintroducing the
GridMap-batching performance fix's whole reason for existing. Building
each car from its full source scene rather than just its first mesh
(the pattern that worked fine for single-mesh buildings/trees) turned up
a second, separately real bug along the way: the car-kit's models are
multi-part -- a body plus four separate wheel meshes -- so grabbing "the
first `MeshInstance3D`" silently rendered every car as just a stray wheel
or door panel. Both bugs are why the cars in the screenshot read as an
odd, motionless yellow blob instead of a car.

People got the same treatment. The previous round's honest write-up
above explains why `kenney_animated-characters-protagonists` shipped
disabled -- no baked idle pose, so instantiating it directly is a
T-pose. Fixing it needed the exact mechanism spelled out there: importing
`idle.fbx`/`run.fbx` as separate clips and driving them through a real
runtime `AnimationPlayer`. The one non-obvious part, found by testing it
directly rather than guessing: that `AnimationPlayer` has to be added as
a sibling of the character's `Root` node, not nested inside it -- the
clip's own animation tracks are baked as `Root/Skeleton3D:<bone>` paths
relative to wherever the player sits, so nesting it inside `Root` doubles
that first path segment and every track silently fails to resolve
(confirmed both ways with a headless bone-pose check before touching the
real scene). With that working, pedestrians are `RoadWalker` actors too,
looping the run clip (there's no separate walk clip in this kit; run,
looped, reads fine at an unhurried `PERSON_SPEED`) and offset to the side
of the road so they read as a sidewalk instead of walking down the middle
of the carriageway cars use.

Scale needed a second pass once both were actually moving and visible.
The strict, physically-derived figures (car ≈0.25x native, brings the
longest car in just under one grid cell; person ≈0.11x native, a person
a third of a house's height) are the "objectively correct" proportions,
measured the same way as everything else in this file -- but tested
against a real Web export, both read as an almost invisible speck next
to the building grid, to the point where a temporary 10x-scale render was
needed just to confirm the RoadWalker/rendering pipeline itself was
working at all (it was; screenshot showed giant cars in exactly the right
place). Shipped at 0.4x/0.2x instead -- still meaningfully smaller than
the old native scale and smaller than a house, but an actual car- and
person-sized silhouette you can see moving on the road, not a
technically-correct dot. Legibility beat strict proportion here.

The district-gap complaint was a real gap in the *previous* fix, not a
regression: `WORLD_SCALE` converts the whole town through one shared
scale factor, so shrinking it further shrinks every district's own
content by the same ratio it shrinks the gaps between them -- it cannot
change how big a gap *reads* relative to the district sitting next to it,
only how big everything is on screen together. Actually closing the gaps
needed to treat inter-district spacing as its own problem, separate from
in-district density: `City3DView._compute_district_layout()` now runs a
small force-directed relaxation once at build time -- each district (a
real circle, per `WestfordMapFactory`'s own `_circle_polygon` boundary)
is pulled toward the town's overall centroid a little at a time, with a
pairwise overlap-resolution pass after each pull so no two districts'
circles (plus a small margin, enough to still read as a real gap/road,
not a seam) ever end up closer than they safely can. This settles into a
packed layout where every gap has closed as far as its own local slack
allows, which a single uniform scale can't do -- the tightest-already
pair of districts (south_residential/rural_outskirts, both close and
both large) capped how far a global shrink could go before that one pair
started overlapping, while every other pair barely moved. The result is
a rigid per-district translation applied on top of the existing
`world_to_3d()` conversion, so it moves whole districts closer together
without touching anything about their own internal building grid/road
layout -- buildings, GridMap cells, and each district's own road nodes
all pick it up automatically via `_world_to_3d_in_district()`. The
arterial road ribbon connecting district hubs is built from those same
compacted node positions, so the connecting roads visibly shorten right
along with the gap, instead of a static-length ribbon now looking too
long for the space it's spanning.

Verifying the moving traffic/pedestrians actually worked, rather than
just trusting the code, took more than the usual screenshot: a real car-
or person-sized object turned out to be genuinely hard to pick out by eye
in a single screenshot of a dense town at normal camera zoom, even though
the feature was working correctly the whole time. What actually settled
it, in order: (1) a direct scene-tree inspection confirming 10 cars/8
pedestrians exist with the correct full multi-part meshes and a
correctly non-T-posed skeleton; (2) manually advancing a `RoadWalker`'s
`_process()` by a simulated second and confirming its position changed;
(3) the temporary 10x-scale render described above, proving the
rendering path itself places them correctly; and (4) a pixel-diff between
two real Web-export screenshots taken 5 real seconds apart, which showed
a handful of small, tightly localized changed regions (tens of pixels
each, not a global lighting drift) sitting exactly on road corridors --
consistent with real objects moving along them. No single one of these
was fully conclusive by itself; together they are.

The player added another batch of Kenney packs to the shared Google Drive
and asked for two specific things this round: fill in the town's bare/
empty lots, and visibly bridge the gaps between districts rather than
leaving the inter-district connector as a flat ribbon over open ground.
Reviewing what was actually new turned up a genuine surprise: the two
kits that mattered most weren't new uploads at all. `data/models/roads/`
and `data/models/nature/` already held the *complete* kenney_city-kit-
roads and kenney_mini-forest kits from earlier rounds -- every road prop,
bridge, street light, ground patch, and rock Kenney ships in them -- but
only road-straight/road-crossroad and tree/tree-high had ever actually
been used. Dozens of already-imported, already-paid-for pieces (a real
road-bridge + bridge-pillar-wide, light-square/light-curved street lamps,
patch-grass/patch-dirt/plant/rocks-low/rocks-ramp/stones, mini-forest's
own fence.glb) were sitting unused the whole time. Three genuinely new
packs went in alongside that: kenney_modular-buildings' pre-assembled
`building-sample-house-*`/`building-sample-tower-*` (single-mesh complete
buildings, unlike the kit's ~100 other raw wall/window/roof pieces, which
would need real modular assembly -- the same disproportionate-effort call
the animated-characters kit's T-pose got a few rounds back, so left
unused) and kenney_factory-kit's industrial clutter (crates, pipework, a
hopper, a warning marker) for WEST_INDUSTRIAL specifically. The actual
kenney_nature-kit.zip the player also added (a much larger kit than
mini-forest) was reviewed too, but this session's Google Drive download
tool caps individual files at 10MB and it's 10.5MB -- noted here rather
than silently skipped; a future round with a working download path for it
is the honest way to pick that back up.

Bare lots (`City3DView.OPEN_CELL_CHANCE` cells) went from a tree-or-
nothing coin flip to real ground-cover variety drawn from a per-land-use
pool: greenery (tree/tree-high/patch-grass/patch-dirt/plant/rocks-low/
rocks-ramp/stones) everywhere, mini-forest's fence.glb added for
RESIDENTIAL/URBAN gardens, and factory-kit clutter *instead of* greenery
for INDUSTRIAL yards. rocks-high was measured and deliberately left out
of the pool -- its origin sits at its own vertical centre rather than its
base, so it would render half-sunk into the ground; every other piece
sits flush, confirmed the same way.

District bridging is a new `City3DView._build_district_connectors()`
pass over the map's 8 real inter-district hub-to-hub edges (Town Centre
-> Northside/East Estate/West Industrial/South Residential, South
Residential -> Rural Outskirts/East Estate, Northside -> West Industrial,
East Estate -> Rural Outskirts -- `WestfordMapFactory._inter_district_
roads()`), which post-compaction measure 18-37 3D-units end to end
(measured directly, not guessed, mirroring `_compute_district_layout()`
in a one-off headless run). Each edge gets a road-bridge.glb deck on two
bridge-pillar-wide.glb supports at its midpoint, 2-6 light-square.glb
street lamps spaced along its length depending on real edge length, and a
gateway building/landmark near *each* end -- a sample house/tower for
RESIDENTIAL/URBAN or factory clutter for INDUSTRIAL, keyed off that end's
own land use. All of it is individually instanced (not GridMap cells),
the same choice already made for named Locations and RoadWalker actors,
for the same reason: a small, bounded count (8 edges, a handful of props
each) where per-instance overhead is fine, at real continuous angles a
grid can't represent anyway since these edges are the deliberately
non-grid-aligned arterial network, not a district's own street lattice.

The first version of the gateway placement had a real bug, caught by a
headless scene-tree inspection rather than by eye: it only dressed the
*far* end of each edge, and `_inter_district_roads()` always lists
`town_centre` first -- so the only URBAN district in the game never once
landed on the dressed end, and none of the four `building-sample-tower-*`
variants imported for it were ever actually placed, despite compiling and
running without error. Counting instances by scene path after a real
`build()` run (8 road-bridge, 16 bridge-pillar-wide, 29 light-square, but
zero tower variants among the 8 gateways) caught it directly. Fixed by
dressing both ends -- district_a's own land use at the near end,
district_b's at the far end -- which brought the count to 16 gateways
using all four tower and three house variants plus both factory variants,
confirmed by re-running the same inspection.

That same headless check surfaced a second thing that looked like a bug
at first but wasn't: every `look_at()` call in `_dress_connector_edge()`
(and, it turned out, in the already-shipped `RoadWalker._apply_transform()`
too) errors with "Node not inside tree" when run from a bare
`SceneTree.-headless --script` entry point, because that harness never
gives the tree a real `_ready()`-equivalent pass before `_init()`/
`_initialize()` runs. Confirmed by reproducing the identical error against
`_build_traffic()` -- code that has shipped and been screenshot-verified
working for two rounds -- under the exact same harness: a pre-existing
harness artifact, not a regression, so no code changed to fix it and the
real running game (which adds `City3DView` to the tree before calling
`build()`, per `main.gd`) never hits it.

Verified against the real engine and a real Web export, not just
compile checks: `godot4 --headless --script tests/run_shift_debug.gd`
still runs a full shift cleanly; a `--check-only` parse and a full
headless-editor reimport are both clean; the headless scene-tree
inspection above confirms every new asset actually gets placed with the
right counts. A real `godot4 --export-release "Web"` build, served
locally and driven with Playwright against the pre-installed headless
Chromium (SwiftShader software rendering, no real GPU in this sandbox --
same caveat as every prior Web check in this file), booted with zero
console errors, scrolled and confirmed a real shift briefing, and ran
live play with incidents dispatching correctly. A cropped/upscaled
full-town screenshot and a closer in-browser zoom both show the new
content actually rendering -- a two-tone `building-sample-tower` standing
out clearly as a gateway landmark, orange-tan factory clutter near an
industrial edge, and richer tree/rock variety in open lots -- corroborating
the scene-tree counts rather than replacing them. Frame time was sampled
via `requestAnimationFrame` for 300 real frames on the same before/after
Web builds in the same sandbox: 847.6ms/frame before this round's changes
vs 835.3ms/frame after -- no regression (if anything a touch faster,
within run-to-run noise) -- though, as with every prior Web performance
note in this file, the absolute numbers themselves (~1.2 "fps") reflect
this sandbox's GPU-less software rendering fallback, not a real device;
only the same-sandbox relative comparison is a valid signal here.

Real playtesting on that build reported three genuine problems, all fixed
this round and reverified the same way.

Cars and pedestrians read as close to building-sized. They actually were:
CAR_SCALE 0.4 put the longest car (delivery, 2.85-3.25 native units) at
1.3 units long -- *longer than a house's own footprint* (1.0-1.3) -- and
PERSON_SCALE 0.2 put a person at 0.75 units tall, nearly a whole house.
Both scales had already been derived once as "the strict, proportionally
correct figure" in an earlier round (CAR_SCALE ~0.25, PERSON_SCALE ~0.11)
but shipped bigger than that on purpose, trading correct proportion for
on-screen legibility in a sandbox with no real device to check against.
Real playtesting is exactly the signal that tradeoff needed, and it came
back the other way -- restored to the strict figures: every car is now
0.28-0.45 tall and 0.69-0.81 long, a person 0.41 tall, both clearly
smaller than a house on every axis and still a visible silhouette
(confirmed against a real Web export screenshot, not just the arithmetic).

Cars and pedestrians also drove/walked straight through buildings. This
was structural, not cosmetic: `RoadWalker` was following `_world.
road_nodes`/`road_edges` -- the original gameplay `RoadGraph`, generated
for the old 2D top-down map, whose nodes sit tens of units apart and
whose edges are straight lines with zero awareness of where
`_build_district_blocks()` actually paints road-straight/road-crossroad
tiles on the much finer per-district `GridMap` lattice. The two graphs
were never the same graph, so a `RoadWalker` following the old one had no
structural reason to stay on a visible road at all. `City3DView.
_build_walk_graph()` now builds the walk graph from the real placed
street cells instead (`_street_cells`, recorded the moment
`_build_district_blocks()` places each tile), with edges only between
orthogonally-adjacent street cells, linked across districts through the
same hub-to-hub positions `_build_district_connectors()` already dressed
with a bridge and lights last round -- so a car crossing a gap now
visibly drives over the dressed bridge instead of cutting through open
ground or a building. A headless scene-tree check building this graph
found it wasn't quite that simple: `_street_cells` comes from
`Geometry2D.is_point_in_polygon` against each district's real (irregular)
boundary, and a handful of cells right at the polygon edge ended up with
none of their would-be neighbours also inside the polygon -- 12 tiny 1-6
cell dead-end stubs, disconnected from the main 762-cell network, that a
`RoadWalker` unlucky enough to *start* in one would loop forever with no
way out. Fixed by keeping only the largest connected component of the
graph (`_largest_component()`) -- confirmed after the fix that all 762
real nodes (street cells plus the 8 pairs of inter-district hub
pseudo-nodes) form exactly one connected component, so every walker can
reach the whole town.

Verifying the road-graph fix took a genuine debugging detour. A first
headless check advanced every `RoadWalker` by 0.5-second steps and found
only 8 of 18 actually moved, with roughly half the sampled positions
landing off the expected road segment -- alarming, since the whole point
of this round was to stop that. The cause turned out to be the test, not
the fix: `RoadWalker._process()` calls `_advance()` and returns
*without* repositioning on whichever frame a segment finishes (a
pre-existing detail, unchanged from before this round) -- invisible at a
real 60fps frame delta (~0.017s), where the one skipped-reposition frame
is a single imperceptible tick, but at CAR_SPEED 3.2 a 0.5-second step
always overshoots a 1-unit street-cell segment, so the crude test hit
that branch on *every single step* and never saw the car actually move.
Re-run at a realistic 240 steps of 1/60s (4 simulated seconds at real
frame timing): all 18 walkers moved, and all 216 sampled positions landed
exactly on the real street/bridge graph -- confirmed by the same direct
scene-tree/position-tracking method the moving-traffic round originally
used, not just re-reading the code.

Every building of a given shape also rendered in exactly one colour --
true, since every GLB in a Kenney kit shares one baked "colormap" texture
(confirmed earlier this project by inspecting road-straight.glb's own
glTF material directly), so nothing about placement ever varied it.
Fixed with a small muted/pastel `BUILDING_TINTS` palette (white/no-op
plus six tones) applied as a `StandardMaterial3D.albedo_color` multiply
over the existing texture -- keeps the baked shading/windows/trim, just
tints the wall tone, the same way real housing stock varies paint colour
on an otherwise identical build. Filler buildings (the dense GridMap
majority of the town) register every variant x every tint as its own
`_register_tinted_library_item()` MeshLibrary entry -- a shallow mesh
duplicate with an independently duplicated, re-tinted surface material,
still a fixed one-time registration cost regardless of placed-cell count,
the same reasoning that put filler buildings on a shared GridMap in the
first place. Individually-instanced buildings (named Locations, the
modular-buildings gateway landmarks) get a per-instance
`set_surface_override_material()` tint instead -- factory-kit gateway
clutter (structure-short/hopper-round for an INDUSTRIAL crossing)
deliberately excluded, since utilitarian equipment tinted pastel colours
read as wrong, not varied. Confirmed against a real Web export screenshot
(cropped and upscaled): the same building shapes that used to render in
one uniform tone per district now show white, cream, blue-grey, and dark
variants side by side.

Frame time was sampled the same way as every prior round, before vs after
on the same real Web export build in the same sandbox: 830.4ms/frame
before, 870.4ms/frame after -- a ~5% swing, within the same run-to-run
sandbox-noise range already seen in earlier rounds' checks (a prior round
saw a comparable-magnitude swing in the *other* direction), and there's
no plausible per-frame cost this round could have added: every new cost
(tinted MeshLibrary registration, largest-component graph filtering) is a
one-time scene-build cost, not something that runs per rendered frame.
Reported honestly with the same caveat as always -- this sandbox has no
real GPU, so only the same-sandbox relative comparison means anything.

The player then asked for something bigger than another bug-fix pass:
fill the ground that's still just empty between/around the six districts
with new roads, buildings, green spaces, water features, and trees, "be
creative," and one hard rule -- every road has to actually join up
somewhere, no dead ends. A new `City3DView._build_infill()` fills that
space with a lower-density extension of the exact same street-lattice
mechanism every district's own interior already used -- which is what
makes "no dead ends" a property of the mechanism rather than something
that needed its own algorithm: every interior cell of a regular lattice
is a 2-4-way junction by construction, the same reason no district had
ever produced a dangling stub road. Infill's own street cells write into
the same shared cell dictionary a district's streets already populate, so
the existing orthogonal-adjacency walk-graph code links the two together
automatically wherever they happen to be neighbours -- no separate
stitching pass, and RoadWalker traffic gets the new roads for free. Two
water features went in the same pass: one river, laid out as a real
3-point polyline across the infill area and reserved as a cell band kept
clear of buildings, with the actual visible water a SurfaceTool ribbon
along the same line and any street lattice road that crosses it swapped
for a real `road-bridge.glb` GridMap tile instead of stopping dead at the
bank; and a small round lake sat inside one of four dedicated
tree-covered park zones. Building/decoration flavour comes from each
infill cell's nearest real district by centroid distance, so infill next
to WEST_INDUSTRIAL reads industrial and infill next to a residential
cluster reads residential, instead of one uniform style dropped in
everywhere. Verified headless: a scene-tree connectivity check found the
whole walk graph (street cells plus infill) forms exactly one connected
component with zero isolated nodes.

Deploying that build drew a sharper follow-up, and it was right: "just
separate clumps of assets placed on the map... none of them join or flow
together... we still have Claude's original old road system hidden
underneath it all." It traced to something real and structural, not a
matter of degree: `_build_roads()`'s diagonal SurfaceTool ribbon -- the
original 2D RoadGraph's own visual, kept since the very first 3D
migration as "the inter-district arterial network" -- was still
rendering as a completely separate road system from the GridMap lattice
every district and infill cell actually used, non-grid-aligned, cutting
across the real streets at whatever angle the underlying 2D data
happened to produce, with the hub-to-hub bridge/lights/gateway dressing
from an earlier round still riding along it. Two independent road
systems that never shared a coordinate space, in the same scene, is
exactly what "separate clumps that don't flow together" looks like.
Retired both entirely -- the ribbon and the whole hub-to-hub connector
dressing -- once a headless connectivity check confirmed
`_build_infill()`'s own grid stitching already links every district into
one town-wide network on its own, with *zero* connectivity loss either
way (1686/1686 nodes in one component, identical result with or without
the old hub-pseudo-node linking the walk graph used to need). The
gateway buildings' assets weren't wasted: folded into a `LANDMARK_VARIANTS`
pool instead, an occasional plain addition to a district/infill cell's
regular filler-building pool, so they still show up in town -- always on
a real GridMap cell with a real connected road on every side, instead of
floating over whatever ground happened to sit under an old diagonal line.

That first infill build also measured a real, not-noise frame-time
regression -- 869ms/frame before vs 1735ms/frame after, roughly 2x, on
the same before/after Web-export sandbox comparison this project always
uses. Traced directly to cell count, not a per-frame algorithmic cost:
the GridMap went from 1846 used cells to 4570. `INFILL_OPEN_CELL_CHANCE`/
`INFILL_DECOR_ON_OPEN_CHANCE` (0.5/0.55 initially) were retuned to 0.85/
0.2 -- deliberately not touched: the street lattice itself, so every
district's real connectivity is exactly as dense either way, only how
many of the *remaining* cells get an actual building/decoration mesh
placed on them changed (GridMap cells used: 4570 -> 3502). Re-measured
after: 875ms/frame before vs 1127ms/frame after, ~29% -- a real,
explainable cost for a town whose actual built content genuinely grew,
not something to chase away entirely, and consistent with this project's
own precedent (the suburban houses' more detailed geometry, a few rounds
back, was "the real content upgrade the player actually asked for, not
something to trade away"). The lower density also reads better, not just
faster: the road grid itself is far more legible in a real screenshot at
this density than the original's denser infill was.

Verified against the real engine and a real Web export throughout:
headless parse/reimport/shift-harness all clean at every stage, the
connectivity check re-confirmed after every retune, a real
`godot4 --export-release "Web"` build served and driven with Playwright
shows zero console errors and the whole town rendering as one continuous
place in a real screenshot -- a winding river with a road crossing it,
one legible grid of streets spanning district cores and the lighter
infill fringe alike, no visible seam or second road system anywhere.

Two real screenshots from that build then found three genuine bugs, all
of which had shipped: "the water does not look right... it's cutting
right through roads and buildings", and "people and cars are moving
underneath the road and houses, not on them?" Three separate causes, each
confirmed by measurement rather than assumed:

1. **The road-bridge swap was dead code.** `_build_infill()`'s main loop
   opened with `if _occupied_cells.has(cell) or water_cells.has(cell) or
   park_cells.has(cell): continue` -- so *every* water cell was skipped
   before reaching the branches below that would have swapped a street
   cell to `road-bridge`. The bridge code existed, read correctly, and
   could never run: wherever a street met the river, the street simply
   stopped, leaving a hole in the network. Now only *non-street* water
   cells skip early (`if crosses_water and not is_street_col and not
   is_street_row`), so a street crossing water falls through and becomes
   a real bridge. Headless check after the fix: 43 `road-bridge` cells
   actually placed, against 0 before.
2. **The river never checked what it was crossing.** `_build_river()`
   picked its start/bend/end from the *whole* infill area's bounding box,
   corner to corner. Since the six districts sit in the middle of that
   box (infill is the ring of ground around them), a corner-to-corner
   diagonal runs straight through the middle of town -- and nothing
   validated the line it drew. That is exactly the screenshot: water
   cutting through buildings and roads. Rewritten to pick candidate
   endpoints from real infill cells and validate the whole path with a
   new `_polyline_clear_of_districts()`, which samples every 0.5 units
   along each segment and tests the centreline *plus* both
   `RIVER_RESERVE_RADIUS` perpendicular offsets against every district's
   real polygon -- so the reserved band stays clear, not just the
   mathematical line through its middle. It retries up to
   `RIVER_PATH_ATTEMPTS` (60) times with fresh endpoints and, if nothing
   validates, ships **no river at all** rather than one through a
   building. Headless check after the fix: 0 of the river mesh's 12
   vertices land inside any district polygon.
3. **Walkers ignored the height of what they were walking on.** This is
   the "underneath the road" half, and the measurement is the whole
   story: `_build_walk_graph()` placed every RoadWalker position at
   y = 0, but a `road-bridge.glb`'s own AABB is **0.52 units tall**
   against a flat `road-straight`/`road-crossroad`'s **0.02**. So a car
   or pedestrian crossing a bridge sat half a unit *below* the deck it
   was supposed to be driving over. Fixed by recording each street cell's
   real surface height in a new `_street_cell_height` dictionary as the
   tile is placed, and offsetting the walk graph's position by it.
   Verified headless per-cell rather than in aggregate: all 43 bridge
   cells sit at exactly `ROAD_BRIDGE_SURFACE_HEIGHT`, all 1702 flat
   street cells at `ROAD_SURFACE_HEIGHT`, 0 mismatches either way.

Worth being explicit about what was *ruled out* rather than fixed: the
0.02-unit flat-road offset is visually negligible on its own, so the
bridge case is the entire visible effect -- and a separate headless sweep
of all 113 building GLBs (suburban/commercial/industrial/modular) found
**0** whose mesh AABB sits off ground level, ruling out a sunken-origin
bug of the kind an earlier round hit with `rocks-high` as a contributing
cause of the "underneath the houses" report.

The frame-time check on this round is worth recording honestly, because
it turned into a lesson about the *measurement* rather than the code. The
first sample read 1355ms/frame against the previous round's recorded
1127ms -- about 20% worse, which would be a real regression if true. It
isn't. Re-running the **identical build, same URL, same sandbox** a
little later measured 1613ms: a 19% swing with zero code difference
between the two runs. This sandbox has no GPU (software WebGL via
SwiftShader) and shares a noisy container, so its run-to-run noise floor
is comfortably wider than any effect these changes could have. The
content delta was measured directly instead, which is the number that
actually means something here: GridMap cells went 3502 -> 3562, **+60
cells (+1.7%)** -- the 43 newly-placed bridge tiles plus the relocated
river's knock-on effect on which cells get built on. A 1.7% content
change cannot produce a 20% frame-time change. The previous round's 2x
regression was far outside this noise floor, so it was real and worth
chasing; a difference this size simply isn't measurable in this
environment. Cross-session absolute numbers are not comparable here, and
this round is where that stopped being an abstract caveat: only
back-to-back, same-session A/B/A/B runs are treated as signal from here
on.

### The HUD redesign

The next round came with a design mockup and a blunt assessment of the
old interface: "currently it just looks basic". It was -- raw engine
default Buttons along the top, one ad-hoc `StyleBoxFlat` in `hud_view`
for the feed, an unrelated one in `side_panel_view` for header bars, and
no visual relationship between any of them.

Two new modules carry the redesign. `ui_theme.gd` holds the whole visual
language in one place -- palette, corner radii, and `StyleBoxFlat`
factories for panels, cards, header strips, pills and badges -- so every
piece of chrome is styled from the same source rather than each view
inventing its own colours and margins. `ui_icon.gd` draws a small icon
set (clock, rain/sun, shield, people, car, house, magnifier, hand,
chevrons, alert, status ring) with Godot's own `_draw()` primitives. The
mockup leans on icons everywhere and the project has no icon art; drawing
them keeps them resolution-independent and recolourable per instance
(every unit row tints the same car glyph to its own status colour), with
no new binary asset or icon-font licence to track, and it stays
consistent with the project's build-the-UI-in-code convention.

What that buys, beyond looking better: the HUD can now *show state it
previously couldn't*. Every speed button used to look identical whether
or not it was the selected one -- there was no way to tell 1x from 4x
without watching the clock. Now the active speed and the open panels are
lit, and both read their real state (`GameClock.paused`/
`speed_multiplier`, and each panel's own `is_open()`) rather than
remembering which button was last tapped, so a pause triggered elsewhere
or a panel closed by its own Close button can't drift out of sync.
Incident rows gained a per-type glyph and a live state line ("Awaiting
dispatch", "En route", "On Scene") in place of a queued call and a unit
already at the scene looking identical, and the whole card became one tap
target instead of just its first line -- on a phone, the rest of the row
was most of its area.

The compact metrics from earlier phone playtesting were deliberately
**not** relaxed to match the mockup, which is a wide desktop frame: the
11px text and thin two-row bar stay where real device testing put them,
and only the mockup's *look* (shape, colour, hierarchy, icons) was
adopted. The single metric that moved is `HUD_BOTTOM`, up 8px, because
rounded cards need internal padding not to look clipped -- and everything
docked below reads that constant rather than hard-coding its own top edge.

Screenshotting a real Web export caught two layout bugs that headless
checks could not have:

- **Icons distorted.** Containers stretch a plain `Control` to fill the
  axis they lay out against, so an icon in a three-line card row got
  pulled tall -- and since each glyph is authored in normalised 0..1
  coordinates, the artwork stretched with it: the car rendered elongated
  with its wheels detached below the body as two stray dots. Fixed with
  `SIZE_SHRINK_CENTER` on both axes, plus `_p()` now mapping into the
  largest centred *square* that fits, so a stretch is harmless even if
  one gets through.
- **A docked panel slid off-screen.** These panels set
  `horizontal_scroll_mode = DISABLED`, which makes the `ScrollContainer`
  adopt its child's horizontal minimum size -- so one non-wrapping
  `Label` pushed the whole panel wider than `_panel_width()`, and since a
  right-anchored panel is positioned at `-(width + 8)`, growing it slid
  it straight off the right edge. The "Dispatch Queue" header did exactly
  that, hiding its own incident rows. Fixed-line labels now clip and
  ellipsise; wrapping labels (which report a near-zero minimum) were left
  alone, and the header dropped to 10px so it reads in full beside the
  scroll bar.

A third, smaller one: `RichTextLabel` underlines `[url]` spans by
default, so every tappable feed line rendered underlined end to end.
`meta_underlined = false` keeps the tap target without the hyperlink
styling.

Frame time was checked with the back-to-back A/B/A/B method this round
established, since the redesign adds real Control nodes and custom
`_draw()` calls. The redesigned build measured **1308ms and 1328ms**
against the pre-redesign build's **1613ms and 1438ms** on the same
machine minutes apart -- i.e. the new UI measured *faster* in both
samples, which is not a real speedup so much as proof the difference is
comfortably inside the noise. Worth noting the redesigned build's two
samples sit 1.5% apart while the old build's sit 12% apart. No
measurable cost.

### Traffic under the road, for real this time

The round above fixed a bridge-height bug and reported traffic as sitting
correctly on the road. Playtesting came straight back: "cars and people
are still moving underneath the road and walkways. The road and building
structures need to be layered underneath them."

That framing was the clue, and the earlier fix was simply wrong -- not
incomplete, wrong. **GridMap defaults `cell_center_y` to true**, so a tile
placed in cell y=0 has its origin half a cell *up*: at `GRID_CELL_SIZE`
1.0 that puts a flat road's drivable surface at **y = 0.52**, not 0.02.
The previous round had added correct *relative* surface heights (0.02
flat, 0.52 bridge) but measured them from a hard-coded `y = 0` baseline,
which left every walker exactly half a cell under **every** road -- which
is why it was never just the bridges, and why the previous round's
verification passed while the game still looked wrong: it checked walkers
against the same wrong baseline it had just written.

The measurement that settled it, printed per cell rather than reasoned
about:

```
cell_center_x=true cell_center_y=true cell_center_z=true
gridmap tile origin y = 0.5     tile road SURFACE y = 0.52
walker placed at    y = 0.02 -> walker is 0.5 BELOW the road surface
```

`_build_walk_graph()` now asks the GridMap where it actually put each
tile (`map_to_local`) instead of assuming a baseline, so this stays
correct if `cell_size` or the centering flags ever change. Re-verified
across every cell, not a sample: **1702/1702 flat cells and 43/43 bridge
cells on-surface, worst deviation 0.0 world units**, and all 18 walkers
confirmed spawning at 0.52. The models themselves were re-measured too
and cleared: every vehicle and the character rig has `y_min = 0`, so
nothing sinks relative to its own origin. (An earlier partial measurement
had suggested otherwise by reading only a car's *first* mesh child --
a wheel, centred on its own axle -- which is exactly the trap
`_load_mesh()`'s own comment warns about.)

### Layout round: one top bar, taller panels, drag-scroll, resizable comms

Four asks from the same playtest, plus one follow-up:

- **"Move the pause and x1 x2 panel to the top right and make the top
  panel bar all flow as one."** The speed pills moved into the stats bar
  itself, which now spans edge to edge with hairline dividers between
  groups instead of two floating cards with a gap.
- **Taller dispatch queue.** Both docked panels now derive their height
  from the real viewport instead of a fixed number.
- **"The only way of scrolling... is on the side bar. This is too hard on
  the screen."** A drag anywhere on a panel body now scrolls it. This is
  handled in `_input` rather than the ScrollContainer's `gui_input`,
  because the cards inside are Buttons that consume the press -- a drag
  starting on a card, i.e. most of the panel, would never reach the
  container. Taps still work: nothing is consumed unless the pointer
  moves past a threshold, and only then is the release swallowed, so a
  drag that begins on a card scrolls instead of also opening it.
- **Resizable comms box.** The "Dispatcher Feed" tab is now a button that
  cycles three heights. A tap target rather than a drag handle precisely
  because the thin scroll bar had already proved too fiddly on a phone --
  a thin resize edge would repeat that mistake.
- **"The incident and resources panel should not overlap the comms
  panel."** They now stop short of it with a clear gap, *and* re-size
  whenever the feed does, so growing the comms box shrinks the panels
  rather than being covered by them.

Four layout bugs were caught by screenshotting real Web exports, each
invisible to a headless check:

1. **Panels ran off the bottom of the screen.** "Taller" was first
   implemented as a flat 300px -- but the project stretches from a
   640x360 base with aspect "expand", so the logical height stays ~360
   and a panel starting at y=58 simply ran past the bottom edge and
   through the feed. Now derived from the viewport.
2. **The speed pills were pushed off the right edge**, unreachable,
   because a Container propagates its children's minimum widths upward:
   the bar's minimum became "every chip plus every pill". The stats now
   sit in a plain `Control` (which reports only its own minimum) with
   `clip_contents`, so chips clip on a narrow screen while the controls
   stay put. Making the labels shrink instead was tried first and was
   worse -- every chip ellipsised at once, leaving "17:00 (en...",
   "CLEA", "6 AVA" across the whole bar.
3. **The entire feed strip vanished.** `Control.position`'s setter
   preserves the control's current size by moving `offset_bottom` with
   `offset_top` -- and at build time that size is still 0, so
   re-positioning the bottom-anchored wrapper pinned it to zero height.
   All four offsets are now set explicitly.
4. **The feed tab drew as bare floating text**, because a `flat` Button
   skips drawing its stylebox entirely, so the overrides never painted.

Verified on a real Web export end to end: zero console errors, the feed
cycling 46 -> 104 -> 170 with the panels shrinking to match at each step,
a drag from the middle of a unit card scrolling the list from Unit 1-3 to
Unit 2-5, and a plain tap after that drag still opening Unit 2's detail
panel -- i.e. drag-to-scroll did not eat ordinary taps.

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

**Six fixes from one round of real playtesting on the live build.** All
from a single player message after a phone session, quoted piece by
piece below because each pointed at a different, specific root cause
rather than one shared bug.

*"The water river in this still does not look right, it almost goes out
of the world side as well?"* `_build_river()` picks a bend point offset
perpendicular to the straight line between two river ends, by up to 15%
of that line's length -- and nothing checked the bend point against the
actual rendered ground plane, only against district polygons (so the
river wouldn't cut through a park or estate, but could still walk off
the edge of the world). Measured directly against the real generated
town: the river's vertices ran from x=-34.69 to the ground plane's own
edge at x=-35.5 -- 0.82 units of margin on a town that's roughly 100
units across, i.e. visibly hugging the boundary, matching the
screenshot. Fixed by extending the same per-sample check
`_build_river()` already used for district avoidance to also require
every sampled point (centreline plus both reserved-band edges) to fall
inside the ground plane inset by a safety margin. Reverified with the
same measurement script: the river's vertices now sit well clear of the
boundary on the real generated town.

*"If I have scrolled down to resources... the very next incident that I
click on opens at the same scrolled point rather than the start
again."* Every docked and pop-up panel shares one `ScrollContainer`
plumbing (`SidePanelView`), and nothing reset its scroll position on
open -- so whatever position the previous panel was left at just carried
forward into the next one's fresh content. Fixed with one line in
`_show_panel()`. Verified against the real engine: drag-scrolled a
unit's detail panel down two officers' worth, closed it, opened a
different unit, and it opened reading from the top.

*"There needs to be a few lines of what the incident is to make it seem
more real."* The content already existed -- each incident type's
`known_fact_templates` render as a "KNOWN" bullet list -- it was just
positioned fourth in the pop-up's layout, after the header, the dispatch
suggestions, and the assigned/available unit lists, so it read as
buried admin rather than the story. Moved it to render immediately after
the header. Verified against the real engine: opening a live domestic
incident now shows "KNOWN -- Neighbour reports a loud argument" directly
under the priority/type/location line, before any dispatch control.

*"Both the incident panel and resource panel are still very sensitive
and open up incidents or resources when I don't want to."* The docked
Resources/Incidents lists rebuild their rows on every simulated tick
(roughly once a real second at 1x) to stay live -- and `DragScroll` only
neutralises row Buttons once a drag is *confirmed* past its 5px
threshold. In the still-ambiguous instant right after a press, a
background rebuild can swap in a brand-new, never-suppressed Button
under the player's finger, which then fires as a genuine tap on release
-- opening whichever row ended up in that screen position, not
necessarily the one the player pressed. Fixed by adding an
`interaction_ended` signal to `DragScroll` and a `request_refresh()` on
`SidePanelView` that defers any background-triggered rebuild until the
current gesture actually ends, rather than rebuilding mid-touch.

*"There needs to be random time lengths built into incidents... a unit
goes to an incident and they are done within a minute."* True by
construction: `GameClock` runs one simulated minute per one real second
at 1x speed, and every incident type's on-scene handling time was a
fixed value (10-20 simulated minutes ON_SCENE, 5-10 DEVELOPING) with no
variance -- 15-30 real seconds, every single time, for a given type.
Added `Incident.duration_multiplier`, rolled once per incident between
1.5x and 4x and applied only to the ON_SCENE/DEVELOPING phases (not the
REPORTED/ASSESSED triage stages, which weren't the complaint), saved and
loaded with the incident so it survives a shift handover. Both ends of
the range stay above 1x, so nothing gets shorter than before, only
longer and more varied call to call. Verified with the project's headless
shift-debug harness: two shoplifting calls in the same run took 60 and 46
simulated minutes end to end respectively (including travel), against a
fixed ~15-minute total before this change.

*"When you click on a resource... it should show where they are, what
job they are at, their skills, their fatigue metrics."* The unit detail
panel showed a generic status word ("On patrol") and each officer's
experience/fatigue/morale, but never their live position, what they were
actually assigned to, or their skills -- despite all of that data already
existing (`PoliceUnit.current_position`/`current_incident_id`,
`Officer.skills`, fully populated per officer in
`data/officer_factory.gd`) and simply never being surfaced. Added a
district lookup for location (same point-in-polygon approach the
roster list already used), a job line that names the specific incident
or patrol point rather than repeating the status word, and a skills line
covering all five tracked skills per officer. Verified against the real
engine: opening a unit's panel now reads "Available at station /
Location: Town Centre / PC Bennett -- Constable / Experience: Low
Driver: Yes / Fatigue: 7 / Morale: 80 / Skills -- Comms: Low, Response:
Med...".

**Phase 1 of a larger feature request: smart dispatch, a live KPI
dashboard, and a tighter consequence loop.** A follow-up request asked for
a broad slate of systems -- smarter dispatch, performance metrics,
time-of-day incident variation, proactive officer interactions, a deeper
consequence engine, supervisor feedback, a rotating shift pattern,
environment/lighting, dispatch queue polish, and a briefing/debrief
redesign. Too much for one pass to build *and* genuinely verify, so it's
being staged: this round is the foundational layer everything else
builds on, chosen because it delivers value on its own and because later
phases (supervisor feedback, the deeper consequence engine) need the KPI
tracking and confidence-linking this round adds. The rest stays on the
roadmap for follow-up rounds, played and reviewed between each.

*Smarter dispatch.* Unit selection used to offer one hint -- the
straight-line-nearest available unit -- and otherwise left the player
reading a flat, unranked list. Added `DispatchScorer`, a stateless engine
class (matching `IncidentProbabilityEngine`/`IncidentOutcomeEngine`'s
existing shape) that ranks every available unit by real road-graph travel
time (not straight-line distance -- a unit on the wrong side of the river
can be close as the crow flies but genuinely slow to reach), by whether
its crew's skills suit this incident type (a new `primary_skill` field per
incident type, e.g. domestic -> communication, burglary -> investigation),
and by whether a sergeant is aboard when one's actually warranted (reusing
the existing `IncidentOutcomeEngine.needs_supervisor`/`has_supervisor`
rather than reimplementing that judgement). The incident panel's "SEND A
UNIT" list is now ranked best-first with a "recommended" tag and each
unit's ETA ("~4 min away"), and the top pick's ETA now appears in the
"SUGGESTED" hint too. Verified against the real engine: a synthetic
domestic incident scored units with a HIGH-communication officer aboard
distinctly higher than otherwise-identical crews, and against the live
browser build, opening a real incident showed "Send Patrol Car 4 --
recommended, ~12 min away" using the actual road-graph path length.

*Realistic unit names.* Units were labelled "Unit 1", "Unit 2"... --
`ResourceManager._make_unit` now names them "Patrol Car 1", "Patrol Car
2"... (display only; the internal `unit_id` used for saves/lookups is
untouched). Confirmed live across the roster panel, dispatch suggestions,
and the assigned-units list, which all read from the same `callsign`
field.

*A live KPI dashboard.* Response-time performance against target,
public confidence, and officer wellbeing previously only existed as a
single number computed once at debrief (`DebriefScorer`) -- nothing was
visible mid-shift. Added `KpiTracker` (shift-scoped, reset each shift like
`WeatherManager`/`SpecialistManager`'s `setup_shift`), which records every
incident's response delay against a priority-banded target (P1 15 min, P2
1 hr, P3 3 hr, plus sensible P4/P5 defaults -- this codebase already
expresses every duration in simulated minutes, so the request's real-world
targets map directly with no conversion) from `IncidentManager.
mark_unit_arrived`, the one real place "first on scene" already happens.
A new "KPI" HUD pill (following the exact `wire_resources_panel`/
`wire_incidents_panel` pattern already used for Res/Inc/Team) opens
`KpiPanelView`: three response-time cards, a town-wide confidence average,
and a workforce wellbeing card (fatigue/morale, sharing a new
`WorkforceStats` helper extracted out of `DebriefScorer` so the live and
end-of-shift numbers can't quietly drift apart), each tappable through to
a detail view with the target's definition and recent call history.
Deliberately scoped down from "trends" to a plain recent-calls list --
this codebase has no charting library, and building one was out of scope
for this round. Verified against the real engine, both headless (a full
simulated shift correctly accumulated response-time history bucketed by
priority) and in the browser: the dashboard opened showing live P1-P3
percentages, confidence, and wellbeing, each drilling into the detail
view.

*Dispatch queue: total count, priority-first.* The queue sorted strictly
newest-first, so a fresh routine call could sit above a lingering critical
one. Re-sorted priority-first (P1 always floats to the top), newest-first
within a priority band, and added an "N OPEN" badge to the panel header --
which needed a real fix along the way: the first attempt used the
existing `_clipping_label` helper for the badge, which deliberately zeros
its own `custom_minimum_size` so the *title* label can be safely squeezed
by its container; without a fill flag of its own, that meant the badge was
allocated **zero width** by the HBoxContainer and rendered completely
invisible -- caught via a real screenshot showing "Dispatch Queue" with no
count next to it despite incidents being open, fixed by building the badge
from a plain `Label` (matching the existing `add_badge` helper's approach)
instead, and confirmed fixed with a second screenshot showing "Dispatch...
4 OPEN".

*Closing the loop: escalation now costs confidence live, not just at
resolution.* Public confidence only ever moved when an incident resolved
(`CommunityManager.apply_incident_resolution_effect`) -- an incident left
to escalate unattended was invisible on the town's confidence reading
until, if ever, it was finally dealt with. `IncidentManager._maybe_escalate`
now also applies a small confidence hit via the same
`DistrictState.apply_community_effect` primitive `CommunityManager`
already uses, at the new trigger point. Verified against the real engine:
forced an incident to sit unattended, confirmed via the `incident_escalated`
signal that confidence dropped by exactly the applied amount (60.0 ->
58.5) at the moment of the first escalation, then partially recovered
toward baseline afterward exactly as `decay_toward_baseline` already does
for every other district variable.

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
