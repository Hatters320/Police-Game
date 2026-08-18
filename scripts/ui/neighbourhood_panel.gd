class_name NeighbourhoodPanelView
extends SidePanelView
## Neighbourhood team roster panel (spec section 10), opened via a HUD
## button rather than a map click since there's no single marker that
## represents "the neighbourhood team" the way a PoliceUnit has one.
## Incident-specific intelligence tasking lives in IncidentPanelView
## instead -- this panel is for the general roster view and district-wide
## community engagement/proactive tasking.

func open() -> void:
	_show_panel()
	refresh()

func refresh() -> void:
	if not is_open():
		return
	clear_content()
	add_title("Neighbourhood Team")
	add_close_button()
	add_dim_line("On duty 07:00-21:00 (spec section 10) -- off duty outside those hours regardless of tasking.")

	var manager: NeighbourhoodManager = Simulation.core.neighbourhood_manager
	for officer: NeighbourhoodOfficer in manager.officers.values():
		_add_officer_block(officer, manager)

func _add_officer_block(officer: NeighbourhoodOfficer, manager: NeighbourhoodManager) -> void:
	add_divider()
	var name_label := Label.new()
	name_label.text = officer.officer_name
	name_label.add_theme_font_size_override("font_size", 14)
	content.add_child(name_label)
	add_dim_line(manager.status_text(officer))

	match officer.status:
		GameEnums.NeighbourhoodStatus.AVAILABLE:
			_add_engagement_controls(officer)
		GameEnums.NeighbourhoodStatus.UNAVAILABLE:
			pass
		_:
			var recall_button := Button.new()
			recall_button.text = "Recall"
			recall_button.pressed.connect(_on_recall.bind(officer.id))
			content.add_child(recall_button)

func _add_engagement_controls(officer: NeighbourhoodOfficer) -> void:
	var row := HBoxContainer.new()
	content.add_child(row)

	var picker := OptionButton.new()
	for district: DistrictDefinition in Simulation.core.world.districts:
		picker.add_item(district.display_name)
		picker.set_item_metadata(picker.item_count - 1, district.id)
	picker.custom_minimum_size = Vector2(180, 0)
	row.add_child(picker)

	var task_button := Button.new()
	task_button.text = "Task"
	task_button.pressed.connect(_on_task_engagement.bind(officer.id, picker))
	row.add_child(task_button)

func _on_task_engagement(officer_id: String, picker: OptionButton) -> void:
	var selected: int = picker.selected
	if selected < 0:
		return
	var district_id: String = picker.get_item_metadata(selected)
	Simulation.commands().task_neighbourhood_engagement(officer_id, district_id)
	refresh()

func _on_recall(officer_id: String) -> void:
	Simulation.commands().recall_neighbourhood_officer(officer_id)
	refresh()
