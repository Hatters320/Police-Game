class_name EventFactory
extends RefCounted
## Builds the one planned event required by spec section 32 -- the Westford
## United football match -- scaled onto the small test map's Town Centre
## district (spec section 62 wants exactly 1 event for the prototype).

static func build_all() -> Array[EventDefinition]:
	return [_football_match()]

static func _football_match() -> EventDefinition:
	var event := EventDefinition.new()
	event.id = "westford_united_match"
	event.display_name = "Westford United v Ashford Town"
	event.start_minute = 19 * 60 + 30 # 19:30 kick-off
	event.duration_minutes = 150 # covers kick-off through to dispersal, per spec section 32's example
	event.affected_district_ids = [TestMapFactory.TOWN_CENTRE]
	event.incident_weight_multiplier = 1.8
	event.district_variable_deltas = {
		"traffic_activity": 25.0,
		"night_economy": 10.0,
		"community_tension": 5.0,
	}
	return event
