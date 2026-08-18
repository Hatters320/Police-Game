class_name SpecialistUnit
extends RefCounted
## A single specialist resource (traffic/dog/firearms, spec section 11) --
## external to the response team, not guaranteed, and travel time matters.
## RefCounted, never a Resource; see docs/ARCHITECTURE.md.

var id: String
var display_name: String
var type: GameEnums.SpecialistType
var status: GameEnums.SpecialistStatus = GameEnums.SpecialistStatus.AVAILABLE

var committed_incident_id: String = ""
var travel_minutes_remaining: float = 0.0
var commitment_minutes_remaining: float = 0.0

func _init(p_id: String, p_display_name: String, p_type: GameEnums.SpecialistType) -> void:
	id = p_id
	display_name = p_display_name
	type = p_type
