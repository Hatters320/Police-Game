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
var audio_manager: AudioManager
var camera: Camera2D
var _briefing_view: BriefingView
var _debrief_view: DebriefView

const ZOOM_STEP_IN := 1.1
const ZOOM_STEP_OUT := 0.9

func _ready() -> void:
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
	# Centred on the full Westford map's bounding box (roughly
	# x: -3800..3850, y: -3500..6400) with room to breathe -- checked
	# against a real rendered screenshot, not guessed blind.
	camera.position = Vector2(25, 1450)
	camera.zoom = Vector2(0.05, 0.05)
	add_child(camera)
	camera.make_current()

	day_night_overlay = DayNightOverlay.new()
	add_child(day_night_overlay)

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

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_by(ZOOM_STEP_IN)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_by(ZOOM_STEP_OUT)

## Shared by scroll-wheel input (desktop) and the HUD's +/- buttons
## (touch/mobile, which have no scroll-wheel equivalent -- spec section 3/56).
func _zoom_by(factor: float) -> void:
	camera.zoom *= factor

func _begin_briefing(shift_number: int) -> void:
	var roster: Array[Officer] = OfficerFactory.build_shift_roster()
	Simulation.core.prepare_shift(shift_number, SHIFT_START_MINUTE, SHIFT_DURATION_MINUTES, roster)
	map_view.refresh_units()

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
