class_name Commands
extends RefCounted
## Validated entry points from Presentation into the simulation (spec
## section 25-27). Every call returns an explicit result -- nothing
## silently no-ops. Owned and wired up by SimulationCore with a
## SimulationContext giving access to every manager it needs.
##
## Reassignment-with-preview (spec section 27 -- show consequences before
## confirming) is deferred to Milestone 3 when there's a UI to preview into;
## assign_unit_to_incident here is the direct dispatch path.

signal command_rejected(command_name: String, reason: String)

var _ctx: SimulationContext

func setup(ctx: SimulationContext) -> void:
	_ctx = ctx

func assign_unit_to_incident(unit_id: String, incident_id: String) -> Dictionary:
	var unit: PoliceUnit = _ctx.resource_manager.get_unit(unit_id)
	var incident: Incident = _ctx.incident_manager.get_incident(incident_id)
	if unit == null:
		return _reject("assign_unit_to_incident", "unknown unit")
	if incident == null:
		return _reject("assign_unit_to_incident", "unknown incident")
	if unit.status != GameEnums.UnitStatus.AVAILABLE and unit.status != GameEnums.UnitStatus.PATROL:
		return _reject("assign_unit_to_incident", "unit not available")
	if not incident.is_open():
		return _reject("assign_unit_to_incident", "incident already resolved")
	if incident.state == GameEnums.IncidentState.CREATED \
			or incident.state == GameEnums.IncidentState.REPORTED \
			or incident.state == GameEnums.IncidentState.ASSESSED:
		# Not yet QUEUED -- dispatching this early would start the unit
		# travelling while the incident's own state machine has nowhere
		# valid to jump to (QUEUED -> ASSIGNED -> TRAVELLING is the only
		# validated path), leaving the two desynced. Reinforcing an
		# incident already ASSIGNED/TRAVELLING/ON_SCENE/DEVELOPING is
		# still fine and intentionally allowed below (spec section 25's
		# "SEND MULTIPLE").
		return _reject("assign_unit_to_incident", "incident still being assessed")

	var location: LocationDefinition = _ctx.world.get_location(incident.location_id)
	if location == null:
		return _reject("assign_unit_to_incident", "incident location not found")

	var path: PackedVector2Array = _ctx.road_graph.get_path(unit.current_road_node_id, location.nearest_road_node_id)
	unit.begin_travel(path, location.nearest_road_node_id, location.id)
	unit.current_incident_id = incident_id
	incident.assigned_unit_ids.append(unit_id)

	if incident.state == GameEnums.IncidentState.QUEUED:
		incident.state_machine.transition_to(GameEnums.IncidentState.ASSIGNED)
	incident.state_machine.transition_to(GameEnums.IncidentState.TRAVELLING)
	return {"result": GameEnums.CommandResultCode.OK}

func set_command_intent(incident_id: String, intent: GameEnums.CommandIntent) -> Dictionary:
	var incident: Incident = _ctx.incident_manager.get_incident(incident_id)
	if incident == null:
		return _reject("set_command_intent", "unknown incident")
	incident.command_intent = intent
	return {"result": GameEnums.CommandResultCode.OK}

func request_information(incident_id: String) -> Dictionary:
	var incident: Incident = _ctx.incident_manager.get_incident(incident_id)
	if incident == null:
		return _reject("request_information", "unknown incident")
	var fact: String = incident.reveal_unknown_fact()
	if fact == "":
		return _reject("request_information", "no further information available")
	return {"result": GameEnums.CommandResultCode.OK, "fact": fact}

func send_for_break(unit_id: String) -> Dictionary:
	var unit: PoliceUnit = _ctx.resource_manager.get_unit(unit_id)
	if unit == null:
		return _reject("send_for_break", "unknown unit")
	if unit.status != GameEnums.UnitStatus.AVAILABLE and unit.status != GameEnums.UnitStatus.PATROL:
		return _reject("send_for_break", "unit not free to break")
	unit.status = GameEnums.UnitStatus.ON_BREAK
	for officer_id in unit.officer_ids:
		var officer: Officer = _ctx.officer_manager.get_officer(officer_id)
		if officer:
			officer.status = GameEnums.OfficerStatus.ON_BREAK
	return {"result": GameEnums.CommandResultCode.OK}

func return_from_break(unit_id: String) -> Dictionary:
	var unit: PoliceUnit = _ctx.resource_manager.get_unit(unit_id)
	if unit == null:
		return _reject("return_from_break", "unknown unit")
	unit.status = GameEnums.UnitStatus.AVAILABLE
	for officer_id in unit.officer_ids:
		var officer: Officer = _ctx.officer_manager.get_officer(officer_id)
		if officer:
			officer.status = GameEnums.OfficerStatus.ON_UNIT
	return {"result": GameEnums.CommandResultCode.OK}

func set_speed(multiplier: float) -> Dictionary:
	_ctx.game_clock.speed_multiplier = maxf(multiplier, 0.0)
	_ctx.game_clock.paused = false
	return {"result": GameEnums.CommandResultCode.OK}

func pause() -> Dictionary:
	_ctx.game_clock.paused = true
	return {"result": GameEnums.CommandResultCode.OK}

func resume() -> Dictionary:
	_ctx.game_clock.paused = false
	return {"result": GameEnums.CommandResultCode.OK}

func set_reserve(count: int) -> Dictionary:
	_ctx.shift_manager.shift_state.reserve_target = maxi(count, 0)
	return {"result": GameEnums.CommandResultCode.OK}

func set_priorities(priorities: Array[String]) -> Dictionary:
	_ctx.shift_manager.shift_state.priorities = priorities.slice(0, 3)
	return {"result": GameEnums.CommandResultCode.OK}

func _reject(command_name: String, reason: String) -> Dictionary:
	command_rejected.emit(command_name, reason)
	return {"result": GameEnums.CommandResultCode.REJECTED, "reason": reason}
