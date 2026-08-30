class_name WeatherManager
extends RefCounted
## Weather (spec section 34): "MVP may include: clear, rain... do not
## build detailed weather simulation." Rolled once per shift (not
## continuously varying) and kept deliberately shallow -- it modulates the
## incident types that actually model outdoor behaviour (IncidentTypeDefinition
## .rain_multiplier) and unit travel speed, rather than touching district
## state directly, which would fight DistrictState's baseline-decay system
## for no real gameplay payoff.

## Chance of each weather type by season -- the seasonal system's main
## teeth. Weights per season, in WeatherType order (clear, rain, fog,
## snow); they sum to 1.0. Summer is mostly dry, autumn is the foggiest,
## and snow only exists in winter.
const SEASON_WEATHER_WEIGHTS := {
	GameEnums.Season.SPRING: [0.62, 0.32, 0.06, 0.0],
	GameEnums.Season.SUMMER: [0.80, 0.18, 0.02, 0.0],
	GameEnums.Season.AUTUMN: [0.48, 0.36, 0.16, 0.0],
	GameEnums.Season.WINTER: [0.44, 0.28, 0.13, 0.15],
}

## Travel-speed multiplier per weather. Snow bites hardest; fog slows
## officers down more than rain does, because visibility rather than grip
## is what limits a response drive.
const TRAVEL_SPEED_MULTIPLIER := {
	GameEnums.WeatherType.CLEAR: 1.0,
	GameEnums.WeatherType.RAIN: 0.85,
	GameEnums.WeatherType.FOG: 0.78,
	GameEnums.WeatherType.SNOW: 0.65,
}

## How strongly each weather suppresses the outdoor incident types --
## scales IncidentTypeDefinition.rain_multiplier rather than needing a
## separate multiplier per type per weather. 0 = no effect, 1 = the full
## effect that type already declares for rain.
const OUTDOOR_SUPPRESSION_STRENGTH := {
	GameEnums.WeatherType.CLEAR: 0.0,
	GameEnums.WeatherType.RAIN: 1.0,
	GameEnums.WeatherType.FOG: 0.5,
	GameEnums.WeatherType.SNOW: 1.3,
}

var current_weather: GameEnums.WeatherType = GameEnums.WeatherType.CLEAR

func setup_shift(rng: RandomNumberGenerator, season: GameEnums.Season = GameEnums.Season.SPRING) -> void:
	var weights: Array = SEASON_WEATHER_WEIGHTS.get(season, SEASON_WEATHER_WEIGHTS[GameEnums.Season.SPRING])
	var roll: float = rng.randf()
	var cumulative := 0.0
	for i in range(weights.size()):
		cumulative += float(weights[i])
		if roll < cumulative:
			current_weather = i as GameEnums.WeatherType
			return
	current_weather = GameEnums.WeatherType.CLEAR

func is_raining() -> bool:
	return current_weather == GameEnums.WeatherType.RAIN

## True for any weather the player should visibly react to -- used by the
## HUD to decide whether to colour the weather chip.
func is_adverse() -> bool:
	return current_weather != GameEnums.WeatherType.CLEAR

func travel_speed_multiplier() -> float:
	return float(TRAVEL_SPEED_MULTIPLIER.get(current_weather, 1.0))

func outdoor_suppression_strength() -> float:
	return float(OUTDOOR_SUPPRESSION_STRENGTH.get(current_weather, 0.0))

func weather_text() -> String:
	match current_weather:
		GameEnums.WeatherType.RAIN: return "Rain"
		GameEnums.WeatherType.FOG: return "Fog"
		GameEnums.WeatherType.SNOW: return "Snow"
	return "Clear"
