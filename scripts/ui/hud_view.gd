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
var _panels_row: HBoxContainer
var _controls_row: HBoxContainer
var _map_view: MapView

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

	# A real user report ("as [incidents] stack up I can't scroll the
	# screen or scroll through them") found this used to just delete
	# anything past MAX_FEED_ENTRIES with nowhere to scroll back to even
	# once wrapped in a container that could scroll -- there was no history
	# left to show. Now a real ScrollContainer over a much longer history
	# (see MAX_FEED_ENTRIES below), and each incident-related line is
	# tappable to open that incident directly, since finding its marker on
	# a busy map is a second, harder way to reach the same thing.
	var feed_scroll := ScrollContainer.new()
	feed_scroll.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	feed_scroll.position = Vector2(20, -90)
	feed_scroll.custom_minimum_size = Vector2(460, 80)
	add_child(feed_scroll)

	_feed_list = VBoxContainer.new()
	_feed_list.custom_minimum_size = Vector2(460, 0)
	feed_scroll.add_child(_feed_list)

	_overlay_row = HBoxContainer.new()
	_overlay_row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_overlay_row.position = Vector2(20, 84)
	_overlay_row.add_theme_constant_override("separation", 8)
	add_child(_overlay_row)

	# Separate row for "open a full panel" buttons (Neighbourhood/Resources/
	# Incidents) rather than piling them onto _overlay_row's map-filter
	# toggles -- together the two rows' 9 buttons measured 709px wide on the
	# 640px design canvas (real headless measurement), well past the edge.
	# Splitting them across two rows keeps every row comfortably under 640
	# without shrinking any button below its spec section 56 touch size.
	_panels_row = HBoxContainer.new()
	_panels_row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_panels_row.position = Vector2(20, 126)
	_panels_row.add_theme_constant_override("separation", 8)
	add_child(_panels_row)

	Simulation.core.incident_manager.incident_created.connect(_on_incident_created)
	Simulation.core.incident_manager.incident_escalated.connect(_on_incident_escalated)
	Simulation.core.incident_manager.incident_resolved.connect(_on_incident_resolved)
	Simulation.core.incident_manager.incident_state_changed.connect(_on_incident_state_changed)
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
	_panels_row.add_child(button)

## Called once by main.gd after MapView exists -- builds the overlay
## toggle row (spec section 41), and keeps the reference for the event
## feed's tap-to-open-incident lines below. Kept out of _ready() since it
## needs a MapView reference to wire the buttons to.
func wire_overlays(map_view: MapView) -> void:
	_map_view = map_view
	_add_overlay_button("None", map_view, MapView.OverlayType.NONE)
	_add_overlay_button("ASB", map_view, MapView.OverlayType.ASB)
	_add_overlay_button("Violence", map_view, MapView.OverlayType.VIOLENCE)
	_add_overlay_button("Burglary", map_view, MapView.OverlayType.BURGLARY)
	_add_overlay_button("Visibility", map_view, MapView.OverlayType.VISIBILITY)
	_add_overlay_button("Demand", map_view, MapView.OverlayType.DEMAND)

func wire_resources_panel(on_pressed: Callable) -> void:
	var button := Button.new()
	button.text = "Resources"
	button.add_theme_font_size_override("font_size", 15)
	button.custom_minimum_size = Vector2(0, 40)
	button.pressed.connect(on_pressed)
	_panels_row.add_child(button)

func wire_incidents_panel(on_pressed: Callable) -> void:
	var button := Button.new()
	button.text = "Incidents"
	button.add_theme_font_size_override("font_size", 15)
	button.custom_minimum_size = Vector2(0, 40)
	button.pressed.connect(on_pressed)
	_panels_row.add_child(button)

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

## Radio colours: CONTROL room traffic reads white (same as the rest of the
## feed), units transmitting back to CONTROL read pale green -- a cheap way
## to tell the two "speakers" apart at a glance in a single shared log,
## since this is a mobile-adapted single feed rather than the mockup's
## separate always-on radio panel (see ResourcesPanelView's header).
const CONTROL_COLOR := Color.WHITE
const UNIT_COLOR := Color(0.55, 0.9, 0.55)

