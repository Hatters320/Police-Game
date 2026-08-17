class_name DebugCommands
extends RefCounted
## Developer tools (spec section 65) -- kept for the life of the MVP, not
## removed after debugging. Thin, deliberately less guarded than Commands
## since these are dev-only.

var _ctx: SimulationContext

func setup(ctx: SimulationContext) -> void:
	_ctx = ctx

func spawn_incident(type_id: String, district_id: String) -> Incident:
	return _ctx.incident_manager.spawn_incident_for_debug(type_id, district_id, _ctx.current_minute, _ctx.rng)

func complete_incident(incident_id: String) -> void:
	_ctx.incident_manager.force_resolve(incident_id, _ctx)

func force_escalate(incident_id: String) -> void:
	var incident: Incident = _ctx.incident_manager.get_incident(incident_id)
	if incident:
		incident.escalation_level += 1
		incident.priority = maxi(incident.priority - 1, 1)

func set_district_value(district_id: String, variable_name: String, value: float) -> void:
	var district: DistrictState = _ctx.district_manager.get_state(district_id)
	if district:
		district.set_variable(variable_name, value)

func make_officer_unavailable(officer_id: String) -> void:
	var officer: Officer = _ctx.officer_manager.get_officer(officer_id)
	if officer:
		officer.status = GameEnums.OfficerStatus.UNAVAILABLE_SICK

func restore_officer(officer_id: String) -> void:
	var officer: Officer = _ctx.officer_manager.get_officer(officer_id)
	if officer:
		officer.status = GameEnums.OfficerStatus.AVAILABLE

func advance_time(minutes: int) -> void:
	_ctx.game_clock.force_advance_minutes(minutes)

func trigger_event(event_id: String) -> void:
	# MVP events are purely schedule-driven (spec section 32); manual
	# triggering isn't wired up yet. Flagged here rather than silently
	# doing nothing, so this gap is visible if a debug UI calls it.
	push_warning("DebugCommands.trigger_event: manual trigger not implemented yet (events are schedule-driven); id=%s" % event_id)

func dump_state() -> String:
	var text: String = "=== SIMULATION STATE @ %s (day minute %d) ===\n" % [_ctx.shift_manager.shift_state.time_of_day_string(), _ctx.current_minute]
	text += "Active incidents: %d\n" % _ctx.incident_manager.active_incidents.size()
	for district_id in _ctx.district_manager.districts.keys():
		var d: DistrictState = _ctx.district_manager.districts[district_id]
		text += "  %s: ASB=%.0f tension=%.0f visibility=%.0f confidence=%.0f\n" % [
			district_id, d.asb, d.community_tension, d.police_visibility, d.community_confidence,
		]
	return text
