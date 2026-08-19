class_name City3DView
extends Node3D
## Renders Westford as a real 3D low-poly city using the player's Kenney
## asset kits (city-kit-roads/commercial/industrial, car-kit), built once
## from the same WorldMapData the existing 2D MapView already reads --
## zero changes to district/road/location/incident data or gameplay logic,
## this is purely a new presentation layer. Positions are converted from
## the simulation's original 2D "world unit" coordinate space (the whole
## town's bounding box measures roughly 7650x9900 units) into a much
## smaller 3D scene via WORLD_SCALE, matching Kenney's ~1-unit-per-building
## real-world scale. WORLD_SCALE is deliberately small enough that the
## whole town's districts -- which really do border each other, per each
## DistrictDefinition's own neighbour_district_ids -- end up close enough
## together to read as one continuous town instead of separate islands
## with empty gaps between them, which is what an earlier, larger
## WORLD_SCALE produced (each district itself was appropriately dense, but
## sat in the middle of a mostly-empty district-sized polygon, and
## districts were far enough apart in the original 2D data that nothing
## bridged the gaps but the thin arterial road ribbon). Because every
## position -- buildings AND roads -- goes through this one shared scale
## factor, shrinking it keeps roads and buildings in lockstep automatically
## rather than needing a second coordinate system just for compactness.
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
##
## A later round added two more of the player's Kenney kits --
## city-kit-suburban (houses for RESIDENTIAL/RURAL, replacing the generic
## commercial shapes those land uses used to reuse) and mini-forest
## (standalone decorative trees) -- plus a scattering of civilian cars from
## the car-kit parked along street cells, and OPEN_CELL_CHANCE, which
## leaves a real fraction of otherwise-buildable cells as bare ground
## rather than filling every available lot: the player's own follow-up ask
## was to space buildings out with gaps/green/pathway room instead of
## building on every cell the grid mechanism made available. A pedestrian
## kit (kenney_animated-characters-protagonists) was tried too and pulled
## back out -- see the doc comment on PARKED_CAR_CHANCE below for why.

## 0.01 (down from an earlier 0.045) puts the whole town's ~7650x9900
## bounding box at roughly 76x99 3D-units -- small enough that adjacent
## districts' own building clusters actually meet or nearly meet, rather
## than sitting in the middle of their own district-sized empty polygon.
## Measured directly against WestfordMapFactory's real district boundary
## polygons (bbox/area per district) before picking this, not guessed.
const WORLD_SCALE := 0.01

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
const SUBURBAN_DIR := "res://data/models/buildings_suburban/"
const NATURE_DIR := "res://data/models/nature/"
const ROADS_DIR := "res://data/models/roads/"
const VEHICLES_DIR := "res://data/models/vehicles/"

