class_name City3DView
extends Node3D
## Renders Westford as a real 3D low-poly city using the player's Kenney
## asset kits (city-kit-roads/commercial/industrial, car-kit), built once
## from the same WorldMapData the existing 2D MapView already reads --
## zero changes to district/road/location/incident data or gameplay logic,
## this is purely a new presentation layer. Positions are converted from
## the simulation's original 2D "world unit" coordinate space (districts
## spanning roughly +/-3000-4800 units) into a much smaller 3D scene via
## WORLD_SCALE, matching Kenney's ~1-2 unit-per-building real-world scale.
##
## The existing RoadGraph (organic, non-grid-aligned, procedurally
## generated for the old 2D top-down view) still becomes one combined
## ribbon mesh via SurfaceTool -- kept as the visible inter-district
## arterial network, since it's real gameplay-relevant connectivity
## between district hubs that a real regenerated grid would risk losing.
##
## Within each district, though, buildings are laid out on a real grid
## instead of scattered: Kenney's building AND road tiles measure exactly
## 1x1x1 unit (confirmed by measuring their AABBs), i.e. they're built for
## exactly this -- snapping to a Godot GridMap. A regular street lattice
## (road tiles every few cells) carves each district's grid into blocks,
## and every non-street cell inside the district polygon gets a building,
## which is what "not so spaced apart" -- the player's own words -- and
## "built along a grid system" both actually asked for. One shared
## GridMap for the whole town batches every placed cell efficiently
## regardless of count (its whole purpose, no MultiMesh bookkeeping
## needed), and a MeshLibrary built once at startup from the same cached
## meshes _load_mesh() already uses feeds it.
##
## Every real Location still becomes one individually instanced building
## GLB (not a GridMap cell) so it stays tap-identifiable and individually
## positioned/rotated -- but now snapped onto the same grid as everything
## else, and its cell reserved so the block fill doesn't double-place one
## on top of it.

const WORLD_SCALE := 0.045

enum LandUse { URBAN, RESIDENTIAL, INDUSTRIAL, RURAL }
const DISTRICT_LAND_USE := {
	"town_centre": LandUse.URBAN,
	"northside": LandUse.RESIDENTIAL,
	"east_estate": LandUse.RESIDENTIAL,
	"south_residential": LandUse.RESIDENTIAL,
	"west_industrial": LandUse.INDUSTRIAL,
	"rural_outskirts": LandUse.RURAL,
}

const COMMERCIAL_DIR := "res://data/models/buildings_commercial/"
const INDUSTRIAL_DIR := "res://data/models/buildings_industrial/"
const ROADS_DIR := "res://data/models/roads/"
const VEHICLES_DIR := "res://data/models/vehicles/"

## A handful of named variants per land use for named Locations (bigger,
## more distinctive -- these are landmarks a player will tap on).
## "low-detail-building-*" (non-wide) turned out to be tall, spindly
## 0.5x2.0x0.5 towers -- Kenney's distant-LOD silhouette shape, not a
## believable up-close building -- confirmed by measuring their actual
## AABB after an early render showed a field of odd thin slivers instead
## of a town. Only the "-wide" ones (sensible 1.0x1.1x0.5 house/shop
## proportions) are used; everything else pulls from the full building-*
## set instead.
const NAMED_BUILDING_VARIANTS := {
	LandUse.URBAN: ["building-a", "building-c", "building-e", "building-g", "building-skyscraper-b", "building-skyscraper-d"],
	LandUse.RESIDENTIAL: ["building-b", "building-d", "building-f", "low-detail-building-wide-a", "low-detail-building-wide-b"],
	LandUse.INDUSTRIAL: ["building-b", "building-d", "building-f", "building-h", "building-k"],
	LandUse.RURAL: ["low-detail-building-wide-a", "low-detail-building-wide-b"],
}
## Smaller/plainer variants for the purely decorative filler pass.
const FILLER_BUILDING_VARIANTS := {
	LandUse.URBAN: ["low-detail-building-wide-a", "low-detail-building-wide-b", "building-i", "building-j"],
	LandUse.RESIDENTIAL: ["low-detail-building-wide-a", "low-detail-building-wide-b", "building-b", "building-d"],
	LandUse.INDUSTRIAL: ["building-a", "building-c", "building-g", "chimney-medium"],
	LandUse.RURAL: ["low-detail-building-wide-a", "low-detail-building-wide-b"],
}
## Tags that mean "no building here" (green space / paved lot, not a
## structure) -- matches spec's location tagging, see WestfordMapFactory.
const NO_BUILDING_TAGS := ["park", "car_park"]

