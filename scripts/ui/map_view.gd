class_name MapView
extends Node2D
## Draws the map (roads, locations, district boundaries) and manages
## UnitMarker/IncidentMarker child nodes reactively via SimulationCore's
## signals (spec section 35-37). No art assets yet -- everything is drawn
## with simple primitives, which is honest about where this is in the
## phased plan (spec section 54: readable and mobile-friendly matters far
## more than polish this early) rather than faking it.
##
## Clicking a unit opens UnitPanelView (welfare/breaks, spec section 14);
## clicking an incident marker opens IncidentPanelView (dispatch/reassign/
## recall/intent, spec section 25-27). The two panels are mutually
## exclusive -- opening one closes the other, since both anchor to the
## same screen position.

const PRIORITY_COLORS := {
	1: Color(0.85, 0.15, 0.15), # critical -- red
	2: Color(0.95, 0.55, 0.1),  # urgent -- orange
	3: Color(0.95, 0.85, 0.1),  # important -- yellow
	4: Color(0.3, 0.75, 0.3),   # routine -- green
	5: Color(0.3, 0.75, 0.3),   # non-urgent -- green
}

const CLICK_RADIUS := 40.0

## Map overlays (spec section 41) -- simple district tinting, not a real
## heatmap texture, which is enough at this scale/fidelity per section 54.
enum OverlayType { NONE, ASB, VIOLENCE, BURGLARY, VISIBILITY, DEMAND }

const DEFAULT_DISTRICT_COLOR := Color(0.5, 0.6, 0.8, 0.08)
const OVERLAY_NOISE_REFRESH_TICKS := 15 # simulated minutes between fuzz re-rolls

var _world: WorldMapData
var _incident_panel: IncidentPanelView
var _unit_panel: UnitPanelView
var _unit_markers: Dictionary = {} # unit_id -> UnitMarker
var _incident_markers: Dictionary = {} # incident_id -> IncidentMarker
var _district_polygons: Dictionary = {} # district_id -> Polygon2D
var _selected_unit_id: String = ""
var _current_overlay: OverlayType = OverlayType.NONE
var _overlay_noise: Dictionary = {} # district_id -> float
var _overlay_tick_counter: int = 0

func setup(world: WorldMapData, incident_panel: IncidentPanelView, unit_panel: UnitPanelView) -> void:
	_world = world
	_incident_panel = incident_panel
	_unit_panel = unit_panel
	_unit_panel.closed.connect(func(): _select_unit(""))
	_draw_static_map()
	_spawn_unit_markers()
	_spawn_existing_incident_markers()

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
		poly.color = DEFAULT_DISTRICT_COLOR
		add_child(poly)
		_district_polygons[district.id] = poly
		var label := Label.new()
		label.text = district.display_name
		label.position = _polygon_centroid(district.boundary) - Vector2(40, 8)
		label.modulate = Color(0.6, 0.65, 0.75)
		add_child(label)

	_draw_building_footprints()

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

## Purely decorative building footprints (spec section 53 wants 500-800 of
## these) -- generated here at draw time from each district's boundary,
## never stored as WorldMapData, since they carry zero gameplay meaning
## and hundreds of rectangle records would only bloat the world data for
## something the simulation layer never needs to know about. A fixed seed
## keeps the layout stable across runs rather than reshuffling every load.
const BUILDING_SEED := 990817
const BUILDING_COUNT_BY_DISTRICT := {
	"town_centre": 160, "northside": 110, "east_estate": 100,
	"south_residential": 130, "west_industrial": 90, "rural_outskirts": 60,
}
const DEFAULT_BUILDING_COUNT := 60

func _draw_building_footprints() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = BUILDING_SEED
	for district: DistrictDefinition in _world.districts:
		if district.boundary.size() < 3:
			continue
		var center: Vector2 = _polygon_centroid(district.boundary)
		var radius: float = center.distance_to(district.boundary[0])
		var count: int = BUILDING_COUNT_BY_DISTRICT.get(district.id, DEFAULT_BUILDING_COUNT)
		for i in range(count):
			var angle: float = rng.randf_range(0.0, TAU)
			# sqrt of a uniform [0,1] sample gives a uniform-by-area
			# distribution across the circle, rather than clumping near
			# the centre the way a plain linear radius sample would.
			var dist: float = sqrt(rng.randf_range(0.0, 1.0)) * radius
			if dist < radius * 0.12:
				continue # leave the district's hub area visually clear
			var pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * dist
			var size := Vector2(rng.randf_range(18.0, 42.0), rng.randf_range(18.0, 42.0))
			var shade: float = rng.randf_range(0.32, 0.5)
			var building := _make_rect(size, Color(shade, shade * 0.96, shade * 0.9, 0.8))
			building.position = pos
			add_child(building)

