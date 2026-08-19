class_name MapView
extends Node2D
## Owns unit/incident marker DATA and all tap-to-select/panel-opening
## logic (spec section 35-37) -- it no longer draws anything itself.
## City3DView (a real Node3D scene built from Kenney low-poly kits, per
## the player's request to move from the flat 2D map to a proper 3D city)
## now owns 100% of what's actually on screen; this class's own Node2D
## drawing methods (_draw_static_map and everything it used to call) are
## unused and kept only as an easy fallback/reference, never invoked.
## UnitMarker/IncidentMarker stay real Node2D children exactly as before,
## but purely as invisible position-tracking + panel-triggering data
## objects now -- MapView is simply never given a Camera2D to render
## through, so nothing they draw is ever seen, but every distance/hit-test
## calculation below still works completely unchanged, since it always
## operated on marker.position in the original 2D "world unit" coordinate
## space, never on screen pixels directly.
##
## Clicking a unit opens UnitPanelView (welfare/breaks, spec section 14);
## clicking an incident marker opens IncidentPanelView (dispatch/reassign/
## recall/intent, spec section 25-27). The two panels are mutually
## exclusive -- opening one closes the other, since both anchor to the
## same screen position.

const POLICE_STATION_TEXTURE := preload("res://data/art/police_station.png")
## Displayed width in world units -- big enough to read as the player's
## home base among the procedural building rects, without dwarfing a
## district (radius ~900).
const POLICE_STATION_DISPLAY_WIDTH := 170.0

const PRIORITY_COLORS := {
	1: Color(0.85, 0.15, 0.15), # critical -- red
	2: Color(0.95, 0.55, 0.1),  # urgent -- orange
	3: Color(0.95, 0.85, 0.1),  # important -- yellow
	4: Color(0.3, 0.75, 0.3),   # routine -- green
	5: Color(0.3, 0.75, 0.3),   # non-urgent -- green
}

## A real touch-target radius in SCREEN pixels, not world units -- the old
## flat 40-world-unit CLICK_RADIUS was tuned once against a fixed desktop
## zoom, but main.gd's camera now ranges 0.04-2.5x zoom, and world-space
## distance shrinks to almost nothing on screen once zoomed out (at the
## default 0.18 zoom it was already only ~7px; zoomed further out to see
## several incidents at once -- exactly when a player most needs to tap
## one -- it was closer to 2-3px). Confirmed by a real user unable to tap
## incidents at all. _click_radius_world() converts this back to world
## units against the CURRENT zoom each time, so the actual on-screen
## target size stays constant regardless of how zoomed in/out the camera is.
const TAP_RADIUS_SCREEN_PX := 44.0

## Map overlays (spec section 41) -- simple district tinting, not a real
## heatmap texture, which is enough at this scale/fidelity per section 54.
enum OverlayType { NONE, ASB, VIOLENCE, BURGLARY, VISIBILITY, DEMAND }

const DEFAULT_DISTRICT_COLOR := Color(0.5, 0.6, 0.8, 0.08)
const OVERLAY_NOISE_REFRESH_TICKS := 15 # simulated minutes between fuzz re-rolls

## Loose SimCity-style land-use tint per district (spec's target art
## direction, section 2/61) -- still flat colour fills, no textures, but
## gives each zone a distinct identity at a glance instead of one uniform
## tint everywhere. Falls back to DEFAULT_DISTRICT_COLOR for any id not
## listed here (e.g. a future map with different districts).
const DISTRICT_BASE_COLORS := {
	"town_centre": Color(0.62, 0.56, 0.42, 0.16),        # urban/commercial -- warm tan
	"northside": Color(0.42, 0.5, 0.36, 0.14),            # residential -- soft green-brown
	"east_estate": Color(0.42, 0.5, 0.36, 0.14),          # residential -- soft green-brown
	"south_residential": Color(0.42, 0.5, 0.36, 0.14),    # residential -- soft green-brown
	"west_industrial": Color(0.45, 0.5, 0.56, 0.16),      # industrial -- cool blue-grey
	"rural_outskirts": Color(0.36, 0.5, 0.3, 0.16),       # farmland -- richer green
}