## A handful of named variants per land use for named Locations (bigger,
## more distinctive -- these are landmarks a player will tap on). Stored
## as full dir+variant strings now (no extension) rather than a bare
## variant name plus a separate dir-selection ternary, since there are now
## three building source kits instead of two -- RESIDENTIAL/RURAL pull
## from the player's suburban house kit (kenney_city-kit-suburban) added
## alongside the original commercial/industrial ones, so a real town has
## actual houses rather than every district reusing the same shop/office
## shapes. "low-detail-building-*" (non-wide) turned out to be tall,
## spindly 0.5x2.0x0.5 towers -- Kenney's distant-LOD silhouette shape,
## not a believable up-close building -- confirmed by measuring their
## actual AABB after an early render showed a field of odd thin slivers
## instead of a town; still used sparingly where noted.
const NAMED_BUILDING_VARIANTS := {
	LandUse.URBAN: [
		COMMERCIAL_DIR + "building-a", COMMERCIAL_DIR + "building-c", COMMERCIAL_DIR + "building-e",
		COMMERCIAL_DIR + "building-g", COMMERCIAL_DIR + "building-skyscraper-b", COMMERCIAL_DIR + "building-skyscraper-d",
	],
	LandUse.RESIDENTIAL: [
		SUBURBAN_DIR + "building-type-a", SUBURBAN_DIR + "building-type-e", SUBURBAN_DIR + "building-type-j",
		SUBURBAN_DIR + "building-type-o", SUBURBAN_DIR + "building-type-s",
	],
	LandUse.INDUSTRIAL: [
		INDUSTRIAL_DIR + "building-b", INDUSTRIAL_DIR + "building-d", INDUSTRIAL_DIR + "building-f",
		INDUSTRIAL_DIR + "building-h", INDUSTRIAL_DIR + "building-k",
	],
	LandUse.RURAL: [SUBURBAN_DIR + "building-type-c", SUBURBAN_DIR + "building-type-m"],
}
## Smaller/plainer variants for the district block-fill pass.
const FILLER_BUILDING_VARIANTS := {
	LandUse.URBAN: [
		COMMERCIAL_DIR + "low-detail-building-wide-a", COMMERCIAL_DIR + "low-detail-building-wide-b",
		COMMERCIAL_DIR + "building-i", COMMERCIAL_DIR + "building-j",
	],
	LandUse.RESIDENTIAL: [
		SUBURBAN_DIR + "building-type-b", SUBURBAN_DIR + "building-type-d", SUBURBAN_DIR + "building-type-f",
		SUBURBAN_DIR + "building-type-h", SUBURBAN_DIR + "building-type-k", SUBURBAN_DIR + "building-type-n",
		SUBURBAN_DIR + "building-type-q", SUBURBAN_DIR + "building-type-t",
	],
	LandUse.INDUSTRIAL: [
		INDUSTRIAL_DIR + "building-a", INDUSTRIAL_DIR + "building-c", INDUSTRIAL_DIR + "building-g",
		INDUSTRIAL_DIR + "chimney-medium",
	],
	LandUse.RURAL: [SUBURBAN_DIR + "building-type-g", SUBURBAN_DIR + "building-type-l", SUBURBAN_DIR + "building-type-r"],
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
## No separate "cluster size" any more -- at WORLD_SCALE 0.01 a district's
## own real polygon (18-32 3D-units across, measured directly rather than
## the ~1800-3200 *old-2D-unit* figures that used to make a full-polygon
## fill mean tens of thousands of cells) is already close to the size a
## hand-picked cluster used to be, so _build_district_blocks below just
## fills each district's own real boundary polygon directly.

## Fraction of non-street cells left as bare (already-green) ground
## instead of a building -- directly answers "space the buildings out...
## doesn't feel so compact": a real town has gaps, gardens, and paved
## space between buildings, not a solid building in every available lot.
## Left as open ground rather than a distinct "path" tile since the
## ground plane is already a park-like green (GROUND_COLOR below) -- an
## open cell reads as a gap you could walk or drive through without
## needing a separate mesh for it.
const OPEN_CELL_CHANCE := 0.22
## Of those open cells, the fraction that gets a standalone decorative
## tree (kenney_mini-forest) so "open space" reads as real greenery in
## some of those gaps, not just absence.
const TREE_ON_OPEN_CHANCE := 0.25
const NATURE_TREE_VARIANTS := ["tree", "tree-high"]

## Sparse decoration scattered on top of the finished grid, seeded
## independently of the building/street RNG so tuning one doesn't shift
## the other: a small fraction of road cells gets a parked civilian car
## just off the carriageway. An ordinary child node (like named
## buildings), not a GridMap cell, since there are few enough of them
## that per-instance draw calls are not a real cost the way thousands of
## building cells would be.
##
## Pedestrians (kenney_animated-characters-protagonists) were tried here
## too and pulled back out: the shared rig has no baked idle pose, so
## instantiating it without wiring up real animation import renders its
## raw bind pose -- a T-pose, arms straight out -- at a scale that
## towered over multi-storey buildings, confirmed as genuinely broken
## (not just unpolished) against a real Web export screenshot. Fixing it
## properly means importing the kit's separate idle animation and
## driving it through an AnimationPlayer, real work disproportionate to
## background scenery; the raw FBX/skin files are left in
## data/models/people/ unused, in case that's worth doing in a later
## round, but nothing in this file references them.
const PARKED_CAR_CHANCE := 0.035
const CAR_VARIANTS := ["hatchback-sports", "taxi", "van", "delivery"]

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
		var variant_path: String = variants[hash(location.id) % variants.size()]
		var scene: PackedScene = load(variant_path + ".glb")
		if scene == null:
			continue
		var cell: Vector2i = _world_to_cell(world_to_3d(location.position))
		_occupied_cells[cell] = true
		var inst: Node3D = scene.instantiate()
		inst.position = _cell_center_3d(cell)
		inst.rotation.y = (hash(location.id + "r") % 4) * (PI * 0.5)
		add_child(inst)

## The actual grid: for each district, every cell in its own real
## bounding box (at WORLD_SCALE 0.01 this is now small -- 18 to 32
## 3D-units across -- not the "tens of thousands of cells" a full-polygon
## fill would have meant at the old, larger WORLD_SCALE) whose centre
## falls inside the real district polygon (Geometry2D.is_point_in_polygon
## against the actual boundary, not a circle approximation like the
## original scatter used) gets either a road tile, if it's on a street
## row/column of a regular lattice spaced by the land use's block size, or
## a building otherwise. Every cell this places, road or building, goes
## through the single shared GridMap -- that's the whole performance case
## for using one: it batches per unique mesh internally regardless of how
## many thousand cells are placed, so cell count here isn't a draw-call
## multiplier the way individual scene instances would be.
func _build_district_blocks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = FILLER_SEED
	# Separate RNG stream for decoration (cars/pedestrians/trees) so tuning
	# those chances can't perturb which cells get which building variant,
	# and vice versa -- two independent seeded sequences instead of one
	# shared one that shifts every downstream roll whenever either changes.
	var decor_rng := RandomNumberGenerator.new()
	decor_rng.seed = FILLER_SEED + 1

	for district: DistrictDefinition in _world.districts:
		if district.boundary.size() < 3:
			continue
		var land_use: LandUse = DISTRICT_LAND_USE.get(district.id, LandUse.RESIDENTIAL)
		var variants: Array = FILLER_BUILDING_VARIANTS.get(land_use, FILLER_BUILDING_VARIANTS[LandUse.URBAN])
		var item_ids: Array = []
		for variant_path in variants:
			item_ids.append(_register_library_item(variant_path + ".glb"))

		var block_size: int = BLOCK_SIZE_BY_LAND_USE.get(land_use, 3)
		var street_period: int = block_size + 1

		var min_pos := Vector2.INF
		var max_pos := -Vector2.INF
		for point in district.boundary:
			min_pos = min_pos.min(point)
			max_pos = max_pos.max(point)
		var min_cell: Vector2i = _world_to_cell(world_to_3d(min_pos))
		var max_cell: Vector2i = _world_to_cell(world_to_3d(max_pos))

		for cx in range(min_cell.x, max_cell.x + 1):
			for cy in range(min_cell.y, max_cell.y + 1):
				var cell := Vector2i(cx, cy)
				if _occupied_cells.has(cell):
					continue
				var cell_center_2d: Vector2 = Vector2(_cell_center_3d(cell).x, _cell_center_3d(cell).z) / WORLD_SCALE
				if not Geometry2D.is_point_in_polygon(cell_center_2d, district.boundary):
					continue

				var is_street_col: bool = posmod(cx, street_period) == 0
				var is_street_row: bool = posmod(cy, street_period) == 0
				var grid_pos := Vector3i(cell.x, 0, cell.y)

				if is_street_col and is_street_row:
					_grid_map.set_cell_item(grid_pos, _road_crossroad_item)
					_occupied_cells[cell] = true
				elif is_street_col:
					var vertical: int = _grid_map.get_orthogonal_index_from_basis(Basis(Vector3.UP, PI * 0.5))
					if decor_rng.randf() < PARKED_CAR_CHANCE:
						_place_car_cell(grid_pos, PI * 0.5, decor_rng)
					else:
						_grid_map.set_cell_item(grid_pos, _road_straight_item, vertical)
					_occupied_cells[cell] = true
				elif is_street_row:
					if decor_rng.randf() < PARKED_CAR_CHANCE:
						_place_car_cell(grid_pos, 0.0, decor_rng)
					else:
						_grid_map.set_cell_item(grid_pos, _road_straight_item)
					_occupied_cells[cell] = true
				elif rng.randf() < OPEN_CELL_CHANCE:
					# Left as bare ground -- deliberately not marked
					# occupied unless a tree lands here, so the
					# already-green ground plane shows through as open
					# space between buildings (spec: "space out the
					# individual buildings... doesn't feel so compact").
					if decor_rng.randf() < TREE_ON_OPEN_CHANCE:
						var tree_path: String = NATURE_DIR + NATURE_TREE_VARIANTS[decor_rng.randi() % NATURE_TREE_VARIANTS.size()] + ".glb"
						var tree_item: int = _register_library_item(tree_path)
						var tree_facing: int = _grid_map.get_orthogonal_index_from_basis(Basis(Vector3.UP, (decor_rng.randi() % 4) * PI * 0.5))
						_grid_map.set_cell_item(grid_pos, tree_item, tree_facing)
						_occupied_cells[cell] = true
				else:
					var item_id: int = item_ids[rng.randi() % item_ids.size()]
					var facing: int = _grid_map.get_orthogonal_index_from_basis(Basis(Vector3.UP, (rng.randi() % 4) * PI * 0.5))
					_grid_map.set_cell_item(grid_pos, item_id, facing)
					_occupied_cells[cell] = true

## Cars and trees both go through the same shared GridMap as buildings and
## roads -- confirmed necessary, not just convenient, after measuring a
## real ~2x frame-time regression (requestAnimationFrame sampling, same
## sandbox before/after) from an earlier version that gave each car/tree
## its own individually instanced scene node the way named buildings get
## one. GridMap batches per unique mesh internally regardless of cell
## count, the same reason it replaced the original MultiMesh-bucketed
## filler-building approach; individual scene instances don't get that for
## free, and there turned out to be enough scattered decoration for the
## difference to be real. The one cost: a GridMap cell can't have a
## sub-cell position offset, so a "parked" car sits centred in its road
## cell rather than pulled over to the shoulder -- reads fine at this
## camera angle as a car in traffic, not a real visual downgrade.
func _place_car_cell(grid_pos: Vector3i, road_yaw: float, decor_rng: RandomNumberGenerator) -> void:
	var variant: String = CAR_VARIANTS[decor_rng.randi() % CAR_VARIANTS.size()]
	var item_id: int = _register_library_item(VEHICLES_DIR + variant + ".glb")
	# Facing along the road, randomly one direction or the other.
	var yaw: float = road_yaw + (PI if decor_rng.randf() < 0.5 else 0.0)
	var facing: int = _grid_map.get_orthogonal_index_from_basis(Basis(Vector3.UP, yaw))
	_grid_map.set_cell_item(grid_pos, item_id, facing)

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