func _make_rect(size: Vector2, color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(-size.x / 2.0, -size.y / 2.0), Vector2(size.x / 2.0, -size.y / 2.0),
		Vector2(size.x / 2.0, size.y / 2.0), Vector2(-size.x / 2.0, size.y / 2.0),
	])
	poly.color = color
	return poly

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

## Markers for incidents that already existed before this MapView was set
## up -- i.e. carried over from a loaded save (spec section 47/67). New
## incidents generated during play arrive via _on_incident_created instead.
func _spawn_existing_incident_markers() -> void:
	for incident_id in Simulation.core.incident_manager.active_incidents.keys():
		_create_incident_marker(incident_id)

func _on_incident_created(incident_id: String) -> void:
	_create_incident_marker(incident_id)

func _create_incident_marker(incident_id: String) -> void:
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
	if _unit_panel and _unit_panel.visible:
		_unit_panel.refresh()
	if _current_overlay != OverlayType.NONE:
		_overlay_tick_counter += 1
		if _overlay_tick_counter >= OVERLAY_NOISE_REFRESH_TICKS:
			_overlay_tick_counter = 0
			_refresh_overlay_noise()
		_apply_overlay()

## Called by HudView's overlay buttons (spec section 41).
func set_overlay(overlay: OverlayType) -> void:
	_current_overlay = overlay
	_overlay_tick_counter = 0
	_refresh_overlay_noise()
	_apply_overlay()

func _apply_overlay() -> void:
	for district_id in _district_polygons.keys():
		var poly: Polygon2D = _district_polygons[district_id]
		if _current_overlay == OverlayType.NONE:
			poly.color = DEFAULT_DISTRICT_COLOR
			continue
		var district: DistrictState = Simulation.core.district_manager.get_state(district_id)
		if district == null:
			continue
		var value: float = _overlay_value(district)
		# Low intelligence quality blurs the displayed value toward a
		# per-district random offset, refreshed only occasionally (not
		# every frame) so it reads as "uncertain," not flickering.
		var noise: float = _overlay_noise.get(district_id, 0.0)
		var displayed: float = clampf(value + noise, 0.0, 100.0)
		# Visibility is the one overlay where HIGH is good, not bad --
		# invert it so the heat colour still means "this needs attention."
		var heat_input: float = 100.0 - displayed if _current_overlay == OverlayType.VISIBILITY else displayed
		poly.color = _heat_color(heat_input)

func _overlay_value(district: DistrictState) -> float:
	match _current_overlay:
		OverlayType.ASB: return district.asb
		OverlayType.VIOLENCE: return district.violence
		OverlayType.BURGLARY: return district.burglary_risk
		OverlayType.VISIBILITY: return district.police_visibility
		OverlayType.DEMAND: return district.incident_pressure
		_: return 0.0

func _refresh_overlay_noise() -> void:
	_overlay_noise.clear()
	for district_id in _district_polygons.keys():
		var district: DistrictState = Simulation.core.district_manager.get_state(district_id)
		var quality: float = district.intel_quality if district else 50.0
		var noise_range: float = (100.0 - quality) * 0.3
		_overlay_noise[district_id] = randf_range(-noise_range, noise_range)

func _heat_color(value: float) -> Color:
	var t: float = clampf(value / 100.0, 0.0, 1.0)
	var color: Color
	if t < 0.5:
		color = Color(0.3, 0.75, 0.3).lerp(Color(0.9, 0.85, 0.2), t * 2.0)
	else:
		color = Color(0.9, 0.85, 0.2).lerp(Color(0.9, 0.2, 0.2), (t - 0.5) * 2.0)
	color.a = 0.35
	return color

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click(get_global_mouse_position())

func _handle_click(click_pos: Vector2) -> void:
	for unit_id in _unit_markers.keys():
		var marker: UnitMarker = _unit_markers[unit_id]
		if marker.position.distance_to(click_pos) <= CLICK_RADIUS:
			if _incident_panel:
				_incident_panel.close()
			if _unit_panel:
				_unit_panel.open(unit_id)
			_select_unit(unit_id)
			return
	for incident_id in _incident_markers.keys():
		var marker: IncidentMarker = _incident_markers[incident_id]
		if marker.position.distance_to(click_pos) <= CLICK_RADIUS:
			if _unit_panel:
				_unit_panel.close()
			if _incident_panel:
				_incident_panel.open(incident_id)
			return
	# Clicked empty space -- close whichever panel is open.
	if _incident_panel:
		_incident_panel.close()
	if _unit_panel:
		_unit_panel.close()

func _select_unit(unit_id: String) -> void:
	if _selected_unit_id != "" and _unit_markers.has(_selected_unit_id):
		_unit_markers[_selected_unit_id].set_selected(false)
	_selected_unit_id = unit_id
	if unit_id != "" and _unit_markers.has(unit_id):
		_unit_markers[unit_id].set_selected(true)
