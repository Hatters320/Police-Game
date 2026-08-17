extends SceneTree
## Headless debug harness -- Milestone 1's exit criterion (spec section 61
## Phase 1 / section 63): proves a full simulated shift runs end-to-end
## without any scene, map, or UI. Run with:
##
##   godot4 --headless --script res://tests/run_shift_debug.gd
##
## Builds the small test map, its 5 incident types and 1 event, and a
## 12-officer shift roster, then fast-forwards a full 12h shift while a
## trivial auto-dispatch stand-in plays the Inspector's role (send nearest
## available unit to the highest-priority queued incident), and prints a
## shift log + debrief-shaped summary. No autoload, no SimulationCore
## private methods reached into -- everything here goes through the same
## public surface Presentation would use.

var _core: SimulationCore

func _init() -> void:
	print("=== WESTFORD headless shift debug run ===")

	_core = SimulationCore.new()
	var world: WorldMapData = TestMapFactory.build()
	var incident_types: Array[IncidentTypeDefinition] = IncidentTypeFactory.build_all()
	var events: Array[EventDefinition] = EventFactory.build_all()
	_core.initialize(world, incident_types, events, 42) # fixed seed -- reproducible runs, spec section 64

	_core.incident_manager.incident_created.connect(_on_incident_created)
	_core.incident_manager.incident_escalated.connect(_on_incident_escalated)
	_core.incident_manager.incident_resolved.connect(_on_incident_resolved)
	_core.fatigue_manager.fatigue_warning.connect(_on_fatigue_warning)
	_core.tick_completed.connect(_on_tick_completed)

	var roster: Array[Officer] = OfficerFactory.build_shift_roster()
	var priorities: Array[String] = ["asb", "town_centre_disorder"]
	var shift_start_minute := 17 * 60 # 17:00
	var shift_duration_minutes := 12 * 60 # 12h shift -- spec section 15 default
	_core.start_shift(1, shift_start_minute, shift_duration_minutes, roster, priorities, 2)

	var priorities_text: String = ""
	for i in range(priorities.size()):
		if i > 0:
			priorities_text += ", "
		priorities_text += priorities[i]

	print("\nShift 1 briefing:")
	print("  Available officers: %d" % roster.size())
	print("  Deployable units: %d" % _core.resource_manager.units.size())
	print("  Priorities: %s" % priorities_text)
	print("")

	_core.fast_forward_shift()

	var summary: Dictionary = _core.compile_shift_summary()
	print("\n=== SHIFT DEBRIEF (raw counters -- full 5-dimension scoring is Milestone 5) ===")
	print("Resolved this shift: %d" % summary["resolved_this_shift"])
	print("Still open at shift end (carried into next shift, not discarded): %d" % summary["still_open_incidents"])
	print("Total incidents in history: %d" % summary["total_history_count"])
	print("Intelligence items gathered: %d" % summary["intelligence_items"])
	print("")
	print(_core.debug_commands.dump_state())

	quit()

## Trivial stand-in for the player so this harness runs unattended --
## Milestone 3's incident panel replaces this with real decisions. Sends
## the nearest available unit to the highest-priority queued incident,
## once per simulated minute.
func _on_tick_completed() -> void:
	var available: Array[PoliceUnit] = _core.resource_manager.available_units()
	if available.is_empty():
		return
	var queued: Array[Incident] = []
	for incident: Incident in _core.incident_manager.active_incidents.values():
		if incident.state == GameEnums.IncidentState.QUEUED:
			queued.append(incident)
	if queued.is_empty():
		return
	queued.sort_custom(func(a, b): return a.priority < b.priority)
	for incident in queued:
		if available.is_empty():
			break
		var unit: PoliceUnit = available.pop_back()
		var result: Dictionary = _core.commands.assign_unit_to_incident(unit.id, incident.id)
		if result["result"] == GameEnums.CommandResultCode.OK:
			_core.commands.set_command_intent(incident.id, GameEnums.CommandIntent.RESPOND)

func _on_incident_created(incident_id: String) -> void:
	var incident: Incident = _core.incident_manager.get_incident(incident_id)
	print("[%s] NEW %s (P%d) at %s" % [_core.shift_manager.shift_state.time_of_day_string(), incident.type_id, incident.priority, incident.location_id])

func _on_incident_escalated(incident_id: String) -> void:
	var incident: Incident = _core.incident_manager.get_incident(incident_id)
	print("[%s] ESCALATED %s -> level %d (now P%d)" % [_core.shift_manager.shift_state.time_of_day_string(), incident.type_id, incident.escalation_level, incident.priority])

func _on_incident_resolved(incident_id: String, outcome_id: String) -> void:
	var incident: Incident = _core.incident_manager.get_incident(incident_id)
	print("[%s] RESOLVED %s -> %s" % [_core.shift_manager.shift_state.time_of_day_string(), incident.type_id, outcome_id])

func _on_fatigue_warning(officer_id: String) -> void:
	print("  fatigue warning: %s" % officer_id)
