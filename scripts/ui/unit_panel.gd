class_name UnitPanelView
extends SidePanelView
## Unit welfare panel (spec section 14/27/44), opened by clicking a unit
## marker on the map. Shows each crew member's experience, driver
## qualification, fatigue and morale, and lets the player send the whole
## unit for a break or recall it from patrol -- the trade-off spec
## section 14 is built around: better welfare, but one fewer unit on the
## street while it's resting.

var _current_unit_id: String = ""

## Draws above the always-docked Resources/Incidents panels, which stay
## visible underneath rather than closing whenever this opens.
## Takes over the screen while open -- see SidePanelView._is_modal.
func _is_modal() -> bool:
	return true

func _panel_layer() -> int:
	return 4

func open(unit_id: String) -> void:
	_current_unit_id = unit_id
	_show_panel()
	refresh()

func close() -> void:
	_current_unit_id = ""
	super.close()

func is_open_for(unit_id: String) -> bool:
	return is_open() and _current_unit_id == unit_id

func refresh() -> void:
	if _current_unit_id == "":
		return
	var unit: PoliceUnit = Simulation.core.resource_manager.get_unit(_current_unit_id)
	if unit == null:
		close()
		return

	clear_content()
	add_title(unit.callsign)
	add_close_button()
	add_dim_line(_status_text(unit))
	add_dim_line("Location: %s" % _location_text(unit))
	var job_text: String = _job_text(unit)
	if job_text != "":
		add_dim_line(job_text)
	add_divider()

	for officer_id in unit.officer_ids:
		var officer: Officer = Simulation.core.officer_manager.get_officer(officer_id)
		if officer:
			_add_officer_block(officer)

	add_divider()
	_add_actions(unit)

func _add_officer_block(officer: Officer) -> void:
	var name_label := Label.new()
	name_label.text = "%s -- %s" % [officer.officer_name, _rank_text(officer.rank)]
	name_label.add_theme_font_size_override("font_size", 13)
	content.add_child(name_label)
	add_dim_line("Experience: %s   Driver: %s" % [_experience_text(officer.experience), "Yes" if officer.driver_qualified else "No"])

	var fatigue_label := Label.new()
	fatigue_label.text = "Fatigue: %d%s" % [int(officer.fatigue), "  (ELEVATED)" if officer.is_elevated_fatigue() else ""]
	fatigue_label.add_theme_font_size_override("font_size", CONTENT_FONT_SIZE)
	fatigue_label.modulate = Color(0.9, 0.5, 0.25) if officer.is_elevated_fatigue() else Color(0.7, 0.7, 0.7)
	content.add_child(fatigue_label)
	add_dim_line("Morale: %d" % int(officer.morale))
	add_dim_line(_skills_text(officer))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	content.add_child(spacer)

func _add_actions(unit: PoliceUnit) -> void:
	match unit.status:
		GameEnums.UnitStatus.ON_BREAK:
			var return_button := Button.new()
			return_button.text = "Return From Break"
			return_button.custom_minimum_size = Vector2(0, 32)
			return_button.add_theme_font_size_override("font_size", CONTENT_FONT_SIZE)
			return_button.pressed.connect(_on_return_from_break)
			content.add_child(return_button)
		GameEnums.UnitStatus.AVAILABLE, GameEnums.UnitStatus.PATROL:
			var break_button := Button.new()
			break_button.text = "Send For Break"
			break_button.custom_minimum_size = Vector2(0, 32)
			break_button.add_theme_font_size_override("font_size", CONTENT_FONT_SIZE)
			break_button.pressed.connect(_on_send_for_break)
			content.add_child(break_button)
			if unit.status == GameEnums.UnitStatus.PATROL:
				var recall_button := Button.new()
				recall_button.text = "Recall to Station"
				recall_button.custom_minimum_size = Vector2(0, 32)
				recall_button.add_theme_font_size_override("font_size", CONTENT_FONT_SIZE)
				recall_button.pressed.connect(_on_recall)
				content.add_child(recall_button)
		_:
			add_dim_line("(committed to an incident -- use the incident panel to recall)")

