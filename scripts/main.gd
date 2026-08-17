extends Node2D
## Milestone 2 entry point (spec section 61 Phase 3). Wires the one real
## SimulationCore (owned by the Simulation autoload) up to a minimal
## code-built map + HUD -- no .tscn authoring beyond this scene's own bare
## root, since hand-writing Godot's scene resource format without the
## editor available to validate it is far riskier than building node trees
## with add_child() calls, which is ordinary GDScript. See
## docs/ARCHITECTURE.md section 3 for the Simulation<->Presentation
## contract this follows (signals out, pull for high-frequency data,
## validated commands in -- never direct state mutation from here).

var map_view: MapView
var hud_view: HudView
var camera: Camera2D

func _ready() -> void:
	var world: WorldMapData = TestMapFactory.build()
	var incident_types: Array[IncidentTypeDefinition] = IncidentTypeFactory.build_all()
	var events: Array[EventDefinition] = EventFactory.build_all()
	Simulation.core.initialize(world, incident_types, events, 0) # 0 = random seed for a normal play session

	var roster: Array[Officer] = OfficerFactory.build_shift_roster()
	var priorities: Array[String] = ["asb", "town_centre_disorder"]
	Simulation.core.start_shift(1, 17 * 60, 12 * 60, roster, priorities, 2)

	camera = Camera2D.new()
	camera.position = Vector2(700, -600) # roughly centred on the small test map
	camera.zoom = Vector2(0.3, 0.3) # zoomed out enough to see the whole map; scroll to adjust
	add_child(camera)
	camera.make_current()

	map_view = MapView.new()
	add_child(map_view)
	map_view.setup(world)

	hud_view = HudView.new()
	add_child(hud_view)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.zoom *= 1.1
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom *= 0.9
