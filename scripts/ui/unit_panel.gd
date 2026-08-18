class_name UnitPanelView
extends SidePanelView
## Unit welfare panel (spec section 14/27/44), opened by clicking a unit
## marker on the map. Shows each crew member's experience, driver
## qualification, fatigue and morale, and lets the player send the whole
## unit for a break or recall it from patrol -- the trade-off spec
## section 14 is built around: better welfare, but one fewer unit on the
## street while it's resting.

var _current_unit_id: String = ""

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
	name_label.add_theme_font_size_override("font_size", 18)
	content.add_child(name_label)
	add_dim_line("Experience: %s   Driver: %s" % [_experience_text(officer.experience), "Yes" if officer.driver_qualified else "No"])

	var fatigue_label := Label.new()
	fatigue_label.text = "Fatigue: %d%s" % [int(officer.fatigue), "  (ELEVATED)" if officer.is_elevated_fatigue() else ""]
	fatigue_label.modulate = Color(0.9, 0.5, 0.25) if officer.is_elevated_fatigue() else Color(0.7, 0.7, 0.7)
	content.add_child(fatigue_label)
	add_dim_line("Morale: %d" % int(officer.morale))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	content.add_child(spacer)

func _add_actions(unit: PoliceUnit) -> void:
	match unit.status:
		GameEnums.UnitStatus.ON_BREAK:
			var return_button := Button.new()
			return_button.text = "Return From Break"
			return_button.custom_minimum_size = Vector2(0, 52)
			return_button.pressed.connect(_on_return_from_break)
			content.add_child(return_button)
		GameEnums.UnitStatus.AVAILABLE, GameEnums.UnitStatus.PATROL:
			var break_button := Button.new()
			break_button.text = "Send For Break"
			break_button.custom_minimum_size = Vector2(0, 52)
			break_button.pressed.connect(_on_send_for_break)
			content.add_child(break_button)
			if unit.status == GameEnums.UnitStatus.PATROL:
				var recall_button := Button.new()
				recall_button.text = "Recall to Station"
				recall_button.custom_minimum_size = Vector2(0, 52)
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

func _rank_text(rank: GameEnums.OfficerRank) -> String:
	return "Sergeant" if rank == GameEnums.OfficerRank.SERGEANT else "Constable"

func _experience_text(level: GameEnums.OfficerExperience) -> String:
	match level:
		GameEnums.OfficerExperience.LOW: return "Low"
		GameEnums.OfficerExperience.HIGH: return "High"
		_: return "Medium"
