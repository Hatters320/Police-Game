class_name IncidentPanelView
extends SidePanelView
## Incident information + action panel (spec section 25-27), opened by
## clicking an incident marker on the map. Shows known/unknown facts (with
## a Request Information action), command intent, currently assigned
## units (with Recall), and every other usable unit (with Send / Reassign
## here) -- reassigning a busy unit shows what it's currently doing right
## next to the button that would pull it off that, which stands in for a
## separate preview/confirm step (see Commands.assign_unit_to_incident's
## header comment).

var _current_incident_id: String = ""

## Draws above the always-docked Resources/Incidents panels, which stay
## visible underneath rather than closing whenever this opens.
## Takes over the screen while open -- see SidePanelView._is_modal.
func _is_modal() -> bool:
	return true

func _panel_layer() -> int:
	return 4

## Wider and taller than the other detail panels: since real playtesting
## asked for this pop-up to "take priority until it is closed", it is now
## modal (see SidePanelView's scrim) and is the screen the player actually
## makes their decision on, so it gets room to lay that decision out
## rather than being a cramped overlay.
func _panel_width() -> float:
	return 250.0

func _panel_height() -> float:
	return minf(268.0, maxf(150.0, get_viewport().get_visible_rect().size.y - PANEL_TOP_Y - 30.0))

## Centred rather than docked to one side -- a modal decision surface
## reads better in the middle than clinging to an edge.
func _panel_anchor() -> int:
	return Control.PRESET_CENTER

const ACTION_BUTTON_SIZE := Vector2(0, 26)

func open(incident_id: String) -> void:
	_current_incident_id = incident_id
	_show_panel()
	refresh()

func close() -> void:
	_current_incident_id = ""
	super.close()

func is_open_for(incident_id: String) -> bool:
	return is_open() and _current_incident_id == incident_id

func refresh() -> void:
	if _current_incident_id == "":
		return
	var incident: Incident = Simulation.core.incident_manager.get_incident(_current_incident_id)
	if incident == null:
		close()
		return

	clear_content()

	var type_def: IncidentTypeDefinition = _type_def_for(incident.type_id)
	var location: LocationDefinition = Simulation.core.world.get_location(incident.location_id)

	# Order matters and is the point of this layout, per real playtesting:
	# "the top of the pop up should present detail about the incident and
	# then the game should present the user with their deployment
	# options... and the game should have helpful suggestions to the user."
	# So: what is it, what should I do, then how to do it, then the
	# secondary tools.
	_add_header(type_def, incident, location)
	_add_suggestions_block(incident, location)
	_add_assigned_units_block(incident)
	_add_available_units_block(incident)
	_add_facts_block(incident)
	_add_intent_block(incident)
	_add_specialist_block(incident)
	_add_neighbourhood_block(incident)
	add_divider()
	add_close_button()

func _add_header(type_def: IncidentTypeDefinition, incident: Incident, location: LocationDefinition) -> void:
	add_badge(
		"P%d  %s" % [incident.priority, _priority_text(incident.priority)],
		MapView.PRIORITY_COLORS.get(incident.priority, Color.WHITE),
	)
	add_title(type_def.display_name if type_def else incident.type_id)
	add_line(location.display_name if location else incident.location_id)

	var state_text: String = "%s  ·  reported %s" % [
		_state_text(incident.state), TimeFormat.clock(incident.created_at_minute),
	]
	if incident.escalation_level > 0:
		state_text += "  ·  escalated x%d" % incident.escalation_level
	var state_label := Label.new()
	state_label.text = state_text
	state_label.add_theme_font_size_override("font_size", SMALL_FONT_SIZE)
	state_label.add_theme_color_override("font_color", Color(0.9, 0.55, 0.25) if incident.escalation_level > 0 else UiTheme.TEXT_DIM)
	state_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	content.add_child(state_label)
	add_dim_line("Threat %d   Harm %d   Vulnerability %d" % [int(incident.threat), int(incident.harm), int(incident.vulnerability)])

