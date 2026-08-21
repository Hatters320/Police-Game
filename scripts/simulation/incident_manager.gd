class_name IncidentManager
extends RefCounted
## Generates, advances, escalates, and resolves incidents (spec section
## 20-30). Active incidents stay live across shifts (cross-shift handover --
## see docs/ARCHITECTURE.md) and every incident that reaches OUTCOME is
## appended to an ever-growing history log.

signal incident_created(incident_id: String)
signal incident_state_changed(incident_id: String, old_state: GameEnums.IncidentState, new_state: GameEnums.IncidentState)
signal incident_escalated(incident_id: String)
signal incident_resolved(incident_id: String, outcome_id: String)

## Range for Incident.duration_multiplier, rolled once per incident and
## applied to its ON_SCENE/DEVELOPING handling time. Real playtesting: "a
## unit goes to an incident and they are done within a minute whereas in
## the real world this does not happen" -- at 1x speed a simulated minute
## is one real second, so the configured 15-30 simulated-minute on-scene
## totals (data/incident_type_factory.gd) were reading as barely any time
## at all. Both ends stay above 1.0 so no incident gets shorter than
## before, only longer and more varied call to call.
const ON_SCENE_DURATION_MULTIPLIER_MIN := 1.5
const ON_SCENE_DURATION_MULTIPLIER_MAX := 4.0

var active_incidents: Dictionary = {} # incident_id -> Incident
var history: Array[IncidentHistoryEntry] = []

var _type_defs: Dictionary = {} # type_id -> IncidentTypeDefinition
var _type_defs_list: Array[IncidentTypeDefinition] = []
var _world: WorldMapData
var _next_incident_number: int = 1

func setup(type_defs: Array[IncidentTypeDefinition], world: WorldMapData) -> void:
	_type_defs.clear()
	_type_defs_list = type_defs
	for def in type_defs:
		_type_defs[def.id] = def
	_world = world

func get_incident(incident_id: String) -> Incident:
	return active_incidents.get(incident_id)

## Called by SaveManager after loading incidents from disk, so newly
## generated incidents can't collide with ids restored from the save.
func ensure_next_incident_number_above(n: int) -> void:
	_next_incident_number = maxi(_next_incident_number, n)

func get_type_definition(type_id: String) -> IncidentTypeDefinition:
	return _type_defs.get(type_id)

func open_incidents_in_district(district_id: String) -> Array[Incident]:
	var result: Array[Incident] = []
	for incident: Incident in active_incidents.values():
		if incident.district_id == district_id and incident.is_open():
			result.append(incident)
	return result

func tick(ctx: SimulationContext) -> void:
	_maybe_generate_incident(ctx)
	_advance_active_incidents(ctx)

## Called by ResourceManager the moment a unit assigned to this incident
## finishes travelling. `ctx` is optional (kept so any direct/debug caller
## without a context still works) -- when given, the KPI dashboard's
## response-time-vs-target tracking is recorded here, the one real place
## "first on scene" happens.
func mark_unit_arrived(incident_id: String, current_minute: int, ctx: SimulationContext = null) -> void:
	var incident: Incident = active_incidents.get(incident_id)
	if incident == null:
		return
	if incident.state == GameEnums.IncidentState.TRAVELLING:
		var old_state: GameEnums.IncidentState = incident.state
		incident.state_machine.transition_to(GameEnums.IncidentState.ON_SCENE)
		if incident.first_on_scene_minute < 0:
			incident.first_on_scene_minute = current_minute
			if ctx and ctx.kpi_tracker:
				ctx.kpi_tracker.record_arrival(incident.priority, float(current_minute - incident.created_at_minute))
		incident_state_changed.emit(incident_id, old_state, incident.state)

## Debug/dev tool entry point (spec section 65). Normal generation happens
## via tick(); this exists so DebugCommands can force one on demand.
func spawn_incident_for_debug(type_id: String, district_id: String, current_minute: int, rng: RandomNumberGenerator) -> Incident:
	return _create_incident(type_id, district_id, current_minute, rng)

## Debug/dev tool entry point (spec section 65): resolves an incident
## immediately regardless of its current state, running the same outcome
## computation / unit release / history logging a natural resolution
## does. Not just flipping a field to RESOLVED -- resolution is driven by
## _advance_active_incidents noticing a state *change* during its tick,
## so setting the field alone (with no tick in between) would silently
## never actually resolve it.
func force_resolve(incident_id: String, ctx: SimulationContext) -> void:
	var incident: Incident = active_incidents.get(incident_id)
	if incident == null or not incident.is_open():
		return
	var type_def: IncidentTypeDefinition = _type_defs.get(incident.type_id)
	if type_def == null:
		return
	var old_state: GameEnums.IncidentState = incident.state
	incident.state = GameEnums.IncidentState.RESOLVED # force, from whatever state it was in
	incident_state_changed.emit(incident.id, old_state, incident.state)
	_resolve(incident, type_def, ctx)
	active_incidents.erase(incident_id)
	history.append(incident.to_history_entry())

