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
## back out at the time -- see PEOPLE_DIR below for how it was fixed
## properly in the next round.
##
## The round after that replaced the parked, static, oversized cars with
## real moving traffic and walking pedestrians (see RoadWalker), and
## added real inter-district compaction (see _compute_district_layout):
## measuring cars/houses against each other properly showed the car kit's
## native scale was 2-3x too big next to the suburban houses, and a real
## GridMap cell can't move regardless of scale, so parked cars were a dead
## end for "moving traffic" on both counts. Districts sitting close in the
## generated 2D layout still read as separated islands at any single
## uniform WORLD_SCALE, because shrinking WORLD_SCALE shrinks gaps and
## district content by the same ratio -- it can't change how big a gap
## looks *relative to* the district next to it. Actually closing that gap
## needed a real per-district compaction pass instead.

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

## _compute_district_layout tuning: each district is treated as a circle
## (its real generated boundary already is one -- WestfordMapFactory hands
## every district a `_circle_polygon(center, radius, 12)`) and relaxed
## toward the town's overall centroid, with a simple pairwise
## overlap-resolution pass so no two districts' circles (plus this margin)
## ever end up closer than DISTRICT_MIN_GAP -- small enough to still read
## as a real gap/road corridor between districts, not a seam where their
## building grids visibly collide.
const DISTRICT_MIN_GAP := 120.0
const DISTRICT_ATTRACT_STRENGTH := 0.05
const DISTRICT_RELAX_ITERATIONS := 300

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

const PEOPLE_DIR := "res://data/models/people/"

## Real moving traffic and pedestrians, both driven by RoadWalker along the
## same road_nodes/road_edges graph the 2D MapView and the gameplay layer
## already use -- not a separate path network, so "roads leading to all of
## them" (the player's own words) is also where the traffic literally
## drives. Cars and people are individually instanced Node3D actors (never
## GridMap cells, which cannot move at all), but the counts are small and
## fixed regardless of town size, so this doesn't reintroduce the
## per-instance-node performance regression the old scattered-parked-car
## GridMap fix specifically existed to avoid.
##
## CAR_SCALE was measured, not guessed: the car-kit's native scale put
## every vehicle (hatchback/taxi/van/delivery/police/ambulance alike, all
## from the same kit) at a 2.75-3.25 unit length against ~1-1.4 unit-wide
## suburban houses and a 1-unit GridMap cell -- visibly, and correctly,
## reported as "too big" against a real screenshot. The strict
## house-height-derived figure (~0.25, putting a car's footprint just
## inside one building cell) turned out to make cars so small next to the
## dense building grid that they were nearly impossible to actually pick
## out and confirm as moving -- checked directly with a temporary 10x
## scale purely to prove the RoadWalker/rendering pipeline itself was
## fine (it was; the real cars just read as a barely-visible speck at
## normal camera zoom). 0.4 is a deliberate legibility compromise: still
## roughly a third smaller than the old native scale and clearly smaller
## than a house, but a car-sized silhouette on the road you can actually
## see driving rather than a technically-correct dot.
const CAR_SCALE := 0.4
const CAR_VARIANTS := ["hatchback-sports", "taxi", "van", "delivery"]
const CAR_COUNT := 10
const CAR_SPEED := 3.2

## PEOPLE_DIR's characterMedium.fbx + Skins/ were added in an earlier round
## and left completely unused: the shared rig ships with no baked idle
## pose, so instantiating it directly renders its raw bind pose -- a
## T-pose, arms straight out -- confirmed genuinely broken (not just
## unpolished) against a real Web export screenshot, and pulled back out
## rather than shipped. Fixed here by importing the kit's separate
## idle.fbx/run.fbx animation clips and driving them through a real
## AnimationPlayer built at runtime -- see _character_anim_library() and
## _build_pedestrians(). Measured directly: characterMedium's bind-pose
## AABB is ~3.76 units tall next to suburban houses measuring ~0.83-1.14
## units tall (the same "too big" problem the cars had). Like CAR_SCALE
## above, the strict height-derived figure (~0.11) read as an
## all-but-invisible speck next to the building grid at normal camera
## zoom -- confirmed harmless by a temporary 10x-scale render that proved
## the animation/rendering side was working correctly the whole time. 0.2
## keeps a person clearly shorter than a house while actually being
## visible as a walking figure.
const PERSON_SCALE := 0.2
const PERSON_COUNT := 8
const PERSON_SPEED := 0.9
## Walk a "sidewalk" a little off the road centreline instead of straight
## down the middle of the carriageway cars use.
const PERSON_LATERAL_OFFSET := 0.32

