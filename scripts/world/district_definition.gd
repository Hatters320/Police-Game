class_name DistrictDefinition
extends Resource
## Static geography for a district. Its dynamic simulation variables (ASB,
## tension, police visibility, ...) live separately on a runtime
## DistrictState with the same id -- see docs/ARCHITECTURE.md section 1-2.

@export var id: String
@export var display_name: String
## World-space polygon, used for map drawing and district hit-testing.
@export var boundary: PackedVector2Array = PackedVector2Array()
@export var location_ids: Array[String] = []
@export var neighbour_district_ids: Array[String] = []
