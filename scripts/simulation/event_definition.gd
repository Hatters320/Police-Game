class_name EventDefinition
extends Resource
## A scheduled event (spec section 32) -- e.g. the Westford United football
## match. Modifies incident probability and district variables for its
## affected district(s) while active, rather than just spawning one
## incident.

@export var id: String
@export var display_name: String
@export var start_minute: int # minutes since simulated day start, 0-1439
@export var duration_minutes: int
@export var affected_district_ids: Array[String] = []
@export var incident_weight_multiplier: float = 1.5
## DistrictState variable name -> flat delta, applied once when the event
## starts and reversed once it ends.
@export var district_variable_deltas: Dictionary = {}

func affects_district(district_id: String) -> bool:
	return affected_district_ids.has(district_id)

func is_active_at(minute_of_day: int) -> bool:
	return minute_of_day >= start_minute and minute_of_day < start_minute + duration_minutes
