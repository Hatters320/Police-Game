class_name LocationDefinition
extends Resource
## A named, gameplay-meaningful place (railway station, community centre,
## football stadium, ...). Incidents, patrol tasking, and events all
## reference locations by id.

@export var id: String
@export var display_name: String
@export var district_id: String
@export var position: Vector2
## Snaps this location onto the road graph deterministically, rather than
## relying on a runtime nearest-neighbour search.
@export var nearest_road_node_id: String
@export var tags: Array[String] = []
