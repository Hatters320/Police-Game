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
	return 110.0

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
		refresh()

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
	add_header_bar("Active Incidents")

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
	if incidents.is_empty():
		add_dim_line("(none currently open)")
		return
	# Newest first, per a real player request -- a fresh call is what a
	# player most needs to see without scrolling, and priority is already
	# visible per-row via the accent colour/text.
	incidents.sort_custom(func(a, b): return a.created_at_minute > b.created_at_minute)
	for incident: Incident in incidents:
		var accent: Color = DISPATCHED_COLOR if not incident.assigned_unit_ids.is_empty() else MapView.PRIORITY_COLORS.get(incident.priority, Color.GRAY)
		add_card(
			accent,
			"P%d %s" % [incident.priority, incident.type_id],
			incident.location_id,
			_on_incident_row_pressed.bind(incident.id),
		)

func _on_incident_row_pressed(incident_id: String) -> void:
	var marker: Node2D = _map_view._incident_markers.get(incident_id) if _map_view else null
	if marker == null:
		return
	_map_view.pan_camera_to(marker.global_position)
	_map_view.open_incident_panel(incident_id)
