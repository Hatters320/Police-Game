class_name HudView
extends CanvasLayer
## Top HUD bar (spec section 38), pause/1x/2x/4x speed controls (spec
## section 40), and a simple scrolling event feed (spec section 39). Built
## entirely via code -- see MapView's header comment for why (no .tscn
## authoring beyond the bare main scene root). Stats refresh once per
## simulation tick, not once per rendered frame, per
## docs/ARCHITECTURE.md's "signals fire / UI refreshes on meaningful
## change" performance discipline.

var _time_label: Label
var _units_label: Label
var _incidents_label: Label
var _staffing_label: Label
var _fatigue_label: Label
var _feed_list: VBoxContainer
var _overlay_row: HBoxContainer
var _controls_row: HBoxContainer

var _fatigue_warning_count: int = 0

## Minimum touch target size (spec section 56: "buttons must be large
## enough for mobile use, avoid tiny controls"), sized to clear the ~44px
## real-screen-pixel guideline once the project's stretch/canvas_items
## scaling (project.godot) is applied on an actual phone, without going
## bigger than that and eating the screen -- the previous (72, 54) was
## tuned before that scaling existed and, once it did, rendered these
## rows (plus the ones below) at roughly double their intended on-screen
## size, confirmed by real mobile playtesting: the HUD was consuming most
## of the vertical screen space above the map.
const TOUCH_BUTTON_SIZE := Vector2(60, 42)
const STAT_FONT_SIZE := 17

func _ready() -> void:
	layer = 2 # above DayNightOverlay's tint (layer 1), below side panels (layer 3)

	var top_bar := HBoxContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.position = Vector2(20, 12)
	top_bar.add_theme_constant_override("separation", 16)
	add_child(top_bar)

	_time_label = _add_stat_label(top_bar)
	_units_label = _add_stat_label(top_bar)
	_incidents_label = _add_stat_label(top_bar)
	_staffing_label = _add_stat_label(top_bar)
	_fatigue_label = _add_stat_label(top_bar)

	# On its own row below the stats, not beside them -- side by side, the
	# stat row's text and this row's buttons collided on narrower real
	# phone screens (confirmed by real mobile playtesting at 844px wide).
	# Stacking rows needs vertical room, which phones have far more of than
	# horizontal, so this scales to any reasonably-sized viewport without
	# per-resolution tuning.
	_controls_row = HBoxContainer.new()
	_controls_row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_controls_row.position = Vector2(20, 38)
	_controls_row.add_theme_constant_override("separation", 8)
	add_child(_controls_row)
	_add_button(_controls_row, "Pause", func(): Simulation.commands().pause())
	_add_button(_controls_row, "1x", func(): Simulation.commands().set_speed(1.0))
	_add_button(_controls_row, "2x", func(): Simulation.commands().set_speed(2.0))
	_add_button(_controls_row, "4x", func(): Simulation.commands().set_speed(4.0))

	_feed_list = VBoxContainer.new()
	_feed_list.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_feed_list.position = Vector2(20, -90)
	_feed_list.custom_minimum_size = Vector2(460, 80)
	add_child(_feed_list)

	_overlay_row = HBoxContainer.new()
	_overlay_row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_overlay_row.position = Vector2(20, 84)
	_overlay_row.add_theme_constant_override("separation", 8)
	add_child(_overlay_row)

	Simulation.core.incident_manager.incident_created.connect(_on_incident_created)
	Simulation.core.incident_manager.incident_escalated.connect(_on_incident_escalated)
	Simulation.core.incident_manager.incident_resolved.connect(_on_incident_resolved)
	Simulation.core.fatigue_manager.fatigue_warning.connect(_on_fatigue_warning)
	Simulation.core.tick_completed.connect(refresh_stats)
	# Commands.gd's own header comment says "nothing silently no-ops", but
	# until this, nothing in the UI actually listened for a rejection --
	# every Send/Recall/Request tap that failed a validity check (most
	# commonly: an incident tapped the moment it's reported is still
	# CREATED/REPORTED/ASSESSED, not yet QUEUED, so assign_unit_to_incident
	# rejects it) did nothing visible at all. Confirmed by a real player
	# report: "no way to... decide which officer to deploy" on a freshly-
	# reported incident, which is exactly this window.
	Simulation.commands().command_rejected.connect(_on_command_rejected)
	refresh_stats()

func _add_stat_label(parent: Node) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", STAT_FONT_SIZE)
	parent.add_child(label)
	return label

