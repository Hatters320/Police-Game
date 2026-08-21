class_name HudView
extends CanvasLayer
## Top HUD bar (spec section 38), pause/1x/2x/4x speed controls (spec
## section 40), and a scrolling event feed (spec section 39). Built
## entirely via code -- see MapView's header comment for why (no .tscn
## authoring beyond the bare main scene root). Stats refresh once per
## simulation tick, not once per rendered frame, per
## docs/ARCHITECTURE.md's "signals fire / UI refreshes on meaningful
## change" performance discipline.
##
## The layout here is the product of two rounds of real player feedback
## pulling in different directions, and both are honoured deliberately:
##
## 1. Real phone playtesting found the original chrome (4 stacked rows of
##    42-52px buttons at the project's 22px default font) eating most of
##    the screen -- "the sizes of all the menus and panel boxes needs to
##    be reduced... top menu should be long and thin along the top". That
##    shrank everything to the compact metrics below (11px text, 22px
##    controls, two thin rows), and those metrics are NOT up for grabs.
## 2. A supplied design mockup then asked for a genuinely designed look
##    rather than raw engine defaults: rounded translucent cards, icons
##    beside every stat, colour-coded pills that actually show which
##    speed/panel is currently active, and a grouped control cluster.
##
## So this pass changes the *look* (UiTheme/UiIcon, grouped cards, active
## states) while keeping the *size* where phone testing put it. The one
## metric that moved is HUD_BOTTOM, up by 8px, because rounded cards need
## a little internal padding to not look clipped -- everything docked
## below reads that constant rather than hard-coding its own top edge.

var _time_label: Label
var _weather_label: Label
var _weather_icon: UiIcon
var _units_label: Label
var _incidents_label: Label
var _staffing_label: Label
var _fatigue_label: Label
var _feed_list: VBoxContainer
var _feed_scroll: ScrollContainer
var _feed_panel: PanelContainer
var _feed_wrapper: VBoxContainer
var _feed_tab_button: Button
var _feed_size_icon: UiIcon
var _feed_height_index: int = 0
var _controls_row: HBoxContainer
var _right_cluster: HBoxContainer
var _stats_row: HBoxContainer
var _overlay_picker: OptionButton
var _map_view: MapView

var _fatigue_warning_count: int = 0

## Speed pills, keyed by the multiplier they select (0.0 = Pause), so
## refresh_stats can light up whichever one matches the clock's real
## current state. The old HUD had no concept of this at all -- every
## speed button looked identical whether or not it was the active one,
## which the mockup calls out by highlighting "1x".
var _speed_buttons: Dictionary = {}
## Panel-toggle pills (Team/Res/Inc), keyed by label, lit while that
## panel is the open one -- same reasoning as the speed pills.
var _panel_buttons: Dictionary = {}

const TOUCH_BUTTON_SIZE := Vector2(34, 22)
const CONTROL_FONT_SIZE := 11
const STAT_FONT_SIZE := 11
const ICON_SIZE := 12.0

## Where the thin top HUD ends and the always-docked side panels begin --
## SidePanelView positions against this same value so nothing overlaps.
const HUD_BOTTOM := 52.0

## The sizes the dispatcher feed cycles through when its tab is tapped,
## by request: "I'd like the user to be able to make the dispatcher comms
## box larger if they want to so they can clearly see all comms."
##
## Three discrete steps rather than a free drag -- compact (the default
## thin strip this shipped with, which keeps the map maximally visible),
## medium, and tall enough to read a real run of traffic at once without
## scrolling. Starts compact so the default screen is unchanged for anyone
## who never touches it.
const FEED_HEIGHTS: Array[float] = [46.0, 104.0, 170.0]

## Fired whenever the feed changes size, so the always-docked side panels
## can shrink to keep clear of it. Without this, growing the comms box
## would grow it straight up underneath the Unit Management / Dispatch
## Queue panels -- which is the overlap real playtesting already objected
## to once ("they should stop short of that with a little bit of padding
## between them to clearly show they are different").
signal feed_height_changed

## Total vertical space the feed strip occupies from the bottom of the
## screen, including its tab row and the panel's own padding -- the single
## number SidePanelView needs to know to stay clear of it.
func feed_total_height() -> float:
	return FEED_HEIGHTS[_feed_height_index] + 32.0

