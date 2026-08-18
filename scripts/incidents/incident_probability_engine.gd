class_name IncidentProbabilityEngine
extends RefCounted
## Turns district state + time-of-day + active events into a weighted
## choice of which incident type (if any) fires this tick, and where.
## Spec section 20: incidents are generated from world state, not pure
## randomness. Stateless -- every method is pure given its inputs, so it's
## trivially unit-testable and needs no instance.

## Returns {} if no incident should be generated this tick, else
## {"type_id": String, "district_id": String}.
static func roll_for_incident(
	type_defs: Array[IncidentTypeDefinition],
	district_states: Dictionary, # district_id -> DistrictState
	active_events: Array[EventDefinition],
	current_minute: int,
	dt_minutes: float,
	rng: RandomNumberGenerator
) -> Dictionary:
	var weights: Dictionary = {} # "type_id|district_id" -> weight (expected/hour)
	var total_weight := 0.0
	for type_def in type_defs:
		for district_id in district_states.keys():
			var district: DistrictState = district_states[district_id]
			var w: float = _weight_for(type_def, district, active_events, current_minute)
			if w <= 0.0:
				continue
			var key: String = "%s|%s" % [type_def.id, district_id]
			weights[key] = w
			total_weight += w
	if total_weight <= 0.0:
		return {}
	# total_weight is an expected-incidents-per-hour rate; convert to a
	# probability for this tick's dt and roll once against it.
	var expected_this_tick: float = total_weight * (dt_minutes / 60.0)
	if rng.randf() > expected_this_tick:
		return {}
	var roll: float = rng.randf() * total_weight
	var cumulative := 0.0
	for key in weights.keys():
		cumulative += weights[key]
		if roll <= cumulative:
			var parts: PackedStringArray = key.split("|")
			return {"type_id": parts[0], "district_id": parts[1]}
	return {}

static func _weight_for(
	type_def: IncidentTypeDefinition,
	district: DistrictState,
	active_events: Array[EventDefinition],
	current_minute: int
) -> float:
	var rate: float = type_def.base_rate_per_hour
	for variable_name in type_def.district_weight_factors.keys():
		var value: float = district.get_variable(variable_name)
		var baseline: float = district.get_baseline_variable(variable_name)
		var factor: float = type_def.district_weight_factors[variable_name]
		# Weighted off deviation from this district's own normal, not a
		# universal midpoint -- see DistrictState.get_baseline_variable.
		rate *= 1.0 + ((value - baseline) / 50.0) * factor
	if type_def.night_weighted and _is_night(current_minute):
		rate *= 1.6
	for event in active_events:
		if event.affects_district(district.district_id):
			rate *= event.incident_weight_multiplier
	return maxf(rate, 0.0)

static func _is_night(current_minute: int) -> bool:
	var hour: int = (current_minute % (24 * 60)) / 60
	return hour >= 21 or hour < 5

## Applies random variance around the type's base priority inputs and
## derives a 1-5 priority band from combined severity. Spec section 24 is
## explicit that this is a gameplay abstraction, not a real grading model.
static func roll_priority_inputs(type_def: IncidentTypeDefinition, rng: RandomNumberGenerator) -> Dictionary:
	var threat: float = clampf(type_def.base_threat + rng.randfn(0.0, 8.0), 0.0, 100.0)
	var harm: float = clampf(type_def.base_harm + rng.randfn(0.0, 8.0), 0.0, 100.0)
	var vulnerability: float = clampf(type_def.base_vulnerability + rng.randfn(0.0, 8.0), 0.0, 100.0)
	var immediacy: float = clampf(type_def.base_immediacy + rng.randfn(0.0, 8.0), 0.0, 100.0)
	var opportunity: float = clampf(type_def.base_opportunity + rng.randfn(0.0, 8.0), 0.0, 100.0)
	var severity: float = threat * 0.3 + harm * 0.3 + vulnerability * 0.2 + immediacy * 0.2
	var priority: int = 5
	if severity >= 80.0:
		priority = 1
	elif severity >= 60.0:
		priority = 2
	elif severity >= 40.0:
		priority = 3
	elif severity >= 20.0:
		priority = 4
	return {
		"threat": threat, "harm": harm, "vulnerability": vulnerability,
		"immediacy": immediacy, "opportunity": opportunity, "priority": priority,
	}
