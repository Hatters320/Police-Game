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
	return 180.0

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

func refresh() -> void:
	if not is_open():
		return
	clear_content()
	add_header_bar("Active Incidents")

	var incidents: Array = Simulation.core.incident_manager.active_incidents.values()
	if incidents.is_empty():
		add_dim_line("(none currently open)")
		return
	# Most urgent first (lowest priority number = most urgent, matches
	# IncidentPanelView/spec convention throughout).
	incidents.sort_custom(func(a, b): return a.priority < b.priority)
	for incident: Incident in incidents:
		add_card(
			MapView.PRIORITY_COLORS.get(incident.priority, Color.GRAY),
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
