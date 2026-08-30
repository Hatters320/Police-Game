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

## Time-of-day band name -> rate multiplier, e.g.
## {"business": 1.6, "evening": 1.0, "overnight": 0.3} for a type that is
## overwhelmingly a working-hours call. Bands come from
## IncidentProbabilityEngine._time_band; an unlisted band multiplies by
## 1.0, so a type with no entries is simply flat across the day.
##
## Replaces the old single `night_weighted` bool, which could only express
## "busier after 21:00" and so couldn't distinguish a shoplifting (a
## daytime call) from a workplace dispute (daytime) from a burglary
## (overnight) -- spec section 7/33.
@export var time_band_multipliers: Dictionary = {}

## GameEnums.Season -> rate multiplier, same shape as
## time_band_multipliers and read the same way (an unlisted season
## multiplies by 1.0). Only populated where there is a real seasonal
## reason -- dark winter evenings for burglary, summer streets for
## disorder -- rather than inventing a number per type per season.
@export var season_multipliers: Dictionary = {}

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

## Which of Officer.skills this incident type most rewards in the
## responding crew -- e.g. a domestic hinges on communication, a burglary
## on investigation. Used by DispatchScorer to rank candidate units by
## suitability, not just proximity.
@export var primary_skill: String = "response"

func state_duration(state: GameEnums.IncidentState, fallback: float = 10.0) -> float:
	return state_durations.get(state, fallback)
