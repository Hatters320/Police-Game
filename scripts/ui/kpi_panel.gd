class_name KpiPanelView
extends SidePanelView
## Live shift performance dashboard -- feature request: "a dashboard
## showing key performance indicators... allow players to tap any metric
## to open a detailed statistics page". A HUD-button-opened modal,
## following NeighbourhoodPanelView's exact shape (same reasoning: like
## the team roster, there's no single map marker that represents "the
## whole shift's performance" to open this from).

var _map_view: MapView

## -1 = overview. 1-5 = a response-time priority band's detail. 0 =
## confidence detail. 6 = wellbeing detail.
var _detail: int = -1

const COLOR_GOOD := Color(0.3, 0.75, 0.3)
const COLOR_WARN := Color(0.95, 0.55, 0.1)
const COLOR_BAD := Color(0.85, 0.15, 0.15)

func _is_modal() -> bool:
	return true

func _panel_layer() -> int:
	return 4

func wire(map_view: MapView) -> void:
	_map_view = map_view

func open() -> void:
	if _map_view:
		_map_view.close_other_panels(self)
	_detail = -1
	_show_panel()
	refresh()

func refresh() -> void:
	if not is_open():
		return
	clear_content()
	add_title("Shift Performance")
	add_close_button()
	if _detail == -1:
		_add_overview()
	else:
		_add_back_row()
		_add_detail(_detail)

func _add_overview() -> void:
	var tracker: KpiTracker = Simulation.core.kpi_tracker
	add_mini_header("RESPONSE TIME")
	for priority in [1, 2, 3]:
		_add_response_card(tracker, priority)

	add_divider()
	add_mini_header("TOWN")
	_add_confidence_card()

	add_divider()
	add_mini_header("WORKFORCE")
	_add_wellbeing_card()

func _add_response_card(tracker: KpiTracker, priority: int) -> void:
	var pct: float = tracker.attainment_pct(priority)
	var attended: int = tracker.attended_count(priority)
	var target: float = tracker.target_minutes(priority)
	var primary: String
	var accent: Color
	if attended == 0:
		primary = "P%d RESPONSE -- no calls yet" % priority
		accent = UiTheme.TEXT_DIM
	else:
		primary = "P%d RESPONSE -- %d%% within target" % [priority, roundi(pct)]
		accent = _band_color(pct)
	var secondary: String = "%d attended this shift -- target %s" % [attended, _target_text(target)]
	add_card(accent, primary, secondary, _on_response_card_pressed.bind(priority))

func _add_confidence_card() -> void:
	var districts: Array = Simulation.core.district_manager.districts.values()
	var sum := 0.0
	for district: DistrictState in districts:
		sum += district.community_confidence
	var avg: float = sum / districts.size() if districts.size() > 0 else 60.0
	add_card(
		_band_color(avg),
		"Public confidence -- %d%%" % roundi(avg),
		"Town-wide average across every district",
		_on_confidence_card_pressed,
	)

func _add_wellbeing_card() -> void:
	var stats: Dictionary = WorkforceStats.average_fatigue_morale(Simulation.core.officer_manager.officers.values())
	var avg_fatigue: float = stats["avg_fatigue"]
	var avg_morale: float = stats["avg_morale"]
	var band: String
	var accent: Color
	if avg_fatigue >= 70.0:
		band = "CRITICAL"
		accent = COLOR_BAD
	elif avg_fatigue >= 50.0:
		band = "ELEVATED"
		accent = COLOR_WARN
	else:
		band = "OK"
		accent = COLOR_GOOD
	add_card(
		accent,
		"Officer wellbeing -- %s" % band,
		"Avg fatigue %d, avg morale %d" % [roundi(avg_fatigue), roundi(avg_morale)],
		_on_wellbeing_card_pressed,
	)

func _band_color(pct: float) -> Color:
	if pct >= 90.0:
		return COLOR_GOOD
	if pct >= 70.0:
		return COLOR_WARN
	return COLOR_BAD

func _target_text(target_minutes: float) -> String:
	if target_minutes >= 60.0 and fmod(target_minutes, 60.0) == 0.0:
		return "%d hr" % roundi(target_minutes / 60.0)
	if target_minutes >= 60.0:
		return "%.1f hr" % (target_minutes / 60.0)
	return "%d min" % roundi(target_minutes)

func _on_response_card_pressed(priority: int) -> void:
	_detail = priority
	refresh()

func _on_confidence_card_pressed() -> void:
	_detail = 0
	refresh()

func _on_wellbeing_card_pressed() -> void:
	_detail = 6
	refresh()

func _add_back_row() -> void:
	var back_button := Button.new()
	back_button.text = "< Back"
	back_button.custom_minimum_size = Vector2(0, 26)
	back_button.add_theme_font_size_override("font_size", SMALL_FONT_SIZE)
	back_button.pressed.connect(_on_back_pressed)
	content.add_child(back_button)
	add_divider()

func _on_back_pressed() -> void:
	_detail = -1
	refresh()

func _add_detail(kind: int) -> void:
	if kind >= 1 and kind <= 5:
		_add_response_detail(kind)
	elif kind == 0:
		_add_confidence_detail()
	elif kind == 6:
		_add_wellbeing_detail()

func _add_response_detail(priority: int) -> void:
	var tracker: KpiTracker = Simulation.core.kpi_tracker
	add_mini_header("P%d RESPONSE TARGET" % priority)
	add_line("Every Priority %d call is measured from the moment it's reported to the moment a unit reaches the scene, against a %s target." % [priority, _target_text(tracker.target_minutes(priority))])
	add_divider()
	add_mini_header("RECENT CALLS")
	var recent: Array[Dictionary] = tracker.recent_for_priority(priority, 10)
	if recent.is_empty():
		add_dim_line("(none attended yet this shift)")
		return
	for entry in recent:
		var within: bool = entry["within_target"]
		var line: String = "%s -- %d min" % ["Within target" if within else "Missed target", roundi(entry["delay_minutes"])]
		if within:
			add_line(line)
		else:
			add_dim_line(line)

func _add_confidence_detail() -> void:
	add_mini_header("PUBLIC CONFIDENCE")
	add_line("How positively each district's residents currently view local policing, out of 100. Resolving incidents well -- especially with a reassurance or intelligence-gathering approach -- raises it; incidents left to escalate unattended pull it down.")
	add_divider()
	add_mini_header("BY DISTRICT")
	for district: DistrictState in Simulation.core.district_manager.districts.values():
		var district_def: DistrictDefinition = Simulation.core.world.get_district(district.district_id)
		var name: String = district_def.display_name if district_def else district.district_id
		add_line("%s -- %d%%" % [name, roundi(district.community_confidence)])

func _add_wellbeing_detail() -> void:
	add_mini_header("OFFICER WELLBEING")
	add_line("Average fatigue and morale across every officer on duty this shift. Fatigue climbs while an officer is engaged on an incident or on patrol, and recovers on a break; sustained high fatigue drags morale down with it.")
	add_divider()
	add_mini_header("ON DUTY")
	for officer: Officer in Simulation.core.officer_manager.officers.values():
		add_line("%s -- fatigue %d, morale %d" % [officer.officer_name, roundi(officer.fatigue), roundi(officer.morale)])
