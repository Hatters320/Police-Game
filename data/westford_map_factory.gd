class_name WestfordMapFactory
extends RefCounted
## Full 6-district Westford (spec section 5/53): ~70-90 gameplay
## locations, procedurally laid out around each district's road-network
## sub-hubs rather than each hand-placed individually. With no art assets
## yet, exact pixel placement of "Shop #47" carries no more meaning than a
## generated one -- the effort goes into a data-driven per-district
## *shape* (what kinds of places exist here, roughly how many, per spec
## section 5's content list) instead of typing out ~80 sets of
## coordinates by hand.
##
## The 500-800 decorative buildings spec section 53 also wants are
## deliberately NOT part of this data at all: they carry zero gameplay
## meaning, so MapView generates them procedurally at draw time from each
## district's boundary polygon instead of bloating WorldMapData with
## hundreds of rectangles nothing else ever needs to know about.
##
## Swap this factory for real hand-authored/artist-placed content later --
## nothing else in the simulation layer cares which factory supplied the
## WorldMapData. tests/run_shift_debug.gd deliberately keeps using the
## small TestMapFactory instead of this one, so headless regression tests
## stay fast and don't churn every time this layout changes.

const POLICE_STATION := "police_station"

## Deterministic -- the same layout every run, so it's a stable target
## for screenshots/testing rather than a moving one.
const LAYOUT_SEED := 20260817

static func build() -> WorldMapData:
	var rng := RandomNumberGenerator.new()
	rng.seed = LAYOUT_SEED

	var all_road_nodes: Array[RoadNode] = []
	var all_road_edges: Array[RoadEdge] = []
	var all_locations: Array[LocationDefinition] = []
	var all_districts: Array[DistrictDefinition] = []
	var hub_node_id_by_district: Dictionary = {}

	for spec: Dictionary in _district_specs():
		var built: Dictionary = _build_district(spec, rng)
		all_road_nodes.append_array(built["road_nodes"])
		all_road_edges.append_array(built["road_edges"])
		all_locations.append_array(built["locations"])
		all_districts.append(built["district"])
		hub_node_id_by_district[spec["id"]] = built["hub_node_id"]

	var neighbours_by_district: Dictionary = {}
	for pair in _inter_district_roads():
		var a: String = pair[0]
		var b: String = pair[1]
		all_road_edges.append(_road_edge(hub_node_id_by_district[a], hub_node_id_by_district[b]))
		if not neighbours_by_district.has(a):
			neighbours_by_district[a] = []
		if not neighbours_by_district.has(b):
			neighbours_by_district[b] = []
		neighbours_by_district[a].append(b)
		neighbours_by_district[b].append(a)
	for district: DistrictDefinition in all_districts:
		var neighbours: Array = neighbours_by_district.get(district.id, [])
		district.neighbour_district_ids = _to_string_array(neighbours)

	var world := WorldMapData.new()
	world.districts = all_districts
	world.locations = all_locations
	world.road_nodes = all_road_nodes
	world.road_edges = all_road_edges
	world.police_station_location_id = POLICE_STATION
	world.rebuild_index()
	return world

static func _inter_district_roads() -> Array:
	return [
		[DistrictIds.TOWN_CENTRE, DistrictIds.NORTHSIDE],
		[DistrictIds.TOWN_CENTRE, DistrictIds.EAST_ESTATE],
		[DistrictIds.TOWN_CENTRE, DistrictIds.WEST_INDUSTRIAL],
		[DistrictIds.TOWN_CENTRE, DistrictIds.SOUTH_RESIDENTIAL],
		[DistrictIds.SOUTH_RESIDENTIAL, DistrictIds.RURAL_OUTSKIRTS],
		[DistrictIds.SOUTH_RESIDENTIAL, DistrictIds.EAST_ESTATE],
		[DistrictIds.NORTHSIDE, DistrictIds.WEST_INDUSTRIAL],
		[DistrictIds.EAST_ESTATE, DistrictIds.RURAL_OUTSKIRTS],
	]