## Ground-base tint per district, matching the palette above but used for
## building colour selection (BUILDING_PALETTE) rather than the polygon
## fill itself.
enum LandUse { URBAN, RESIDENTIAL, INDUSTRIAL, RURAL }
const DISTRICT_LAND_USE := {
	"town_centre": LandUse.URBAN,
	"northside": LandUse.RESIDENTIAL,
	"east_estate": LandUse.RESIDENTIAL,
	"south_residential": LandUse.RESIDENTIAL,
	"west_industrial": LandUse.INDUSTRIAL,
	"rural_outskirts": LandUse.RURAL,
}
const BUILDING_PALETTE := {
	LandUse.URBAN: [Color(0.55, 0.42, 0.34), Color(0.5, 0.46, 0.4), Color(0.58, 0.5, 0.3)],
	LandUse.RESIDENTIAL: [Color(0.58, 0.38, 0.3), Color(0.5, 0.42, 0.32), Color(0.55, 0.46, 0.36)],
	LandUse.INDUSTRIAL: [Color(0.42, 0.44, 0.48), Color(0.36, 0.4, 0.44), Color(0.46, 0.46, 0.42)],
	LandUse.RURAL: [Color(0.42, 0.36, 0.26), Color(0.48, 0.42, 0.3)],
}

## Backdrop ground colour behind the whole map -- grass/earth rather than
## void black, so the town reads as sitting on a landscape (spec's
## SimCity-style target, section 2).
const GROUND_COLOR := Color(0.16, 0.19, 0.15)
const GROUND_MARGIN := 600.0

var _world: WorldMapData
var _incident_panel: IncidentPanelView
var _unit_panel: UnitPanelView
var _unit_markers: Dictionary = {} # unit_id -> UnitMarker
var _incident_markers: Dictionary = {} # incident_id -> IncidentMarker
var _district_polygons: Dictionary = {} # district_id -> Polygon2D
var _district_base_colors: Dictionary = {} # district_id -> Color, this district's NONE-overlay fill
var _selected_unit_id: String = ""
var _current_overlay: OverlayType = OverlayType.NONE
var _overlay_noise: Dictionary = {} # district_id -> float
var _overlay_tick_counter: int = 0
## Fixed yaw+pitch the 3D camera is created with in main.gd, and the fixed
## distance back along that facing from whatever ground point it's focused
## on. All three are constant for the camera's whole lifetime (only the
## ground focus point and orthogonal size/zoom ever change), so the offset
## from a focus point to the actual camera position is always the same
## vector -- one source of truth shared by main.gd (which sets the
## camera's rotation and does per-frame panning) and pan_camera_to below
## (which needs to reproduce the same math for the list-panel "jump to
## this location" shortcut). 45 degrees of yaw plus a shallow ~32 degree
## pitch is a classic city-builder dimetric/isometric look (streets run
## diagonally across the screen rather than straight up/down) -- matches
## a mockup the player supplied directly, replacing the original
## steeper, non-rotated top-down-ish tilt from the first 3D pass.
const CAMERA_YAW_DEG := 45.0
const CAMERA_PITCH_DEG := -32.0
const CAMERA_DISTANCE := 34.0

var _camera: Camera3D
var _neighbourhood_panel: NeighbourhoodPanelView

func setup(world: WorldMapData, incident_panel: IncidentPanelView, unit_panel: UnitPanelView) -> void:
	_world = world
	_incident_panel = incident_panel
	_unit_panel = unit_panel
	_unit_panel.closed.connect(func(): _select_unit(""))
	Simulation.core.incident_manager.incident_created.connect(_on_incident_created)
	Simulation.core.incident_manager.incident_state_changed.connect(_on_incident_state_changed)
	Simulation.core.incident_manager.incident_resolved.connect(_on_incident_resolved)
	Simulation.core.tick_completed.connect(_on_tick_completed)
	_spawn_unit_markers()
	_spawn_existing_incident_markers()

