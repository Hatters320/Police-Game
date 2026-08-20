extends Node2D
## Entry point for the full shift loop (spec section 4/16/45): briefing ->
## confirm -> play -> debrief -> next briefing. Wires the one real
## SimulationCore (owned by the Simulation autoload) to the code-built
## MapView/HudView/IncidentPanelView/BriefingView/DebriefView -- no .tscn
## authoring beyond this scene's own bare root, since hand-writing Godot's
## scene resource format without the editor available to validate it is
## far riskier than building node trees with add_child() calls, which is
## ordinary GDScript. See docs/ARCHITECTURE.md section 3 for the
## Simulation<->Presentation contract this follows (signals out, pull for
## high-frequency data, validated commands in -- never direct state
## mutation from here).

const SHIFT_START_MINUTE := 17 * 60 # 17:00
const SHIFT_DURATION_MINUTES := 12 * 60 # 12h -- spec section 15 default

var map_view: MapView
var hud_view: HudView
var incident_panel: IncidentPanelView
var unit_panel: UnitPanelView
var neighbourhood_panel: NeighbourhoodPanelView
var resources_panel: ResourcesPanelView
var incidents_list_panel: IncidentsListPanelView
var day_night_overlay: DayNightOverlay
var weather_overlay: WeatherOverlay
var audio_manager: AudioManager
var rotate_prompt: RotatePromptOverlay
var camera: Camera3D
var city_3d: City3DView
var _briefing_view: BriefingView
var _debrief_view: DebriefView

## Bigger per-tap step than a desktop scroll-wheel needs, since a phone's
## on-screen +/- buttons (spec section 56) get far fewer discrete inputs
## than a wheel does -- reaching a meaningfully different zoom level
## should take a handful of taps, not fifteen-plus.
const ZOOM_STEP_IN := 1.25
const ZOOM_STEP_OUT := 0.8
## Orthogonal Camera3D's "size" is the vertical extent of the view in 3D
## world-units (KEEP_HEIGHT), the inverse sense of the old Camera2D.zoom
## (bigger size = more of the world visible = more zoomed OUT, whereas
## bigger zoom used to mean more zoomed IN) -- see _zoom_by and
## _effective_zoom_2d below for the conversion.
## Building-apparent-size on screen depends only on camera.size and the
## viewport, never on WORLD_SCALE (a Kenney building is always ~1 native
## unit regardless of how far apart the world positions it into) -- but
## "how much of one district a fixed camera.size shows" very much does,
## since a district's own footprint is now only 18-32 3D-units across
## (WORLD_SCALE 0.01) instead of the hundreds-of-units span it used to
## have. The old tuning (8/220, in a comment further up) never accounted
## for that: confirmed against a real Web export screenshot that camera.
## size 8 now shows less than half of a single district, not "several
## buildings with room to breathe" as intended. Retuned by the same
## method -- real screenshots, not formulas -- against the actual compact
## town: 75 comfortably frames all six districts at once (so this is also
## MAX_CAMERA_SIZE's basis, with a little headroom, not the old 220 left
## over from the since-shrunk, far more spread-out town, which let
## zooming out continue many times longer than the actual town needed).
## MIN_CAMERA_SIZE (individual buildings read clearly around size 2-3) is
## untouched by any of this, since it was never about world extent.
const MIN_CAMERA_SIZE := 3.0 # most zoomed in
const MAX_CAMERA_SIZE := 85.0 # most zoomed out -- the whole town plus a little margin

## A press/touch that moves less than this many screen pixels before
## release is a tap (dispatch to MapView.handle_tap); anything past it is
## a drag/pan instead. Without this, click-to-select and drag-to-pan can't
## coexist on the same pointer down/up sequence.
const TAP_DRAG_THRESHOLD := 14.0

