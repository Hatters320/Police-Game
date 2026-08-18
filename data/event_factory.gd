class_name EventFactory
extends RefCounted
## Builds the one planned event required by spec section 32 -- the
## Westford United football match, affecting the Town Centre district on
## whichever map is currently loaded (small test map or the full town).

static func build_all() -> Array[EventDefinition]:
	return [_football_match()]

static func _football_match() -> EventDefinition:
	var event := EventDefinition.new()
	event.id = "westford_united_match"
	event.display_name = "Westford United v Ashford Town"
	event.start_minute = 19 * 60 + 30 # 19:30 kick-off
	event.duration_minutes = 150 # covers kick-off through to dispersal, per spec section 32's example
	event.affected_district_ids = [DistrictIds.TOWN_CENTRE]
	event.incident_weight_multiplier = 1.8
	event.district_variable_deltas = {
		"traffic_activity": 25.0,
		"night_economy": 10.0,
		"community_tension": 5.0,
	}
	# Spec section 31's literal controlled-chain example: this event, once
	# it has pulled enough units away to leave the town thin on coverage,
	# can spawn one opportunist shoplifting incident -- see EventManager.
	event.secondary_incident_type_id = "shoplifting"
	event.secondary_incident_chance_per_hour = 3.0
	event.secondary_incident_coverage_threshold = 1
	return event
