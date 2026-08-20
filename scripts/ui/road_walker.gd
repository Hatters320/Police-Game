class_name RoadWalker
extends Node3D
## A single moving actor (car or pedestrian) that follows City3DView's real
## street-cell walk graph (see City3DView._build_walk_graph()) -- a
## node_id -> position/neighbour lookup built from the actual placed
## road-straight/road-crossroad GridMap tiles, not the original gameplay
## RoadGraph (an earlier version of this used that graph directly, which
## put cars/pedestrians driving straight through buildings since it was
## never aligned to the finer per-district street lattice actually
## rendered). On reaching a node this picks a random adjacent edge (never
## immediately doubling back unless it's a dead end) and keeps going,
## forever -- no destination, no pathfinding, just believable ambient
## traffic/pedestrian life. Deliberately its own individually instanced
## Node3D (not a GridMap cell) since a GridMap cell can't move: this IS the
## fix for "cars are just static" -- movement is the one thing the
## shared-mesh GridMap approach used for buildings/trees fundamentally
## cannot do.
##
## `lateral_offset` lets pedestrians walk a "sidewalk" a little off the
## road centreline instead of down the middle of the carriageway cars use
## (offset 0).

var _positions: Dictionary # node_id (Vector2i street cell, or String hub pseudo-node) -> Vector3
var _adjacency: Dictionary # node_id -> Array[node_id]
var _from_id: Variant
var _to_id: Variant
var _progress: float = 0.0
var _speed: float = 1.0
var _lateral_offset: float = 0.0
var _rng := RandomNumberGenerator.new()

func setup(positions: Dictionary, adjacency: Dictionary, start_id: Variant, speed: float, lateral_offset: float, seed: int) -> void:
	_positions = positions
	_adjacency = adjacency
	_from_id = start_id
	_speed = speed
	_lateral_offset = lateral_offset
	_rng.seed = seed
	_to_id = _pick_next(_from_id, null)
	_progress = 0.0
	_place_at_edge_start()

func _process(delta: float) -> void:
	if _to_id == null:
		return
	var from_pos: Vector3 = _positions[_from_id]
	var to_pos: Vector3 = _positions[_to_id]
	var seg_len: float = from_pos.distance_to(to_pos)
	if seg_len < 0.05:
		_advance()
		return
	_progress += (_speed * delta) / seg_len
	if _progress >= 1.0:
		_advance()
		return
	_apply_transform(from_pos, to_pos)

func _apply_transform(from_pos: Vector3, to_pos: Vector3) -> void:
	var dir: Vector3 = (to_pos - from_pos).normalized()
	var side: Vector3 = dir.cross(Vector3.UP).normalized() * _lateral_offset
	position = from_pos.lerp(to_pos, _progress) + side
	if dir.length_squared() > 0.0001:
		# look_at aims the node's -Z axis at the target, but these models
		# (Kenney vehicles and the character rig alike) are authored facing
		# +Z. Aiming at position + dir therefore pointed every car and
		# pedestrian's back down its direction of travel -- real
		# playtesting: "the people and cars are moving backwards".
		# Targeting position - dir puts -Z behind them, so +Z (their front)
		# leads.
		look_at(position - dir, Vector3.UP)

func _place_at_edge_start() -> void:
	if _to_id == null:
		position = _positions.get(_from_id, Vector3.ZERO)
		return
	_apply_transform(_positions[_from_id], _positions[_to_id])

func _advance() -> void:
	var prev: Variant = _from_id
	_from_id = _to_id
	_to_id = _pick_next(_from_id, prev)
	_progress = 0.0

func _pick_next(node_id: Variant, avoid_id: Variant) -> Variant:
	var neighbours: Array = _adjacency.get(node_id, [])
	if neighbours.is_empty():
		return null
	var candidates: Array = neighbours.filter(func(n): return n != avoid_id)
	if candidates.is_empty():
		candidates = neighbours
	return candidates[_rng.randi() % candidates.size()]