## The comms strip stops accepting drags while a modal detail panel is
## open, so an incident pop-up owns the gesture until it is closed.
func _feed_scroll_allowed() -> bool:
	for node in get_tree().get_nodes_in_group(SidePanelView.MODAL_PANEL_GROUP):
		var panel_view := node as SidePanelView
		if panel_view != null and panel_view.visible:
			return false
	return true

func _ready() -> void:
	layer = 2 # above DayNightOverlay's tint (layer 1), below side panels (layer 3)

	_build_stats_bar()
	_build_controls_bar()
	_build_feed()

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

## Row 1: two rounded cards -- shift time/weather on the left, the four
## headline counts on the right -- each holding icon+label chips with thin
## dividers between them, per the mockup. Grouping them into cards (rather
## than the old flat run of six bare labels) is what makes the row read as
## "when/what conditions" then "what have I got", instead of one
## undifferentiated string of numbers.
func _build_stats_bar() -> void:
	# One continuous full-width bar rather than the free-floating cards
	# this started as. Real playtesting on a wide screen asked for the top
	# to "all flow as one", and the two-cards-plus-gap arrangement read as
	# separate floating widgets over the map instead of a single piece of
	# chrome. The bar spans edge to edge and the groups inside it are now
	# separated by hairline dividers instead of by gaps in a background.
	var bar := PanelContainer.new()
	var bar_style := UiTheme.panel_style(UiTheme.PANEL_BG, UiTheme.RADIUS_CARD)
	bar_style.content_margin_top = 3
	bar_style.content_margin_bottom = 3
	bar.add_theme_stylebox_override("panel", bar_style)
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.position = Vector2(6, 3)
	bar.offset_right = -6
	add_child(bar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	bar.add_child(row)

	# The stats sit inside a plain Control, not a Container, and that is
	# load-bearing: a Container propagates its children's minimum widths
	# upward, so the bar's minimum became "every chip at full width plus
	# every pill" and on the 640-logical-wide base viewport that overflowed
	# -- a real screenshot showed the speed pills pushed clean off the
	# right edge, unreachable. A plain Control reports only its own
	# minimum, so the chips keep their natural size and are simply clipped
	# if the screen is too narrow for all of them, while the controls stay
	# put. (Making the labels themselves shrink was tried first and was
	# worse: every chip ellipsised at once, leaving "17:00 (en...", "CLEA",
	# "6 AVA" across the whole bar.)
	var stats_clip := Control.new()
	stats_clip.clip_contents = true
	stats_clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_clip.size_flags_vertical = Control.SIZE_FILL
	stats_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(stats_clip)

	var stats_box := HBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 7)
	stats_box.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	stats_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_clip.add_child(stats_box)

	_time_label = _add_chip(stats_box, UiIcon.Kind.CLOCK)
	_add_chip_divider(stats_box)
	_weather_label = _add_chip(stats_box, UiIcon.Kind.CLEAR)
	# Kept so refresh_stats can swap sun<->cloud as the weather actually
	# changes, rather than showing one fixed glyph whatever it says.
	_weather_icon = stats_box.get_child(stats_box.get_child_count() - 2) as UiIcon
	_add_chip_divider(stats_box)

	_units_label = _add_chip(stats_box, UiIcon.Kind.SHIELD)
	_add_chip_divider(stats_box)
	_incidents_label = _add_chip(stats_box, UiIcon.Kind.PEOPLE)
	_add_chip_divider(stats_box)
	_staffing_label = _add_chip(stats_box, UiIcon.Kind.CLOCK)
	_add_chip_divider(stats_box)
	_fatigue_label = _add_chip(stats_box, UiIcon.Kind.FATIGUE)

	# Speed controls live top-right now, by request -- and in the same bar
	# as the stats rather than a row of their own, which is what lets the
	# whole top read as one continuous strip.
	_speed_buttons[0.0] = _add_pill(row, "Pause", func(): Simulation.commands().pause())
	_speed_buttons[1.0] = _add_pill(row, "1x", func(): Simulation.commands().set_speed(1.0))
	_speed_buttons[2.0] = _add_pill(row, "2x", func(): Simulation.commands().set_speed(2.0))
	_speed_buttons[4.0] = _add_pill(row, "4x", func(): Simulation.commands().set_speed(4.0))
	_stats_row = stats_box