## Gates all camera gesture handling below to the actual play screen --
## true only between _on_briefing_confirmed and the shift ending. Without
## this, wheel/drag input meant for the briefing/debrief screen's own
## ScrollContainer can still reach the (already-existing, just not
## visible yet) game camera once that Control stops consuming further
## scroll at its own top/bottom -- confirmed via a real Web export test
## that repeatedly scrolling the briefing all the way down measurably
## changed the camera's zoom before the shift had even started.
var _gameplay_active: bool = false
var _pointer_down: bool = false
var _pointer_start_screen: Vector2 = Vector2.ZERO
var _pointer_dragged: bool = false
var _touch_points: Dictionary = {} # touch index -> Vector2 screen position
var _pinch_start_distance: float = 0.0
var _pinch_start_size: float = 0.0

## True on a real touchscreen device -- set once in _ready(). Gates the
## mouse-event branches in _unhandled_input below so our own map gesture
## code is driven exclusively by real ScreenTouch/ScreenDrag on those
## devices, since Godot's touch-to-mouse emulation (left enabled so
## built-in Controls like ScrollContainer keep working via touch) would
## otherwise fire a synthetic mouse echo for every real touch event,
## double-applying every pan.
var _use_touch_events: bool = false

## Raises every Control's default text size (Godot's built-in default is
## 16) before any UI exists -- real phone playtesting found the whole
## game illegibly small even after fixing the map's default zoom, since
## most labels/buttons never set an explicit font size and just inherited
## the engine default. Assigning this to the root Window cascades to every
## Control created afterwards, in every view built across this whole
## session, without editing each one's theme individually.
const DEFAULT_FONT_SIZE := 22

