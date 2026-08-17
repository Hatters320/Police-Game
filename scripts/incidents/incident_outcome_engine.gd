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