## district/location layout: town centre in the middle, the four "inner"
## districts arranged around it, rural/outskirts further out beyond
## south residential -- a rough town shape rather than a grid.
static func _district_specs() -> Array:
	return [
		{
			"id": DistrictIds.TOWN_CENTRE, "name": "Town Centre", "center": Vector2(0, 0), "radius": 900.0, "branches": 5,
			"locations": [
				{"id": POLICE_STATION, "name": "Westford Police Station", "tag": "station", "count": 1},
				{"id": "high_street", "name": "High Street", "tag": "retail", "count": 1},
				{"id": "railway_station", "name": "Railway Station", "tag": "transport", "count": 1},
				{"id": "football_stadium", "name": "Westford United Stadium", "tag": "event_venue", "count": 1},
				{"id": "town_shop", "name": "Shop", "tag": "retail", "count": 6, "names": ["Bakery", "Newsagent", "Electronics Store", "Chemist", "Phone Shop", "Bookshop"]},
				{"id": "town_pub", "name": "Pub", "tag": "night_economy", "count": 4, "names": ["The Crown", "The Red Lion", "The Ship Inn", "The Feathers"]},
				{"id": "town_restaurant", "name": "Restaurant", "tag": "night_economy", "count": 3, "names": ["Bella Italia", "Golden Dragon", "The Bistro"]},
				{"id": "supermarket", "name": "Supermarket", "tag": "retail", "count": 1},
				{"id": "town_car_park", "name": "Car Park", "tag": "car_park", "count": 2},
			],
		},
		{
			"id": DistrictIds.NORTHSIDE, "name": "Northside", "center": Vector2(0, -2600), "radius": 900.0, "branches": 4,
			"locations": [
				{"id": "northside_community_centre", "name": "Northside Community Centre", "tag": "community", "count": 1},
				{"id": "northside_estate", "name": "Estate", "tag": "residential", "count": 6, "names": ["Elm Close", "Oak Row", "Birch Gardens", "Cedar Walk", "Pine Court", "Willow Drive"]},
				{"id": "northside_shop", "name": "Shop", "tag": "retail", "count": 3, "names": ["Corner Shop", "Hair Salon", "Off-Licence"]},
				{"id": "northside_petrol_station", "name": "Petrol Station", "tag": "retail", "count": 1},
				{"id": "northside_park", "name": "Northside Park", "tag": "park", "count": 1},
			],
		},
		{
			"id": DistrictIds.EAST_ESTATE, "name": "East Estate", "center": Vector2(2900, -200), "radius": 950.0, "branches": 4,
			"locations": [
				{"id": "east_estate_community_centre", "name": "East Estate Community Centre", "tag": "community", "count": 1},
				{"id": "east_estate_row", "name": "Estate", "tag": "residential", "count": 6, "names": ["Maple Close", "Ashford Row", "Chestnut Walk", "Sycamore Court", "Rowan Drive", "Hazel Grove"]},
				{"id": "east_estate_shop", "name": "Shop", "tag": "retail", "count": 2, "names": ["Convenience Store", "Takeaway"]},
				{"id": "east_estate_park", "name": "East Estate Park", "tag": "park", "count": 1},
			],
		},
		{
			"id": DistrictIds.SOUTH_RESIDENTIAL, "name": "South Residential", "center": Vector2(0, 2600), "radius": 1000.0, "branches": 5,
			"locations": [
				{"id": "south_school", "name": "Westford Primary School", "tag": "school", "count": 1},
				{"id": "south_community_centre", "name": "South Residential Community Centre", "tag": "community", "count": 1},
				{"id": "south_estate", "name": "Estate", "tag": "residential", "count": 8, "names": ["Meadow Close", "Orchard Row", "Hillside Drive", "Riverside Walk", "Fairview Court", "Green Lane", "Beechwood Close", "Sunnyside Avenue"]},
				{"id": "south_park", "name": "Park", "tag": "park", "count": 2, "names": ["Westford Park", "Riverside Gardens"]},
				{"id": "south_shop", "name": "Shop", "tag": "retail", "count": 2, "names": ["Village Shop", "Post Office"]},
			],
		},
		{
			"id": DistrictIds.WEST_INDUSTRIAL, "name": "West Industrial", "center": Vector2(-2900, -200), "radius": 900.0, "branches": 4,
			"locations": [
				{"id": "industrial_unit", "name": "Industrial Unit", "tag": "industrial", "count": 5, "names": ["Unit 1 Distribution", "Unit 2 Engineering", "Unit 3 Logistics", "Unit 4 Warehousing", "Unit 5 Manufacturing"]},
				{"id": "west_petrol_station", "name": "Petrol Station", "tag": "retail", "count": 1},
				{"id": "west_car_park", "name": "Car Park", "tag": "car_park", "count": 1},
				{"id": "west_shop", "name": "Trade Shop", "tag": "retail", "count": 2, "names": ["Trade Counter", "Builders Merchant"]},
			],
		},
		{
			"id": DistrictIds.RURAL_OUTSKIRTS, "name": "Rural / Outskirts", "center": Vector2(2200, 4800), "radius": 1600.0, "branches": 3,
			"locations": [
				{"id": "secondary_school", "name": "Westford Secondary School", "tag": "school", "count": 1},
				{"id": "hospital", "name": "Westford General Hospital", "tag": "hospital", "count": 1},
				{"id": "fire_station", "name": "Westford Fire Station", "tag": "station", "count": 1},
				{"id": "farm", "name": "Farm", "tag": "rural", "count": 4, "names": ["Hillcrest Farm", "Long Meadow Farm", "Oak Tree Farm", "Valley View Farm"]},
				{"id": "rural_petrol_station", "name": "Petrol Station", "tag": "retail", "count": 1},
			],
		},
	]