## Called once by main.gd after the neighbourhood panel exists.
## Resources/Incidents are always-docked chrome now (spec's mockup asked
## for the same permanent position as its desktop render, just sized for
## a phone) -- they stay visible the whole time and never need closing, so
## close_other_panels below only ever needs to arbitrate between the three
## detail overlays (Incident/Unit/Neighbourhood), which still are mutually
## exclusive and draw on a higher CanvasLayer, on top of the docked ones.
func wire_other_panels(neighbourhood_panel: NeighbourhoodPanelView) -> void:
	_neighbourhood_panel = neighbourhood_panel

func close_other_panels(except: Node = null) -> void:
	for panel in [_incident_panel, _unit_panel, _neighbourhood_panel]:
		if panel and panel != except and panel.is_open():
			panel.close()

func set_camera(camera: Camera3D) -> void:
	_camera = camera

## The camera's fixed orientation as a Basis -- same Euler order Node3D's
## own `rotation` property uses internally (YXZ), so this always matches
## camera.global_transform.basis exactly for whatever rotation main.gd
## sets from CAMERA_YAW_DEG/CAMERA_PITCH_DEG.
static func camera_basis() -> Basis:
	return Basis.from_euler(Vector3(deg_to_rad(CAMERA_PITCH_DEG), deg_to_rad(CAMERA_YAW_DEG), 0.0))

## The constant offset from a ground focus point to the camera position,
## given the fixed yaw/pitch tilt and CAMERA_DISTANCE back-off -- see the
## doc comment on those consts above.
static func camera_ground_offset() -> Vector3:
	return camera_basis().z * CAMERA_DISTANCE

## Recentres the map on a world position without changing zoom -- used by
## the resources/incidents list panels (spec: selecting an entry "should
## take the map to the [unit/incident] location") so a player doesn't have
## to hunt for it on the map themselves after picking it from a list.
## world_pos is still in the original 2D "world unit" space (everything
## that calls this -- list panels, unit/incident lookups -- only ever
## deals in that space), converted to the 3D scene via City3DView's own
## WORLD_SCALE so the two stay in lockstep however that constant changes.
func pan_camera_to(world_pos: Vector2) -> void:
	if _camera:
		var focus_3d := Vector3(world_pos.x, 0.0, world_pos.y) * City3DView.WORLD_SCALE
		_camera.position = focus_3d + camera_ground_offset()

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
	_draw_ground_backdrop()

	for district: DistrictDefinition in _world.districts:
		if district.boundary.size() < 3:
			continue
		var base_color: Color = DISTRICT_BASE_COLORS.get(district.id, DEFAULT_DISTRICT_COLOR)
		_district_base_colors[district.id] = base_color
		var poly := Polygon2D.new()
		poly.polygon = district.boundary
		poly.color = base_color
		add_child(poly)
		_district_polygons[district.id] = poly

		# Zone edge outline so districts read as distinct areas rather than
		# soft unbounded tints (SimCity-style zone borders, spec section 2).
		var outline := Line2D.new()
		var loop: PackedVector2Array = district.boundary.duplicate()
		loop.append(district.boundary[0])
		outline.points = loop
		outline.width = 3.0
		outline.default_color = Color(base_color.r, base_color.g, base_color.b, 0.5)
		add_child(outline)

		var label := Label.new()
		label.text = district.display_name
		label.position = _polygon_centroid(district.boundary) - Vector2(40, 8)
		label.modulate = Color(0.6, 0.65, 0.75)
		add_child(label)

	_draw_river()
	_draw_building_footprints()

	for edge: RoadEdge in _world.road_edges:
		var from_node: RoadNode = _find_road_node(edge.from_id)
		var to_node: RoadNode = _find_road_node(edge.to_id)
		if from_node == null or to_node == null:
			continue
		var points := PackedVector2Array([from_node.position, to_node.position])
		# Dark road base plus a thin lighter centreline, rather than one flat
		# grey stroke -- cheap two-line trick that reads as a paved road
		# instead of a schematic connector.
		var base_line := Line2D.new()
		base_line.points = points
		base_line.width = 24.0
		base_line.default_color = Color(0.22, 0.22, 0.24)
		add_child(base_line)
		var center_line := Line2D.new()
		center_line.points = points
		center_line.width = 3.0
		center_line.default_color = Color(0.5, 0.48, 0.4, 0.6)
		add_child(center_line)

	for location: LocationDefinition in _world.locations:
		_add_location_marker(location)

