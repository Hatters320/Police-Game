class_name WorldMapData
extends Resource
## The complete static map: districts, locations, and the road graph's raw
## node/edge data. Loaded/built once and shared read-only by the simulation
## (district ids, pathfinding, location lookups) and the map scene
## (drawing). Never mutated at runtime -- the debug tool that changes
## district values mutates the runtime DistrictState, never this.

@export var districts: Array[DistrictDefinition] = []
@export var locations: Array[LocationDefinition] = []
@export var road_nodes: Array[RoadNode] = []
@export var road_edges: Array[RoadEdge] = []
@export var police_station_location_id: String

var _district_by_id: Dictionary = {}
var _location_by_id: Dictionary = {}

## Must be called once after districts/locations are populated (the data
## factories call this). Not automatic, so callers never pay for a lazy
## rebuild check on every lookup.
func rebuild_index() -> void:
	_district_by_id.clear()
	for d: DistrictDefinition in districts:
		_district_by_id[d.id] = d
	_location_by_id.clear()
	for l: LocationDefinition in locations:
		_location_by_id[l.id] = l

func get_district(district_id: String) -> DistrictDefinition:
	return _district_by_id.get(district_id)

func get_location(location_id: String) -> LocationDefinition:
	return _location_by_id.get(location_id)
