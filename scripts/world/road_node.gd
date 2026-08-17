class_name RoadNode
extends Resource
## A point on the road graph. Static map data -- authored once, never mutated
## at runtime (see docs/ARCHITECTURE.md's Resource-vs-RefCounted rule).

@export var id: String
@export var position: Vector2