## Per-tag look for gameplay locations (spec section 53/54's readability
## target) -- distinct colour/shape per land-use tag instead of one grey
## dot for everything, so the map communicates what a place is at a glance
## without needing real art. Falls back to a plain grey dot for any
## location with no recognised tag.
const LOCATION_STYLES := {
	"hospital": {"color": Color(0.88, 0.86, 0.9), "shape": "cross", "radius": 16.0},
	"school": {"color": Color(0.78, 0.68, 0.35), "shape": "square", "radius": 13.0},
	"transport": {"color": Color(0.4, 0.4, 0.46), "shape": "square", "radius": 15.0},
	"event_venue": {"color": Color(0.3, 0.6, 0.35), "shape": "oval", "radius": 22.0},
	"retail": {"color": Color(0.78, 0.45, 0.22), "shape": "square", "radius": 9.0},
	"night_economy": {"color": Color(0.55, 0.28, 0.55), "shape": "square", "radius": 9.0},
	"community": {"color": Color(0.3, 0.58, 0.58), "shape": "square", "radius": 11.0},
	"car_park": {"color": Color(0.58, 0.58, 0.62), "shape": "square", "radius": 10.0},
	"residential": {"color": Color(0.68, 0.48, 0.32), "shape": "house", "radius": 9.0},
	"rural": {"color": Color(0.48, 0.42, 0.26), "shape": "square", "radius": 10.0},
	"industrial": {"color": Color(0.42, 0.44, 0.5), "shape": "square", "radius": 11.0},
	"park": {"color": Color(0.32, 0.58, 0.32), "shape": "trees", "radius": 26.0},
}

func _add_location_marker(location: LocationDefinition) -> void:
	var marker := Node2D.new()
	marker.position = location.position
	add_child(marker)

	if location.tags.has("station"):
		var is_police: bool = location.id == _world.police_station_location_id
		if is_police:
			marker.add_child(_make_police_station_sprite())
		else:
			marker.add_child(make_circle(18.0, Color(0.85, 0.3, 0.2)))
	elif location.tags.has("park"):
		_add_tree_cluster(marker, LOCATION_STYLES["park"]["color"], LOCATION_STYLES["park"]["radius"])
	else:
		var style: Dictionary = _style_for(location)
		match style["shape"]:
			"cross": marker.add_child(_make_cross(style["radius"], style["color"]))
			"house": marker.add_child(_make_house(style["radius"], style["color"]))
			"oval": marker.add_child(_make_oval(style["radius"], style["color"]))
			_: marker.add_child(_make_rect(Vector2(style["radius"], style["radius"]) * 1.6, style["color"]))

	var label := Label.new()
	label.text = location.display_name
	label.position = Vector2(14, -8) if not (location.tags.has("station") and location.id == _world.police_station_location_id) \
		else Vector2(-POLICE_STATION_DISPLAY_WIDTH * 0.35, 14)
	label.add_theme_font_size_override("font_size", 15)
	label.modulate = Color(0.85, 0.85, 0.85)
	marker.add_child(label)

func _make_police_station_sprite() -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = POLICE_STATION_TEXTURE
	var scale_factor: float = POLICE_STATION_DISPLAY_WIDTH / POLICE_STATION_TEXTURE.get_width()
	sprite.scale = Vector2(scale_factor, scale_factor)
	# The illustration's own ground shadow sits below the building's visual
	# centre -- shift up so the building itself (not the empty isometric
	# ground plane) sits over the location's actual coordinate.
	sprite.offset.y = -POLICE_STATION_TEXTURE.get_height() * 0.22
	return sprite

func _style_for(location: LocationDefinition) -> Dictionary:
	for tag in location.tags:
		if LOCATION_STYLES.has(tag):
			return LOCATION_STYLES[tag]
	return {"color": Color(0.75, 0.75, 0.78), "shape": "square", "radius": 10.0}