const FILLER_SEED := 990817

## Kenney's road/building modules are exactly 1x1x1 (measured via AABB),
## so this is both "the GridMap cell size" and "one Kenney unit" -- no
## separate scale factor needed, unlike WORLD_SCALE for gameplay
## positions.
const GRID_CELL_SIZE := 1.0

## Cells between streets, per land use -- smaller means a tighter grid
## with more, closer-together streets (a dense town-centre feel); bigger
## means larger blocks with more building-to-building distance along a
## street (a sparser, rural feel). URBAN intentionally has the smallest
## blocks of any land use, since "town centre" is the one place a tight
## grid reads correctly; RURAL the biggest, so it doesn't turn a
## deliberately sparse district into a dense one just because the same
## grid mechanism now touches every district.
const BLOCK_SIZE_BY_LAND_USE := {
	LandUse.URBAN: 2,
	LandUse.RESIDENTIAL: 3,
	LandUse.INDUSTRIAL: 3,
	LandUse.RURAL: 6,
}
## Grid cluster side length in cells, centred on each district's centroid
## -- NOT the whole district polygon (which spans thousands of world
## units; gridding all of it would mean tens of thousands of cells for no
## visual gain, since a real town isn't wall-to-wall buildings across its
## entire administrative area either). Roughly proportional to the old
## per-district filler counts, scaled up substantially -- but pulled back
## once already from a first pass (town centre 26, ~300+ buildings) that
## measured a real ~3x frame-time regression against a real Web export
## (confirmed via requestAnimationFrame sampling before/after, same
## sandbox both times so the comparison is apples-to-apples even though
## the sandbox itself has no GPU and isn't a real-device number). These
## smaller sizes still land at several times the old flat-scatter
## version's per-district counts (36 at town centre, down to single
## digits at rural_outskirts).
const CLUSTER_SIZE_BY_DISTRICT := {
	"town_centre": 18, "northside": 14, "east_estate": 14,
	"south_residential": 15, "west_industrial": 13, "rural_outskirts": 9,
}
const DEFAULT_CLUSTER_SIZE := 11

const ROAD_WIDTH := 0.55
const ROAD_COLOR := Color(0.35, 0.35, 0.38)
const GROUND_COLOR := Color(0.22, 0.34, 0.2)

var _world: WorldMapData
var _mesh_cache: Dictionary = {} # path -> Mesh
var _grid_map: GridMap
var _mesh_library: MeshLibrary
var _library_item_by_path: Dictionary = {} # glb path -> MeshLibrary item id
var _next_library_item_id: int = 0
var _road_straight_item: int = -1
var _road_crossroad_item: int = -1
## Vector2i grid cell -> true, shared between named-building placement and
## the district block fill so neither ever double-places on the other's
## cell.
var _occupied_cells: Dictionary = {}

func build(world: WorldMapData) -> void:
	_world = world
	_build_lighting()
	_build_ground()
	_build_roads()
	_build_grid_map()
	_build_named_buildings()
	_build_district_blocks()

## Without this the scene has no light source at all -- StandardMaterial3D
## surfaces get zero light contribution and render pure black regardless
## of albedo_color, indistinguishable from the project's near-black
## default_clear_color in a screenshot. Missed by the earlier proof-of-
## concept renders (tasks 94/97/98) because those used a throwaway test
## scene that set up its own light, never carried over into the real
## City3DView. Shadows stay off -- a real cost on the mobile Web
## gl_compatibility target for a presentation layer that doesn't need them.
func _build_lighting() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.75, 0.95)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.68, 0.78)
	env.ambient_light_energy = 0.6
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sun.light_energy = 1.15
	sun.shadow_enabled = false
	add_child(sun)

func world_to_3d(pos: Vector2) -> Vector3:
	return Vector3(pos.x * WORLD_SCALE, 0.0, pos.y * WORLD_SCALE)

func _build_ground() -> void:
	var min_pos := Vector2.INF
	var max_pos := -Vector2.INF
	for district: DistrictDefinition in _world.districts:
		for point in district.boundary:
			min_pos = min_pos.min(point)
			max_pos = max_pos.max(point)
	var center: Vector2 = (min_pos + max_pos) * 0.5
	var size: Vector2 = (max_pos - min_pos) * WORLD_SCALE + Vector2(40, 40)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = GROUND_COLOR
	mat.roughness = 1.0
	plane.material = mat
	ground.mesh = plane
	ground.position = world_to_3d(center)
	add_child(ground)