const ROAD_WIDTH := 0.7
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

## district_id -> Vector3, added on top of world_to_3d() for every point
## that belongs to that district (buildings, GridMap blocks, and its own
## road nodes) -- computed once by _compute_district_layout(). A rigid
## per-district translation, so it moves whole districts closer together
## without touching anything about their own internal layout/density.
var _district_offset: Dictionary = {}
## road_node id -> district_id, so _build_roads() knows which district's
## offset applies to each endpoint of an edge (including the inter-
## district hub-to-hub edges, whose two ends belong to different
## districts and so end up displaced by different amounts -- which is
## exactly what makes the connecting road visibly shorten).
var _node_district: Dictionary = {}

## Shared AnimationLibrary resources extracted once from idle.fbx/run.fbx,
## reused by every pedestrian's own runtime AnimationPlayer rather than
## re-loading the source scene per pedestrian.
var _person_mesh: Mesh
var _idle_anim_library: AnimationLibrary
var _run_anim_library: AnimationLibrary
var _idle_anim_name: String
var _run_anim_name: String

func build(world: WorldMapData) -> void:
	_world = world
	_compute_district_layout()
	_build_lighting()
	_build_ground()
	_build_roads()
	_build_grid_map()
	_build_named_buildings()
	_build_district_blocks()
	_build_traffic()
	_build_pedestrians()

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

## Every other _build_* function converts a district-owned point (building,
## GridMap cell, road node) through this instead of world_to_3d() directly,
## so it picks up that district's compaction offset automatically.
func _world_to_3d_in_district(pos: Vector2, district_id: String) -> Vector3:
	return world_to_3d(pos) + _district_offset.get(district_id, Vector3.ZERO)

## Pulls every district's centroid toward the town's overall centroid,
## resolving circle-circle overlaps as it goes, until it settles into a
## packed layout with no two districts closer than DISTRICT_MIN_GAP apart
## -- a plain force-directed relaxation (attract-then-separate, repeated),
## not a single global scale, because a single scale can't work here: the
## tightest-already pair of districts caps how far a uniform shrink can
## go before it starts overlapping that one pair, which left most other
## pairs barely moved. Relaxing each pair's own slack independently instead
## lets every gap close as far as it safely can. Runs once at scene build
## time on 6 districts (a handful of circle checks per iteration), not a
## per-frame cost.
func _compute_district_layout() -> void:
	var ids: Array = []
	var centers: Dictionary = {} # district_id -> Vector2, mutated by relaxation
	var original_centers: Dictionary = {}
	var radii: Dictionary = {}

	for district: DistrictDefinition in _world.districts:
		var min_pos := Vector2.INF
		var max_pos := -Vector2.INF
		for point in district.boundary:
			min_pos = min_pos.min(point)
			max_pos = max_pos.max(point)
		var center: Vector2 = (min_pos + max_pos) * 0.5
		ids.append(district.id)
		centers[district.id] = center
		original_centers[district.id] = center
		radii[district.id] = (max_pos.x - min_pos.x) * 0.5

	var town_centroid := Vector2.ZERO
	for id in ids:
		town_centroid += centers[id]
	if ids.size() > 0:
		town_centroid /= ids.size()

	for i in DISTRICT_RELAX_ITERATIONS:
		for id in ids:
			centers[id] = centers[id].lerp(town_centroid, DISTRICT_ATTRACT_STRENGTH)
		for a_idx in ids.size():
			for b_idx in range(a_idx + 1, ids.size()):
				var a: String = ids[a_idx]
				var b: String = ids[b_idx]
				var delta: Vector2 = centers[b] - centers[a]
				var dist: float = delta.length()
				var min_dist: float = radii[a] + radii[b] + DISTRICT_MIN_GAP
				if dist < 0.001:
					centers[b] += Vector2(min_dist, 0.0)
				elif dist < min_dist:
					var push: Vector2 = delta / dist * ((min_dist - dist) * 0.5)
					centers[a] -= push
					centers[b] += push

	_district_offset = {}
	for id in ids:
		var original_3d: Vector3 = world_to_3d(original_centers[id])
		var compacted_3d: Vector3 = world_to_3d(centers[id])
		_district_offset[id] = compacted_3d - original_3d

	_node_district = {}
	for node: RoadNode in _world.road_nodes:
		for district: DistrictDefinition in _world.districts:
			if node.id.begins_with(district.id + "_"):
				_node_district[node.id] = district.id
				break

