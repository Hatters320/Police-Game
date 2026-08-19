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
var _feed_scroll: ScrollContainer
var _controls_row: HBoxContainer
var _overlay_picker: OptionButton
var _map_view: MapView

var _fatigue_warning_count: int = 0

## A real player screenshot at real device width found the previous
## chrome (4 stacked rows up top, each with 42-52px buttons at the
## project's 22px default font) consuming most of the screen, leaving
## barely any map -- "the sizes of all the menus and panel boxes needs to
## be reduced... top menu should be long and thin along the top". This
## pass shrinks every control down to a genuinely thin strip: one stats
## line plus one control line, both well under half the height the old
## 4-row layout used.
const TOUCH_BUTTON_SIZE := Vector2(34, 22)
const CONTROL_FONT_SIZE := 11
const STAT_FONT_SIZE := 11

## Where the thin top HUD ends and the always-docked side panels begin --
## SidePanelView positions against this same value so nothing overlaps.
const HUD_BOTTOM := 44.0

func _ready() -> void:
	layer = 2 # above DayNightOverlay's tint (layer 1), below side panels (layer 3)

	var top_bar := HBoxContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.position = Vector2(8, 3)
	top_bar.add_theme_constant_override("separation", 10)
	add_child(top_bar)

	_time_label = _add_stat_label(top_bar)
	_units_label = _add_stat_label(top_bar)
	_incidents_label = _add_stat_label(top_bar)
	_staffing_label = _add_stat_label(top_bar)
	_fatigue_label = _add_stat_label(top_bar)

	# Every remaining control -- speed/zoom, the overlay filter, and the
	# panel toggles -- now lives on this one thin row rather than three
	# separate ones. Fits comfortably under the 640px design canvas even
	# with every control present (measured well under 640 headless).
	_controls_row = HBoxContainer.new()
	_controls_row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_controls_row.position = Vector2(8, 20)
	_controls_row.add_theme_constant_override("separation", 6)
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
	#
	# A thin strip spanning the full width along the very bottom -- mirrors
	# the thin top bar rather than the earlier boxed panel wedged into the
	# gap between the two docked side panels, per the same feedback this
	# whole pass responds to ("bottom comms panel should [be] long and thin
	# along the bottom").
	var feed_panel := PanelContainer.new()
	var feed_style := StyleBoxFlat.new()
	feed_style.bg_color = Color(0.05, 0.07, 0.1, 0.85)
	feed_style.border_color = Color(0.09, 0.16, 0.28)
	feed_style.set_border_width_all(1)
	feed_style.content_margin_left = 8
	feed_style.content_margin_right = 8
	feed_style.content_margin_top = 2
	feed_style.content_margin_bottom = 2
	feed_panel.add_theme_stylebox_override("panel", feed_style)
	feed_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	feed_panel.position = Vector2(16, -60)
	feed_panel.custom_minimum_size = Vector2(0, 56)
	feed_panel.offset_right = -16
	add_child(feed_panel)

	# Still a real vertical scroll, not a single-line ticker -- "thin" means
	# noticeably shorter than the old ~90px box (spec section 39/a real
	# user report both want scroll-back history kept, not traded away for
	# thinness), not reduced to one line with no way to browse past lines.
	_feed_scroll = ScrollContainer.new()
	_feed_scroll.custom_minimum_size = Vector2(0, 52)
	# Horizontal scroll left enabled (the default) let _feed_list collapse
	# to its content-minimum width instead of filling the bar -- since
	# every line here autowraps (which reports a near-zero minimum), that
	# meant almost every message wrapped into a stack of tiny few-word
	# fragments instead of reading as one line, confirmed by a real player
	# report. Disabling it forces _feed_list to fill the bar's actual
	# (now full-width) space, so a line only wraps if it's genuinely too
	# long for that, not because the container never gave it room.
	_feed_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	feed_panel.add_child(_feed_scroll)

	_feed_list = VBoxContainer.new()
	_feed_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_feed_scroll.add_child(_feed_list)

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
	button.add_theme_font_size_override("font_size", CONTROL_FONT_SIZE)
	button.pressed.connect(on_pressed)
	parent.add_child(button)

## Scroll-wheel zoom (main.gd) has no touch equivalent -- these give
## touch/mobile players a way to zoom at all (spec section 3/56).
func wire_zoom_controls(zoom_in: Callable, zoom_out: Callable) -> void:
	_add_button(_controls_row, "-", zoom_out)
	_add_button(_controls_row, "+", zoom_in)

## Opens NeighbourhoodPanelView (spec section 10) -- placed alongside the
## other panel-toggle buttons since it's the same "open a side panel"
## action, not a simulation-speed control like Pause/1x/2x/4x.
func wire_neighbourhood_panel(on_pressed: Callable) -> void:
	_add_button(_controls_row, "Team", on_pressed)

