class_name DaylightModel
extends RefCounted
## Turns "what time is it, and what season" into actual lighting values for
## the 3D town: where the sun sits, what colour it is, how strong the
## ambient fill is, and what colour the sky behind the buildings is.
##
## Stateless -- pure functions of (minute, season), so it's testable
## headlessly without a viewport, matching the engine-class shape used by
## IncidentProbabilityEngine/DispatchScorer/DutyPattern.
##
## The minute is a float, not an int, deliberately: City3DView drives this
## every frame using the clock's sub-tick fraction, so dawn actually
## sweeps rather than stepping once per simulated minute (which at 4x
## speed reads as a visible flicker between light levels).
##
## This replaces what used to be the whole day/night visual: a single flat
## blue ColorRect faded over the screen. That tinted the HUD and the map
## markers along with the town, and could never show a sunrise -- the town
## went from "day" to "blue" and back. Driving the real DirectionalLight3D
## and WorldEnvironment instead means dawn actually rakes across the
## buildings from the east and dusk warms them from the west.

## Sun colours through the day. Low sun is warm and red-shifted because it
## is travelling through more atmosphere; midday is near-white.
const SUN_DAWN := Color(1.0, 0.72, 0.45)
const SUN_NOON := Color(1.0, 0.97, 0.90)
const SUN_DUSK := Color(1.0, 0.62, 0.38)
## "Moonlight" -- not black, or night would be unreadable; a dim blue key
## light that still separates roofs from streets.
const SUN_NIGHT := Color(0.42, 0.50, 0.78)

const SUN_ENERGY_DAY := 1.15
const SUN_ENERGY_NIGHT := 0.28

const AMBIENT_DAY := Color(0.65, 0.68, 0.78)
const AMBIENT_NIGHT := Color(0.16, 0.19, 0.34)
const AMBIENT_ENERGY_DAY := 0.60
const AMBIENT_ENERGY_NIGHT := 0.30

const SKY_DAY := Color(0.55, 0.75, 0.95)
const SKY_DAWN := Color(0.85, 0.62, 0.52)
const SKY_DUSK := Color(0.75, 0.48, 0.42)
const SKY_NIGHT := Color(0.04, 0.05, 0.13)

## Weather desaturates and darkens the sky rather than adding particles --
## the spec's "do not build detailed weather simulation" line still holds.
const SKY_OVERCAST := Color(0.48, 0.52, 0.58)
const SKY_FOG := Color(0.62, 0.64, 0.66)
const SKY_SNOW := Color(0.72, 0.75, 0.82)

## 0.0 = full night, 1.0 = full day, with dawn and dusk ramping between
## over the season's twilight length. Everything else keys off this.
static func daylight_factor(minute_of_day: float, season: GameEnums.Season) -> float:
	var sunrise: float = float(SeasonCycle.sunrise_minute(season))
	var sunset: float = float(SeasonCycle.sunset_minute(season))
	var twilight: float = float(SeasonCycle.twilight_minutes(season))
	if minute_of_day >= sunrise + twilight and minute_of_day <= sunset - twilight:
		return 1.0
	if minute_of_day >= sunrise and minute_of_day < sunrise + twilight:
		return (minute_of_day - sunrise) / twilight
	if minute_of_day > sunset - twilight and minute_of_day <= sunset:
		return (sunset - minute_of_day) / twilight
	return 0.0

## True while the sun is up at all -- used for the warm-vs-cool decision
## and by callers that just want "is it dark out".
static func is_daylight(minute_of_day: float, season: GameEnums.Season) -> bool:
	return daylight_factor(minute_of_day, season) > 0.0

## Sun rotation. X is elevation (-90 straight down at noon, near 0 on the
## horizon at sunrise/sunset); Y swings the azimuth from east through
## south to west across the day, so shadowless as the scene is, the lit
## faces of the buildings change side between morning and evening.
static func sun_rotation_degrees(minute_of_day: float, season: GameEnums.Season) -> Vector3:
	var sunrise: float = float(SeasonCycle.sunrise_minute(season))
	var sunset: float = float(SeasonCycle.sunset_minute(season))
	var progress: float = 0.5
	if sunset > sunrise:
		progress = clampf((minute_of_day - sunrise) / (sunset - sunrise), 0.0, 1.0)
	# Elevation peaks mid-arc. Capped below vertical so the town never
	# renders flat-lit from directly overhead.
	var elevation: float = lerpf(12.0, 62.0, sin(progress * PI))
	var azimuth: float = lerpf(-75.0, 5.0, progress)
	return Vector3(-elevation, azimuth, 0.0)

static func sun_color(minute_of_day: float, season: GameEnums.Season) -> Color:
	var factor: float = daylight_factor(minute_of_day, season)
	if factor <= 0.0:
		return SUN_NIGHT
	var midpoint: float = float(SeasonCycle.sunrise_minute(season) + SeasonCycle.sunset_minute(season)) * 0.5
	var horizon_tint: Color = SUN_DAWN if minute_of_day < midpoint else SUN_DUSK
	# Warm at the horizon, white overhead -- factor is already 0 at the
	# horizon and 1 in the middle of the day.
	return horizon_tint.lerp(SUN_NOON, factor)

static func sun_energy(minute_of_day: float, season: GameEnums.Season) -> float:
	return lerpf(SUN_ENERGY_NIGHT, SUN_ENERGY_DAY, daylight_factor(minute_of_day, season))

static func ambient_color(minute_of_day: float, season: GameEnums.Season) -> Color:
	return AMBIENT_NIGHT.lerp(AMBIENT_DAY, daylight_factor(minute_of_day, season))

static func ambient_energy(minute_of_day: float, season: GameEnums.Season) -> float:
	return lerpf(AMBIENT_ENERGY_NIGHT, AMBIENT_ENERGY_DAY, daylight_factor(minute_of_day, season))

static func sky_color(minute_of_day: float, season: GameEnums.Season, weather: GameEnums.WeatherType = GameEnums.WeatherType.CLEAR) -> Color:
	var factor: float = daylight_factor(minute_of_day, season)
	var midpoint: float = float(SeasonCycle.sunrise_minute(season) + SeasonCycle.sunset_minute(season)) * 0.5
	var horizon: Color = SKY_DAWN if minute_of_day < midpoint else SKY_DUSK
	var clear_sky: Color = SKY_NIGHT
	if factor > 0.0:
		# Horizon colour dominates during twilight, true sky by mid-morning.
		clear_sky = horizon.lerp(SKY_DAY, factor)
	var overcast: Color = _weather_sky(weather)
	if overcast == Color.TRANSPARENT:
		return clear_sky
	# Weather only washes out the daytime sky; an overcast night is still
	# a dark night, not a grey one.
	return clear_sky.lerp(overcast, 0.75 * factor)

static func _weather_sky(weather: GameEnums.WeatherType) -> Color:
	match weather:
		GameEnums.WeatherType.RAIN: return SKY_OVERCAST
		GameEnums.WeatherType.FOG: return SKY_FOG
		GameEnums.WeatherType.SNOW: return SKY_SNOW
	return Color.TRANSPARENT