func _build_roads() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var node_by_id: Dictionary = {}
	for node: RoadNode in _world.road_nodes:
		node_by_id[node.id] = node.position

	for edge: RoadEdge in _world.road_edges:
		if not node_by_id.has(edge.from_id) or not node_by_id.has(edge.to_id):
			continue
		var from_pos: Vector2 = node_by_id[edge.from_id]
		var to_pos: Vector2 = node_by_id[edge.to_id]
		_add_road_quad(st, world_to_3d(from_pos), world_to_3d(to_pos))

	var mat := StandardMaterial3D.new()
	mat.albedo_color = ROAD_COLOR
	mat.roughness = 1.0
	st.set_material(mat)
	var mesh: ArrayMesh = st.commit()

	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	# Slightly above the ground plane -- coplanar geometry z-fights flicker
	# unpredictably, especially on the Web export's Compatibility renderer.
	inst.position = Vector3(0, 0.02, 0)
	add_child(inst)

func _add_road_quad(st: SurfaceTool, a: Vector3, b: Vector3) -> void:
	var dir: Vector3 = (b - a)
	if dir.length() < 0.001:
		return
	dir = dir.normalized()
	var side: Vector3 = dir.cross(Vector3.UP).normalized() * (ROAD_WIDTH * 0.5)
	var p1 := a - side
	var p2 := a + side
	var p3 := b + side
	var p4 := b - side
	st.set_normal(Vector3.UP)
	st.add_vertex(p1)
	st.add_vertex(p3)
	st.add_vertex(p2)
	st.set_normal(Vector3.UP)
	st.add_vertex(p1)
	st.add_vertex(p4)
	st.add_vertex(p3)

func _build_grid_map() -> void:
	_mesh_library = MeshLibrary.new()
	_grid_map = GridMap.new()
	_grid_map.mesh_library = _mesh_library
	_grid_map.cell_size = Vector3(GRID_CELL_SIZE, GRID_CELL_SIZE, GRID_CELL_SIZE)
	add_child(_grid_map)
	_road_straight_item = _register_library_item(ROADS_DIR + "road-straight.glb")
	_road_crossroad_item = _register_library_item(ROADS_DIR + "road-crossroad.glb")

func _register_library_item(path: String) -> int:
	if _library_item_by_path.has(path):
		return _library_item_by_path[path]
	var mesh: Mesh = _load_mesh(path)
	var id: int = _next_library_item_id
	_next_library_item_id += 1
	_mesh_library.create_item(id)
	_mesh_library.set_item_mesh(id, mesh)
	_library_item_by_path[path] = id
	return id

func _world_to_cell(pos_3d: Vector3) -> Vector2i:
	return Vector2i(floori(pos_3d.x / GRID_CELL_SIZE), floori(pos_3d.z / GRID_CELL_SIZE))

func _cell_center_3d(cell: Vector2i) -> Vector3:
	return Vector3((cell.x + 0.5) * GRID_CELL_SIZE, 0.0, (cell.y + 0.5) * GRID_CELL_SIZE)

## Real Locations still get their own individually instanced scene (not a
## GridMap cell) so each stays a distinct, individually rotatable node --
## but snapped onto the same grid as the block fill below, and rotation
## limited to the 4 cardinal directions, so it sits flush against
## neighbouring GridMap-placed buildings instead of floating at an
## arbitrary sub-cell offset/angle. Reserves its cell in _occupied_cells
## before the block fill runs, so nothing else gets placed on top of it.
func _build_named_buildings() -> void:
	for location: LocationDefinition in _world.locations:
		if _has_any_tag(location.tags, NO_BUILDING_TAGS):
			continue
		var land_use: LandUse = _land_use_for_district(location.district_id)
		var variants: Array = NAMED_BUILDING_VARIANTS.get(land_use, NAMED_BUILDING_VARIANTS[LandUse.URBAN])
		var dir: String = INDUSTRIAL_DIR if land_use == LandUse.INDUSTRIAL else COMMERCIAL_DIR
		var variant: String = variants[hash(location.id) % variants.size()]
		var scene: PackedScene = load(dir + variant + ".glb")
		if scene == null:
			continue
		var cell: Vector2i = _world_to_cell(world_to_3d(location.position))
		_occupied_cells[cell] = true
		var inst: Node3D = scene.instantiate()
		inst.position = _cell_center_3d(cell)
		inst.rotation.y = (hash(location.id + "r") % 4) * (PI * 0.5)
		add_child(inst)

