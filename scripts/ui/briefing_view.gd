class_name BriefingView
extends CanvasLayer
## Pre-shift briefing (spec section 16): staffing picture, intelligence/
## community issues/planned events/information gaps, priority selection
## (max 3), per-unit patrol tasking, and a reserve target, ending in a
## confirm button. Built entirely via code -- see MapView's header comment
## for why. Units must already exist (SimulationCore.prepare_shift already
## called) before setup() runs, since patrol tasking needs them.

signal confirmed

const MAX_PRIORITIES := 3

var _world: WorldMapData
var _shift_number: int
var _priority_buttons: Dictionary = {} # option text -> Button
var _selected_priorities: Array[String] = []
var _patrol_pickers: Dictionary = {} # unit_id -> OptionButton
var _reserve_spinbox: SpinBox

func setup(world: WorldMapData, shift_number: int) -> void:
	_world = world
	_shift_number = shift_number
	layer = 5

	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.05, 0.07, 0.92)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 60
	scroll.offset_top = 30
	scroll.offset_right = -60
	scroll.offset_bottom = -30
	add_child(scroll)

	var content := VBoxContainer.new()
	# Below the widest actual row (a patrol picker: label 320 + 12 sep +
	# picker 300 = 632), not an arbitrary desktop-era width -- the old 900
	# forced this wider than the scroll area on a real phone (logical
	# viewport ~660-780 wide once project.godot's stretch/canvas_items
	# scaling applies), so users needed a second, horizontal scroll on top
	# of the vertical one just to reach the patrol pickers.
	content.custom_minimum_size = Vector2(600, 0)
	content.add_theme_constant_override("separation", 18)
	scroll.add_child(content)

	_add_title(content, "SHIFT %d BRIEFING" % _shift_number)
	_add_staffing_section(content)
	_add_text_section(content, "INTELLIGENCE", _gather_intelligence())
	_add_text_section(content, "COMMUNITY ISSUES", BriefingContentFactory.community_issues())
	_add_events_section(content)
	_add_text_section(content, "INFORMATION GAPS", BriefingContentFactory.information_gaps())
	_add_priorities_section(content)
	_add_patrol_section(content)
	_add_reserve_section(content)

	var confirm_button := Button.new()
	confirm_button.text = "CONFIRM SHIFT PLAN"
	confirm_button.custom_minimum_size = Vector2(300, 58)
	confirm_button.pressed.connect(_on_confirm_pressed)
	content.add_child(confirm_button)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	content.add_child(spacer)

func _add_title(parent: Node, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 34)
	parent.add_child(label)