## Concrete next moves, computed from the same conditions the simulation
## actually scores on -- real playtesting asked for "helpful suggestions
## to the user", and the honest version of that is surfacing the things
## the outcome engine already weighs (supervision, a suited specialist,
## unknown facts) plus the obvious dispatch call, rather than generic
## advice. Deliberately capped: a wall of hints is as unhelpful as none.
func _add_suggestions_block(incident: Incident, location: LocationDefinition) -> void:
	add_divider()
	add_mini_header("SUGGESTED")

	var shown := 0
	if incident.assigned_unit_ids.is_empty():
		var nearest_id: String = _nearest_available_unit_id(incident, location)
		if nearest_id != "":
			var nearest: PoliceUnit = Simulation.core.resource_manager.get_unit(nearest_id)
			if nearest:
				var urgent: bool = incident.priority <= 2
				add_advice("Send %s -- nearest available unit." % nearest.callsign, urgent)
				shown += 1
		else:
			add_advice("No units free. Consider recalling one from a lower-priority job.", true)
			shown += 1
	elif incident.state == GameEnums.IncidentState.ON_SCENE or incident.state == GameEnums.IncidentState.DEVELOPING:
		add_advice("Unit on scene. Let it develop, or send support if it escalates.")
		shown += 1

	var officers: Array[Officer] = _assigned_officers(incident)
	if IncidentOutcomeEngine.needs_supervisor(incident, officers) and not IncidentOutcomeEngine.has_supervisor(officers):
		add_advice("Send a sergeant -- this one warrants supervision.", true)
		shown += 1

	if shown < MAX_SUGGESTIONS and not incident.unknown_facts.is_empty():
		add_advice("Request information -- %d detail(s) still unknown." % incident.unknown_facts.size())
		shown += 1

	if shown < MAX_SUGGESTIONS:
		var type_def: IncidentTypeDefinition = _type_def_for(incident.type_id)
		var recommended: int = type_def.recommended_specialist if type_def else -1
		if recommended >= 0:
			var specialist: SpecialistUnit = Simulation.core.specialist_manager.unit_for_type(recommended)
			if specialist and specialist.status == GameEnums.SpecialistStatus.AVAILABLE:
				add_advice("Request %s -- suited to this incident." % specialist.display_name)
				shown += 1

	if shown == 0:
		add_dim_line("Nothing pressing -- this one is in hand.")

const MAX_SUGGESTIONS := 3

func _state_text(state: GameEnums.IncidentState) -> String:
	match state:
		GameEnums.IncidentState.CREATED: return "Just reported"
		GameEnums.IncidentState.REPORTED: return "Being logged"
		GameEnums.IncidentState.ASSESSED: return "Being assessed"
		GameEnums.IncidentState.QUEUED: return "Queued for dispatch"
		GameEnums.IncidentState.ASSIGNED: return "Assigned"
		GameEnums.IncidentState.TRAVELLING: return "Unit travelling"
		GameEnums.IncidentState.ON_SCENE: return "Unit on scene"
		GameEnums.IncidentState.DEVELOPING: return "Developing"
		GameEnums.IncidentState.RESOLVED, GameEnums.IncidentState.OUTCOME: return "Closed"
		_: return "Unknown"

func _priority_text(priority: int) -> String:
	match priority:
		1: return "CRITICAL"
		2: return "URGENT"
		3: return "IMPORTANT"
		4: return "ROUTINE"
		_: return "NON-URGENT"

func _add_facts_block(incident: Incident) -> void:
	add_divider()
	add_mini_header("KNOWN")
	if incident.known_facts.is_empty():
		add_dim_line("(nothing confirmed yet)")
	else:
		for fact in incident.known_facts:
			add_line("•  %s" % fact)

	add_mini_header("UNKNOWN")
	if incident.unknown_facts.is_empty():
		add_dim_line("(nothing outstanding)")
	else:
		add_dim_line("%d piece(s) of information not yet known" % incident.unknown_facts.size())
		add_action_row("%d detail(s) outstanding" % incident.unknown_facts.size(), "Request", _on_request_information)

func _on_request_information() -> void:
	Simulation.commands().request_information(_current_incident_id)
	refresh()

func _add_intent_block(incident: Incident) -> void:
	add_divider()
	add_mini_header("COMMAND INTENT")
	var row := HFlowContainer.new()
	content.add_child(row)
	for pair in _intent_options():
		var button := Button.new()
		button.text = pair[1]
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(0, 24)
		button.add_theme_font_size_override("font_size", SMALL_FONT_SIZE)
		UiTheme.style_pill_button(button, incident.command_intent == pair[0])
		button.button_pressed = incident.command_intent == pair[0]
		button.pressed.connect(_on_intent_pressed.bind(pair[0]))
		row.add_child(button)

func _intent_options() -> Array:
	return [
		[GameEnums.CommandIntent.RESPOND, "Respond"],
		[GameEnums.CommandIntent.CONTAIN, "Contain"],
		[GameEnums.CommandIntent.LOCATE, "Locate"],
		[GameEnums.CommandIntent.REASSURE, "Reassure"],
		[GameEnums.CommandIntent.GATHER_INTELLIGENCE, "Gather Intel"],
		[GameEnums.CommandIntent.RESOLVE, "Resolve"],
	]