func _add_button(parent: Node, text: String, on_pressed: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = TOUCH_BUTTON_SIZE
	button.pressed.connect(on_pressed)
	parent.add_child(button)

## Scroll-wheel zoom (main.gd) has no touch equivalent -- these give
## touch/mobile players a way to zoom at all (spec section 3/56).
func wire_zoom_controls(zoom_in: Callable, zoom_out: Callable) -> void:
	_add_button(_controls_row, "-", zoom_out)
	_add_button(_controls_row, "+", zoom_in)

## Opens NeighbourhoodPanelView (spec section 10) -- placed alongside the
## overlay toggles since it's the same "open a side panel" action, not a
## simulation-speed control like the buttons in _controls_row.
func wire_neighbourhood_panel(on_pressed: Callable) -> void:
	var button := Button.new()
	button.text = "Neighbourhood"
	button.add_theme_font_size_override("font_size", 15)
	button.custom_minimum_size = Vector2(0, 40)
	button.pressed.connect(on_pressed)
	_overlay_row.add_child(button)

## Called once by main.gd after MapView exists -- builds the overlay
## toggle row (spec section 41). Kept out of _ready() since it needs a
## MapView reference to wire the buttons to.
func wire_overlays(map_view: MapView) -> void:
	_add_overlay_button("None", map_view, MapView.OverlayType.NONE)
	_add_overlay_button("ASB", map_view, MapView.OverlayType.ASB)
	_add_overlay_button("Violence", map_view, MapView.OverlayType.VIOLENCE)
	_add_overlay_button("Burglary", map_view, MapView.OverlayType.BURGLARY)
	_add_overlay_button("Visibility", map_view, MapView.OverlayType.VISIBILITY)
	_add_overlay_button("Demand", map_view, MapView.OverlayType.DEMAND)

func _add_overlay_button(text: String, map_view: MapView, overlay: MapView.OverlayType) -> void:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 15)
	button.custom_minimum_size = Vector2(0, 40) # spec section 56 -- still a real tap target, just not as wide as the main controls
	button.pressed.connect(func(): map_view.set_overlay(overlay))
	_overlay_row.add_child(button)

func refresh_stats() -> void:
	var core: SimulationCore = Simulation.core
	var shift: ShiftState = core.shift_manager.shift_state
	# Kept deliberately short -- at the larger font size real phone
	# playtesting called for, a longer line risks running off narrower
	# screens since this row has nothing beside it to wrap into.
	_time_label.text = "%s  (ends %s)  -- %s" % [
		shift.time_of_day_string(), TimeFormat.clock(shift.shift_end_minute),
		core.weather_manager.weather_text().to_upper(),
	]
	_time_label.modulate = Color(0.6, 0.75, 0.95) if core.weather_manager.is_raining() else Color.WHITE
	var available_count: int = core.resource_manager.available_units().size()
	_units_label.text = "%d AVAILABLE" % available_count
	# Spec section 19: warn when reserve is running dangerously low, rather
	# than forcing a fixed minimum -- the right number depends on what's
	# happening, so this is a signal, not a hard rule.
	_units_label.modulate = Color(0.95, 0.45, 0.25) if available_count < shift.reserve_target else Color.WHITE
	_incidents_label.text = "%d ACTIVE" % core.incident_manager.active_incidents.size()
	_staffing_label.text = "%d/%d MINIMUM" % [core.officer_manager.officers.size(), OfficerFactory.MINIMUM_STAFFING]
	_fatigue_label.text = "%d FATIGUE" % _fatigue_warning_count

func _on_fatigue_warning(officer_id: String) -> void:
	_fatigue_warning_count += 1
	_append_feed("Fatigue warning: %s" % officer_id)

## Player-facing wording for Commands.gd's rejection reasons -- most
## already read fine as-is ("incident still being assessed", "unit not
## available"), this just prefixes them so a rejection reads as a direct
## response to the tap that caused it, not an ambient feed line.
func _on_command_rejected(_command_name: String, reason: String) -> void:
	_append_feed("Can't do that -- %s" % reason, Color(0.95, 0.65, 0.3))

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

## Kept short now that each line renders bigger and the feed's reserved
## screen space was cut back (see _feed_list above) -- older entries
## scrolling off matters less than the visible ones actually being
## readable, and not covering more of the map than necessary, on a real
## phone screen.
const MAX_FEED_ENTRIES := 4

func _append_feed(text: String, color: Color = Color.WHITE) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.modulate = color
	_feed_list.add_child(label)
	if _feed_list.get_child_count() > MAX_FEED_ENTRIES:
		_feed_list.get_child(0).queue_free()