## Row 2: the overlay picker and the panel/zoom cluster. The speed pills
## moved up into the stats bar (see above), leaving this row for "choose
## what to look at" only.
func _build_controls_bar() -> void:
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	row.position = Vector2(6, 25)
	row.offset_right = -6
	row.add_theme_constant_override("separation", 6)
	add_child(row)

	_controls_row = _add_card(row)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	_right_cluster = _add_card(row)

## One rounded translucent card holding a run of chips/pills.
func _add_card(parent: Node) -> HBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.PANEL_BG, UiTheme.RADIUS_CARD))
	parent.add_child(panel)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)
	return box

## Icon + label pair. Returns the label so callers keep a handle for
## refresh; the icon is positioned immediately before it.
func _add_chip(parent: Node, icon_kind: UiIcon.Kind) -> Label:
	var icon := UiIcon.new(icon_kind, UiTheme.TEXT_DIM, ICON_SIZE)
	parent.add_child(icon)
	var label := Label.new()
	label.add_theme_font_size_override("font_size", STAT_FONT_SIZE)
	label.add_theme_color_override("font_color", UiTheme.TEXT_PRIMARY)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Natural width -- the stats row is clipped by its parent Control if the
	# screen is too narrow (see _build_stats_bar), rather than each label
	# being squeezed until none of them are readable.
	parent.add_child(label)
	return label

## Hairline separator between chips inside one card.
func _add_chip_divider(parent: Node) -> void:
	var divider := ColorRect.new()
	divider.color = UiTheme.PANEL_BORDER
	divider.custom_minimum_size = Vector2(1, 12)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(divider)

