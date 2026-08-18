class_name WeatherManager
extends RefCounted
## Weather (spec section 34): "MVP may include: clear, rain... do not
## build detailed weather simulation." Rolled once per shift (not
## continuously varying) and kept deliberately shallow -- it modulates the
## incident types that actually model outdoor behaviour (IncidentTypeDefinition
## .rain_multiplier) and unit travel speed, rather than touching district
## state directly, which would fight DistrictState's baseline-decay system
## for no real gameplay payoff.

const RAIN_CHANCE := 0.3
## Applied to ResourceManager.BASE_SPEED_UNITS_PER_MIN while it's raining
## (spec section 34's "traffic" influence) -- a flat slowdown stands in for
## wet-road congestion without simulating actual traffic.
const RAIN_TRAVEL_SPEED_MULTIPLIER := 0.85

var current_weather: GameEnums.WeatherType = GameEnums.WeatherType.CLEAR

func setup_shift(rng: RandomNumberGenerator) -> void:
	current_weather = GameEnums.WeatherType.RAIN if rng.randf() < RAIN_CHANCE else GameEnums.WeatherType.CLEAR

func is_raining() -> bool:
	return current_weather == GameEnums.WeatherType.RAIN

func weather_text() -> String:
	return "Rain" if is_raining() else "Clear"
