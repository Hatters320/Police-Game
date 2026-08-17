class_name HudView
extends CanvasLayer
## Top HUD bar (spec section 38), pause/1x/2x/4x speed controls (spec
## section 40), and a simple scrolling event feed (spec section 39). Built
## entirely via code -- see MapView's header comment for why (no .tscn
## authoring beyond the bare main scene root). Stats refresh once per
## simulation tick, not once per rendered frame, per
## docs/ARCHITECTURE.md's "signals fire / UI refreshes on meaningful
## change" performance discipline.

const MIN_STAFFING := 10

var _time_label: Label
var _units_label: Label
var _incidents_label: Label
var _staffing_label: Label
var _fatigue_label: Label
var _feed_list: VBoxContainer

var _fatigue_warning_count: int = 0

func _ready() -> void:
	var top_bar := HBoxContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.position = Vector2(20, 12)
	top_bar.add_theme_constant_override("separation", 28)
	add_child(top_bar)

	_time_label = _add_stat_label(top_bar)
	_units_label = _add_stat_label(top_bar)
	_incidents_label = _add_stat_label(top_bar)
	_staffing_label = _add_stat_label(top_bar)
	_fatigue_label = _add_stat_label(top_bar)

	var controls := HBoxContainer.new()
	controls.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	controls.position = Vector2(-280, 12)
	controls.add_theme_constant_override("separation", 8)
	add_child(controls)
	_add_button(controls, "Pause", func(): Simulation.commands().pause())
	_add_button(controls, "1x", func(): Simulation.commands().set_speed(1.0))
	_add_button(controls, "2x", func(): Simulation.commands().set_speed(2.0))
	_add_button(controls, "4x", func(): Simulation.commands().set_speed(4.0))

	_feed_list = VBoxContainer.new()
	_feed_list.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_feed_list.position = Vector2(20, -260)
	_feed_list.custom_minimum_size = Vector2(460, 240)
	add_child(_feed_list)

	Simulation.core.incident_manager.incident_created.connect(_on_incident_created)
	Simulation.core.incident_manager.incident_escalated.connect(_on_incident_escalated)
	Simulation.core.incident_manager.incident_resolved.connect(_on_incident_resolved)
	Simulation.core.fatigue_manager.fatigue_warning.connect(_on_fatigue_warning)
	Simulation.core.tick_completed.connect(_refresh_stats)
	_refresh_stats()

func _add_stat_label(parent: Node) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 16)
	parent.add_child(label)
	return label

func _add_button(parent: Node, text: String, on_pressed: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(on_pressed)
	parent.add_child(button)

func _refresh_stats() -> void:
	var core: SimulationCore = Simulation.core
	var shift: ShiftState = core.shift_manager.shift_state
	_time_label.text = "%s  (shift %s-%s)" % [
		shift.time_of_day_string(), _minute_to_clock(shift.shift_start_minute), _minute_to_clock(shift.shift_end_minute),
	]
	_units_label.text = "%d AVAILABLE" % core.resource_manager.available_units().size()
	_incidents_label.text = "%d ACTIVE" % core.incident_manager.active_incidents.size()
	_staffing_label.text = "%d/%d MINIMUM" % [core.officer_manager.officers.size(), MIN_STAFFING]
	_fatigue_label.text = "%d FATIGUE WARNINGS" % _fatigue_warning_count

func _on_fatigue_warning(officer_id: String) -> void:
	_fatigue_warning_count += 1
	_append_feed("Fatigue warning: %s" % officer_id)

func _on_incident_created(incident_id: String) -> void:
	var incident: Incident = Simulation.core.incident_manager.get_incident(incident_id)
	if incident:
		_append_feed("New %s (P%d) at %s" % [incident.type_id, incident.priority, incident.location_id])

func _on_incident_escalated(incident_id: String) -> void:
	var incident: Incident = Simulation.core.incident_manager.get_incident(incident_id)
	if incident:
		_append_feed("ESCALATED: %s (now P%d)" % [incident.type_id, incident.priority])

func _on_incident_resolved(incident_id: String, outcome_id: String) -> void:
	var incident: Incident = Simulation.core.incident_manager.get_incident(incident_id)
	if incident:
		_append_feed("Resolved %s -> %s" % [incident.type_id, outcome_id])

func _append_feed(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	_feed_list.add_child(label)
	if _feed_list.get_child_count() > 12:
		_feed_list.get_child(0).queue_free()

func _minute_to_clock(total_minute: int) -> String:
	var minute_of_day: int = total_minute % (24 * 60)
	return "%02d:%02d" % [minute_of_day / 60, minute_of_day % 60]
