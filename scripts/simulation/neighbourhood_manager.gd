class_name NeighbourhoodManager
extends RefCounted
## Owns the neighbourhood team (spec section 10) -- 2-4 officers who exist
## separately from the main response team, generally don't work overnight,
## and have their own simplified task states rather than being folded into
## PoliceUnit/ResourceManager. Persists across shifts the way OfficerManager
## does not, since spec doesn't describe them as rotating staff the way the
## response roster does; built once in setup(), not per-shift.

signal officer_task_completed(officer_id: String)

## A day/evening resource in the MVP (spec section 10: "generally do not
## work overnight") -- outside this window they're forced UNAVAILABLE
## regardless of what they were doing, which matters a lot given the
## game's one shift runs 17:00-05:00 and mostly falls outside it.
const DUTY_START_MINUTE := 7 * 60
const DUTY_END_MINUTE := 21 * 60

## How long a proactive/engagement/incident task runs before the officer
## reports back available -- a simplified stand-in for however long the
## real task actually takes, same abstraction SpecialistManager uses.
const TASK_MINUTES := 45.0

var officers: Dictionary = {} # id -> NeighbourhoodOfficer

func setup() -> void:
	officers.clear()
	_add("pcso_ferreira", "PCSO Ferreira")
	_add("pcso_doyle", "PCSO Doyle")
	_add("pcso_ahmadi", "PCSO Ahmadi")

func _add(id: String, display_name: String) -> void:
	officers[id] = NeighbourhoodOfficer.new(id, display_name)

func get_officer(officer_id: String) -> NeighbourhoodOfficer:
	return officers.get(officer_id)

func is_on_duty(current_minute: int) -> bool:
	var minute_of_day: int = current_minute % (24 * 60)
	return minute_of_day >= DUTY_START_MINUTE and minute_of_day < DUTY_END_MINUTE

func task_to_incident(officer_id: String, incident_id: String) -> Dictionary:
	var officer: NeighbourhoodOfficer = get_officer(officer_id)
	if officer == null:
		return {"accepted": false, "reason": "unknown officer"}
	if officer.status != GameEnums.NeighbourhoodStatus.AVAILABLE:
		return {"accepted": false, "reason": "officer not available"}
	officer.status = GameEnums.NeighbourhoodStatus.EXISTING_TASK
	officer.task_incident_id = incident_id
	officer.task_district_id = ""
	officer.task_minutes_remaining = TASK_MINUTES
	return {"accepted": true}

## General proactive/community-engagement tasking to a district (spec
## section 10's "community engagement / ASB / reassurance / problem-solving")
## rather than to a specific incident.
func task_engagement(officer_id: String, district_id: String) -> Dictionary:
	var officer: NeighbourhoodOfficer = get_officer(officer_id)
	if officer == null:
		return {"accepted": false, "reason": "unknown officer"}
	if officer.status != GameEnums.NeighbourhoodStatus.AVAILABLE:
		return {"accepted": false, "reason": "officer not available"}
	officer.status = GameEnums.NeighbourhoodStatus.COMMUNITY_ENGAGEMENT
	officer.task_incident_id = ""
	officer.task_district_id = district_id
	officer.task_minutes_remaining = TASK_MINUTES
	return {"accepted": true}

func recall(officer_id: String) -> Dictionary:
	var officer: NeighbourhoodOfficer = get_officer(officer_id)
	if officer == null:
		return {"accepted": false, "reason": "unknown officer"}
	if officer.status == GameEnums.NeighbourhoodStatus.UNAVAILABLE:
		return {"accepted": false, "reason": "off duty"}
	_finish_task(officer)
	return {"accepted": true}

func tick(ctx: SimulationContext) -> void:
	var on_duty: bool = is_on_duty(ctx.current_minute)
	for officer: NeighbourhoodOfficer in officers.values():
		if not on_duty:
			if officer.status != GameEnums.NeighbourhoodStatus.UNAVAILABLE:
				_finish_task(officer) # clears any task cleanly before going off duty
				officer.status = GameEnums.NeighbourhoodStatus.UNAVAILABLE
			continue
		if officer.status == GameEnums.NeighbourhoodStatus.UNAVAILABLE:
			officer.status = GameEnums.NeighbourhoodStatus.AVAILABLE
			continue
		if officer.status == GameEnums.NeighbourhoodStatus.COMMUNITY_ENGAGEMENT and officer.task_district_id != "":
			ctx.district_manager.apply_patrol(officer.task_district_id, ctx.dt_minutes, 0.5)
			var district: DistrictState = ctx.district_manager.get_state(officer.task_district_id)
			if district:
				district.apply_delta("community_confidence", 0.05 * ctx.dt_minutes)
		if officer.status != GameEnums.NeighbourhoodStatus.AVAILABLE:
			officer.task_minutes_remaining = maxf(officer.task_minutes_remaining - ctx.dt_minutes, 0.0)
			if officer.task_minutes_remaining <= 0.0:
				_complete_task(officer, ctx)

func _complete_task(officer: NeighbourhoodOfficer, ctx: SimulationContext) -> void:
	if officer.status == GameEnums.NeighbourhoodStatus.EXISTING_TASK and officer.task_incident_id != "":
		var incident: Incident = ctx.incident_manager.get_incident(officer.task_incident_id)
		if incident and incident.is_open():
			incident.reveal_unknown_fact() # already appends to known_facts itself
	officer_task_completed.emit(officer.id)
	_finish_task(officer)

func _finish_task(officer: NeighbourhoodOfficer) -> void:
	officer.status = GameEnums.NeighbourhoodStatus.AVAILABLE
	officer.task_incident_id = ""
	officer.task_district_id = ""
	officer.task_minutes_remaining = 0.0

func status_text(officer: NeighbourhoodOfficer) -> String:
	match officer.status:
		GameEnums.NeighbourhoodStatus.AVAILABLE:
			return "Available"
		GameEnums.NeighbourhoodStatus.COMMUNITY_ENGAGEMENT:
			return "Community engagement (%d min)" % int(ceil(officer.task_minutes_remaining))
		GameEnums.NeighbourhoodStatus.PROACTIVE_TASK:
			return "Proactive task (%d min)" % int(ceil(officer.task_minutes_remaining))
		GameEnums.NeighbourhoodStatus.EXISTING_TASK:
			return "Gathering intelligence (%d min)" % int(ceil(officer.task_minutes_remaining))
		GameEnums.NeighbourhoodStatus.UNAVAILABLE:
			return "Off duty"
		_:
			return "Unknown"
