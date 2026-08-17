class_name MapView
extends Node2D
## Draws the map (roads, locations, district boundaries) and manages
## UnitMarker/IncidentMarker child nodes reactively via SimulationCore's
## signals (spec section 35-37). No art assets yet -- everything is drawn
## with simple primitives, which is honest about where this is in the
## phased plan (spec section 54: readable and mobile-friendly matters far
## more than polish this early) rather than faking it.
##
## Clicking a unit is a lightweight visual select (no functional effect);
## clicking an incident marker opens IncidentPanelView, which owns every
## actual dispatch/reassign/recall/intent action (spec section 25-27) --
## Milestone 2's click-unit-then-click-incident quick-dispatch shortcut is
## gone, replaced by the panel it was always meant to lead to.

const PRIORITY_COLORS := {
	1: Color(0.85, 0.15, 0.15), # critical -- red
	2: Color(0.95, 0.55, 0.1),  # urgent -- orange
	3: Color(0.95, 0.85, 0.1),  # important -- yellow
	4: Color(0.3, 0.75, 0.3),   # routine -- green
	5: Color(0.3, 0.75, 0.3),   # non-urgent -- green
}

const CLICK_RADIUS := 40.0

var _world: WorldMapData
var _incident_panel: IncidentPanelView
var _unit_markers: Dictionary = {} # unit_id -> UnitMarker
var _incident_markers: Dictionary = {} # incident_id -> IncidentMarker
var _selected_unit_id: String = ""

func setup(world: WorldMapData, incident_panel: IncidentPanelView) -> void:
	_world = world
	_incident_panel = incident_panel
	_draw_static_map()
	_spawn_unit_markers()

	Simulation.core.incident_manager.incident_created.connect(_on_incident_created)
	Simulation.core.incident_manager.incident_state_changed.connect(_on_incident_state_changed)
	Simulation.core.incident_manager.incident_resolved.connect(_on_incident_resolved)
	Simulation.core.tick_completed.connect(_on_tick_completed)

## Shared by UnitMarker/IncidentMarker too, so the circle-approximation
## logic lives in exactly one place. segments=4 with the same formula
## yields a diamond, used to make incident markers visually distinct from
## unit markers without needing separate art.
static func make_circle(radius: float, color: Color, segments: int = 16) -> Polygon2D:
	var points := PackedVector2Array()
	for i in range(segments):
		var angle: float = TAU * i / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	var poly := Polygon2D.new()
	poly.polygon = points
	poly.color = color
	return poly

func _draw_static_map() -> void:
	for district: DistrictDefinition in _world.districts:
		if district.boundary.size() < 3:
			continue
		var poly := Polygon2D.new()
		poly.polygon = district.boundary
		poly.color = Color(0.5, 0.6, 0.8, 0.08)
		add_child(poly)
		var label := Label.new()
		label.text = district.display_name
		label.position = _polygon_centroid(district.boundary) - Vector2(40, 8)
		label.modulate = Color(0.6, 0.65, 0.75)
		add_child(label)

	for edge: RoadEdge in _world.road_edges:
		var from_node: RoadNode = _find_road_node(edge.from_id)
		var to_node: RoadNode = _find_road_node(edge.to_id)
		if from_node == null or to_node == null:
			continue
		var line := Line2D.new()
		line.points = PackedVector2Array([from_node.position, to_node.position])
		line.width = 24.0
		line.default_color = Color(0.55, 0.55, 0.58)
		add_child(line)

	for location: LocationDefinition in _world.locations:
		var marker := Node2D.new()
		marker.position = location.position
		add_child(marker)
		var is_station: bool = location.tags.has("station")
		var radius: float = 18.0 if is_station else 10.0
		var color: Color = Color(0.2, 0.35, 0.85) if is_station else Color(0.75, 0.75, 0.78)
		marker.add_child(make_circle(radius, color))
		var label := Label.new()
		label.text = location.display_name
		label.position = Vector2(14, -8)
		label.add_theme_font_size_override("font_size", 12)
		label.modulate = Color(0.85, 0.85, 0.85)
		marker.add_child(label)

func _find_road_node(node_id: String) -> RoadNode:
	for node: RoadNode in _world.road_nodes:
		if node.id == node_id:
			return node
	return null

func _polygon_centroid(points: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for p in points:
		sum += p
	return sum / points.size()

func _spawn_unit_markers() -> void:
	for unit: PoliceUnit in Simulation.core.resource_manager.units.values():
		var marker := UnitMarker.new()
		add_child(marker)
		marker.setup(unit)
		_unit_markers[unit.id] = marker

## Called by main.gd whenever a new shift forms a new roster/units --
## Milestone 1/2's units don't persist across shifts the way districts and
## incidents do, so their markers need rebuilding from scratch.
func refresh_units() -> void:
	for marker in _unit_markers.values():
		marker.queue_free()
	_unit_markers.clear()
	_selected_unit_id = ""
	_spawn_unit_markers()

func _on_incident_created(incident_id: String) -> void:
	var incident: Incident = Simulation.core.incident_manager.get_incident(incident_id)
	if incident == null:
		return
	var location: LocationDefinition = _world.get_location(incident.location_id)
	var marker := IncidentMarker.new()
	add_child(marker)
	marker.setup(incident, location.position if location else Vector2.ZERO)
	_incident_markers[incident_id] = marker

func _on_incident_state_changed(incident_id: String, _old_state: GameEnums.IncidentState, _new_state: GameEnums.IncidentState) -> void:
	if _incident_markers.has(incident_id):
		_incident_markers[incident_id].refresh()
	if _incident_panel and _incident_panel.is_open_for(incident_id):
		_incident_panel.refresh()

func _on_incident_resolved(incident_id: String, _outcome_id: String) -> void:
	if _incident_markers.has(incident_id):
		_incident_markers[incident_id].queue_free()
		_incident_markers.erase(incident_id)
	if _incident_panel and _incident_panel.is_open_for(incident_id):
		_incident_panel.close()

func _on_tick_completed() -> void:
	for unit_id in _unit_markers.keys():
		_unit_markers[unit_id].on_tick()
	# Assigned/available lists in an open panel change as units move and
	# arrive even without an explicit state-change signal (e.g. a unit
	# reaching ON_SCENE updates its own status but that's driven by
	# ResourceManager.tick, not an incident signal) -- cheap to just
	# refresh every tick while a panel is actually open.
	if _incident_panel and _incident_panel.visible:
		_incident_panel.refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click(get_global_mouse_position())

func _handle_click(click_pos: Vector2) -> void:
	for unit_id in _unit_markers.keys():
		var marker: UnitMarker = _unit_markers[unit_id]
		if marker.position.distance_to(click_pos) <= CLICK_RADIUS:
			_select_unit(unit_id)
			return
	for incident_id in _incident_markers.keys():
		var marker: IncidentMarker = _incident_markers[incident_id]
		if marker.position.distance_to(click_pos) <= CLICK_RADIUS:
			if _incident_panel:
				_incident_panel.open(incident_id)
			return
	_select_unit("") # clicked empty space -- deselect, and leave any open panel as-is

func _select_unit(unit_id: String) -> void:
	if _selected_unit_id != "" and _unit_markers.has(_selected_unit_id):
		_unit_markers[_selected_unit_id].set_selected(false)
	_selected_unit_id = unit_id
	if unit_id != "" and _unit_markers.has(unit_id):
		_unit_markers[unit_id].set_selected(true)
