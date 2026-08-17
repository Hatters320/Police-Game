class_name RoadGraph
extends RefCounted
## Wraps an AStar2D built from WorldMapData's road nodes/edges. Vehicles are
## constrained to this fixed graph, which is exactly AStar2D's design case --
## see docs/ARCHITECTURE.md section 7 for why this is used instead of
## NavigationServer2D.

var _astar: AStar2D = AStar2D.new()
var _node_index_by_id: Dictionary = {}
var _node_position_by_id: Dictionary = {}

func build(world: WorldMapData) -> void:
	_astar.clear()
	_node_index_by_id.clear()
	_node_position_by_id.clear()
	var next_index := 0
	for node: RoadNode in world.road_nodes:
		_astar.add_point(next_index, node.position)
		_node_index_by_id[node.id] = next_index
		_node_position_by_id[node.id] = node.position
		next_index += 1
	for edge: RoadEdge in world.road_edges:
		if not _node_index_by_id.has(edge.from_id) or not _node_index_by_id.has(edge.to_id):
			push_warning("RoadEdge references unknown node: %s -> %s" % [edge.from_id, edge.to_id])
			continue
		_astar.connect_points(_node_index_by_id[edge.from_id], _node_index_by_id[edge.to_id])

## Path is computed once per dispatch (by the caller) and cached on the
## PoliceUnit -- never recomputed per tick/frame.
func get_path(from_node_id: String, to_node_id: String) -> PackedVector2Array:
	if not _node_index_by_id.has(from_node_id) or not _node_index_by_id.has(to_node_id):
		push_warning("RoadGraph.get_path: unknown node id(s) %s -> %s" % [from_node_id, to_node_id])
		return PackedVector2Array()
	return _astar.get_point_path(_node_index_by_id[from_node_id], _node_index_by_id[to_node_id])

static func path_length(path: PackedVector2Array) -> float:
	var length := 0.0
	for i in range(path.size() - 1):
		length += path[i].distance_to(path[i + 1])
	return length

func node_position(node_id: String) -> Vector2:
	return _node_position_by_id.get(node_id, Vector2.ZERO)
