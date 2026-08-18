class_name IncidentOutcomeEngine
extends RefCounted
## Resolves a RESOLVED incident into one weighted outcome, influenced by
## assigned-officer capability, response delay, fatigue, and the chosen
## command intent -- spec section 30/48/49: outcomes are influenced by the
## player's decisions, never a coin flip.

static func resolve(
	incident: Incident,
	type_def: IncidentTypeDefinition,
	assigned_officers: Array[Officer],
	response_delay_minutes: float,
	rng: RandomNumberGenerator
) -> String:
	if type_def.possible_outcomes.is_empty():
		return "unresolved"
	var skill_avg: float = _average_relevant_skill(assigned_officers)
	# Spec section 9: sergeants are resources the player can specifically
	# commit to a difficult incident, and that choice should matter. Folded
	# into skill_avg (rather than a separate flat multiplier on every
	# outcome weight, which the roll below normalises by total and so would
	# have zero effect) so it pulls favoured-skill outcomes the same way
	# officer competence already does.
	if needs_supervisor(incident, assigned_officers):
		skill_avg = clampf(skill_avg + (0.15 if has_supervisor(assigned_officers) else -0.15), 0.0, 1.0)
	var avg_fatigue: float = _average_fatigue(assigned_officers)
	var weights: Array[float] = []
	var total := 0.0
	for outcome in type_def.possible_outcomes:
		var w: float = outcome.get("base_weight", 1.0)
		var favoured_skill: String = outcome.get("favoured_skill", "")
		if favoured_skill != "":
			w *= 0.5 + skill_avg # stronger crews pull good outcomes up, weak crews down
		var favoured_intent = outcome.get("favoured_intent", GameEnums.CommandIntent.NONE)
		if incident.command_intent == favoured_intent:
			w *= 1.4
		w *= clampf(1.0 - response_delay_minutes / 120.0, 0.3, 1.0)
		w *= clampf(1.0 - (avg_fatigue / 100.0) * 0.4, 0.4, 1.0)
		weights.append(maxf(w, 0.01))
		total += weights[-1]
	var roll: float = rng.randf() * total
	var cumulative := 0.0
	for i in range(type_def.possible_outcomes.size()):
		cumulative += weights[i]
		if roll <= cumulative:
			return type_def.possible_outcomes[i].get("id", "unresolved")
	return type_def.possible_outcomes[-1].get("id", "unresolved")

## Spec section 9: "a supervisor may be required for difficult incidents,
## officer support, developing incidents, incidents involving inexperienced
## officers." Deliberately simple rules, not supervisory AI, per spec.
## `officers` is optional so callers who only have the incident (e.g. the
## panel, before any unit is assigned) can still check the incident-only
## conditions.
static func needs_supervisor(incident: Incident, officers: Array[Officer] = []) -> bool:
	if incident.escalation_level > 0:
		return true
	if incident.state == GameEnums.IncidentState.DEVELOPING:
		return true
	for officer in officers:
		if officer.experience == GameEnums.OfficerExperience.LOW:
			return true
	return false

static func has_supervisor(officers: Array[Officer]) -> bool:
	for officer in officers:
		if officer.rank == GameEnums.OfficerRank.SERGEANT:
			return true
	return false

static func _average_relevant_skill(officers: Array[Officer]) -> float:
	if officers.is_empty():
		return 0.3
	var total := 0.0
	for officer in officers:
		# Response and communication are broadly relevant at MVP scope;
		# per-type skill weighting can be added later purely as data, since
		# this engine already reads favoured_skill from the outcome table.
		total += (officer.skill_value("response") + officer.skill_value("communication")) / 2.0
	return total / officers.size()

static func _average_fatigue(officers: Array[Officer]) -> float:
	if officers.is_empty():
		return 0.0
	var total := 0.0
	for officer in officers:
		total += officer.fatigue
	return total / officers.size()