func _on_intent_pressed(intent) -> void:
	Simulation.commands().set_command_intent(_current_incident_id, intent)
	refresh()

func _add_assigned_units_block(incident: Incident) -> void:
	add_divider()
	add_mini_header("ASSIGNED")
	_add_supervisor_line(incident)
	if incident.assigned_unit_ids.is_empty():
		add_dim_line("(no units assigned)")
		return
	for unit_id in incident.assigned_unit_ids:
		var unit: PoliceUnit = Simulation.core.resource_manager.get_unit(unit_id)
		if unit == null:
			continue
		add_action_row(
			"%s%s -- %s" % [unit.callsign, _sergeant_tag(unit), _unit_status_text(unit)],
			"Recall",
			_on_stand_down.bind(unit_id),
		)

## Spec section 9: surfaces whether this incident could use a sergeant's
## attention (difficult/developing/an inexperienced crew) and whether one
## is currently assigned -- the outcome engine actually weights this, so
## the panel makes the same condition visible before the player decides.
func _add_supervisor_line(incident: Incident) -> void:
	var officers: Array[Officer] = _assigned_officers(incident)
	if not IncidentOutcomeEngine.needs_supervisor(incident, officers):
		return
	var label := Label.new()
	if IncidentOutcomeEngine.has_supervisor(officers):
		label.text = "A sergeant is supervising this incident."
		label.modulate = Color(0.5, 0.85, 0.4)
	else:
		label.text = "Supervisor recommended -- consider sending a sergeant."
		label.modulate = Color(0.9, 0.65, 0.3)
	label.add_theme_font_size_override("font_size", CONTENT_FONT_SIZE)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	content.add_child(label)

func _sergeant_tag(unit: PoliceUnit) -> String:
	for officer_id in unit.officer_ids:
		var officer: Officer = Simulation.core.officer_manager.get_officer(officer_id)
		if officer and officer.rank == GameEnums.OfficerRank.SERGEANT:
			return " (Sgt)"
	return ""

func _assigned_officers(incident: Incident) -> Array[Officer]:
	var officers: Array[Officer] = []
	for unit_id in incident.assigned_unit_ids:
		var unit: PoliceUnit = Simulation.core.resource_manager.get_unit(unit_id)
		if unit == null:
			continue
		for officer_id in unit.officer_ids:
			var officer: Officer = Simulation.core.officer_manager.get_officer(officer_id)
			if officer:
				officers.append(officer)
	return officers

func _on_stand_down(unit_id: String) -> void:
	Simulation.commands().stand_down_unit(unit_id)
	refresh()

## The nearest-unit tag (below) is real guidance, not decoration -- spec
## section 25/56 both want the player steered toward a sensible choice
## rather than reading five equivalent-looking rows and guessing.
func _add_available_units_block(incident: Incident) -> void:
	add_divider()
	add_mini_header("SEND A UNIT")
	var location: LocationDefinition = Simulation.core.world.get_location(incident.location_id)
	var nearest_unit_id: String = _nearest_available_unit_id(incident, location)
	var any_shown := false
	for unit: PoliceUnit in Simulation.core.resource_manager.units.values():
		if unit.status == GameEnums.UnitStatus.ON_BREAK or unit.status == GameEnums.UnitStatus.UNAVAILABLE:
			continue
		if incident.assigned_unit_ids.has(unit.id):
			continue # already shown above with a Recall button
		any_shown = true
		var is_nearest: bool = unit.id == nearest_unit_id
		add_action_row(
			"%s%s -- %s%s" % [unit.callsign, _sergeant_tag(unit), _unit_status_text(unit), "  (nearest)" if is_nearest else ""],
			"Send" if unit.current_incident_id == "" else "Reassign",
			_on_send_unit.bind(unit.id),
			is_nearest,
		)
	if not any_shown:
		add_dim_line("(no other units free)")