func _on_send_for_break() -> void:
	Simulation.commands().send_for_break(_current_unit_id)
	refresh()

func _on_return_from_break() -> void:
	Simulation.commands().return_from_break(_current_unit_id)
	refresh()

func _on_recall() -> void:
	Simulation.commands().recall_to_station(_current_unit_id)
	refresh()

func _status_text(unit: PoliceUnit) -> String:
	match unit.status:
		GameEnums.UnitStatus.AVAILABLE: return "Available at station"
		GameEnums.UnitStatus.PATROL: return "On patrol"
		GameEnums.UnitStatus.TRAVELLING: return "Travelling"
		GameEnums.UnitStatus.ON_SCENE: return "On scene"
		GameEnums.UnitStatus.ON_BREAK: return "On break"
		_: return "Unavailable"

## Which district the unit currently sits in, read from its real live
## position -- same point-in-polygon approach as ResourcesPanelView's
## roster list, duplicated here rather than shared since each panel's
## exact wording differs slightly. Real playtesting asked the unit panel
## to show "where they are, what job they are at, their skills, their
## fatigue metrics" -- this is the "where".
func _location_text(unit: PoliceUnit) -> String:
	var world: WorldMapData = Simulation.core.world
	for district: DistrictDefinition in world.districts:
		if Geometry2D.is_point_in_polygon(unit.current_position, district.boundary):
			return district.display_name
	var closest_name: String = "en route"
	var closest_dist: float = INF
	for district: DistrictDefinition in world.districts:
		for point in district.boundary:
			var dist: float = point.distance_to(unit.current_position)
			if dist < closest_dist:
				closest_dist = dist
				closest_name = district.display_name
	return closest_name

## The "what job they are at" half of the same request -- names the
## specific incident or patrol point rather than just repeating the
## generic status line above.
func _job_text(unit: PoliceUnit) -> String:
	match unit.status:
		GameEnums.UnitStatus.TRAVELLING, GameEnums.UnitStatus.ON_SCENE:
			if unit.current_incident_id != "":
				var incident: Incident = Simulation.core.incident_manager.get_incident(unit.current_incident_id)
				if incident:
					var type_def: IncidentTypeDefinition = Simulation.core.incident_manager.get_type_definition(incident.type_id)
					var location: LocationDefinition = Simulation.core.world.get_location(incident.location_id)
					var type_name: String = type_def.display_name if type_def else incident.type_id
					var location_name: String = location.display_name if location else ""
					var verb: String = "Travelling to" if unit.status == GameEnums.UnitStatus.TRAVELLING else "Dealing with"
					return "%s: %s%s" % [verb, type_name, (" at " + location_name) if location_name != "" else ""]
			return "Travelling"
		GameEnums.UnitStatus.PATROL:
			if unit.patrol_location_id != "":
				var location: LocationDefinition = Simulation.core.world.get_location(unit.patrol_location_id)
				if location:
					return "Patrolling near %s" % location.display_name
			return ""
		_:
			return ""

func _skills_text(officer: Officer) -> String:
	return "Skills -- Comms: %s  Response: %s  Investigation: %s  Community: %s  Driving: %s" % [
		_skill_text(officer.skill_level("communication")), _skill_text(officer.skill_level("response")),
		_skill_text(officer.skill_level("investigation")), _skill_text(officer.skill_level("community")),
		_skill_text(officer.skill_level("driving")),
	]

func _skill_text(level: GameEnums.SkillLevel) -> String:
	match level:
		GameEnums.SkillLevel.LOW: return "Low"
		GameEnums.SkillLevel.HIGH: return "High"
		_: return "Med"

func _rank_text(rank: GameEnums.OfficerRank) -> String:
	return "Sergeant" if rank == GameEnums.OfficerRank.SERGEANT else "Constable"

func _experience_text(level: GameEnums.OfficerExperience) -> String:
	match level:
		GameEnums.OfficerExperience.LOW: return "Low"
		GameEnums.OfficerExperience.HIGH: return "High"
		_: return "Medium"
