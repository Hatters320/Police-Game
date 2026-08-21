class_name DispatchScorer
extends RefCounted
## Scores a candidate unit for a specific incident, combining skill fit,
## real travel time, and supervision suitability into one ranked
## recommendation -- the feature request's "unit selection based on
## officer skills, availability, proximity, and suitability for the
## incident type", replacing the previous straight-line "nearest unit"
## hint (IncidentPanelView used to call this a "cheap, close-enough
## proxy" rather than the real thing). Availability is filtered by the
## caller before this runs; this only ranks units already known sendable.

const SKILL_WEIGHT := 10.0
const ETA_WEIGHT := 2.0
const SUPERVISOR_BONUS := 8.0
const SUPERVISOR_PENALTY := -8.0

## Returns {"score": float, "eta_minutes": float}. Higher score = better
## pick. eta_minutes is INF if no road route exists between the unit and
## the incident's location.
static func score_unit(
	unit: PoliceUnit,
	crew: Array[Officer],
	incident: Incident,
	type_def: IncidentTypeDefinition,
	location: LocationDefinition,
	road_graph: RoadGraph,
	speed_units_per_min: float,
) -> Dictionary:
	var eta_minutes: float = _eta_minutes(unit, location, road_graph, speed_units_per_min)
	var skill_score: float = _skill_score(crew, type_def)

	var eta_penalty: float = eta_minutes * ETA_WEIGHT if not is_inf(eta_minutes) else 999.0
	var score: float = skill_score * SKILL_WEIGHT - eta_penalty
	if IncidentOutcomeEngine.needs_supervisor(incident, crew):
		score += SUPERVISOR_BONUS if IncidentOutcomeEngine.has_supervisor(crew) else SUPERVISOR_PENALTY

	return {"score": score, "eta_minutes": eta_minutes}

## Path length via the real road graph, not the straight-line distance the
## previous "nearest unit" hint used -- a unit on the wrong side of the
## river or a dead-end estate can be close as the crow flies but genuinely
## slow to reach, and this is what the player actually experiences once
## dispatched (Commands.assign_unit_to_incident builds this exact path).
static func _eta_minutes(unit: PoliceUnit, location: LocationDefinition, road_graph: RoadGraph, speed_units_per_min: float) -> float:
	if location == null or road_graph == null or speed_units_per_min <= 0.0:
		return INF
	var path: PackedVector2Array = road_graph.get_path(unit.current_road_node_id, location.nearest_road_node_id)
	if path.is_empty():
		return INF
	return RoadGraph.path_length(path) / speed_units_per_min

## 0..1, matching Officer.skill_value's own scale -- the crew's best
## matching officer for the incident type's primary skill, since a
## two-officer unit only needs one of them to be the strong hand for it.
static func _skill_score(crew: Array[Officer], type_def: IncidentTypeDefinition) -> float:
	if crew.is_empty() or type_def == null or type_def.primary_skill == "":
		return 0.55
	var best := 0.0
	for officer: Officer in crew:
		best = maxf(best, officer.skill_value(type_def.primary_skill))
	return best
