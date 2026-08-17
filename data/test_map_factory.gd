class_name TestMapFactory
extends RefCounted
## Builds the small test map (spec section 62): 3 districts, 12 locations,
## 4 road nodes / 5 edges. Built in code rather than authored as .tres --
## Godot isn't available in the sandbox this was written in to validate
## hand-written resource files, so a factory function is the safer choice
## for now. Swap for real authored .tres content (or an in-editor tool)
## once this can be opened and checked in the actual editor; nothing else
## in the simulation layer cares which one supplies the WorldMapData.

const TOWN_CENTRE := DistrictIds.TOWN_CENTRE
const NORTHSIDE := DistrictIds.NORTHSIDE
const EAST_ESTATE := DistrictIds.EAST_ESTATE

const POLICE_STATION := "police_station"

static func build() -> WorldMapData:
	var world := WorldMapData.new()

	var node_hub := _road_node("node_hub", Vector2(0, 0))
	var node_town_centre := _road_node("node_town_centre", Vector2(800, 0))
	var node_northside := _road_node("node_northside", Vector2(0, -1500))
	var node_east_estate := _road_node("node_east_estate", Vector2(1500, 800))
	world.road_nodes = [node_hub, node_town_centre, node_northside, node_east_estate]

	world.road_edges = [
		_road_edge("node_hub", "node_town_centre"),
		_road_edge("node_hub", "node_northside"),
		_road_edge("node_hub", "node_east_estate"),
		_road_edge("node_town_centre", "node_northside"),
		_road_edge("node_town_centre", "node_east_estate"),
	]

	var town_centre_locations: Array[LocationDefinition] = [
		_location(POLICE_STATION, "Westford Police Station", TOWN_CENTRE, Vector2(0, 0), "node_hub", ["station"]),
		_location("high_street", "High Street", TOWN_CENTRE, Vector2(800, 50), "node_town_centre", ["retail", "night_economy"]),
		_location("railway_station", "Railway Station", TOWN_CENTRE, Vector2(850, -50), "node_town_centre", ["transport"]),
		_location("football_stadium", "Westford United Stadium", TOWN_CENTRE, Vector2(900, 100), "node_town_centre", ["event_venue"]),
	]
	var northside_locations: Array[LocationDefinition] = [
		_location("northside_retail_park", "Northside Retail Park", NORTHSIDE, Vector2(0, -1450), "node_northside", ["retail"]),
		_location("northside_community_centre", "Northside Community Centre", NORTHSIDE, Vector2(50, -1550), "node_northside", ["community"]),
		_location("northside_estate", "Northside Estate", NORTHSIDE, Vector2(-50, -1500), "node_northside", ["residential"]),
		_location("petrol_station", "Northside Petrol Station", NORTHSIDE, Vector2(100, -1500), "node_northside", ["retail"]),
	]
	var east_estate_locations: Array[LocationDefinition] = [
		_location("east_estate_shops", "East Estate Shops", EAST_ESTATE, Vector2(1500, 850), "node_east_estate", ["retail"]),
		_location("east_estate_community_centre", "East Estate Community Centre", EAST_ESTATE, Vector2(1550, 750), "node_east_estate", ["community"]),
		_location("east_estate_park", "East Estate Park", EAST_ESTATE, Vector2(1450, 900), "node_east_estate", ["residential"]),
		_location("industrial_estate", "Industrial Estate", EAST_ESTATE, Vector2(1600, 800), "node_east_estate", ["industrial"]),
	]

	world.locations = []
	world.locations.append_array(town_centre_locations)
	world.locations.append_array(northside_locations)
	world.locations.append_array(east_estate_locations)

	world.districts = [
		_district(TOWN_CENTRE, "Town Centre", town_centre_locations, [NORTHSIDE, EAST_ESTATE]),
		_district(NORTHSIDE, "Northside", northside_locations, [TOWN_CENTRE]),
		_district(EAST_ESTATE, "East Estate", east_estate_locations, [TOWN_CENTRE]),
	]

	world.police_station_location_id = POLICE_STATION
	world.rebuild_index()
	return world

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

static func _location(id: String, display_name: String, district_id: String, position: Vector2, road_node_id: String, tags: Array[String]) -> LocationDefinition:
	var loc := LocationDefinition.new()
	loc.id = id
	loc.display_name = display_name
	loc.district_id = district_id
	loc.position = position
	loc.nearest_road_node_id = road_node_id
	loc.tags = tags
	return loc

static func _district(id: String, display_name: String, locations: Array[LocationDefinition], neighbour_ids: Array[String]) -> DistrictDefinition:
	var district := DistrictDefinition.new()
	district.id = id
	district.display_name = display_name
	var location_ids: Array[String] = []
	for loc in locations:
		location_ids.append(loc.id)
	district.location_ids = location_ids
	district.neighbour_district_ids = neighbour_ids
	# Simple bounding-box boundary around this district's locations, enough
	# for future map drawing/hit-testing -- not meaningful yet with no map.
	var min_pos: Vector2 = locations[0].position
	var max_pos: Vector2 = locations[0].position
	for loc in locations:
		min_pos = Vector2(minf(min_pos.x, loc.position.x), minf(min_pos.y, loc.position.y))
		max_pos = Vector2(maxf(max_pos.x, loc.position.x), maxf(max_pos.y, loc.position.y))
	var pad := Vector2(300, 300)
	min_pos -= pad
	max_pos += pad
	district.boundary = PackedVector2Array([
		Vector2(min_pos.x, min_pos.y), Vector2(max_pos.x, min_pos.y),
		Vector2(max_pos.x, max_pos.y), Vector2(min_pos.x, max_pos.y),
	])
	return district
