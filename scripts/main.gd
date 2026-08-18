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
var day_night_overlay: DayNightOverlay
var weather_overlay: WeatherOverlay
var audio_manager: AudioManager
var rotate_prompt: RotatePromptOverlay
var camera: Camera2D
var _briefing_view: BriefingView
var _debrief_view: DebriefView

## Bigger per-tap step than a desktop scroll-wheel needs, since a phone's
## on-screen +/- buttons (spec section 56) get far fewer discrete inputs
## than a wheel does -- reaching a meaningfully different zoom level
## should take a handful of taps, not fifteen-plus.
const ZOOM_STEP_IN := 1.25
const ZOOM_STEP_OUT := 0.8
const MIN_ZOOM := 0.02
const MAX_ZOOM := 2.5

## A press/touch that moves less than this many screen pixels before
## release is a tap (dispatch to MapView.handle_tap); anything past it is
## a drag/pan instead. Without this, click-to-select and drag-to-pan can't
## coexist on the same pointer down/up sequence.
const TAP_DRAG_THRESHOLD := 14.0

var _pointer_down: bool = false
var _pointer_start_screen: Vector2 = Vector2.ZERO
var _pointer_dragged: bool = false
var _touch_points: Dictionary = {} # touch index -> Vector2 screen position
var _pinch_start_distance: float = 0.0
var _pinch_start_zoom: float = 0.0

## Raises every Control's default text size (Godot's built-in default is
## 16) before any UI exists -- real phone playtesting found the whole
## game illegibly small even after fixing the map's default zoom, since
## most labels/buttons never set an explicit font size and just inherited
## the engine default. Assigning this to the root Window cascades to every
## Control created afterwards, in every view built across this whole
## session, without editing each one's theme individually.
const DEFAULT_FONT_SIZE := 22

func _ready() -> void:
	# Web export emulates mouse events from real touch input by default, so
	# without this a single finger drag fires both a real
	# InputEventScreenDrag and a synthetic InputEventMouseMotion for the same
	# physical movement -- _unhandled_input below handles both, so every
	# drag got applied twice (and pinch fought with a phantom mouse-drag
	# from whichever finger the browser picked as "primary"). Confirmed via
	# real mobile playtesting: panning was wildly oversensitive and pinch
	# barely worked. Controls/Buttons handle real touch input natively, so
	# nothing in this project actually needs the emulated mouse events.
	Input.set_emulate_mouse_from_touch(false)

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

	camera = Camera2D.new()
	# Starts centred on Town Centre / the police station (both sit at the
	# world origin) at a close-enough zoom to actually read buildings, unit
	# markers, and location labels -- the old default zoomed out to fit the
	# entire 6-district town in frame, which was illegible on a real phone
	# screen (confirmed by real mobile playtesting, not just a screenshot at
	# desktop resolution). Zoom out via scroll/the HUD's -/+ buttons to see
	# the wider town from here.
	camera.position = Vector2(0, 0)
	camera.zoom = Vector2(0.18, 0.18)
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

	map_view = MapView.new()
	add_child(map_view)
	map_view.setup(world, incident_panel, unit_panel)

	hud_view = HudView.new()
	add_child(hud_view)
	hud_view.wire_overlays(map_view)
	hud_view.wire_zoom_controls(func(): _zoom_by(ZOOM_STEP_IN), func(): _zoom_by(ZOOM_STEP_OUT))
	hud_view.wire_neighbourhood_panel(func(): neighbourhood_panel.open())
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
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion and _pointer_down:
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
			map_view.handle_tap(get_global_mouse_position())

func _handle_drag_delta(relative: Vector2, current_screen: Vector2) -> void:
	if current_screen.distance_to(_pointer_start_screen) > TAP_DRAG_THRESHOLD:
		_pointer_dragged = true
	if _pointer_dragged:
		camera.position -= relative / camera.zoom

func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touch_points[event.index] = event.position
		if _touch_points.size() == 1:
			_pointer_down = true
			_pointer_start_screen = event.position
			_pointer_dragged = false
		elif _touch_points.size() == 2:
			_pinch_start_distance = _current_pinch_distance()
			_pinch_start_zoom = camera.zoom.x
		return
	var was_single_tap: bool = _touch_points.size() == 1 and not _pointer_dragged
	_touch_points.erase(event.index)
	if _touch_points.is_empty():
		_pointer_down = false
		_pinch_start_distance = 0.0
	if was_single_tap:
		map_view.handle_tap(get_global_mouse_position())

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
	var new_zoom: float = clampf(_pinch_start_zoom * (distance / _pinch_start_distance), MIN_ZOOM, MAX_ZOOM)
	camera.zoom = Vector2(new_zoom, new_zoom)

## Shared by scroll-wheel input (desktop) and the HUD's +/- buttons
## (touch/mobile, which have no scroll-wheel equivalent -- spec section 3/56).
func _zoom_by(factor: float) -> void:
	camera.zoom = (camera.zoom * factor).clamp(Vector2(MIN_ZOOM, MIN_ZOOM), Vector2(MAX_ZOOM, MAX_ZOOM))

func _begin_briefing(shift_number: int) -> void:
	var roster: Array[Officer] = OfficerFactory.build_shift_roster()
	Simulation.core.prepare_shift(shift_number, SHIFT_START_MINUTE, SHIFT_DURATION_MINUTES, roster)
	map_view.refresh_units()
	weather_overlay.refresh() # weather is rolled fresh by prepare_shift -- reflect it immediately

	hud_view.hide()
	incident_panel.close()
	unit_panel.close()
	neighbourhood_panel.close()

	_briefing_view = BriefingView.new()
	add_child(_briefing_view)
	_briefing_view.setup(Simulation.core.world, shift_number)
	_briefing_view.confirmed.connect(_on_briefing_confirmed)

func _on_briefing_confirmed() -> void:
	_briefing_view.queue_free()
	_briefing_view = null
	hud_view.show()
	# Without this, the HUD would show stale zeros (whatever it last
	# displayed before this shift existed) until the first simulation
	# tick fires, up to ~1 real second later at 1x speed.
	hud_view.refresh_stats()

func _on_shift_ended(summary: Dictionary) -> void:
	hud_view.hide()
	incident_panel.close()
	unit_panel.close()
	neighbourhood_panel.close()

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
