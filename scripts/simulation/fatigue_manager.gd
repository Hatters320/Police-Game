class_name FatigueManager
extends RefCounted
## Owns fatigue accrual/recovery policy (spec section 14/44) -- kept
## separate from Officer's data fields so the tuning lives in one place,
## and from OfficerManager so "who are my officers" and "how tired are
## they" stay independent concerns.

signal fatigue_warning(officer_id: String)

const ENGAGED_RATE := 0.12 # fatigue points per simulated minute, actively on an incident
const IDLE_RATE := 0.04 # ... available or on patrol
const RECOVERY_RATE := 0.5 # ... on a break
const MORALE_DRAIN_THRESHOLD := 70.0
const MORALE_DRAIN_RATE := 0.02
const MORALE_RECOVERY_RATE := 0.05

func tick(ctx: SimulationContext) -> void:
	for officer: Officer in ctx.officer_manager.officers.values():
		if officer.status == GameEnums.OfficerStatus.ON_BREAK:
			_recover(officer, ctx.dt_minutes)
			continue
		var engaged: bool = _is_actively_engaged(officer, ctx.resource_manager)
		var was_elevated: bool = officer.is_elevated_fatigue()
		_accrue(officer, ctx.dt_minutes, engaged)
		if not was_elevated and officer.is_elevated_fatigue():
			fatigue_warning.emit(officer.id)

func _is_actively_engaged(officer: Officer, resource_manager: ResourceManager) -> bool:
	if officer.current_unit_id == "":
		return false
	var unit: PoliceUnit = resource_manager.get_unit(officer.current_unit_id)
	if unit == null:
		return false
	return unit.status == GameEnums.UnitStatus.TRAVELLING or unit.status == GameEnums.UnitStatus.ON_SCENE

func _accrue(officer: Officer, dt_minutes: float, engaged: bool) -> void:
	var rate: float = ENGAGED_RATE if engaged else IDLE_RATE
	officer.fatigue = clampf(officer.fatigue + rate * dt_minutes, 0.0, 100.0)
	if officer.fatigue > MORALE_DRAIN_THRESHOLD:
		officer.morale = clampf(officer.morale - MORALE_DRAIN_RATE * dt_minutes, 0.0, 100.0)

func _recover(officer: Officer, dt_minutes: float) -> void:
	officer.fatigue = clampf(officer.fatigue - RECOVERY_RATE * dt_minutes, 0.0, 100.0)
	officer.morale = clampf(officer.morale + MORALE_RECOVERY_RATE * dt_minutes, 0.0, 100.0)