func _make_cross(radius: float, color: Color) -> Node2D:
	var group := Node2D.new()
	group.add_child(make_circle(radius, Color(0.2, 0.2, 0.22, 0.5))) # subtle backing so white reads against the ground
	var bar_a := _make_rect(Vector2(radius * 0.5, radius * 1.5), Color(0.85, 0.2, 0.2))
	var bar_b := _make_rect(Vector2(radius * 1.5, radius * 0.5), Color(0.85, 0.2, 0.2))
	group.add_child(bar_a)
	group.add_child(bar_b)
	return group

## A tiny square base with a triangular roof -- the one departure from
## flat rects/circles, since "a street of houses" reads far better as a
## house glyph than as another shop-like square.
func _make_house(radius: float, color: Color) -> Node2D:
	var group := Node2D.new()
	var base := _make_rect(Vector2(radius * 1.6, radius * 1.2), color)
	base.position = Vector2(0, radius * 0.3)
	group.add_child(base)
	var roof := Polygon2D.new()
	roof.polygon = PackedVector2Array([
		Vector2(-radius * 1.0, -radius * 0.1), Vector2(radius * 1.0, -radius * 0.1), Vector2(0, -radius * 1.1),
	])
	roof.color = Color(color.r * 0.6, color.g * 0.6, color.b * 0.6)
	group.add_child(roof)
	return group

func _make_oval(radius: float, color: Color) -> Polygon2D:
	var oval: Polygon2D = make_circle(radius, color, 20)
	oval.scale = Vector2(1.3, 0.8) # a stadium pitch reads better wide than round
	return oval

