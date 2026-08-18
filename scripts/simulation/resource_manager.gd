class_name ResourceManager
extends RefCounted
## Forms deployable PoliceUnits from available officers (spec section 12 --
## the single/double-crewing mechanic) and advances travelling units along
## their cached paths each tick.

## Tune once the small test map's real scale (pixels/meters between nodes)
## is known -- this is a placeholder that makes cross-town journeys take a
## few simulated minutes on a map a few thousand units wide.
const BASE_SPEED_UNITS_PER_MIN := 400.0

var units: Dictionary = {} # unit_id -> PoliceUnit

## Greedy crew formation: pair every non-driver with a driver first (so
## nobody who can't drive is stranded without a crewmate who can), then
## double-crew remaining drivers where there are enough left, otherwise
## single-crew. See docs/ARCHITECTURE.md section 3/4.
func form_units(officers: Array[Officer], start_location: LocationDefinition) -> Array[PoliceUnit]:
	units.clear()
	var drivers: Array[Officer] = []
	var non_drivers: Array[Officer] = []
	for o in officers:
		if o.driver_qualified:
			drivers.append(o)
		else:
			non_drivers.append(o)

	var formed: Array[PoliceUnit] = []
	var unit_number := 1

	while not non_drivers.is_empty() and not drivers.is_empty():
		var driver: Officer = drivers.pop_back()
		var passenger: Officer = non_drivers.pop_back()
		formed.append(_make_unit(unit_number, [driver, passenger], start_location))
		unit_number += 1

	if not non_drivers.is_empty():
		# Real staffing-pressure signal, not a bug: these officers stay
		# AVAILABLE but have no vehicle to crew this shift.
		push_warning("%d non-driving officer(s) have no driver to crew with this shift" % non_drivers.size())

	while drivers.size() >= 2:
		var a: Officer = drivers.pop_back()
		var b: Officer = drivers.pop_back()
		formed.append(_make_unit(unit_number, [a, b], start_location))
		unit_number += 1
	for remaining_driver in drivers:
		formed.append(_make_unit(unit_number, [remaining_driver], start_location))
		unit_number += 1

	for unit in formed:
		units[unit.id] = unit
	return formed

func _make_unit(number: int, crew: Array[Officer], start_location: LocationDefinition) -> PoliceUnit:
	var officer_ids: Array[String] = []
	for o in crew:
		officer_ids.append(o.id)
		o.status = GameEnums.OfficerStatus.ON_UNIT
	var unit_id: String = "unit_%d" % number
	var unit := PoliceUnit.new(unit_id, "Unit %d" % number, officer_ids)
	unit.status = GameEnums.UnitStatus.AVAILABLE
	if start_location:
		unit.current_position = start_location.position
		unit.current_road_node_id = start_location.nearest_road_node_id
	for o in crew:
		o.current_unit_id = unit_id
	return unit

func get_unit(unit_id: String) -> PoliceUnit:
	return units.get(unit_id)

func available_units() -> Array[PoliceUnit]:
	var result: Array[PoliceUnit] = []
	for unit: PoliceUnit in units.values():
		if unit.status == GameEnums.UnitStatus.AVAILABLE:
			result.append(unit)
	return result

## Advances every travelling unit along its cached path (computed once at
## dispatch by Commands, never recomputed here), notifies IncidentManager
## the moment a unit assigned to an incident arrives, and applies patrol
## presence for every unit currently on station at a directed patrol point
## (spec section 18) -- withdrawn automatically the moment a unit's status
## changes away from PATROL, since this is computed fresh each tick rather
## than toggled on/off by whoever moves the unit.
func tick(ctx: SimulationContext) -> void:
	for unit: PoliceUnit in units.values():
		match unit.status:
			GameEnums.UnitStatus.TRAVELLING:
				_advance_travel(unit, ctx)
			GameEnums.UnitStatus.PATROL:
				_apply_patrol_presence(unit, ctx)
			_:
				pass

func _advance_travel(unit: PoliceUnit, ctx: SimulationContext) -> void:
	# Spec section 34's "traffic" weather influence -- a flat travel-speed
	# reduction stands in for wet-road congestion without simulating actual
	# traffic (see WeatherManager).
	var speed: float = BASE_SPEED_UNITS_PER_MIN
	if ctx.weather_manager.is_raining():
		speed *= WeatherManager.RAIN_TRAVEL_SPEED_MULTIPLIER
	var arrived: bool = unit.advance_along_path(speed * ctx.dt_minutes)
	if not arrived:
		return
	if unit.current_incident_id != "":
		unit.status = GameEnums.UnitStatus.ON_SCENE
		ctx.incident_manager.mark_unit_arrived(unit.current_incident_id, ctx.current_minute)
	elif unit.patrol_mode == GameEnums.PatrolMode.DIRECTED and unit.patrol_location_id != "":
		unit.status = GameEnums.UnitStatus.PATROL
	else:
		unit.status = GameEnums.UnitStatus.AVAILABLE

func _apply_patrol_presence(unit: PoliceUnit, ctx: SimulationContext) -> void:
	if unit.patrol_location_id == "":
		return
	var location: LocationDefinition = ctx.world.get_location(unit.patrol_location_id)
	if location == null:
		return
	ctx.district_manager.apply_patrol(location.district_id, ctx.dt_minutes)
