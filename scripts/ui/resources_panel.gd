class_name ResourcesPanelView
extends SidePanelView
## Always-reachable roster (left side, per real playtesting feedback: a
## permanent left/right/bottom desktop layout doesn't fit a phone screen
## alongside a usable map, so this is an open-on-demand panel instead of
## permanent chrome) -- every patrol unit, specialist unit, and
## neighbourhood officer with its current status and location in one
## scrollable list. Tapping a unit/specialist row pans the map to it and
## opens its existing detail panel (UnitPanelView); neighbourhood officers
## don't have individual per-officer detail beyond NeighbourhoodPanelView,
## so their rows are informational only.

var _map_view: MapView
var _unit_panel: UnitPanelView

func _panel_anchor() -> int:
	return Control.PRESET_TOP_LEFT

func wire(map_view: MapView, unit_panel: UnitPanelView) -> void:
	_map_view = map_view
	_unit_panel = unit_panel

func open() -> void:
	if _map_view:
		_map_view.close_other_panels(self)
	_show_panel()
	refresh()

func refresh() -> void:
	if not is_open():
		return
	clear_content()
	add_title("Resources")
	add_close_button()

	add_mini_header("PATROL UNITS")
	var resource_manager: ResourceManager = Simulation.core.resource_manager
	for unit: PoliceUnit in resource_manager.units.values():
		_add_unit_row(unit)

	var specialist_manager: SpecialistManager = Simulation.core.specialist_manager
	if not specialist_manager.units.is_empty():
		add_divider()
		add_mini_header("SPECIALIST UNITS")
		for unit: SpecialistUnit in specialist_manager.units.values():
			add_line("%s -- %s" % [unit.display_name, specialist_manager.status_text(unit)])

	var neighbourhood_manager: NeighbourhoodManager = Simulation.core.neighbourhood_manager
	if not neighbourhood_manager.officers.is_empty():
		add_divider()
		add_mini_header("NEIGHBOURHOOD TEAM")
		for officer: NeighbourhoodOfficer in neighbourhood_manager.officers.values():
			add_line("%s -- %s" % [officer.officer_name, neighbourhood_manager.status_text(officer)])

func _add_unit_row(unit: PoliceUnit) -> void:
	var row := HBoxContainer.new()
	content.add_child(row)
	var button := Button.new()
	button.text = "%s -- %s -- %s" % [unit.callsign, _status_text(unit), _location_text(unit)]
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(_on_unit_row_pressed.bind(unit.id))
	row.add_child(button)

func _status_text(unit: PoliceUnit) -> String:
	match unit.status:
		GameEnums.UnitStatus.AVAILABLE: return "available"
		GameEnums.UnitStatus.PATROL: return "on patrol"
		GameEnums.UnitStatus.TRAVELLING: return "travelling"
		GameEnums.UnitStatus.ON_SCENE: return "on scene"
		GameEnums.UnitStatus.ON_BREAK: return "on break"
		GameEnums.UnitStatus.UNAVAILABLE: return "unavailable"
		_: return "unknown"

## Which district the unit's current world position is actually inside,
## per spec section 56's "location" ask -- units don't have a single named
## point the way a location does, so this is the closest reasonable
## summary. Point-in-polygon against each district's real boundary rather
## than nearest-centroid, since districts vary a lot in size/shape and a
## centroid comparison can pick the wrong neighbour near a border.
func _location_text(unit: PoliceUnit) -> String:
	var world: WorldMapData = Simulation.core.world
	for district: DistrictDefinition in world.districts:
		if Geometry2D.is_point_in_polygon(unit.current_position, district.boundary):
			return district.display_name
	# Between districts (travelling a connecting road) -- fall back to
	# whichever boundary is nearest.
	var closest_name: String = "en route"
	var closest_dist: float = INF
	for district: DistrictDefinition in world.districts:
		for point in district.boundary:
			var dist: float = point.distance_to(unit.current_position)
			if dist < closest_dist:
				closest_dist = dist
				closest_name = district.display_name
	return closest_name

func _on_unit_row_pressed(unit_id: String) -> void:
	var unit: PoliceUnit = Simulation.core.resource_manager.get_unit(unit_id)
	if unit == null:
		return
	close()
	if _map_view:
		_map_view.pan_camera_to(unit.current_position)
	if _unit_panel:
		_unit_panel.open(unit_id)
