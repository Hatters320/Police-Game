class_name OfficerInteractionPanelView
extends SidePanelView
## Proactive officer pop-up -- feature request: "officers ask the player
## for guidance... requesting breaks due to fatigue or hunger... reporting
## concerns about workload, morale... multiple response options that
## influence future outcomes." Modal + centred, matching IncidentPanelView
## (the existing "decision surface" pop-up), rather than docked -- this is
## the game interrupting the player, not something they tapped open.
##
## Driven by OfficerInteractionManager's queue rather than a single tap
## target: main.gd opens this whenever the queue has something pending and
## nothing else is already showing, and re-checks the queue every time
## this panel closes, so several officers crossing a threshold in the same
## tick still get shown one at a time rather than lost or stacked.

var _officer_id: String = ""
var _kind: String = ""
var _map_view: MapView

func wire(map_view: MapView) -> void:
	_map_view = map_view

func _is_modal() -> bool:
	return true

func _panel_layer() -> int:
	return 4

func _panel_anchor() -> int:
	return Control.PRESET_CENTER

func _panel_width() -> float:
	return 250.0

func _panel_height() -> float:
	return minf(220.0, maxf(150.0, get_viewport().get_visible_rect().size.y - PANEL_TOP_Y - 30.0))

func open(officer_id: String, kind: String) -> void:
	if _map_view:
		_map_view.close_other_panels(self)
	_officer_id = officer_id
	_kind = kind
	_show_panel()
	refresh()

func close() -> void:
	_officer_id = ""
	_kind = ""
	super.close()

func refresh() -> void:
	if _officer_id == "":
		return
	var officer: Officer = Simulation.core.officer_manager.get_officer(_officer_id)
	if officer == null:
		close()
		return

	clear_content()
	add_title(officer.officer_name)
	add_close_button()
	add_dim_line(_job_text(officer))
	add_divider()
	add_line(_prompt_text(officer))
	add_divider()
	_add_response_row()

func _job_text(officer: Officer) -> String:
	var unit: PoliceUnit = Simulation.core.resource_manager.get_unit(officer.current_unit_id)
	if unit == null:
		return "Off duty"
	match unit.status:
		GameEnums.UnitStatus.TRAVELLING:
			return "Currently travelling to a call"
		GameEnums.UnitStatus.ON_SCENE:
			return "Currently on scene at a call"
		GameEnums.UnitStatus.PATROL:
			return "Currently on patrol"
		GameEnums.UnitStatus.ON_BREAK:
			return "Currently on a break"
		_:
			return "Available at the station"

func _prompt_text(officer: Officer) -> String:
	if _kind == "morale_concern":
		return "\"Honestly, this shift's been a lot. Morale's down to %d.\"" % roundi(officer.morale)
	return "\"I'm running on empty out here. Fatigue's at %d. Can I get a break?\"" % roundi(officer.fatigue)

func _add_response_row() -> void:
	var row := HFlowContainer.new()
	content.add_child(row)
	for pair in _response_options():
		var button := Button.new()
		button.text = pair[1]
		button.custom_minimum_size = Vector2(0, 26)
		button.add_theme_font_size_override("font_size", SMALL_FONT_SIZE)
		UiTheme.style_pill_button(button, false)
		button.pressed.connect(_on_response_pressed.bind(pair[0]))
		row.add_child(button)

func _response_options() -> Array:
	if _kind == "morale_concern":
		return [
			["ease_workload", "Ease their workload -- send them for a break"],
			["acknowledge_push_on", "Acknowledge it, but they need to push on"],
			["recall_debrief", "Recall the car for a debrief"],
		]
	return [
		["grant_break", "Grant the break"],
		["ask_to_hold", "Ask them to hold 10 more minutes"],
		["recall_station", "Send the whole car back to the station"],
	]

func _on_response_pressed(response_id: String) -> void:
	Simulation.commands().respond_to_officer_interaction(_officer_id, response_id)
	close()