func _ready() -> void:
	# Web export emulates mouse events from real touch input by default.
	# Turning that off (an earlier attempt at this) stopped a physical drag
	# from double-firing our own gesture code below, but it also broke
	# built-in Controls that depend on the emulation to handle touch at
	# all -- confirmed via real mobile playtesting: the briefing's
	# ScrollContainer could no longer be scrolled by touch, leaving CONFIRM
	# SHIFT PLAN unreachable. So the emulation stays on (Godot's default),
	# and instead _use_touch_events below makes our OWN gesture handling
	# ignore the synthetic mouse echo on touch devices, leaving Controls'
	# native use of it untouched.
	_use_touch_events = DisplayServer.is_touchscreen_available()

	var theme := Theme.new()
	theme.default_font_size = DEFAULT_FONT_SIZE
	get_tree().root.theme = theme

	rotate_prompt = RotatePromptOverlay.new()
	add_child(rotate_prompt)

	var world: WorldMapData = WestfordMapFactory.build()
	var incident_types: Array[IncidentTypeDefinition] = IncidentTypeFactory.build_all()
	var events: Array[EventDefinition] = EventFactory.build_all()
	Simulation.core.initialize(world, incident_types, events, 0) # 0 = random seed for a normal play session
	Simulation.core.shift_ended.connect(_on_shift_ended)

	# Local save/load (spec section 47/67) -- explicitly called here, not
	# from SimulationCore itself, so the headless test harness (which wants
	# a fixed, reproducible scenario) never touches a real save file as a
	# side effect of running.
	var next_shift_number: int = SaveManager.load_into(Simulation.core)

	city_3d = City3DView.new()
	add_child(city_3d)
	city_3d.build(world)

	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	# Fixed yaw+pitch, never changed after this -- MapView.CAMERA_YAW_DEG/
	# CAMERA_PITCH_DEG/CAMERA_DISTANCE are the single source of truth for
	# this offset (see map_view.gd's doc comment on those consts), since
	# pan_camera_to there needs to reproduce the same math for the
	# list-panel "jump to this location" shortcut.
	camera.rotation = Vector3(deg_to_rad(MapView.CAMERA_PITCH_DEG), deg_to_rad(MapView.CAMERA_YAW_DEG), 0.0)
	# Starts centred on Town Centre / the police station (both sit at the
	# world origin), zoomed to show the whole compact town at once (all
	# six districts, per the player's own request that the default view
	# shouldn't need zooming out any further than that) -- confirmed
	# against a real Web export screenshot, not derived from a formula
	# (see MAX_CAMERA_SIZE's comment above for why: "how much of the town
	# a given size shows" depends on the town's actual real footprint in a
	# way a formula would need to duplicate exactly). Zoom in via scroll/
	# the HUD's -/+ buttons to read individual buildings from here.
	camera.size = 75.0
	camera.position = MapView.camera_ground_offset()
	add_child(camera)
	camera.make_current()

	day_night_overlay = DayNightOverlay.new()
	add_child(day_night_overlay)

	weather_overlay = WeatherOverlay.new()
	add_child(weather_overlay)

	audio_manager = AudioManager.new()
	add_child(audio_manager)

	incident_panel = IncidentPanelView.new()
	add_child(incident_panel)

	unit_panel = UnitPanelView.new()
	add_child(unit_panel)

	neighbourhood_panel = NeighbourhoodPanelView.new()
	add_child(neighbourhood_panel)

	resources_panel = ResourcesPanelView.new()
	add_child(resources_panel)

	incidents_list_panel = IncidentsListPanelView.new()
	add_child(incidents_list_panel)

	map_view = MapView.new()
	add_child(map_view)
	# No Camera2D drives the viewport any more (City3DView owns the visible
	# scene, via Camera3D above), so the canvas transform defaults to
	# identity -- UnitMarker/IncidentMarker's raw 2D world-unit positions
	# would otherwise land directly on-screen as stray pixel-coordinate
	# dots for anything within screen-size of the origin (confirmed via a
	# real Web export screenshot: a cluster of small dots exactly where
	# Town Centre/the police station, at the world origin, would land under
	# an identity transform). Hiding the whole node cascades to every
	# marker child without touching any of their hit-testing/panel-opening
	# logic below, none of which reads .visible.
	map_view.visible = false
	map_view.setup(world, incident_panel, unit_panel)
	map_view.set_camera(camera)
	map_view.wire_other_panels(neighbourhood_panel)
	neighbourhood_panel.wire(map_view)
	resources_panel.wire(map_view, unit_panel)
	incidents_list_panel.wire(map_view, incident_panel)

	hud_view = HudView.new()
	add_child(hud_view)
	hud_view.wire_overlays(map_view)
	hud_view.wire_zoom_controls(func(): _zoom_by(ZOOM_STEP_IN), func(): _zoom_by(ZOOM_STEP_OUT))
	hud_view.wire_neighbourhood_panel(func(): neighbourhood_panel.open())
	# Resources/Incidents are always-docked by default now (open in
	# _on_briefing_confirmed below) -- these buttons toggle them off/back
	# on, for a player who wants to reclaim map space on a small screen.
	hud_view.wire_resources_panel(func():
		if resources_panel.is_open(): resources_panel.close()
		else: resources_panel.open()
		_refresh_panel_pills())
	hud_view.wire_incidents_panel(func():
		if incidents_list_panel.is_open(): incidents_list_panel.close()
		else: incidents_list_panel.open()
		_refresh_panel_pills())
	# A panel can also be closed by its own Close button or by
	# close_other_panels arbitration, not just by its HUD pill -- so the
	# pills re-read real panel state rather than tracking their own taps,
	# which would drift out of sync the moment either of those happened.
	neighbourhood_panel.closed.connect(_refresh_panel_pills)
	resources_panel.closed.connect(_refresh_panel_pills)
	incidents_list_panel.closed.connect(_refresh_panel_pills)
	hud_view.hide()

	_begin_briefing(next_shift_number)

## Owns all map camera gestures: scroll-wheel zoom and click-to-select on
## desktop, drag-to-pan and pinch-to-zoom on touch. This lives here (not in
## MapView, which used to handle its own clicks) because telling a tap from
## the start of a drag needs to watch the whole press-move-release
## sequence, and a single owner has to arbitrate between "this press became
## a pan" and "this press was a marker tap" -- splitting that across two
## nodes listening independently would double-handle every input.
func _unhandled_input(event: InputEvent) -> void:
	if not _gameplay_active:
		return
	if event is InputEventMouseButton:
		if _use_touch_events:
			return # real touch drives this device; ignore the emulated echo
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion and _pointer_down:
		if _use_touch_events:
			return
		_handle_drag_delta(event.relative, event.position)
	elif event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_zoom_by(ZOOM_STEP_IN)
		return
	if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_zoom_by(ZOOM_STEP_OUT)
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		_pointer_down = true
		_pointer_start_screen = event.position
		_pointer_dragged = false
	else:
		_pointer_down = false
		if not _pointer_dragged:
			map_view.handle_tap(_screen_to_ground(event.position), _effective_zoom_2d())

