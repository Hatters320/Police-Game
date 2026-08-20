class_name ResourcesPanelView
extends SidePanelView
## Always-docked roster (left side, matching the player mockup's
## permanent desktop position -- just sized for a phone rather than
## dropped for an open-on-demand panel) -- every patrol unit, specialist
## unit, and neighbourhood officer with its current status and location in
## one scrollable list. Tapping a unit/specialist row pans the map to it
## and opens its existing detail panel (UnitPanelView), which draws above
## this panel rather than closing it. Neighbourhood officers don't have
## individual per-officer detail beyond NeighbourhoodPanelView, so their
## rows are informational only.

var _map_view: MapView
var _unit_panel: UnitPanelView

## Colour-coded status accent per unit.status, standing in for the
## mockup's per-unit-type icon art since none is available this pass --
## green reads "out and working", amber "en route", red "committed to a
## scene", blue "resting", grey "off the board".
const STATUS_COLORS := {
	GameEnums.UnitStatus.AVAILABLE: Color(0.3, 0.75, 0.3),
	GameEnums.UnitStatus.PATROL: Color(0.3, 0.75, 0.3),
	GameEnums.UnitStatus.TRAVELLING: Color(0.95, 0.55, 0.1),
	GameEnums.UnitStatus.ON_SCENE: Color(0.85, 0.15, 0.15),
	GameEnums.UnitStatus.ON_BREAK: Color(0.3, 0.6, 0.9),
	GameEnums.UnitStatus.UNAVAILABLE: Color(0.5, 0.5, 0.5),
}
const SPECIALIST_ACCENT := Color(0.65, 0.45, 0.85)
const NEIGHBOURHOOD_ACCENT := Color(0.4, 0.75, 0.7)

func _panel_anchor() -> int:
	return Control.PRESET_TOP_LEFT

## Slim docked strip, not the 360-wide default every detail panel wants --
## this is always on screen, so it needs to leave the map usable beside it.
func _panel_width() -> float:
	return 132.0

## Same derived height as the dispatch queue, so the two docked panels
## frame the map symmetrically.
func _panel_height() -> float:
	return available_docked_height()

func wire(map_view: MapView, unit_panel: UnitPanelView) -> void:
	_map_view = map_view
	_unit_panel = unit_panel
	# Always-docked now rather than opened fresh each time (which used to
	# guarantee up-to-date content just by calling refresh() on open()) --
	# needs to actually stay live while visible. incident_state_changed
	# covers a dispatch/arrival (both flip unit.status the instant they
	# happen, not on the next tick), tick_completed covers everything else
	# that changes between ticks (patrol movement, district crossed), and
	# _unit_panel closing covers a break/recall made from its controls.
	Simulation.core.incident_manager.incident_state_changed.connect(func(_a, _b, _c): _refresh_if_open())
	Simulation.core.tick_completed.connect(_refresh_if_open)
	_unit_panel.closed.connect(_refresh_if_open)

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
	add_header_bar("Unit Management")

	var resource_manager: ResourceManager = Simulation.core.resource_manager
	for unit: PoliceUnit in resource_manager.units.values():
		_add_unit_card(unit)

	var specialist_manager: SpecialistManager = Simulation.core.specialist_manager
	if not specialist_manager.units.is_empty():
		add_divider()
		for unit: SpecialistUnit in specialist_manager.units.values():
			add_card(SPECIALIST_ACCENT, unit.display_name, specialist_manager.status_text(unit), Callable(), UiIcon.Kind.SHIELD)

	var neighbourhood_manager: NeighbourhoodManager = Simulation.core.neighbourhood_manager
	if not neighbourhood_manager.officers.is_empty():
		add_divider()
		for officer: NeighbourhoodOfficer in neighbourhood_manager.officers.values():
			add_card(NEIGHBOURHOOD_ACCENT, officer.officer_name, neighbourhood_manager.status_text(officer), Callable(), UiIcon.Kind.PEOPLE)

func _add_unit_card(unit: PoliceUnit) -> void:
	var accent: Color = STATUS_COLORS.get(unit.status, Color.GRAY)
	# The mockup puts a vehicle glyph on the right of every unit row --
	# a patrol unit is a car, so the same glyph serves all of them here
	# (specialists/neighbourhood officers below get their own).
	add_card(
		accent,
		unit.callsign,
		"%s -- %s" % [_status_text(unit), _location_text(unit)],
		_on_unit_row_pressed.bind(unit.id),
		UiIcon.Kind.CAR,
	)

func _status_text(unit: PoliceUnit) -> String:
	match unit.status:
		GameEnums.UnitStatus.AVAILABLE: return "available"
		GameEnums.UnitStatus.PATROL: return "on patrol"
		GameEnums.UnitStatus.TRAVELLING: return "en route to incident"
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
	if _map_view:
		_map_view.pan_camera_to(unit.current_position)
	if _unit_panel:
		_unit_panel.open(unit_id)