## Parks get a loose cluster of small tree-canopy dots instead of a
## building-shaped marker, so green space actually looks like green space.
func _add_tree_cluster(parent: Node2D, color: Color, radius: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(parent.position.x * 1000.0 + parent.position.y) # stable per-location layout
	for i in range(9):
		var angle: float = rng.randf_range(0.0, TAU)
		var dist: float = sqrt(rng.randf_range(0.0, 1.0)) * radius
		var tree := make_circle(rng.randf_range(6.0, 11.0), Color(color.r, color.g, color.b, 0.75), 8)
		tree.position = Vector2(cos(angle), sin(angle)) * dist
		parent.add_child(tree)

## A single large rect behind everything so the town sits on a ground
## colour instead of the viewport's void black -- computed from the actual
## district boundaries so it always covers the map regardless of which
## WorldMapData (small test map or full Westford) is loaded.
func _draw_ground_backdrop() -> void:
	var min_pos := Vector2.INF
	var max_pos := -Vector2.INF
	for district: DistrictDefinition in _world.districts:
		for p in district.boundary:
			min_pos = Vector2(minf(min_pos.x, p.x), minf(min_pos.y, p.y))
			max_pos = Vector2(maxf(max_pos.x, p.x), maxf(max_pos.y, p.y))
	if min_pos == Vector2.INF:
		return
	min_pos -= Vector2(GROUND_MARGIN, GROUND_MARGIN)
	max_pos += Vector2(GROUND_MARGIN, GROUND_MARGIN)
	var backdrop := Polygon2D.new()
	backdrop.polygon = PackedVector2Array([
		Vector2(min_pos.x, min_pos.y), Vector2(max_pos.x, min_pos.y),
		Vector2(max_pos.x, max_pos.y), Vector2(min_pos.x, max_pos.y),
	])
	backdrop.color = GROUND_COLOR
	add_child(backdrop)

## Purely decorative river between South Residential and Rural/Outskirts,
## tying into the "Riverside Walk"/"Riverside Gardens" flavour names
## already in WestfordMapFactory. Skipped entirely if either district
## doesn't exist on the currently loaded map (e.g. the small test map),
## rather than guessing coordinates that wouldn't line up with real
## district geometry.
func _draw_river() -> void:
	var south: DistrictDefinition = _world.get_district(DistrictIds.SOUTH_RESIDENTIAL)
	var rural: DistrictDefinition = _world.get_district(DistrictIds.RURAL_OUTSKIRTS)
	if south == null or rural == null:
		return
	var a: Vector2 = _polygon_centroid(south.boundary)
	var b: Vector2 = _polygon_centroid(rural.boundary)
	var bow: Vector2 = (b - a).orthogonal().normalized() * 350.0
	var mid: Vector2 = a.lerp(b, 0.5) + bow
	var points := PackedVector2Array([
		a + (b - a).normalized() * 200.0,
		a.lerp(mid, 0.6),
		mid,
		mid.lerp(b, 0.6),
		b - (b - a).normalized() * 500.0,
	])
	var river := Line2D.new()
	river.points = points
	river.width = 90.0
	river.default_color = Color(0.25, 0.4, 0.55, 0.55)
	river.joint_mode = Line2D.LINE_JOINT_ROUND
	river.begin_cap_mode = Line2D.LINE_CAP_ROUND
	river.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(river)

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
		var land_use: LandUse = DISTRICT_LAND_USE.get(district.id, LandUse.RESIDENTIAL)
		var palette: Array = BUILDING_PALETTE[land_use]
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
			var base_color: Color = palette[rng.randi() % palette.size()]
			var shade_jitter: float = rng.randf_range(0.85, 1.15)
			var wall_color := Color(base_color.r * shade_jitter, base_color.g * shade_jitter, base_color.b * shade_jitter, 0.85)
			var building := _make_rect(size, wall_color)
			building.position = pos
			add_child(building)
			# A smaller, darker rect offset toward one corner reads as a
			# pitched-roof shadow -- a cheap pseudo-3D cue matching the
			# angled/isometric presentation target (README's Engine section)
			# without needing actual art.
			var roof_size: Vector2 = size * 0.55
			var roof := _make_rect(roof_size, Color(wall_color.r * 0.55, wall_color.g * 0.55, wall_color.b * 0.55, 0.9))
			roof.position = pos - size * 0.12
			add_child(roof)

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
			poly.color = _district_base_colors.get(district_id, DEFAULT_DISTRICT_COLOR)
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

## Called by main.gd once its gesture recognizer has determined a press
## was a genuine tap and not the start of a drag/pan -- MapView no longer
## listens for input directly, since telling a tap from the start of a
## pan gesture needs to see the whole gesture, not just the initial press
## (see main.gd's header comment on why that lives there now).
func handle_tap(world_pos: Vector2, camera_zoom: float) -> void:
	_handle_click(world_pos, camera_zoom)

## Shared by a marker tap and HudView's event feed (spec section 39's
## incident notifications now double as a tappable incident list, since a
## busy real phone screen can make a specific marker hard to find/hit even
## with the zoom-scaled tap radius above) -- keeps the "opening one panel
## closes the other" rule in one place either way.
func open_incident_panel(incident_id: String) -> void:
	if not _incident_markers.has(incident_id):
		return
	close_other_panels(_incident_panel)
	if _incident_panel:
		_incident_panel.open(incident_id)

func _handle_click(click_pos: Vector2, camera_zoom: float) -> void:
	var click_radius: float = TAP_RADIUS_SCREEN_PX / camera_zoom

	var closest_unit_id: String = ""
	var closest_unit_dist: float = INF
	for unit_id in _unit_markers.keys():
		var dist: float = (_unit_markers[unit_id] as UnitMarker).position.distance_to(click_pos)
		if dist <= click_radius and dist < closest_unit_dist:
			closest_unit_id = unit_id
			closest_unit_dist = dist

	var closest_incident_id: String = ""
	var closest_incident_dist: float = INF
	for incident_id in _incident_markers.keys():
		var dist: float = (_incident_markers[incident_id] as IncidentMarker).position.distance_to(click_pos)
		if dist <= click_radius and dist < closest_incident_dist:
			closest_incident_id = incident_id
			closest_incident_dist = dist

	# A unit and an incident marker can both fall within the (now zoom-
	# scaled, sometimes generous) radius when zoomed far out -- resolve by
	# whichever is actually nearer to the tap, not just "units win".
	if closest_unit_id != "" and (closest_incident_id == "" or closest_unit_dist <= closest_incident_dist):
		close_other_panels(_unit_panel)
		if _unit_panel:
			_unit_panel.open(closest_unit_id)
		_select_unit(closest_unit_id)
		return
	if closest_incident_id != "":
		open_incident_panel(closest_incident_id)
		return
	# Tapped empty space -- close whichever panel is open.
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