func _on_incident_created(incident_id: String) -> void:
	var incident: Incident = Simulation.core.incident_manager.get_incident(incident_id)
	if incident:
		_append_feed("CONTROL to all units: new call, P%d %s, %s." % [incident.priority, incident.type_id, incident.location_id], CONTROL_COLOR, incident_id)

func _on_incident_escalated(incident_id: String) -> void:
	var incident: Incident = Simulation.core.incident_manager.get_incident(incident_id)
	if incident:
		_append_feed("CONTROL to all units: urgent, %s escalating, now P%d." % [incident.type_id, incident.priority], CONTROL_COLOR, incident_id)

func _on_incident_resolved(incident_id: String, outcome_id: String) -> void:
	var incident: Incident = Simulation.core.incident_manager.get_incident(incident_id)
	if incident:
		_append_feed("CONTROL: %s resolved -- %s. Stand down." % [incident.type_id, outcome_id])

## Player-driven dispatch (Commands.assign_unit_to_incident) and an actual
## unit arriving (IncidentManager.mark_unit_arrived) are the only two state
## changes worth reading as radio traffic -- the timer-driven ones
## (REPORTED->ASSESSED->QUEUED, ON_SCENE->DEVELOPING->RESOLVED) are call-
## room/scene process, not a transmission, and RESOLVED is already covered
## by _on_incident_resolved above.
func _on_incident_state_changed(incident_id: String, old_state: GameEnums.IncidentState, new_state: GameEnums.IncidentState) -> void:
	var incident: Incident = Simulation.core.incident_manager.get_incident(incident_id)
	if incident == null:
		return
	var callsigns: String = _assigned_callsigns(incident)
	if new_state == GameEnums.IncidentState.TRAVELLING and old_state != GameEnums.IncidentState.TRAVELLING:
		_append_feed("CONTROL to %s: proceed to %s for P%d %s." % [callsigns, incident.location_id, incident.priority, incident.type_id], CONTROL_COLOR, incident_id)
	elif new_state == GameEnums.IncidentState.ON_SCENE and old_state == GameEnums.IncidentState.TRAVELLING:
		_append_feed("%s to Control: on scene, %s." % [callsigns, incident.location_id], UNIT_COLOR, incident_id)

func _assigned_callsigns(incident: Incident) -> String:
	var callsigns: Array[String] = []
	for unit_id in incident.assigned_unit_ids:
		var unit: PoliceUnit = Simulation.core.resource_manager.get_unit(unit_id)
		if unit:
			callsigns.append(unit.callsign)
	return ", ".join(PackedStringArray(callsigns)) if not callsigns.is_empty() else "Unit"

## Enough history to actually scroll through, not just a handful of lines
## that immediately fall off the end -- a real user found the previous
## cap of 4 meant there was nothing left to scroll BACK to even once this
## became a real ScrollContainer, since anything past the cap was already
## queue_free()'d.
const MAX_FEED_ENTRIES := 20

## incident_id, when given, makes this line a tappable shortcut to that
## incident's panel -- a busy real phone screen can make the matching map
## marker hard to find/hit even with MapView's zoom-scaled tap radius, so
## the feed doubles as a full, scrollable incident list.
func _append_feed(text: String, color: Color = Color.WHITE, incident_id: String = "") -> void:
	if incident_id != "":
		var button := Button.new()
		button.text = text
		button.flat = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = false
		button.add_theme_font_size_override("font_size", 16)
		button.modulate = color
		button.pressed.connect(func():
			if _map_view:
				_map_view.open_incident_panel(incident_id))
		_feed_list.add_child(button)
		if _feed_list.get_child_count() > MAX_FEED_ENTRIES:
			_feed_list.get_child(0).queue_free()
		return
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.modulate = color
	_feed_list.add_child(label)
	if _feed_list.get_child_count() > MAX_FEED_ENTRIES:
		_feed_list.get_child(0).queue_free()