func _handle_drag_delta(relative: Vector2, current_screen: Vector2) -> void:
	if current_screen.distance_to(_pointer_start_screen) > TAP_DRAG_THRESHOLD:
		_pointer_dragged = true
	if _pointer_dragged:
		_pan_by_screen_delta(relative)

func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touch_points[event.index] = event.position
		if _touch_points.size() == 1:
			_pointer_down = true
			_pointer_start_screen = event.position
			_pointer_dragged = false
		elif _touch_points.size() == 2:
			_pinch_start_distance = _current_pinch_distance()
			_pinch_start_size = camera.size
		return
	var was_single_tap: bool = _touch_points.size() == 1 and not _pointer_dragged
	var tap_screen_pos: Vector2 = event.position
	_touch_points.erase(event.index)
	if _touch_points.is_empty():
		_pointer_down = false
		_pinch_start_distance = 0.0
	if was_single_tap:
		map_view.handle_tap(_screen_to_ground(tap_screen_pos), _effective_zoom_2d())

func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	_touch_points[event.index] = event.position
	if _touch_points.size() >= 2:
		_handle_pinch()
	elif _touch_points.size() == 1:
		_handle_drag_delta(event.relative, event.position)

func _current_pinch_distance() -> float:
	var points: Array = _touch_points.values()
	if points.size() < 2:
		return 0.0
	return points[0].distance_to(points[1])

func _handle_pinch() -> void:
	var distance: float = _current_pinch_distance()
	if _pinch_start_distance <= 0.0 or distance <= 0.0:
		return
	_pointer_dragged = true # two-finger contact is never a tap
	# Camera3D.size shrinks to zoom IN (opposite sense to the old
	# Camera2D.zoom), so spreading fingers apart (distance grows) divides
	# the starting size down rather than multiplying it up.
	var new_size: float = clampf(_pinch_start_size / (distance / _pinch_start_distance), MIN_CAMERA_SIZE, MAX_CAMERA_SIZE)
	camera.size = new_size

## Shared by scroll-wheel input (desktop) and the HUD's +/- buttons
## (touch/mobile, which have no scroll-wheel equivalent -- spec section 3/56).
## factor > 1 means zoom IN, matching what every call site already expects
## from the old Camera2D.zoom convention -- since a bigger Camera3D.size is
## more zoomed OUT, zooming in divides rather than multiplies.
func _zoom_by(factor: float) -> void:
	camera.size = clampf(camera.size / factor, MIN_CAMERA_SIZE, MAX_CAMERA_SIZE)

## Screen tap -> world ground position, via a ray/Y=0-plane intersection --
## the 3D equivalent of the old direct Camera2D->world coordinate read.
## Returns a position in the original 2D "world unit" space (not 3D scene
## units) since map_view.handle_tap and everything downstream of it
## (marker hit-testing, panel opening) still operates entirely in that
## space, unchanged by this whole 3D migration.
func _screen_to_ground(screen_pos: Vector2) -> Vector2:
	var origin: Vector3 = camera.project_ray_origin(screen_pos)
	var dir: Vector3 = camera.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return Vector2.ZERO
	var t: float = -origin.y / dir.y
	var hit: Vector3 = origin + dir * t
	return Vector2(hit.x, hit.z) / City3DView.WORLD_SCALE

## The Camera2D.zoom-equivalent MapView.handle_tap expects, for its
## click_radius = TAP_RADIUS_SCREEN_PX / zoom math -- that math is
## unchanged from the 2D system, just fed a value computed from
## Camera3D.size/viewport height instead of a Camera2D.zoom directly.
func _effective_zoom_2d() -> float:
	if camera.size <= 0.0:
		return 1.0
	var viewport_height: float = get_viewport().get_visible_rect().size.y
	return viewport_height * City3DView.WORLD_SCALE / camera.size