static func _build_district(spec: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var id: String = spec["id"]
	var center: Vector2 = spec["center"]
	var radius: float = spec["radius"]
	var branch_count: int = spec["branches"]

	var road_nodes: Array[RoadNode] = []
	var road_edges: Array[RoadEdge] = []
	var locations: Array[LocationDefinition] = []

	var hub_id: String = "%s_hub" % id
	road_nodes.append(_road_node(hub_id, center))

	var branch_ids: Array[String] = []
	for i in range(branch_count):
		var angle: float = TAU * i / branch_count
		var branch_pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius * 0.6
		var branch_id: String = "%s_branch_%d" % [id, i]
		road_nodes.append(_road_node(branch_id, branch_pos))
		road_edges.append(_road_edge(hub_id, branch_id))
		branch_ids.append(branch_id)

	var location_ids: Array[String] = []
	var branch_cursor := 0
	for loc_spec: Dictionary in spec["locations"]:
		var count: int = int(loc_spec.get("count", 1))
		var names: Array = loc_spec.get("names", [])
		for i in range(count):
			var loc_id: String = String(loc_spec["id"]) if count == 1 else "%s_%d" % [loc_spec["id"], i + 1]
			var display_name: String
			if count == 1:
				display_name = String(loc_spec["name"])
			elif i < names.size():
				display_name = String(names[i])
			else:
				display_name = "%s %d" % [loc_spec["name"], i + 1]

			var branch_id: String = branch_ids[branch_cursor % branch_ids.size()]
			branch_cursor += 1
			var branch_node: RoadNode = _find_node(road_nodes, branch_id)
			var jitter := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * radius * 0.18
			var position: Vector2 = branch_node.position + jitter

			var location := LocationDefinition.new()
			location.id = loc_id
			location.display_name = display_name
			location.district_id = id
			location.position = position
			location.nearest_road_node_id = branch_id
			location.tags = [String(loc_spec.get("tag", ""))]
			locations.append(location)
			location_ids.append(loc_id)

	var district := DistrictDefinition.new()
	district.id = id
	district.display_name = String(spec["name"])
	district.location_ids = location_ids
	district.boundary = _circle_polygon(center, radius, 12)

	return {"district": district, "locations": locations, "road_nodes": road_nodes, "road_edges": road_edges, "hub_node_id": hub_id}

static func _find_node(nodes: Array[RoadNode], id: String) -> RoadNode:
	for n in nodes:
		if n.id == id:
			return n
	return null

static func _circle_polygon(center: Vector2, radius: float, sides: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(sides):
		var angle: float = TAU * i / sides
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points

static func _road_node(id: String, position: Vector2) -> RoadNode:
	var node := RoadNode.new()
	node.id = id
	node.position = position
	return node

static func _road_edge(from_id: String, to_id: String) -> RoadEdge:
	var edge := RoadEdge.new()
	edge.from_id = from_id
	edge.to_id = to_id
	return edge

static func _to_string_array(value: Array) -> Array[String]:
	var result: Array[String] = []
	for item in value:
		result.append(String(item))
	return result
