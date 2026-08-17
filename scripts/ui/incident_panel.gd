class_name IncidentPanelView
extends CanvasLayer
## Incident information + action panel (spec section 25-27), opened by
## clicking an incident marker on the map. Shows known/unknown facts (with
## a Request Information action), command intent, currently assigned
## units (with Recall), and every other usable unit (with Send / Reassign
## here) -- reassigning a busy unit shows what it's currently doing right
## next to the button that would pull it off that, which stands in for a
## separate preview/confirm step (see Commands.assign_unit_to_incident's
## header comment).

signal closed

var _content: VBoxContainer
var _current_incident_id: String = ""

func _ready() -> void:
	layer = 3
	visible = false

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-380, 80)
	add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(360, 520)
	panel.add_child(scroll)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_content)

func open(incident_id: String) -> void:
	_current_incident_id = incident_id
	visible = true
	refresh()

func close() -> void:
	_current_incident_id = ""
	visible = false
	closed.emit()

func is_open_for(incident_id: String) -> bool:
	return visible and _current_incident_id == incident_id

func refresh() -> void:
	if _current_incident_id == "":
		return
	var incident: Incident = Simulation.core.incident_manager.get_incident(_current_incident_id)
	if incident == null:
		close()
		return

	for child in _content.get_children():
		child.queue_free()

	var type_def: IncidentTypeDefinition = _type_def_for(incident.type_id)
	var location: LocationDefinition = Simulation.core.world.get_location(incident.location_id)

	_add_header(type_def, incident, location)
	_add_close_button()
	_add_priority_block(incident)
	_add_facts_block(incident)
	_add_intent_block(incident)
	_add_assigned_units_block(incident)
	_add_available_units_block(incident)

func _add_header(type_def: IncidentTypeDefinition, incident: Incident, location: LocationDefinition) -> void:
	var title := Label.new()
	title.text = type_def.display_name if type_def else incident.type_id
	title.add_theme_font_size_override("font_size", 20)
	_content.add_child(title)

	_add_line(location.display_name if location else incident.location_id)
	_add_dim_line("Reported: %s" % TimeFormat.clock(incident.created_at_minute))

	var state_label := Label.new()
	state_label.text = _state_text(incident.state)
	if incident.escalation_level > 0:
		state_label.text += "  (escalated x%d)" % incident.escalation_level
		state_label.modulate = Color(0.9, 0.55, 0.25)
	else:
		state_label.modulate = Color(0.7, 0.7, 0.7)
	_content.add_child(state_label)

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

func _add_priority_block(incident: Incident) -> void:
	_add_divider()
	var priority_label := Label.new()
	priority_label.text = "Priority %d -- %s" % [incident.priority, _priority_text(incident.priority)]
	priority_label.modulate = MapView.PRIORITY_COLORS.get(incident.priority, Color.WHITE)
	_content.add_child(priority_label)
	_add_dim_line("Threat %d   Harm %d   Vulnerability %d" % [int(incident.threat), int(incident.harm), int(incident.vulnerability)])

func _priority_text(priority: int) -> String:
	match priority:
		1: return "CRITICAL"
		2: return "URGENT"
		3: return "IMPORTANT"
		4: return "ROUTINE"
		_: return "NON-URGENT"

func _add_facts_block(incident: Incident) -> void:
	_add_divider()
	_add_mini_header("KNOWN")
	if incident.known_facts.is_empty():
		_add_dim_line("(nothing confirmed yet)")
	else:
		for fact in incident.known_facts:
			_add_line("•  %s" % fact)

	_add_mini_header("UNKNOWN")
	if incident.unknown_facts.is_empty():
		_add_dim_line("(nothing outstanding)")
	else:
		_add_dim_line("%d piece(s) of information not yet known" % incident.unknown_facts.size())
		var request_button := Button.new()
		request_button.text = "Request Information"
		request_button.pressed.connect(_on_request_information)
		_content.add_child(request_button)

func _on_request_information() -> void:
	Simulation.commands().request_information(_current_incident_id)
	refresh()

func _add_intent_block(incident: Incident) -> void:
	_add_divider()
	_add_mini_header("COMMAND INTENT")
	var row := HFlowContainer.new()
	_content.add_child(row)
	for pair in _intent_options():
		var button := Button.new()
		button.text = pair[1]
		button.toggle_mode = true
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
	_add_divider()
	_add_mini_header("ASSIGNED")
	if incident.assigned_unit_ids.is_empty():
		_add_dim_line("(no units assigned)")
		return
	for unit_id in incident.assigned_unit_ids:
		var unit: PoliceUnit = Simulation.core.resource_manager.get_unit(unit_id)
		if unit == null:
			continue
		var row := HBoxContainer.new()
		_content.add_child(row)
		var label := Label.new()
		label.text = "%s -- %s" % [unit.callsign, _unit_status_text(unit)]
		label.custom_minimum_size = Vector2(220, 0)
		row.add_child(label)
		var recall_button := Button.new()
		recall_button.text = "Recall"
		recall_button.pressed.connect(_on_stand_down.bind(unit_id))
		row.add_child(recall_button)

func _on_stand_down(unit_id: String) -> void:
	Simulation.commands().stand_down_unit(unit_id)
	refresh()

func _add_available_units_block(incident: Incident) -> void:
	_add_divider()
	_add_mini_header("SEND A UNIT")
	var any_shown := false
	for unit: PoliceUnit in Simulation.core.resource_manager.units.values():
		if unit.status == GameEnums.UnitStatus.ON_BREAK or unit.status == GameEnums.UnitStatus.UNAVAILABLE:
			continue
		if incident.assigned_unit_ids.has(unit.id):
			continue # already shown above with a Recall button
		any_shown = true
		var row := HBoxContainer.new()
		_content.add_child(row)
		var label := Label.new()
		label.text = "%s -- %s" % [unit.callsign, _unit_status_text(unit)]
		label.custom_minimum_size = Vector2(220, 0)
		row.add_child(label)
		var send_button := Button.new()
		send_button.text = "Send" if unit.current_incident_id == "" else "Reassign here"
		send_button.pressed.connect(_on_send_unit.bind(unit.id))
		row.add_child(send_button)
	if not any_shown:
		_add_dim_line("(no other units free)")

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

func _add_divider() -> void:
	_content.add_child(HSeparator.new())

func _add_mini_header(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.modulate = Color(0.75, 0.8, 1.0)
	_content.add_child(label)

func _add_line(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_content.add_child(label)

func _add_dim_line(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = Color(0.6, 0.6, 0.6)
	_content.add_child(label)

func _add_close_button() -> void:
	var button := Button.new()
	button.text = "Close"
	button.pressed.connect(close)
	_content.add_child(button)