## Pans the camera along the ground plane so world content tracks the
## finger/mouse 1:1 on screen in both directions -- the forward/back
## (screen-Y) direction needs a foreshortening correction the lateral
## (screen-X) one doesn't, since the camera's fixed downward tilt means
## equal ground-plane distances along its view direction cover less
## vertical screen space than the same distance sideways.
func _pan_by_screen_delta(relative: Vector2) -> void:
	var viewport_height: float = get_viewport().get_visible_rect().size.y
	if viewport_height <= 0.0:
		return
	var world_units_per_px: float = camera.size / viewport_height
	var basis_y: Vector3 = camera.global_transform.basis.y
	var ground_forward: Vector3 = Vector3(basis_y.x, 0.0, basis_y.z)
	var foreshortening: float = ground_forward.length()
	if foreshortening < 0.0001:
		return
	ground_forward /= foreshortening
	var ground_right: Vector3 = camera.global_transform.basis.x
	camera.position -= ground_right * (relative.x * world_units_per_px)
	# + here, not -=: ground_forward is derived from the camera's local UP
	# axis projected onto the ground, which points toward the FAR/top-of-
	# screen side of the tilted view -- moving the camera further along it
	# is what pulls near/bottom-of-screen content up to reveal more of the
	# far side, the same direction relationship screen_y already has with
	# camera position once the basis.y sign flip from projecting "camera
	# up" to "screen down" is accounted for. Confirmed backwards against a
	# real drag on a real Web export (content moved up when dragging down)
	# before this fix, and correct after.
	camera.position += ground_forward * (relative.y * world_units_per_px / foreshortening)

func _begin_briefing(shift_number: int) -> void:
	_gameplay_active = false
	var roster: Array[Officer] = OfficerFactory.build_shift_roster()
	Simulation.core.prepare_shift(shift_number, SHIFT_START_MINUTE, SHIFT_DURATION_MINUTES, roster)
	map_view.refresh_units()
	weather_overlay.refresh() # weather is rolled fresh by prepare_shift -- reflect it immediately

	hud_view.hide()
	incident_panel.close()
	unit_panel.close()
	neighbourhood_panel.close()
	resources_panel.close()
	incidents_list_panel.close()

	_briefing_view = BriefingView.new()
	add_child(_briefing_view)
	_briefing_view.setup(Simulation.core.world, shift_number)
	_briefing_view.confirmed.connect(_on_briefing_confirmed)

func _on_briefing_confirmed() -> void:
	_gameplay_active = true
	_briefing_view.queue_free()
	_briefing_view = null
	hud_view.show()
	# Without this, the HUD would show stale zeros (whatever it last
	# displayed before this shift existed) until the first simulation
	# tick fires, up to ~1 real second later at 1x speed.
	hud_view.refresh_stats()
	# Always-docked chrome (spec's mockup asked for the same permanent
	# position as its desktop render) -- open by default the moment play
	# actually starts, not on the briefing/debrief screens either side of it.
	resources_panel.open()
	incidents_list_panel.open()
	_refresh_panel_pills()

## Keeps the HUD's Team/Res/Inc pills lit in step with which panels are
## actually open -- the mockup shows the current panel called out this
## way, and reading real panel state (rather than remembering taps) means
## a panel closed by its own Close button, or by close_other_panels
## arbitration, still updates its pill.
func _refresh_panel_pills() -> void:
	if hud_view == null:
		return
	hud_view.set_panel_active("Team", neighbourhood_panel.is_open())
	hud_view.set_panel_active("Res", resources_panel.is_open())
	hud_view.set_panel_active("Inc", incidents_list_panel.is_open())

func _on_shift_ended(summary: Dictionary) -> void:
	_gameplay_active = false
	hud_view.hide()
	incident_panel.close()
	unit_panel.close()
	neighbourhood_panel.close()
	resources_panel.close()
	incidents_list_panel.close()

	SaveManager.save(Simulation.core, int(summary["shift_number"]) + 1)

	_debrief_view = DebriefView.new()
	add_child(_debrief_view)
	_debrief_view.setup(summary)
	_debrief_view.start_next_shift.connect(_on_start_next_shift)

func _on_start_next_shift() -> void:
	var next_shift_number: int = Simulation.core.shift_manager.shift_state.shift_number + 1
	_debrief_view.queue_free()
	_debrief_view = null
	_begin_briefing(next_shift_number)
