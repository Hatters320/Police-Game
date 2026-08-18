class_name Commands
extends RefCounted
## Validated entry points from Presentation into the simulation (spec
## section 25-27). Every call returns an explicit result -- nothing
## silently no-ops. Owned and wired up by SimulationCore with a
## SimulationContext giving access to every manager it needs.
##
## assign_unit_to_incident doubles as the reassignment path (spec section
## 27): sending an already-busy unit elsewhere pulls it off its current
## incident first. The "show consequences before confirming" part isn't a
## separate preview/confirm step -- IncidentPanelView always shows what a
## unit is currently doing right next to the button that would reassign
## it, so the information is visible before the click rather than after.

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
	if unit.status == GameEnums.UnitStatus.ON_BREAK or unit.status == GameEnums.UnitStatus.UNAVAILABLE:
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
	if unit.current_incident_id == incident_id:
		return _reject("assign_unit_to_incident", "already assigned to this incident")

	# Unit is committed elsewhere (AVAILABLE/PATROL units simply have no
	# current_incident_id set, so this only fires for a genuine
	# reassignment) -- free it from the old incident first so that
	# incident doesn't keep a ghost assignment to a unit that's now gone.
	if unit.current_incident_id != "":
		var old_incident: Incident = _ctx.incident_manager.get_incident(unit.current_incident_id)
		if old_incident:
			old_incident.assigned_unit_ids.erase(unit_id)

	var location: LocationDefinition = _ctx.world.get_location(incident.location_id)
	if location == null:
		return _reject("assign_unit_to_incident", "incident location not found")

	var path: PackedVector2Array = _ctx.road_graph.get_path(unit.current_road_node_id, location.nearest_road_node_id)
	unit.begin_travel(path, location.nearest_road_node_id, location.id)
	unit.current_incident_id = incident_id
	unit.patrol_mode = GameEnums.PatrolMode.RESERVE
	unit.patrol_location_id = ""
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

## Pulls a unit off whatever incident it's on (if any) and returns it to
## AVAILABLE, without sending it anywhere else -- the "stand it down, I
## didn't need backup after all" action alongside assign_unit_to_incident's
## reassign-to-somewhere-else path.
func stand_down_unit(unit_id: String) -> Dictionary:
	var unit: PoliceUnit = _ctx.resource_manager.get_unit(unit_id)
	if unit == null:
		return _reject("stand_down_unit", "unknown unit")
	if unit.current_incident_id != "":
		var incident: Incident = _ctx.incident_manager.get_incident(unit.current_incident_id)
		if incident:
			incident.assigned_unit_ids.erase(unit_id)
	unit.current_incident_id = ""
	unit.command_intent = GameEnums.CommandIntent.NONE
	unit.status = GameEnums.UnitStatus.AVAILABLE
	unit.patrol_mode = GameEnums.PatrolMode.RESERVE
	unit.patrol_location_id = ""
	return {"result": GameEnums.CommandResultCode.OK}

## Directed patrol tasking (spec section 18): sends an available unit to a
## location, where ResourceManager.tick applies police-visibility/crime
## suppression to that location's district for as long as it stays there.
## Withdrawn the moment the unit leaves (reassigned, sent on break, etc.)
## since patrol presence is computed live off the unit's current status.
func set_directed_patrol(unit_id: String, location_id: String) -> Dictionary:
	var unit: PoliceUnit = _ctx.resource_manager.get_unit(unit_id)
	if unit == null:
		return _reject("set_directed_patrol", "unknown unit")
	if unit.status != GameEnums.UnitStatus.AVAILABLE:
		return _reject("set_directed_patrol", "unit not available")
	var location: LocationDefinition = _ctx.world.get_location(location_id)
	if location == null:
		return _reject("set_directed_patrol", "unknown location")
	var path: PackedVector2Array = _ctx.road_graph.get_path(unit.current_road_node_id, location.nearest_road_node_id)
	unit.begin_travel(path, location.nearest_road_node_id, location.id)
	unit.patrol_mode = GameEnums.PatrolMode.DIRECTED
	unit.patrol_location_id = location_id
	return {"result": GameEnums.CommandResultCode.OK}

