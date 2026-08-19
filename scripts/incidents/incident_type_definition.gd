class_name IncidentTypeDefinition
extends Resource
## Static definition for one incident type (spec section 21). Adding a new
## incident type should mean a new instance of this (data), never new code
## -- spec section 59.

@export var id: String
@export var display_name: String

## Priority-input baselines (spec section 24); the probability engine adds
## random variance per instance. See IncidentProbabilityEngine.roll_priority_inputs.
@export var base_threat: float = 20.0
@export var base_harm: float = 20.0
@export var base_vulnerability: float = 10.0
@export var base_immediacy: float = 20.0
@export var base_opportunity: float = 10.0

## Expected incidents of this type per simulated hour, town-wide, before any
## district/time/event modifiers.
@export var base_rate_per_hour: float = 0.05

## DistrictState variable name (e.g. "night_economy") -> multiplier. Points
## above this district's own captured baseline scale the rate up by this
## factor (points below scale it down); see
## IncidentProbabilityEngine._weight_for and DistrictState.get_baseline_variable.
@export var district_weight_factors: Dictionary = {}

## True for types whose rate should rise during evening/night hours (spec
## section 7/33 -- night-time economy disorder).
@export var night_weighted: bool = false

## Multiplier applied while it's raining (spec section 34: "weather can
## influence... outdoor ASB"). 1.0 (no effect) for types the MVP's weather
## system doesn't model -- see WeatherManager.
@export var rain_multiplier: float = 1.0

## Array of Dictionaries: {id: String, display_name: String, base_weight:
## float, favoured_skill: String, favoured_intent: GameEnums.CommandIntent}.
## See IncidentOutcomeEngine.
@export var possible_outcomes: Array[Dictionary] = []

## GameEnums.IncidentState (int) -> simulated minutes typically spent in
## that state once reached. See IncidentManager.
@export var state_durations: Dictionary = {}

## Escalation risk added per simulated minute an incident spends unassigned
## past its priority's expected response window -- see IncidentManager.
@export var escalation_risk_per_minute: float = 0.01

@export var known_fact_templates: Array[String] = []
@export var unknown_fact_templates: Array[String] = []

## Which REQUEST SPECIALIST type (GameEnums.SpecialistType), if any, best
## fits this incident type -- surfaced in IncidentPanelView as a
## "recommended for this incident" tag so the player has a concrete steer
## instead of guessing cold between Traffic/Dog/Firearms. -1 = no
## particular recommendation (most types: a general response is fine).
@export var recommended_specialist: int = -1

func state_duration(state: GameEnums.IncidentState, fallback: float = 10.0) -> float:
	return state_durations.get(state, fallback)
