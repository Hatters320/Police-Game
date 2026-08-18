class_name SpecialistManager
extends RefCounted
## Owns the town's 3 specialist resources (spec section 11: 1 traffic, 1
## dog, 1 firearms). They are NOT part of the response team's roster --
## external resources the Inspector can request but isn't guaranteed to
## get, with simplified availability/travel-time behaviour rather than a
## full simulation of a wider force area ("For MVP purposes, specialist
## units can be represented as external resources with simplified
## behaviour" -- spec section 11).

signal specialist_committed(specialist_id: String, incident_id: String)

const TRAVEL_MINUTES_NEARBY := 12.0
const TRAVEL_MINUTES_FAR := 35.0
## How long a specialist stays committed to an incident once it arrives,
## before reverting to available -- a simplified stand-in for however long
## the real task takes, same abstraction as PatrolMode's directed patrol.
const COMMITMENT_MINUTES := 30.0

var units: Dictionary = {} # id -> SpecialistUnit

func setup() -> void:
	units.clear()
	units["specialist_traffic"] = SpecialistUnit.new("specialist_traffic", "Traffic Unit", GameEnums.SpecialistType.TRAFFIC)
	units["specialist_dog"] = SpecialistUnit.new("specialist_dog", "Dog Unit", GameEnums.SpecialistType.DOG)
	units["specialist_firearms"] = SpecialistUnit.new("specialist_firearms", "Firearms Unit", GameEnums.SpecialistType.FIREARMS)

## Rerolls each unit's starting availability for the shift (spec section
## 11: "NOT guaranteed") -- called once per shift, not per request, so
## status is something the Inspector can actually plan a briefing around
## rather than a coin flip on every single request.
func setup_shift(rng: RandomNumberGenerator) -> void:
	for unit: SpecialistUnit in units.values():
		if unit.status == GameEnums.SpecialistStatus.COMMITTED:
			continue # still finishing a task carried over from the previous shift
		var roll: float = rng.randf()
		if roll < 0.4:
			unit.status = GameEnums.SpecialistStatus.AVAILABLE
		elif roll < 0.7:
			unit.status = GameEnums.SpecialistStatus.NEARBY
		elif roll < 0.9:
			unit.status = GameEnums.SpecialistStatus.FAR_AWAY
		else:
			unit.status = GameEnums.SpecialistStatus.UNAVAILABLE

func get_unit(specialist_id: String) -> SpecialistUnit:
	return units.get(specialist_id)

func unit_for_type(type: GameEnums.SpecialistType) -> SpecialistUnit:
	for unit: SpecialistUnit in units.values():
		if unit.type == type:
			return unit
	return null

## Returns {"accepted": false, "reason": String} or
## {"accepted": true, "eta_minutes": float}.
func request(specialist_id: String, incident_id: String) -> Dictionary:
	var unit: SpecialistUnit = get_unit(specialist_id)
	if unit == null:
		return {"accepted": false, "reason": "unknown specialist"}
	if unit.status == GameEnums.SpecialistStatus.UNAVAILABLE:
		return {"accepted": false, "reason": "not available this shift"}
	if unit.status == GameEnums.SpecialistStatus.COMMITTED:
		return {"accepted": false, "reason": "already committed elsewhere"}

	var eta: float = 0.0
	if unit.status == GameEnums.SpecialistStatus.NEARBY:
		eta = TRAVEL_MINUTES_NEARBY
	elif unit.status == GameEnums.SpecialistStatus.FAR_AWAY:
		eta = TRAVEL_MINUTES_FAR

	unit.status = GameEnums.SpecialistStatus.COMMITTED
	unit.committed_incident_id = incident_id
	unit.travel_minutes_remaining = eta
	unit.commitment_minutes_remaining = eta + COMMITMENT_MINUTES
	specialist_committed.emit(unit.id, incident_id)
	return {"accepted": true, "eta_minutes": eta}

func tick(ctx: SimulationContext) -> void:
	for unit: SpecialistUnit in units.values():
		if unit.status != GameEnums.SpecialistStatus.COMMITTED:
			continue
		unit.travel_minutes_remaining = maxf(unit.travel_minutes_remaining - ctx.dt_minutes, 0.0)
		unit.commitment_minutes_remaining = maxf(unit.commitment_minutes_remaining - ctx.dt_minutes, 0.0)
		if unit.commitment_minutes_remaining <= 0.0:
			unit.status = GameEnums.SpecialistStatus.AVAILABLE
			unit.committed_incident_id = ""

func status_text(unit: SpecialistUnit) -> String:
	match unit.status:
		GameEnums.SpecialistStatus.AVAILABLE:
			return "Available"
		GameEnums.SpecialistStatus.NEARBY:
			return "Nearby (~%d min if requested)" % int(TRAVEL_MINUTES_NEARBY)
		GameEnums.SpecialistStatus.FAR_AWAY:
			return "Far away (~%d min if requested)" % int(TRAVEL_MINUTES_FAR)
		GameEnums.SpecialistStatus.UNAVAILABLE:
			return "Unavailable this shift"
		GameEnums.SpecialistStatus.COMMITTED:
			if unit.travel_minutes_remaining > 0.0:
				return "Travelling (%d min)" % int(ceil(unit.travel_minutes_remaining))
			return "On task (%d min)" % int(ceil(unit.commitment_minutes_remaining))
		_:
			return "Unknown"
