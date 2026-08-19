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
## Roads are NOT built from Kenney's modular road pieces -- the existing
## road graph is an organic, non-grid-aligned network (procedurally
## generated for the 2D top-down view), and forcing Kenney's fixed-size
## snap-together tiles onto arbitrary-length, arbitrary-angle edges would
## need either heavy stretching (distorting their lane-marking texture) or
## a full regeneration of the road layout onto a real grid -- out of scope
## for a presentation-layer swap. Instead each edge becomes a flat
## generated ribbon quad in a single combined mesh (one draw call for the
## whole network), coloured from the roads kit's own asphalt swatch for
## visual consistency with the buildings/vehicles that DO use the kits
## directly.
##
## Buildings: every real Location becomes one instanced building GLB
## (individual scenes -- there are only a few dozen, so per-instance scene
## overhead is fine and keeps them individually identifiable for later
## interaction work). Purely decorative filler buildings (matching 2D
## MapView's _draw_building_footprints density system) use
## MultiMeshInstance3D instead -- hundreds of individual scene instances
## would be hundreds of extra draw calls, a real risk on the mobile Web
## export target, whereas MultiMesh batches same-mesh instances into one.

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

## Reduced from the 2D version's 60-160 per district: those counts existed
## to fill visual space in a flat top-down view at zoomed-out scale. Seen
## from an angled 3D camera, far fewer real building volumes already read
## as "a built-up district" -- and each one here is a real draw call
## batch, not a free rectangle.
const FILLER_COUNT_BY_DISTRICT := {
	"town_centre": 36, "northside": 24, "east_estate": 22,
	"south_residential": 26, "west_industrial": 20, "rural_outskirts": 10,
}
const DEFAULT_FILLER_COUNT := 14
const FILLER_SEED := 990817

const ROAD_WIDTH := 0.55
const ROAD_COLOR := Color(0.35, 0.35, 0.38)
const GROUND_COLOR := Color(0.22, 0.34, 0.2)

var _world: WorldMapData
var _mesh_cache: Dictionary = {} # path -> Mesh

func build(world: WorldMapData) -> void:
	_world = world
	_build_ground()
	_build_roads()
	_build_named_buildings()
	_build_filler_buildings()

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
		var inst: Node3D = scene.instantiate()
		inst.position = world_to_3d(location.position)
		inst.rotation.y = (hash(location.id + "r") % 360) * PI / 180.0
		add_child(inst)

func _build_filler_buildings() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = FILLER_SEED
	for district: DistrictDefinition in _world.districts:
		if district.boundary.size() < 3:
			continue
		var land_use: LandUse = DISTRICT_LAND_USE.get(district.id, LandUse.RESIDENTIAL)
		var variants: Array = FILLER_BUILDING_VARIANTS.get(land_use, FILLER_BUILDING_VARIANTS[LandUse.URBAN])
		var dir: String = INDUSTRIAL_DIR if land_use == LandUse.INDUSTRIAL else COMMERCIAL_DIR
		var count: int = FILLER_COUNT_BY_DISTRICT.get(district.id, DEFAULT_FILLER_COUNT)
		var center: Vector2 = _polygon_centroid(district.boundary)
		var radius: float = center.distance_to(district.boundary[0])

		# One MultiMesh per (district, variant) bucket, so instances of the
		# same building read visually varied across a district without
		# each one costing its own draw call.
		var buckets: Dictionary = {} # variant -> Array[Transform3D]
		for i in range(count):
			var angle: float = rng.randf_range(0.0, TAU)
			var dist: float = sqrt(rng.randf_range(0.0, 1.0)) * radius
			if dist < radius * 0.15:
				continue # leave the district hub clear, matches 2D
			var pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * dist
			var variant: String = variants[rng.randi() % variants.size()]
			var t := Transform3D()
			t.origin = world_to_3d(pos)
			t = t.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
			if not buckets.has(variant):
				buckets[variant] = []
			buckets[variant].append(t)

		for variant in buckets:
			var mesh: Mesh = _load_mesh(dir + variant + ".glb")
			if mesh == null:
				continue
			var transforms: Array = buckets[variant]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mesh
			mm.instance_count = transforms.size()
			for i in range(transforms.size()):
				mm.set_instance_transform(i, transforms[i])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			add_child(mmi)

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
