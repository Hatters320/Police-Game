class_name DistrictState
extends RefCounted
## Mutable per-district simulation variables (spec section 6). A RefCounted,
## never a Resource -- Resources are shared-by-reference by default in
## Godot, which would risk two districts silently sharing one instance.
## Persists across shifts (docs/ARCHITECTURE.md's cross-shift decision).

const MIN_VALUE := 0.0
const MAX_VALUE := 100.0

var district_id: String

var asb: float = 20.0
var violence: float = 10.0
var burglary_risk: float = 15.0
var vehicle_crime_risk: float = 15.0
var theft_risk: float = 15.0
var community_tension: float = 20.0
var vulnerability: float = 15.0
var police_visibility: float = 30.0
var traffic_activity: float = 20.0
var night_economy: float = 10.0
var intel_quality: float = 30.0
var incident_pressure: float = 0.0
var community_confidence: float = 60.0

var _baseline: Dictionary = {}

func _init(p_district_id: String) -> void:
	district_id = p_district_id

const VARIABLE_NAMES := [
	"asb", "violence", "burglary_risk", "vehicle_crime_risk", "theft_risk",
	"community_tension", "vulnerability", "police_visibility", "traffic_activity",
	"night_economy", "intel_quality", "incident_pressure", "community_confidence",
]

## What "normal" looks like for this district on this variable -- the
## incident probability engine weights off deviation from this, not a
## universal midpoint, since a quiet district's honest baseline (e.g.
## asb=20) is not "50% below normal".
func get_baseline_variable(variable_name: String) -> float:
	if _baseline.has(variable_name):
		return _baseline[variable_name]
	return get_variable(variable_name)

func get_variable(variable_name: String) -> float:
	match variable_name:
		"asb": return asb
		"violence": return violence
		"burglary_risk": return burglary_risk
		"vehicle_crime_risk": return vehicle_crime_risk
		"theft_risk": return theft_risk
		"community_tension": return community_tension
		"vulnerability": return vulnerability
		"police_visibility": return police_visibility
		"traffic_activity": return traffic_activity
		"night_economy": return night_economy
		"intel_quality": return intel_quality
		"incident_pressure": return incident_pressure
		"community_confidence": return community_confidence
		_:
			push_warning("DistrictState.get_variable: unknown variable %s" % variable_name)
			return 0.0

func set_variable(variable_name: String, value: float) -> void:
	var clamped: float = clampf(value, MIN_VALUE, MAX_VALUE)
	match variable_name:
		"asb": asb = clamped
		"violence": violence = clamped
		"burglary_risk": burglary_risk = clamped
		"vehicle_crime_risk": vehicle_crime_risk = clamped
		"theft_risk": theft_risk = clamped
		"community_tension": community_tension = clamped
		"vulnerability": vulnerability = clamped
		"police_visibility": police_visibility = clamped
		"traffic_activity": traffic_activity = clamped
		"night_economy": night_economy = clamped
		"intel_quality": intel_quality = clamped
		"incident_pressure": incident_pressure = clamped
		"community_confidence": community_confidence = clamped
		_:
			push_warning("DistrictState.set_variable: unknown variable %s" % variable_name)

func apply_delta(variable_name: String, delta: float) -> void:
	set_variable(variable_name, get_variable(variable_name) + delta)

## Call once after a district's starting values are configured (by the data
## factory). Explicit, not automatic in _init, so factories fully configure
## a district before "normal" is captured.
func capture_baseline() -> void:
	_baseline.clear()
	for key in VARIABLE_NAMES:
		_baseline[key] = get_variable(key)

## Local save/load (spec section 47/67).
func to_save_dict() -> Dictionary:
	var data := {}
	for key in VARIABLE_NAMES:
		data[key] = get_variable(key)
	return data

func apply_save_dict(data: Dictionary) -> void:
	for key in VARIABLE_NAMES:
		if data.has(key):
			set_variable(key, float(data[key]))

## Slow per-tick drift back toward the captured baseline, so a district
## nudged by a single patrol or incident doesn't stay pinned there forever.
func decay_toward_baseline(dt_minutes: float) -> void:
	if _baseline.is_empty():
		return
	const RATE := 0.01 # fraction of the gap to baseline closed per simulated minute
	for key in VARIABLE_NAMES:
		var current: float = get_variable(key)
		var target: float = _baseline[key]
		apply_delta(key, (target - current) * RATE * dt_minutes)

## Patrol presence raises visibility and gently suppresses opportunist crime
## risk while maintained; withdrawn the moment the unit leaves -- the
## mechanic spec section 18 depends on.
func apply_patrol_presence(dt_minutes: float, strength: float = 1.0) -> void:
	apply_delta("police_visibility", 0.6 * strength * dt_minutes)
	apply_delta("asb", -0.05 * strength * dt_minutes)
	apply_delta("theft_risk", -0.03 * strength * dt_minutes)
	apply_delta("vehicle_crime_risk", -0.03 * strength * dt_minutes)

## Called by CommunityManager when an incident resolves nearby, per spec
## section 42/52 -- REASSURE-style intents build confidence and ease
## tension, enforcement-heavy resolution can raise tension even on success.
func apply_community_effect(confidence_delta: float, tension_delta: float) -> void:
	apply_delta("community_confidence", confidence_delta)
	apply_delta("community_tension", tension_delta)