func _add_section_header(parent: Node, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	label.modulate = Color(0.75, 0.8, 1.0)
	parent.add_child(label)

func _add_staffing_section(parent: Node) -> void:
	_add_section_header(parent, "STAFFING")
	var roster_size: int = Simulation.core.officer_manager.officers.size()
	var sergeant_count := 0
	for officer: Officer in Simulation.core.officer_manager.officers.values():
		if officer.rank == GameEnums.OfficerRank.SERGEANT:
			sergeant_count += 1
	var unit_count: int = Simulation.core.resource_manager.units.size()

	var lines := [
		"Establishment: %d" % OfficerFactory.ESTABLISHMENT,
		"Annual leave: %d   Training: %d   Sickness: %d" % [OfficerFactory.ANNUAL_LEAVE, OfficerFactory.TRAINING, OfficerFactory.SICKNESS],
		"Available this shift: %d (minimum staffing: %d)" % [roster_size, OfficerFactory.MINIMUM_STAFFING],
		"Supervisors on duty: %d" % sergeant_count,
		"Deployable units: %d" % unit_count,
	]
	for line in lines:
		var label := Label.new()
		label.text = line
		parent.add_child(label)

func _gather_intelligence() -> Array[String]:
	var items: Array[String] = BriefingContentFactory.starting_intelligence().duplicate()
	for item: Dictionary in Simulation.core.intelligence_manager.items:
		items.append(String(item["text"]))
	return items

func _add_text_section(parent: Node, header: String, lines: Array[String]) -> void:
	_add_section_header(parent, header)
	if lines.is_empty():
		var empty_label := Label.new()
		empty_label.text = "  (none)"
		empty_label.modulate = Color(0.6, 0.6, 0.6)
		parent.add_child(empty_label)
		return
	for line in lines:
		var label := Label.new()
		label.text = "  •  %s" % line
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		parent.add_child(label)

func _add_events_section(parent: Node) -> void:
	_add_section_header(parent, "PLANNED EVENTS")
	var shift: ShiftState = Simulation.core.shift_manager.shift_state
	var found := false
	for event: EventDefinition in Simulation.core.event_manager.all_events():
		if _event_overlaps_shift(event, shift.shift_start_minute, shift.shift_end_minute):
			found = true
			var label := Label.new()
			label.text = "  •  %s -- kick-off %s. Expect increased Town Centre traffic, crowding, and demand through dispersal." % [event.display_name, TimeFormat.clock(event.start_minute)]
			label.autowrap_mode = TextServer.AUTOWRAP_WORD
			parent.add_child(label)
	if not found:
		var empty_label := Label.new()
		empty_label.text = "  (none scheduled this shift)"
		empty_label.modulate = Color(0.6, 0.6, 0.6)
		parent.add_child(empty_label)

## Events are scheduled by minute-of-day; a 17:00-05:00 shift crosses
## midnight, so this samples across the shift's absolute-minute range
## rather than doing a direct range comparison against the event's
## same-day window.
func _event_overlaps_shift(event: EventDefinition, shift_start: int, shift_end: int) -> bool:
	var minute: int = shift_start
	while minute < shift_end:
		if event.is_active_at(minute % (24 * 60)):
			return true
		minute += 10
	return false

func _add_priorities_section(parent: Node) -> void:
	_add_section_header(parent, "PRIORITIES (pick up to %d)" % MAX_PRIORITIES)
	var row := HFlowContainer.new()
	parent.add_child(row)
	for option in BriefingContentFactory.priority_options():
		var button := Button.new()
		button.text = option
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(0, 52)
		button.toggled.connect(_on_priority_toggled.bind(option))
		row.add_child(button)
		_priority_buttons[option] = button

func _on_priority_toggled(pressed: bool, option: String) -> void:
	if pressed:
		if _selected_priorities.size() >= MAX_PRIORITIES:
			_priority_buttons[option].button_pressed = false # revert -- already at the cap
			return
		_selected_priorities.append(option)
	else:
		_selected_priorities.erase(option)

func _add_patrol_section(parent: Node) -> void:
	_add_section_header(parent, "PATROL TASKING")
	var info := Label.new()
	info.text = "Directed patrol raises visibility and suppresses crime risk at that location while the unit stays there -- but it can't respond to an incident elsewhere until reassigned."
	info.autowrap_mode = TextServer.AUTOWRAP_WORD
	info.modulate = Color(0.7, 0.7, 0.7)
	parent.add_child(info)

	for unit: PoliceUnit in Simulation.core.resource_manager.units.values():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		parent.add_child(row)

		var crew_names: Array[String] = []
		for officer_id in unit.officer_ids:
			var officer: Officer = Simulation.core.officer_manager.get_officer(officer_id)
			if officer:
				crew_names.append(officer.officer_name)
		var label := Label.new()
		label.text = "%s (%s)" % [unit.callsign, _join_names(crew_names)]
		label.custom_minimum_size = Vector2(320, 0)
		row.add_child(label)

		var picker := OptionButton.new()
		picker.add_item("Reserve", 0)
		var index := 1
		for location: LocationDefinition in _world.locations:
			picker.add_item(location.display_name, index)
			picker.set_item_metadata(index, location.id)
			index += 1
		picker.custom_minimum_size = Vector2(300, 52)
		row.add_child(picker)
		_patrol_pickers[unit.id] = picker

func _join_names(names: Array[String]) -> String:
	var text: String = ""
	for i in range(names.size()):
		if i > 0:
			text += ", "
		text += names[i]
	return text

func _add_reserve_section(parent: Node) -> void:
	_add_section_header(parent, "RESPONSE RESERVE")
	var info := Label.new()
	info.text = "How many deployable units to keep back for immediate response, rather than committing to patrol tasks."
	info.autowrap_mode = TextServer.AUTOWRAP_WORD
	info.modulate = Color(0.7, 0.7, 0.7)
	parent.add_child(info)

	_reserve_spinbox = SpinBox.new()
	_reserve_spinbox.min_value = 0
	_reserve_spinbox.max_value = Simulation.core.resource_manager.units.size()
	_reserve_spinbox.value = 2
	_reserve_spinbox.custom_minimum_size = Vector2(140, 48)
	parent.add_child(_reserve_spinbox)

func _on_confirm_pressed() -> void:
	for unit_id in _patrol_pickers.keys():
		var picker: OptionButton = _patrol_pickers[unit_id]
		var location_id = picker.get_item_metadata(picker.selected)
		if location_id != null and location_id != "":
			Simulation.commands().set_directed_patrol(unit_id, location_id)
	Simulation.core.confirm_briefing(_selected_priorities, int(_reserve_spinbox.value))
	confirmed.emit()
