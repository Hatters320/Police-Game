class_name IncidentsListPanelView
extends SidePanelView
## Always-docked, full-scrollable list of every open incident (right
## side, matching the player mockup's permanent desktop position -- just
## sized for a phone rather than dropped for an open-on-demand panel). A
## second, more reliable way to browse and act on incidents than hunting
## for markers on a busy map, alongside the existing tap-a-marker and
## tap-a-feed-line paths. Tapping a row pans the map to it and opens the
## existing IncidentPanelView for full detail/dispatch, which draws above
## this panel (a higher CanvasLayer) rather than closing it.

var _map_view: MapView
var _incident_panel: IncidentPanelView

func _panel_width() -> float:
	return 132.0

## Fills the real available height rather than a fixed number -- the
## dispatch queue is the panel a player reads most, and three-line
## incident rows meant only two fit at the old 200 default. See
## SidePanelView.available_docked_height for why this is derived.
func _panel_height() -> float:
	return available_docked_height()

func wire(map_view: MapView, incident_panel: IncidentPanelView) -> void:
	_map_view = map_view
	_incident_panel = incident_panel
	# Always-docked now rather than opened fresh each time (which used to
	# guarantee up-to-date content just by calling refresh() on open()) --
	# needs to actually stay live while visible, so a new/dispatched/
	# resolved incident shows up without the player having to toggle it.
	Simulation.core.incident_manager.incident_created.connect(func(_a): _refresh_if_open())
	Simulation.core.incident_manager.incident_state_changed.connect(func(_a, _b, _c): _refresh_if_open())
	Simulation.core.incident_manager.incident_resolved.connect(func(_a, _b): _refresh_if_open())

func _refresh_if_open() -> void:
	if is_open():
		request_refresh()

func open() -> void:
	if _map_view:
		_map_view.close_other_panels(self)
	_show_panel()
	refresh()

## A dispatched-but-not-yet-resolved incident reads as "in hand" rather
## than "needs a decision" -- a distinct accent colour (overriding the
## priority colour) lets a player scanning the list tell the two apart at
## a glance instead of having to open each one to check.
const DISPATCHED_COLOR := Color(0.3, 0.6, 0.95)

func refresh() -> void:
	if not is_open():
		return
	clear_content()

	# active_incidents.erase() for a just-resolved incident happens slightly
	# after IncidentManager emits incident_resolved -- is_open() filters it
	# out immediately by its own state instead, rather than by whether the
	# dict has caught up yet, so a resolved incident never has a moment of
	# still showing here (confirmed missing before this fix via real
	# playtesting: resolving one didn't remove it from this list).
	var incidents: Array = []
	for incident: Incident in Simulation.core.incident_manager.active_incidents.values():
		if incident.is_open():
			incidents.append(incident)
	add_header_bar("Dispatch Queue", "%d OPEN" % incidents.size() if not incidents.is_empty() else "")
	if incidents.is_empty():
		add_dim_line("(none currently open)")
		return
	# Priority first (1 = most critical, floats to the top), newest first
	# within the same priority -- "clear prioritisation tools for the
	# player" (feature request). A fresh routine call no longer buries a
	# lingering critical one further down the list the way pure
	# newest-first could; priority is still reinforced per-row by the
	# existing accent colour/text.
	incidents.sort_custom(func(a, b):
		if a.priority != b.priority:
			return a.priority < b.priority
		return a.created_at_minute > b.created_at_minute)
	for incident: Incident in incidents:
		var accent: Color = DISPATCHED_COLOR if not incident.assigned_unit_ids.is_empty() else MapView.PRIORITY_COLORS.get(incident.priority, Color.GRAY)
		add_card(
			accent,
			"P%d %s" % [incident.priority, incident.type_id],
			incident.location_id,
			_on_incident_row_pressed.bind(incident.id),
			_icon_for(incident),
			_state_text(incident),
		)

## Per-incident-type glyph, matching the mockup's right-hand icon on each
## dispatch row -- a house for anything domestic/residential, a magnifier
## for acquisitive crime worth investigating, a hand for violence/public
## order (something officers physically intervene in), falling back to a
## generic alert triangle for anything the type list grows later.
func _icon_for(incident: Incident) -> int:
	var type_id: String = incident.type_id.to_lower()
	if type_id.contains("domestic") or type_id.contains("burglary") or type_id.contains("welfare"):
		return UiIcon.Kind.HOUSE
	if type_id.contains("shoplifting") or type_id.contains("theft") or type_id.contains("suspicious"):
		return UiIcon.Kind.MAGNIFIER
	if type_id.contains("assault") or type_id.contains("violence") or type_id.contains("asb") or type_id.contains("disorder"):
		return UiIcon.Kind.HAND
	return UiIcon.Kind.ALERT

## Player-facing wording for the incident's current state -- the mockup's
## third line per row ("On Scene", "Assigned"). Reads the real state
## rather than just "dispatched or not", so a queued call and a unit
## already at the scene no longer look identical in this list.
func _state_text(incident: Incident) -> String:
	match incident.state:
		GameEnums.IncidentState.CREATED, GameEnums.IncidentState.REPORTED: return "New call"
		GameEnums.IncidentState.ASSESSED: return "Assessing"
		GameEnums.IncidentState.QUEUED: return "Awaiting dispatch"
		GameEnums.IncidentState.ASSIGNED: return "Assigned"
		GameEnums.IncidentState.TRAVELLING: return "En route"
		GameEnums.IncidentState.ON_SCENE: return "On Scene"
		GameEnums.IncidentState.DEVELOPING: return "Developing"
		_: return ""

func _on_incident_row_pressed(incident_id: String) -> void:
	var marker: Node2D = _map_view._incident_markers.get(incident_id) if _map_view else null
	if marker == null:
		return
	_map_view.pan_camera_to(marker.global_position)
	_map_view.open_incident_panel(incident_id)