## Recalls a unit from directed patrol back to the station, becoming
## AVAILABLE once it arrives (handled by ResourceManager.tick the same way
## as any other arrival with no incident/patrol destination).
func recall_to_station(unit_id: String) -> Dictionary:
	var unit: PoliceUnit = _ctx.resource_manager.get_unit(unit_id)
	if unit == null:
		return _reject("recall_to_station", "unknown unit")
	if unit.status != GameEnums.UnitStatus.PATROL:
		return _reject("recall_to_station", "unit is not on patrol")
	var station: LocationDefinition = _ctx.world.get_location(_ctx.world.police_station_location_id)
	if station == null:
		return _reject("recall_to_station", "police station not found")
	unit.patrol_mode = GameEnums.PatrolMode.RESERVE
	unit.patrol_location_id = ""
	var path: PackedVector2Array = _ctx.road_graph.get_path(unit.current_road_node_id, station.nearest_road_node_id)
	unit.begin_travel(path, station.nearest_road_node_id, "")
	return {"result": GameEnums.CommandResultCode.OK}

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

## REQUEST SPECIALIST (spec section 11/25) -- not gated by incident type in
## the MVP, since spec doesn't specify per-type eligibility and "simple
## rules are sufficient" (section 9). Not guaranteed: rejects if the
## specialist rolled UNAVAILABLE this shift or is already committed.
func request_specialist(incident_id: String, specialist_type: GameEnums.SpecialistType) -> Dictionary:
	var incident: Incident = _ctx.incident_manager.get_incident(incident_id)
	if incident == null:
		return _reject("request_specialist", "unknown incident")
	if not incident.is_open():
		return _reject("request_specialist", "incident already resolved")
	var unit: SpecialistUnit = _ctx.specialist_manager.unit_for_type(specialist_type)
	if unit == null:
		return _reject("request_specialist", "unknown specialist type")
	var result: Dictionary = _ctx.specialist_manager.request(unit.id, incident_id)
	if not result["accepted"]:
		return _reject("request_specialist", result["reason"])
	return {"result": GameEnums.CommandResultCode.OK, "eta_minutes": result["eta_minutes"]}

## Tasks a neighbourhood officer to gather intelligence on a specific
## incident (spec section 10's "intelligence gathering").
func task_neighbourhood_to_incident(officer_id: String, incident_id: String) -> Dictionary:
	var incident: Incident = _ctx.incident_manager.get_incident(incident_id)
	if incident == null:
		return _reject("task_neighbourhood_to_incident", "unknown incident")
	var result: Dictionary = _ctx.neighbourhood_manager.task_to_incident(officer_id, incident_id)
	if not result["accepted"]:
		return _reject("task_neighbourhood_to_incident", result["reason"])
	return {"result": GameEnums.CommandResultCode.OK}

## General proactive/community-engagement tasking to a district (spec
## section 10's "community engagement / ASB / reassurance").
func task_neighbourhood_engagement(officer_id: String, district_id: String) -> Dictionary:
	var district: DistrictState = _ctx.district_manager.get_state(district_id)
	if district == null:
		return _reject("task_neighbourhood_engagement", "unknown district")
	var result: Dictionary = _ctx.neighbourhood_manager.task_engagement(officer_id, district_id)
	if not result["accepted"]:
		return _reject("task_neighbourhood_engagement", result["reason"])
	return {"result": GameEnums.CommandResultCode.OK}

func recall_neighbourhood_officer(officer_id: String) -> Dictionary:
	var result: Dictionary = _ctx.neighbourhood_manager.recall(officer_id)
	if not result["accepted"]:
		return _reject("recall_neighbourhood_officer", result["reason"])
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