## Straight-line distance from each candidate unit's current position to
## the incident's location -- a cheap, close-enough proxy for travel time
## (the real path uses RoadGraph, which would be truer but isn't worth a
## pathfind per unit just to sort a hint) among units this block already
## considers sendable.
func _nearest_available_unit_id(incident: Incident, location: LocationDefinition) -> String:
	if location == null:
		return ""
	var nearest_id: String = ""
	var nearest_dist: float = INF
	for unit: PoliceUnit in Simulation.core.resource_manager.units.values():
		if unit.status == GameEnums.UnitStatus.ON_BREAK or unit.status == GameEnums.UnitStatus.UNAVAILABLE:
			continue
		if incident.assigned_unit_ids.has(unit.id):
			continue
		var dist: float = unit.current_position.distance_to(location.position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_id = unit.id
	return nearest_id

func _on_send_unit(unit_id: String) -> void:
	Simulation.commands().assign_unit_to_incident(unit_id, _current_incident_id)
	refresh()

func _unit_status_text(unit: PoliceUnit) -> String:
	match unit.status:
		GameEnums.UnitStatus.AVAILABLE:
			return "available"
		GameEnums.UnitStatus.PATROL:
			return "on patrol"
		GameEnums.UnitStatus.TRAVELLING:
			if unit.current_incident_id != "":
				return "travelling to %s" % _incident_summary(unit.current_incident_id)
			return "travelling to patrol point"
		GameEnums.UnitStatus.ON_SCENE:
			return "on scene at %s" % _incident_summary(unit.current_incident_id)
		GameEnums.UnitStatus.ON_BREAK:
			return "on break"
		_:
			return "unavailable"

func _incident_summary(incident_id: String) -> String:
	var other: Incident = Simulation.core.incident_manager.get_incident(incident_id)
	if other == null:
		return "an incident"
	var type_def: IncidentTypeDefinition = _type_def_for(other.type_id)
	return type_def.display_name if type_def else other.type_id

func _type_def_for(type_id: String) -> IncidentTypeDefinition:
	return Simulation.core.incident_manager.get_type_definition(type_id)

## REQUEST SPECIALIST (spec section 11/25): traffic/dog/firearms, external
## resources that aren't guaranteed -- shows current availability/ETA next
## to the button so the Inspector knows what they're asking for before
## they ask, same "consequences visible before the click" pattern as the
## rest of this panel.
func _add_specialist_block(incident: Incident) -> void:
	add_divider()
	add_mini_header("REQUEST SPECIALIST")
	var type_def: IncidentTypeDefinition = _type_def_for(incident.type_id)
	var recommended: int = type_def.recommended_specialist if type_def else -1
	var manager: SpecialistManager = Simulation.core.specialist_manager
	for pair in [
		[GameEnums.SpecialistType.TRAFFIC, "Traffic"],
		[GameEnums.SpecialistType.DOG, "Dog"],
		[GameEnums.SpecialistType.FIREARMS, "Firearms"],
	]:
		var unit: SpecialistUnit = manager.unit_for_type(pair[0])
		if unit == null:
			continue
		var is_recommended: bool = pair[0] == recommended
		if unit.status == GameEnums.SpecialistStatus.COMMITTED and unit.committed_incident_id == incident.id:
			add_dim_line("%s -- already requested here" % unit.display_name)
			continue
		var row_text: String = "%s -- %s%s" % [unit.display_name, manager.status_text(unit), "  (fits this incident)" if is_recommended else ""]
		var can_request: bool = unit.status != GameEnums.SpecialistStatus.UNAVAILABLE and unit.status != GameEnums.SpecialistStatus.COMMITTED
		if can_request:
			add_action_row(row_text, "Request", _on_request_specialist.bind(pair[0]), is_recommended)
		else:
			add_dim_line(row_text)

func _on_request_specialist(specialist_type: GameEnums.SpecialistType) -> void:
	Simulation.commands().request_specialist(_current_incident_id, specialist_type)
	refresh()

## Neighbourhood intelligence-gathering tasking (spec section 10) tied to
## this specific incident, distinct from the general community-engagement
## tasking in NeighbourhoodPanelView.
func _add_neighbourhood_block(incident: Incident) -> void:
	add_divider()
	add_mini_header("NEIGHBOURHOOD TEAM")
	var manager: NeighbourhoodManager = Simulation.core.neighbourhood_manager
	var any_available := false
	for officer: NeighbourhoodOfficer in manager.officers.values():
		if officer.status == GameEnums.NeighbourhoodStatus.EXISTING_TASK and officer.task_incident_id == incident.id:
			add_dim_line("%s gathering intelligence here (%d min)" % [officer.officer_name, int(ceil(officer.task_minutes_remaining))])
			continue
		if officer.status != GameEnums.NeighbourhoodStatus.AVAILABLE:
			continue
		any_available = true
		add_action_row(officer.officer_name, "Gather Intel", _on_task_neighbourhood.bind(officer.id))
	if not any_available:
		add_dim_line("(no neighbourhood officers free)")

func _on_task_neighbourhood(officer_id: String) -> void:
	Simulation.commands().task_neighbourhood_to_incident(officer_id, _current_incident_id)
	refresh()