## Controlled secondary-incident chain (spec section 31): a scripted, not
## fully emergent, follow-on incident triggered by EventManager when an
## active event's coverage condition is met (e.g. the football match's
## "resources committed -> reduced coverage -> shoplifting opportunity").
## Distinct from spawn_incident_for_debug in intent even though both call
## the same underlying creator -- this is a real gameplay path, not a dev
## tool, and it stamps a known fact explaining why the incident appeared.
func spawn_secondary_incident(type_id: String, district_id: String, ctx: SimulationContext, cause_note: String) -> Incident:
	var incident: Incident = _create_incident(type_id, district_id, ctx.current_minute, ctx.rng)
	if incident:
		incident.known_facts.append(cause_note)
	return incident

## Cross-shift handover (docs/ARCHITECTURE.md): called once by ShiftManager
## at shift end. Every still-open incident loses its assignment and steps
## back no further than QUEUED; nothing else about it resets.
func apply_shift_handover() -> void:
	for incident: Incident in active_incidents.values():
		incident.apply_shift_handover()

func _maybe_generate_incident(ctx: SimulationContext) -> void:
	var pick: Dictionary = IncidentProbabilityEngine.roll_for_incident(
		_type_defs_list, ctx.district_manager.districts, ctx.event_manager.active_events(),
		ctx.current_minute, ctx.dt_minutes, ctx.rng, ctx.weather_manager.current_weather
	)
	if pick.is_empty():
		return
	_create_incident(pick["type_id"], pick["district_id"], ctx.current_minute, ctx.rng)

func _create_incident(type_id: String, district_id: String, current_minute: int, rng: RandomNumberGenerator) -> Incident:
	var type_def: IncidentTypeDefinition = _type_defs.get(type_id)
	if type_def == null:
		push_warning("IncidentManager: unknown incident type %s" % type_id)
		return null

	var location_id: String = district_id
	var district_def: DistrictDefinition = _world.get_district(district_id) if _world else null
	if district_def and not district_def.location_ids.is_empty():
		location_id = district_def.location_ids[rng.randi() % district_def.location_ids.size()]

	var incident_id: String = "incident_%d" % _next_incident_number
	_next_incident_number += 1
	var incident := Incident.new(incident_id, type_id, district_id, location_id, current_minute)

	var inputs: Dictionary = IncidentProbabilityEngine.roll_priority_inputs(type_def, rng)
	incident.threat = inputs["threat"]
	incident.harm = inputs["harm"]
	incident.vulnerability = inputs["vulnerability"]
	incident.immediacy = inputs["immediacy"]
	incident.opportunity = inputs["opportunity"]
	incident.priority = inputs["priority"]

	# MVP: every incident starts with all its "known" facts known; the
	# information-gap gameplay (spec section 23) lives in unknown_facts,
	# which REQUEST INFORMATION reveals over time via Commands.
	incident.known_facts = type_def.known_fact_templates.duplicate()
	incident.unknown_facts = type_def.unknown_fact_templates.duplicate()

	incident.duration_multiplier = rng.randf_range(ON_SCENE_DURATION_MULTIPLIER_MIN, ON_SCENE_DURATION_MULTIPLIER_MAX)

	incident.state_machine.transition_to(GameEnums.IncidentState.REPORTED)
	active_incidents[incident_id] = incident
	incident_created.emit(incident_id)
	return incident

func _advance_active_incidents(ctx: SimulationContext) -> void:
	var resolved_ids: Array[String] = []
	for incident: Incident in active_incidents.values():
		var type_def: IncidentTypeDefinition = _type_defs.get(incident.type_id)
		if type_def == null:
			continue
		var old_state: GameEnums.IncidentState = incident.state
		incident.state_machine.advance(ctx.dt_minutes)
		_maybe_auto_progress(incident, type_def)
		_maybe_escalate(incident, type_def, ctx)
		if incident.state != old_state:
			incident_state_changed.emit(incident.id, old_state, incident.state)
			if incident.state == GameEnums.IncidentState.RESOLVED:
				_resolve(incident, type_def, ctx)
		if incident.state == GameEnums.IncidentState.OUTCOME:
			resolved_ids.append(incident.id)
	for incident_id in resolved_ids:
		var incident: Incident = active_incidents[incident_id]
		history.append(incident.to_history_entry())
		active_incidents.erase(incident_id)

