class_name IncidentsListPanelView
extends SidePanelView
## Always-reachable, full-scrollable list of every open incident (right
## side, per real playtesting feedback -- see ResourcesPanelView's header
## for why this is an open-on-demand panel rather than permanent chrome).
## A second, more reliable way to browse and act on incidents than
## hunting for markers on a busy map, alongside the existing tap-a-marker
## and tap-a-feed-line paths. Tapping a row pans the map to it and opens
## the existing IncidentPanelView for full detail/dispatch -- closing that
## detail view returns here to the list, so browsing multiple incidents
## in a row doesn't need reopening this panel each time.

var _map_view: MapView
var _incident_panel: IncidentPanelView
var _opened_incident_from_list: bool = false

func wire(map_view: MapView, incident_panel: IncidentPanelView) -> void:
	_map_view = map_view
	_incident_panel = incident_panel
	_incident_panel.closed.connect(_on_incident_panel_closed)

func open() -> void:
	if _map_view:
		_map_view.close_other_panels(self)
	_show_panel()
	refresh()

func refresh() -> void:
	if not is_open():
		return
	clear_content()
	add_title("Active Incidents")
	add_close_button()

	var incidents: Array = Simulation.core.incident_manager.active_incidents.values()
	if incidents.is_empty():
		add_dim_line("(none currently open)")
		return
	# Most urgent first (lowest priority number = most urgent, matches
	# IncidentPanelView/spec convention throughout).
	incidents.sort_custom(func(a, b): return a.priority < b.priority)
	for incident: Incident in incidents:
		_add_incident_row(incident)

func _add_incident_row(incident: Incident) -> void:
	var row := HBoxContainer.new()
	content.add_child(row)

	var priority_bar := ColorRect.new()
	priority_bar.color = MapView.PRIORITY_COLORS.get(incident.priority, Color.GRAY)
	priority_bar.custom_minimum_size = Vector2(6, 44)
	row.add_child(priority_bar)

	var button := Button.new()
	button.text = "P%d %s -- %s" % [incident.priority, incident.type_id, incident.location_id]
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(_on_incident_row_pressed.bind(incident.id))
	row.add_child(button)

func _on_incident_row_pressed(incident_id: String) -> void:
	var marker: Node2D = _map_view._incident_markers.get(incident_id) if _map_view else null
	if marker == null:
		return
	close()
	_opened_incident_from_list = true
	_map_view.pan_camera_to(marker.global_position)
	_map_view.open_incident_panel(incident_id)

func _on_incident_panel_closed() -> void:
	if _opened_incident_from_list:
		_opened_incident_from_list = false
		open()