func _build_ground() -> void:
	# Built from each district's already-compacted 3D bounds (its boundary
	# points run through _world_to_3d_in_district), so the ground hugs the
	# tighter post-compaction town instead of leaving a wide green apron
	# sized for the original, further-apart layout.
	var min_pos_3d := Vector3.INF
	var max_pos_3d := -Vector3.INF
	for district: DistrictDefinition in _world.districts:
		for point in district.boundary:
			var p3: Vector3 = _world_to_3d_in_district(point, district.id)
			min_pos_3d = min_pos_3d.min(p3)
			max_pos_3d = max_pos_3d.max(p3)
	var center_3d: Vector3 = (min_pos_3d + max_pos_3d) * 0.5
	var size := Vector2(max_pos_3d.x - min_pos_3d.x, max_pos_3d.z - min_pos_3d.z) + Vector2(20, 20)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = GROUND_COLOR
	mat.roughness = 1.0
	plane.material = mat
	ground.mesh = plane
	ground.position = Vector3(center_3d.x, 0.0, center_3d.z)
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
		var from_pos_3d: Vector3 = _world_to_3d_in_district(node_by_id[edge.from_id], _node_district.get(edge.from_id, ""))
		var to_pos_3d: Vector3 = _world_to_3d_in_district(node_by_id[edge.to_id], _node_district.get(edge.to_id, ""))
		_add_road_quad(st, from_pos_3d, to_pos_3d)

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
		var cell: Vector2i = _world_to_cell(_world_to_3d_in_district(location.position, location.district_id))
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
		var offset: Vector3 = _district_offset.get(district.id, Vector3.ZERO)
		var min_cell: Vector2i = _world_to_cell(_world_to_3d_in_district(min_pos, district.id))
		var max_cell: Vector2i = _world_to_cell(_world_to_3d_in_district(max_pos, district.id))

		for cx in range(min_cell.x, max_cell.x + 1):
			for cy in range(min_cell.y, max_cell.y + 1):
				var cell := Vector2i(cx, cy)
				if _occupied_cells.has(cell):
					continue
				# Reverse of _world_to_3d_in_district: subtract this
				# district's offset before undoing WORLD_SCALE, so the
				# polygon containment check runs against the *original*
				# (uncompacted) boundary points -- the only ones the cell
				# needs to line up with, since compaction is a rigid
				# per-district translation that doesn't change shape.
				var cell_center_3d: Vector3 = _cell_center_3d(cell)
				var cell_center_2d: Vector2 = Vector2(cell_center_3d.x - offset.x, cell_center_3d.z - offset.z) / WORLD_SCALE
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
					_grid_map.set_cell_item(grid_pos, _road_straight_item, vertical)
					_occupied_cells[cell] = true
				elif is_street_row:
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

## Builds the node_id -> 3D position / node_id -> Array[neighbour ids]
## lookups RoadWalker needs, from the same _world.road_nodes/road_edges the
## rest of this file already reads -- shared between _build_traffic() and
## _build_pedestrians() so cars and people move along the identical
## real-connectivity graph.
func _build_walk_graph() -> Dictionary:
	var positions: Dictionary = {}
	for node: RoadNode in _world.road_nodes:
		positions[node.id] = _world_to_3d_in_district(node.position, _node_district.get(node.id, ""))

	var adjacency: Dictionary = {}
	for edge: RoadEdge in _world.road_edges:
		if not positions.has(edge.from_id) or not positions.has(edge.to_id):
			continue
		if not adjacency.has(edge.from_id):
			adjacency[edge.from_id] = []
		if not adjacency.has(edge.to_id):
			adjacency[edge.to_id] = []
		adjacency[edge.from_id].append(edge.to_id)
		adjacency[edge.to_id].append(edge.from_id)

	return {"positions": positions, "adjacency": adjacency}