## States that progress on a timer rather than a player action: call-taking
## / triage (REPORTED -> ASSESSED -> QUEUED) and on-scene handling
## (ON_SCENE -> DEVELOPING -> RESOLVED). QUEUED -> ASSIGNED -> TRAVELLING
## only happens via Commands.assign_unit_to_incident (a player decision),
## and TRAVELLING -> ON_SCENE only via mark_unit_arrived (an actual unit
## arriving) -- neither is a timer.
func _maybe_auto_progress(incident: Incident, type_def: IncidentTypeDefinition) -> void:
	match incident.state:
		GameEnums.IncidentState.REPORTED:
			if incident.time_in_current_state >= type_def.state_duration(GameEnums.IncidentState.REPORTED, 2.0):
				incident.state_machine.transition_to(GameEnums.IncidentState.ASSESSED)
		GameEnums.IncidentState.ASSESSED:
			if incident.time_in_current_state >= type_def.state_duration(GameEnums.IncidentState.ASSESSED, 1.0):
				incident.state_machine.transition_to(GameEnums.IncidentState.QUEUED)
		GameEnums.IncidentState.ON_SCENE:
			# duration_multiplier applies only to the on-scene handling
			# phases (not REPORTED/ASSESSED triage) -- see its declaration
			# on Incident for why.
			if incident.time_in_current_state >= type_def.state_duration(GameEnums.IncidentState.ON_SCENE, 15.0) * incident.duration_multiplier:
				incident.state_machine.transition_to(GameEnums.IncidentState.DEVELOPING)
		GameEnums.IncidentState.DEVELOPING:
			if incident.time_in_current_state >= type_def.state_duration(GameEnums.IncidentState.DEVELOPING, 10.0) * incident.duration_multiplier:
				incident.state_machine.transition_to(GameEnums.IncidentState.RESOLVED)
		_:
			pass

## Unassigned/waiting incidents accrue escalation risk over time (spec
## section 29); being on scene resets the clock since officers are now
## dealing with it. Orthogonal counter, not a state -- see
## docs/ARCHITECTURE.md section 4/6.
func _maybe_escalate(incident: Incident, type_def: IncidentTypeDefinition, ctx: SimulationContext) -> void:
	if not incident.is_open():
		return
	if incident.state == GameEnums.IncidentState.CREATED \
			or incident.state == GameEnums.IncidentState.ON_SCENE \
			or incident.state == GameEnums.IncidentState.DEVELOPING:
		return
	var district: DistrictState = ctx.district_manager.get_state(incident.district_id)
	var tension_modifier: float = 1.0
	if district:
		tension_modifier = 1.0 + (district.community_tension - 50.0) / 100.0
	var risk: float = type_def.escalation_risk_per_minute * ctx.dt_minutes * tension_modifier
	if ctx.rng.randf() < risk:
		incident.escalation_level += 1
		incident.priority = maxi(incident.priority - 1, 1)
		incident.threat = clampf(incident.threat + 10.0, 0.0, 100.0)
		incident.harm = clampf(incident.harm + 10.0, 0.0, 100.0)
		# Previously confidence only moved on resolution (CommunityManager),
		# so a call left to escalate unattended was invisible on the town's
		# confidence reading until (if ever) it was finally dealt with. This
		# is what makes "ignoring a call costs confidence" real and visible
		# on the live KPI dashboard as it happens, not just at debrief.
		if district:
			district.apply_community_effect(-1.5, 1.0)
		incident_escalated.emit(incident.id)

func _resolve(incident: Incident, type_def: IncidentTypeDefinition, ctx: SimulationContext) -> void:
	var assigned_officers: Array[Officer] = []
	for unit_id in incident.assigned_unit_ids:
		var unit: PoliceUnit = ctx.resource_manager.get_unit(unit_id)
		if unit == null:
			continue
		for officer_id in unit.officer_ids:
			var officer: Officer = ctx.officer_manager.get_officer(officer_id)
			if officer:
				assigned_officers.append(officer)

	var response_delay: float
	if incident.first_on_scene_minute >= 0:
		response_delay = float(incident.first_on_scene_minute - incident.created_at_minute)
	else:
		response_delay = 120.0 # never attended -- treat as a poor response for outcome weighting

	incident.outcome_id = IncidentOutcomeEngine.resolve(incident, type_def, assigned_officers, response_delay, ctx.rng)
	incident.resolved_at_minute = ctx.current_minute
	incident.state_machine.transition_to(GameEnums.IncidentState.OUTCOME)

	_free_assigned_units(incident, ctx)

	var district: DistrictState = ctx.district_manager.get_state(incident.district_id)
	if district:
		district.apply_delta("incident_pressure", 3.0)
		ctx.community_manager.apply_incident_resolution_effect(district, incident)
	ctx.intelligence_manager.generate_from_incident_outcome(incident, type_def, ctx.current_minute)

	incident_resolved.emit(incident.id, incident.outcome_id)

func _free_assigned_units(incident: Incident, ctx: SimulationContext) -> void:
	for unit_id in incident.assigned_unit_ids:
		var unit: PoliceUnit = ctx.resource_manager.get_unit(unit_id)
		if unit == null:
			continue
		unit.status = GameEnums.UnitStatus.AVAILABLE
		unit.current_incident_id = ""
		unit.command_intent = GameEnums.CommandIntent.NONE
	incident.assigned_unit_ids.clear()