## The actual grid: for each district, a street lattice (crossroads where
## a "street row" meets a "street column", straight segments elsewhere
## along either) carves a fixed-size cluster of cells centred on the
## district's centroid into blocks, and every remaining cell whose centre
## falls inside the real district polygon (Geometry2D.is_point_in_polygon
## against the actual boundary, not a circle approximation like the old
## scatter used) gets a building. Every cell this places, road or
## building, goes through the single shared GridMap -- that's the whole
## performance case for using one: it batches per unique mesh internally
## regardless of how many thousand cells are placed, so cell count here
## isn't a draw-call multiplier the way individual scene instances would
## be.
func _build_district_blocks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = FILLER_SEED

	for district: DistrictDefinition in _world.districts:
		if district.boundary.size() < 3:
			continue
		var land_use: LandUse = DISTRICT_LAND_USE.get(district.id, LandUse.RESIDENTIAL)
		var variants: Array = FILLER_BUILDING_VARIANTS.get(land_use, FILLER_BUILDING_VARIANTS[LandUse.URBAN])
		var dir: String = INDUSTRIAL_DIR if land_use == LandUse.INDUSTRIAL else COMMERCIAL_DIR
		var item_ids: Array = []
		for variant in variants:
			item_ids.append(_register_library_item(dir + variant + ".glb"))

		var block_size: int = BLOCK_SIZE_BY_LAND_USE.get(land_use, 3)
		var street_period: int = block_size + 1
		var cluster_size: int = CLUSTER_SIZE_BY_DISTRICT.get(district.id, DEFAULT_CLUSTER_SIZE)
		var center_cell: Vector2i = _world_to_cell(world_to_3d(_polygon_centroid(district.boundary)))
		var half: int = cluster_size / 2

		for di in range(-half, half + 1):
			for dj in range(-half, half + 1):
				var cell := Vector2i(center_cell.x + di, center_cell.y + dj)
				if _occupied_cells.has(cell):
					continue
				var cell_center_2d: Vector2 = Vector2(_cell_center_3d(cell).x, _cell_center_3d(cell).z) / WORLD_SCALE
				if not Geometry2D.is_point_in_polygon(cell_center_2d, district.boundary):
					continue

				var is_street_col: bool = posmod(di, street_period) == 0
				var is_street_row: bool = posmod(dj, street_period) == 0
				var grid_pos := Vector3i(cell.x, 0, cell.y)

				if is_street_col and is_street_row:
					_grid_map.set_cell_item(grid_pos, _road_crossroad_item)
				elif is_street_col:
					var vertical: int = _grid_map.get_orthogonal_index_from_basis(Basis(Vector3.UP, PI * 0.5))
					_grid_map.set_cell_item(grid_pos, _road_straight_item, vertical)
				elif is_street_row:
					_grid_map.set_cell_item(grid_pos, _road_straight_item)
				else:
					var item_id: int = item_ids[rng.randi() % item_ids.size()]
					var facing: int = _grid_map.get_orthogonal_index_from_basis(Basis(Vector3.UP, (rng.randi() % 4) * PI * 0.5))
					_grid_map.set_cell_item(grid_pos, item_id, facing)
				_occupied_cells[cell] = true

## Kenney's single-mesh-single-node GLBs (every building/road piece here)
## let this just grab the first MeshInstance3D's mesh directly rather than
## needing real multi-part merging.
func _load_mesh(path: String) -> Mesh:
	if _mesh_cache.has(path):
		return _mesh_cache[path]
	var scene: PackedScene = load(path)
	if scene == null:
		return null
	var inst: Node = scene.instantiate()
	var mesh: Mesh = null
	for child in inst.get_children():
		if child is MeshInstance3D:
			mesh = child.mesh
			break
	inst.queue_free()
	_mesh_cache[path] = mesh
	return mesh

func _land_use_for_district(district_id: String) -> LandUse:
	return DISTRICT_LAND_USE.get(district_id, LandUse.RESIDENTIAL)

func _has_any_tag(tags: Array, needles: Array) -> bool:
	for t in tags:
		if needles.has(t):
			return true
	return false

func _polygon_centroid(points: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for p in points:
		sum += p
	return sum / points.size()
