class_name NeighbourhoodOfficer
extends RefCounted
## A neighbourhood officer (spec section 10) -- exists separately from the
## main response team, with its own task states rather than being folded
## into PoliceUnit/ResourceManager. RefCounted, never a Resource; see
## docs/ARCHITECTURE.md.

var id: String
var officer_name: String
var status: GameEnums.NeighbourhoodStatus = GameEnums.NeighbourhoodStatus.AVAILABLE

var task_incident_id: String = ""
var task_district_id: String = ""
var task_minutes_remaining: float = 0.0

func _init(p_id: String, p_officer_name: String) -> void:
	id = p_id
	officer_name = p_officer_name