## Called once by main.gd after MapView exists -- builds the overlay
## filter dropdown (spec section 41: still every overlay, just one control
## instead of 6 separate toggle buttons, which is most of what let the old
## 4-row HUD collapse to today's 2 thin ones), and keeps the reference for
## the event feed's tap-to-open-incident lines below. Kept out of _ready()
## since it needs a MapView reference to wire to.
func wire_overlays(map_view: MapView) -> void:
	_map_view = map_view
	_overlay_picker = OptionButton.new()
	_overlay_picker.custom_minimum_size = Vector2(0, 22)
	_overlay_picker.add_theme_font_size_override("font_size", CONTROL_FONT_SIZE)
	var overlays: Array[MapView.OverlayType] = [
		MapView.OverlayType.NONE, MapView.OverlayType.ASB, MapView.OverlayType.VIOLENCE,
		MapView.OverlayType.BURGLARY, MapView.OverlayType.VISIBILITY, MapView.OverlayType.DEMAND,
	]
	var labels := ["None", "ASB", "Violence", "Burglary", "Visibility", "Demand"]
	for label in labels:
		_overlay_picker.add_item(label)
	_overlay_picker.item_selected.connect(func(index: int): map_view.set_overlay(overlays[index]))
	_controls_row.add_child(_overlay_picker)

func wire_resources_panel(on_pressed: Callable) -> void:
	_add_button(_controls_row, "Res", on_pressed)

func wire_incidents_panel(on_pressed: Callable) -> void:
	_add_button(_controls_row, "Inc", on_pressed)

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
		_append_feed("Dispatcher: New call -- a %s reported at %s, priority %d." % [_type_display(incident), incident.location_id, incident.priority], CONTROL_COLOR, incident_id)

func _on_incident_escalated(incident_id: String) -> void:
	var incident: Incident = Simulation.core.incident_manager.get_incident(incident_id)
	if incident:
		_append_feed("Dispatcher: Update -- the %s at %s is escalating, now priority %d." % [_type_display(incident), incident.location_id, incident.priority], CONTROL_COLOR, incident_id)

func _on_incident_resolved(incident_id: String, outcome_id: String) -> void:
	var incident: Incident = Simulation.core.incident_manager.get_incident(incident_id)
	if incident:
		_append_feed("Dispatcher: %s at %s resolved -- %s. Stand down." % [_type_display(incident).capitalize(), incident.location_id, outcome_id])

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
		_append_feed("Dispatcher: %s, please attend %s for a %s." % [callsigns, incident.location_id, _type_display(incident)], CONTROL_COLOR, incident_id)
		_append_feed("%s: Copy, I'm en route." % callsigns, UNIT_COLOR, incident_id)
	elif new_state == GameEnums.IncidentState.ON_SCENE and old_state == GameEnums.IncidentState.TRAVELLING:
		_append_feed("%s: On scene at %s now." % [callsigns, incident.location_id], UNIT_COLOR, incident_id)

## The type factory's display_name reads naturally mid-sentence lower-
## cased ("a shoplifting reported at..."); incident.type_id alone (the
## previous wording) was a raw data id ("shoplifting"/"asb"), fine as a
## label but not as something a dispatcher would actually say out loud.
func _type_display(incident: Incident) -> String:
	var type_def: IncidentTypeDefinition = Simulation.core.incident_manager.get_type_definition(incident.type_id)
	return (type_def.display_name if type_def else incident.type_id).to_lower()

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
		button.autowrap_mode = TextServer.AUTOWRAP_WORD
		button.add_theme_font_size_override("font_size", 10)
		button.modulate = color
		button.pressed.connect(func():
			if _map_view:
				_map_view.open_incident_panel(incident_id))
		_feed_list.add_child(button)
		if _feed_list.get_child_count() > MAX_FEED_ENTRIES:
			_feed_list.get_child(0).queue_free()
		_scroll_feed_to_bottom()
		return
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 10)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.modulate = color
	_feed_list.add_child(label)
	if _feed_list.get_child_count() > MAX_FEED_ENTRIES:
		_feed_list.get_child(0).queue_free()
	_scroll_feed_to_bottom()

## New lines should always be visible without the player having to scroll
## down for them, but scroll-back through history (the whole point of
## MAX_FEED_ENTRIES/ScrollContainer above) still needs to work -- deferred
## so it applies after this frame's layout pass has sized the new line in,
## not against the scroll range from before it existed.
func _scroll_feed_to_bottom() -> void:
	_feed_scroll.set_deferred("scroll_vertical", 999999)
