class_name PoliceUnit
extends RefCounted
## A deployable crewed vehicle (1-2 officers) -- spec section 12/36.
## RefCounted, not Resource; see docs/ARCHITECTURE.md.

var id: String
var callsign: String
var officer_ids: Array[String] = []
var status: GameEnums.UnitStatus = GameEnums.UnitStatus.AVAILABLE

var current_position: Vector2 = Vector2.ZERO
var current_road_node_id: String = ""

var path: PackedVector2Array = PackedVector2Array()
var path_length_total: float = 0.0
var path_distance_travelled: float = 0.0
var destination_node_id: String = ""
var destination_location_id: String = ""

var current_incident_id: String = ""
var command_intent: GameEnums.CommandIntent = GameEnums.CommandIntent.NONE

var patrol_mode: GameEnums.PatrolMode = GameEnums.PatrolMode.RESERVE
var patrol_location_id: String = ""

func _init(p_id: String, p_callsign: String, p_officer_ids: Array[String]) -> void:
	id = p_id
	callsign = p_callsign
	officer_ids = p_officer_ids

func is_double_crewed() -> bool:
	return officer_ids.size() >= 2

## Starts travelling a precomputed path (computed once per dispatch by the
## caller via RoadGraph -- never recomputed per tick/frame).
func begin_travel(new_path: PackedVector2Array, to_node_id: String, to_location_id: String = "") -> void:
	path = new_path
	path_length_total = RoadGraph.path_length(new_path)
	path_distance_travelled = 0.0
	destination_node_id = to_node_id
	destination_location_id = to_location_id
	status = GameEnums.UnitStatus.TRAVELLING
	if new_path.size() > 0:
		current_position = new_path[0]

## Advances along the cached path by `distance` (world units). Returns true
## once the unit has arrived at its destination.
func advance_along_path(distance: float) -> bool:
	if path.size() < 2:
		return true
	path_distance_travelled = minf(path_distance_travelled + distance, path_length_total)
	current_position = _position_at_distance(path_distance_travelled)
	var arrived: bool = path_distance_travelled >= path_length_total
	if arrived:
		current_road_node_id = destination_node_id
	return arrived

func remaining_distance() -> float:
	return maxf(path_length_total - path_distance_travelled, 0.0)

func eta_seconds(speed_units_per_min: float) -> float:
	if speed_units_per_min <= 0.0:
		return INF
	return (remaining_distance() / speed_units_per_min) * 60.0

func _position_at_distance(distance: float) -> Vector2:
	var travelled := 0.0
	for i in range(path.size() - 1):
		var segment_length: float = path[i].distance_to(path[i + 1])
		if travelled + segment_length >= distance:
			var t: float = 0.0 if segment_length <= 0.0 else (distance - travelled) / segment_length
			return path[i].lerp(path[i + 1], t)
		travelled += segment_length
	return path[path.size() - 1] if path.size() > 0 else current_position