func _add_pill(parent: Node, text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = TOUCH_BUTTON_SIZE
	button.add_theme_font_size_override("font_size", CONTROL_FONT_SIZE)
	UiTheme.style_pill_button(button, false)
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	return button

## Kept for API compatibility with main.gd's existing wiring calls.
func _add_button(parent: Node, text: String, on_pressed: Callable) -> void:
	_add_pill(parent, text, on_pressed)

## Scroll-wheel zoom (main.gd) has no touch equivalent -- these give
## touch/mobile players a way to zoom at all (spec section 3/56). Drawn as
## icon-only pills in the right-hand cluster, matching the mockup's
## compact zoom/layer controls.
func wire_zoom_controls(zoom_in: Callable, zoom_out: Callable) -> void:
	_add_icon_pill(_right_cluster, UiIcon.Kind.LAYERS, zoom_out)
	_add_icon_pill(_right_cluster, UiIcon.Kind.PLUS, zoom_in)

func _add_icon_pill(parent: Node, icon_kind: UiIcon.Kind, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(26, 22)
	UiTheme.style_pill_button(button, false)
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	# Child of the button, ignoring the mouse, so the whole pill stays one
	# tap target rather than the glyph swallowing the middle of it.
	var icon := UiIcon.new(icon_kind, UiTheme.TEXT_DIM, ICON_SIZE)
	icon.set_anchors_preset(Control.PRESET_CENTER)
	icon.position = Vector2(-ICON_SIZE * 0.5, -ICON_SIZE * 0.5)
	button.add_child(icon)
	return button

## Opens NeighbourhoodPanelView (spec section 10) -- placed alongside the
## other panel-toggle buttons since it's the same "open a side panel"
## action, not a simulation-speed control like Pause/1x/2x/4x.
func wire_neighbourhood_panel(on_pressed: Callable) -> void:
	_panel_buttons["Team"] = _add_pill(_right_cluster, "Team", on_pressed)

## Opens KpiPanelView (the shift performance dashboard) -- same "open a
## side panel" action as Team/Res/Inc, following that exact pattern.
func wire_kpi_panel(on_pressed: Callable) -> void:
	_panel_buttons["KPI"] = _add_pill(_right_cluster, "KPI", on_pressed)

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
	UiTheme.style_pill_button(_overlay_picker, false)
	var overlays: Array[MapView.OverlayType] = [
		MapView.OverlayType.NONE, MapView.OverlayType.ASB, MapView.OverlayType.VIOLENCE,
		MapView.OverlayType.BURGLARY, MapView.OverlayType.VISIBILITY, MapView.OverlayType.DEMAND,
	]
	var labels := ["None", "ASB", "Violence", "Burglary", "Visibility", "Demand"]
	for label in labels:
		_overlay_picker.add_item(label)
	_overlay_picker.item_selected.connect(func(index: int):
		map_view.set_overlay(overlays[index])
		# An overlay other than None is itself an active state worth
		# showing, same as a selected speed -- otherwise the only way to
		# tell an overlay is on is to look at the map and infer it.
		UiTheme.style_pill_button(_overlay_picker, index != 0))
	_controls_row.add_child(_overlay_picker)

func wire_resources_panel(on_pressed: Callable) -> void:
	_panel_buttons["Res"] = _add_pill(_right_cluster, "Res", on_pressed)

func wire_incidents_panel(on_pressed: Callable) -> void:
	_panel_buttons["Inc"] = _add_pill(_right_cluster, "Inc", on_pressed)

## Called by main.gd/MapView when a docked panel opens or closes, so the
## matching pill lights up -- "Inc" is shown active in the mockup.
func set_panel_active(label: String, active: bool) -> void:
	var button: Button = _panel_buttons.get(label)
	if button:
		UiTheme.style_pill_button(button, active)

func refresh_stats() -> void:
	var core: SimulationCore = Simulation.core
	var shift: ShiftState = core.shift_manager.shift_state
	# Kept deliberately short -- at the larger font size real phone
	# playtesting called for, a longer line risks running off narrower
	# screens since this row has nothing beside it to wrap into.
	_time_label.text = "%s (ends %s)" % [
		shift.time_of_day_string(), TimeFormat.clock(shift.shift_end_minute),
	]
	var raining: bool = core.weather_manager.is_raining()
	_weather_label.text = core.weather_manager.weather_text().to_upper()
	_weather_label.add_theme_color_override("font_color", Color(0.6, 0.75, 0.95) if raining else UiTheme.TEXT_PRIMARY)
	_weather_icon.kind = UiIcon.Kind.RAIN if raining else UiIcon.Kind.CLEAR
	_weather_icon.set_icon_color(Color(0.6, 0.75, 0.95) if raining else UiTheme.TEXT_DIM)

	var available_count: int = core.resource_manager.available_units().size()
	_units_label.text = "%d AVAILABLE" % available_count
	# Spec section 19: warn when reserve is running dangerously low, rather
	# than forcing a fixed minimum -- the right number depends on what's
	# happening, so this is a signal, not a hard rule.
	_units_label.add_theme_color_override("font_color", Color(0.95, 0.45, 0.25) if available_count < shift.reserve_target else UiTheme.TEXT_PRIMARY)
	_incidents_label.text = "%d ACTIVE" % core.incident_manager.active_incidents.size()
	_staffing_label.text = "%d/%d MIN" % [core.officer_manager.officers.size(), OfficerFactory.MINIMUM_STAFFING]
	_fatigue_label.text = "%d FATIGUE" % _fatigue_warning_count
	_fatigue_label.add_theme_color_override("font_color", Color(0.95, 0.55, 0.25) if _fatigue_warning_count > 0 else UiTheme.TEXT_PRIMARY)
	_refresh_speed_pills()

## Lights the pill matching the clock's real current state, reading the
## clock rather than remembering what was last tapped -- pause() can also
## be reached from elsewhere, so tracking taps alone would drift out of
## sync with the actual simulation.
func _refresh_speed_pills() -> void:
	var clock: GameClock = Simulation.core.game_clock
	var active_key: float = 0.0 if clock.paused else clock.speed_multiplier
	for key in _speed_buttons:
		UiTheme.style_pill_button(_speed_buttons[key], is_equal_approx(key, active_key))

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

## A real user report ("as [incidents] stack up I can't scroll the screen
## or scroll through them") found the feed used to just delete anything
## past MAX_FEED_ENTRIES with nowhere to scroll back to. Now a real
## ScrollContainer over a much longer history, each incident-related line
## tappable to open that incident directly, since finding its marker on a
## busy map is a second, harder way to reach the same thing.
##
## The mockup gives this strip a titled "Dispatcher Feed" tab sitting on
## top of a rounded card, and colours the speaker prefix apart from the
## message -- both added here, the latter via BBCode rather than a second
## Label so a long line still wraps as one paragraph.
func _build_feed() -> void:
	var wrapper := VBoxContainer.new()
	wrapper.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	wrapper.add_theme_constant_override("separation", 0)
	add_child(wrapper)
	# Offsets are set by _apply_feed_height() at the end of this function,
	# which is the single place that knows how tall the strip currently is.

	# The tab sits half-overlapping the card below it in the mockup; a
	# left-aligned strip in its own row is the closest equivalent that
	# still behaves under Godot's container layout.
	#
	# It doubles as the feed's size control, by request ("I'd like the user
	# to be able to make the dispatcher comms box larger if they want to so
	# they can clearly see all comms"): tapping cycles the strip through
	# FEED_HEIGHTS. A tap target is used rather than a drag handle because
	# the panels' own scroll bars had already proved too fiddly to hit on a
	# real phone -- a thin resize edge would be the same mistake again --
	# and the chevron matches the collapsible-panel language the docked
	# headers already use.
	# The tab is a plain Button carrying its own text, with the chevron
	# anchored inside it -- NOT a Button wrapping an HBoxContainer. Button
	# is not a Container, so it never lays a container child out: a first
	# attempt at this nested a label+chevron box inside the button and the
	# whole feed strip vanished from a real screenshot. The anchored-child
	# pattern below is the one already proven by the zoom/layer pills.
	var tab_row := HBoxContainer.new()
	wrapper.add_child(tab_row)
	_feed_tab_button = Button.new()
	# NOT flat: a flat Button skips drawing its stylebox entirely, so the
	# overrides below simply would not paint and a real screenshot showed
	# the tab as bare text floating over the map instead of a chip.
	_feed_tab_button.flat = false
	_feed_tab_button.text = "Dispatcher Feed"
	_feed_tab_button.add_theme_font_size_override("font_size", 10)
	_feed_tab_button.add_theme_color_override("font_color", UiTheme.HEADER_TEXT)
	_feed_tab_button.add_theme_color_override("font_hover_color", UiTheme.TEXT_PRIMARY)
	_feed_tab_button.add_theme_color_override("font_pressed_color", UiTheme.TEXT_PRIMARY)
	var tab_style := UiTheme.panel_style(UiTheme.HEADER_BG, UiTheme.RADIUS_CARD)
	tab_style.content_margin_top = 2
	tab_style.content_margin_bottom = 2
	# Room on the right for the chevron that sits inside the button.
	tab_style.content_margin_right = 20
	_feed_tab_button.add_theme_stylebox_override("normal", tab_style)
	_feed_tab_button.add_theme_stylebox_override("hover", tab_style)
	_feed_tab_button.add_theme_stylebox_override("pressed", tab_style)
	_feed_tab_button.add_theme_stylebox_override("focus", tab_style)
	_feed_tab_button.pressed.connect(_cycle_feed_height)
	tab_row.add_child(_feed_tab_button)

	_feed_size_icon = UiIcon.new(UiIcon.Kind.CHEVRON_UP, UiTheme.TEXT_DIM, 10.0)
	_feed_size_icon.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_feed_size_icon.position = Vector2(-15, -5)
	_feed_tab_button.add_child(_feed_size_icon)

	_feed_panel = PanelContainer.new()
	_feed_panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
	wrapper.add_child(_feed_panel)
	_feed_wrapper = wrapper

	# Still a real vertical scroll, not a single-line ticker -- "thin" means
	# noticeably shorter than the old ~90px box (spec section 39/a real
	# user report both want scroll-back history kept, not traded away for
	# thinness), not reduced to one line with no way to browse past lines.
	_feed_scroll = ScrollContainer.new()
	# Horizontal scroll left enabled (the default) let _feed_list collapse
	# to its content-minimum width instead of filling the bar -- since
	# every line here autowraps (which reports a near-zero minimum), that
	# meant almost every message wrapped into a stack of tiny few-word
	# fragments instead of reading as one line, confirmed by a real player
	# report. Disabling it forces _feed_list to fill the bar's actual
	# (now full-width) space, so a line only wraps if it's genuinely too
	# long for that, not because the container never gave it room.
	_feed_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_feed_panel.add_child(_feed_scroll)

	_feed_list = VBoxContainer.new()
	_feed_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_feed_list.add_theme_constant_override("separation", 1)
	_feed_scroll.add_child(_feed_list)

	# Drag anywhere on the comms strip to scroll it, with flick inertia --
	# real playtesting: "the scroll function in the comms panel is still
	# very glitchy - it's hard to move even when made big." The feed lines
	# are RichTextLabels with clickable [url] spans, so as with the side
	# panels a drag would otherwise be swallowed before reaching the
	# ScrollContainer. Gated so a modal detail panel takes priority.
	DragScroll.attach(self, _feed_scroll, _feed_panel, _feed_scroll_allowed)

	# Sets the initial (compact) height through the same path a tap uses,
	# so there is one place that knows how the strip is laid out.
	_apply_feed_height()

## incident_id, when given, makes this line a tappable shortcut to that
## incident's panel -- a busy real phone screen can make the matching map
## marker hard to find/hit even with MapView's zoom-scaled tap radius, so
## the feed doubles as a full, scrollable incident list.
##
## Rendered as a RichTextLabel: BBCode lets the speaker prefix
## ("Dispatcher:", "Unit 3:") carry the mockup's accent colour while the
## message stays readable white, and `[url]` gives the whole wrapped
## paragraph a single tap target -- a plain Button could do one or the
## other, not both.
func _append_feed(text: String, color: Color = Color.WHITE, incident_id: String = "") -> void:
	var line := RichTextLabel.new()
	line.bbcode_enabled = true
	line.fit_content = true
	line.scroll_active = false
	# RichTextLabel underlines [url] spans by default, which made every
	# tappable feed line render underlined end to end in a real screenshot
	# -- visually noisy, and nothing like the mockup's clean feed. The line
	# is still tappable; it just no longer advertises itself as a hyperlink.
	line.meta_underlined = false
	line.autowrap_mode = TextServer.AUTOWRAP_WORD
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_theme_font_size_override("normal_font_size", 10)
	line.add_theme_font_size_override("bold_font_size", 10)

	var speaker := ""
	var message := text
	var split_at: int = text.find(": ")
	if split_at > 0:
		speaker = text.substr(0, split_at + 1)
		message = text.substr(split_at + 2)

	# Shift clock stamp, by request: "I'd like timings of the comms to be
	# added so that the user knows when the comms message was said." Uses
	# the simulation's own shift time (not wall-clock), since that is the
	# clock the player is reading everywhere else in the HUD, and is dimmed
	# so it frames the line rather than competing with it.
	var body := "[color=#%s]%s[/color]  " % [
		UiTheme.TEXT_DIM.to_html(false),
		Simulation.core.shift_manager.shift_state.time_of_day_string(),
	]
	if speaker != "":
		body += "[color=#%s][b]%s[/b][/color] " % [UiTheme.TEXT_ACCENT.to_html(false), speaker]
	body += "[color=#%s]%s[/color]" % [color.to_html(false), message]
	if incident_id != "":
		body = "[url=%s]%s[/url]" % [incident_id, body]
		line.meta_clicked.connect(func(meta):
			if _map_view:
				_map_view.open_incident_panel(str(meta)))
	line.text = body

	_feed_list.add_child(line)
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

## Steps the feed to the next size in FEED_HEIGHTS, wrapping back round to
## compact. The whole strip is bottom-anchored, so growing it means moving
## the wrapper's top edge further up rather than letting it extend off the
## bottom of the screen -- hence repositioning here as well as resizing.
func _cycle_feed_height() -> void:
	_feed_height_index = (_feed_height_index + 1) % FEED_HEIGHTS.size()
	_apply_feed_height()

func _apply_feed_height() -> void:
	var height: float = FEED_HEIGHTS[_feed_height_index]
	_feed_scroll.custom_minimum_size = Vector2(0, height)
	_feed_panel.custom_minimum_size = Vector2(0, height + 8.0)
	# Pin all four offsets rather than assigning `position`. Control's
	# position setter *preserves the control's current size* by moving
	# offset_bottom along with offset_top -- and at build time that size is
	# still 0, so re-positioning the bottom-anchored wrapper here pinned it
	# to zero height and the entire feed strip vanished from a real
	# screenshot. Setting the offsets directly states the intent exactly:
	# span from (bottom - height - chrome) to the bottom edge.
	# The 32 is the tab row plus the panel's own padding, measured from the
	# compact layout this replaced (wrapper sat at -78 for a 46px feed).
	_feed_wrapper.offset_left = 10
	_feed_wrapper.offset_right = -10
	_feed_wrapper.offset_top = -(height + 32.0)
	_feed_wrapper.offset_bottom = 0
	# Points the way the next tap will take it: up while there is a bigger
	# size left, back down when the next tap wraps to compact.
	_feed_size_icon.kind = UiIcon.Kind.CHEVRON_DOWN if _feed_height_index == FEED_HEIGHTS.size() - 1 else UiIcon.Kind.CHEVRON_UP
	_feed_size_icon.queue_redraw()
	_scroll_feed_to_bottom()
	feed_height_changed.emit()