## A small, fixed number of cars, each its own RoadWalker instance
## following the real road graph forever -- this is the actual fix for
## "the cars... are just static": a GridMap cell (the old approach) simply
## cannot move regardless of scale, so moving traffic needed individually
## instanced, individually updated nodes no matter what. CAR_SCALE (a
## MeshInstance3D child scale, not on the RoadWalker itself, so it doesn't
## interact with RoadWalker's own look_at()-driven rotation) fixes the
## other half of the complaint, the oversized native car-kit scale.
func _build_traffic() -> void:
	var graph: Dictionary = _build_walk_graph()
	var positions: Dictionary = graph["positions"]
	var adjacency: Dictionary = graph["adjacency"]
	var node_ids: Array = positions.keys()
	if node_ids.is_empty():
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = FILLER_SEED + 2

	var traffic_root := Node3D.new()
	traffic_root.name = "TrafficCars"
	add_child(traffic_root)

	for i in CAR_COUNT:
		var variant: String = CAR_VARIANTS[rng.randi() % CAR_VARIANTS.size()]
		# Unlike the single-mesh-single-node building/road/tree GLBs
		# _load_mesh() is built for, the car kit's models are multi-part
		# (a body mesh plus separate wheel meshes for each corner) -- an
		# earlier version of this used _load_mesh() here too and silently
		# rendered every car as just whichever single part happened to be
		# first in the scene's child list (a stray wheel, a door panel),
		# confirmed by inspecting the built scene tree directly. Loading
		# and instancing the whole car scene, the same way named buildings
		# and pedestrians already do, keeps every part in its correct
		# relative position.
		var car_scene: PackedScene = load(VEHICLES_DIR + variant + ".glb")
		if car_scene == null:
			continue
		var car_inst: Node3D = car_scene.instantiate()
		car_inst.scale = Vector3.ONE * CAR_SCALE
		var walker := RoadWalker.new()
		walker.add_child(car_inst)
		traffic_root.add_child(walker)
		var start_id: String = node_ids[rng.randi() % node_ids.size()]
		walker.setup(positions, adjacency, start_id, CAR_SPEED, 0.0, FILLER_SEED + 100 + i)

## Extracts the idle/run AnimationLibrary from PEOPLE_DIR's separately
## imported clip files and caches them -- see the class doc comment for
## why the character rig itself ships with no baked pose, and the headless
## test that proved this exact recipe (a new AnimationPlayer as a sibling
## of the character's "Root" node, NOT nested inside it, since the
## animation's own tracks are baked as "Root/Skeleton3D:<bone>" paths
## relative to wherever the AnimationPlayer sits -- nesting it inside Root
## would double up that first path segment and silently fail to resolve
## every track).
func _load_person_anim_library(clip_path: String) -> Dictionary:
	var clip_scene: PackedScene = load(clip_path)
	if clip_scene == null:
		return {}
	var clip_inst: Node = clip_scene.instantiate()
	var clip_player: AnimationPlayer = clip_inst.get_node_or_null("AnimationPlayer")
	if clip_player == null:
		clip_inst.queue_free()
		return {}
	var lib: AnimationLibrary = clip_player.get_animation_library("")
	var anim_name: String = ""
	for candidate in lib.get_animation_list():
		if String(candidate).findn("idle") != -1 or String(candidate).findn("run") != -1:
			anim_name = candidate
			break
	if anim_name == "" and lib.get_animation_list().size() > 0:
		anim_name = lib.get_animation_list()[0]
	clip_inst.queue_free()
	return {"library": lib, "anim_name": anim_name}

## A small, fixed number of pedestrians, each a characterMedium instance
## with its own runtime AnimationPlayer looping the run clip (there's no
## dedicated walk clip in this kit; run, looped, reads fine at
## PERSON_SPEED's unhurried pace) while a RoadWalker moves it along the
## same road graph traffic uses, offset to the side by
## PERSON_LATERAL_OFFSET so it reads as a sidewalk instead of walking down
## the middle of the carriageway.
func _build_pedestrians() -> void:
	var graph: Dictionary = _build_walk_graph()
	var positions: Dictionary = graph["positions"]
	var adjacency: Dictionary = graph["adjacency"]
	var node_ids: Array = positions.keys()
	if node_ids.is_empty():
		return

	var char_scene: PackedScene = load(PEOPLE_DIR + "characterMedium.fbx")
	if char_scene == null:
		return
	var run_data: Dictionary = _load_person_anim_library(PEOPLE_DIR + "run.fbx")
	if run_data.is_empty():
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = FILLER_SEED + 3

	var people_root := Node3D.new()
	people_root.name = "Pedestrians"
	add_child(people_root)

	for i in PERSON_COUNT:
		var char_inst: Node3D = char_scene.instantiate()
		char_inst.scale = Vector3.ONE * PERSON_SCALE
		var anim_player := AnimationPlayer.new()
		char_inst.add_child(anim_player)
		anim_player.add_animation_library("", run_data["library"])

		var walker := RoadWalker.new()
		walker.add_child(char_inst)
		people_root.add_child(walker)
		anim_player.play(run_data["anim_name"])

		var lateral: float = PERSON_LATERAL_OFFSET if rng.randf() < 0.5 else -PERSON_LATERAL_OFFSET
		var start_id: String = node_ids[rng.randi() % node_ids.size()]
		walker.setup(positions, adjacency, start_id, PERSON_SPEED, lateral, FILLER_SEED + 200 + i)

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
