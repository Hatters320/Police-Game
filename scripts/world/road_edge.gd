class_name RoadEdge
extends Resource
## Connects two RoadNodes. Length is derived from node positions at graph-
## build time rather than authored here, so it can never drift out of sync
## with the nodes' actual positions.

@export var from_id: String
@export var to_id: String
## 1.0 = normal road speed. Lower values model slower roads (e.g. residential
## streets); higher values model faster ones (e.g. a bypass).
@export var speed_factor: float = 1.0
