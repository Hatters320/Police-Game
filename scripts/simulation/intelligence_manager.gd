class_name IntelligenceManager
extends RefCounted
## Intelligence items surfaced to the player (spec section 43). MVP scope:
## simple text items generated from incident outcomes -- no per-item
## confidence/reliability modelling yet.

signal intelligence_added(item_id: String)

var items: Array[Dictionary] = [] # {id, text, district_id, created_at_minute}
var _next_id: int = 1

func add_item(text: String, district_id: String, current_minute: int) -> void:
	var item_id: String = "intel_%d" % _next_id
	_next_id += 1
	items.append({"id": item_id, "text": text, "district_id": district_id, "created_at_minute": current_minute})
	intelligence_added.emit(item_id)

func generate_from_incident_outcome(incident: Incident, type_def: IncidentTypeDefinition, current_minute: int) -> void:
	if incident.outcome_id == "":
		return
	var text: String = "%s at %s resolved: %s" % [type_def.display_name, incident.location_id, incident.outcome_id]
	add_item(text, incident.district_id, current_minute)

func items_for_district(district_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in items:
		if item["district_id"] == district_id:
			result.append(item)
	return result
