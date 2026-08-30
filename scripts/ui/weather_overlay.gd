class_name WeatherOverlay
extends CanvasLayer
## Visual half of the weather system (spec section 34) -- a single
## semi-transparent wash per weather type, deliberately not a particle/rain
## streak simulation per spec's "do not build detailed weather simulation."
## Weather is fixed for the whole shift (WeatherManager), so this doesn't
## tick continuously like DayNightOverlay -- refresh() is called explicitly
## once per shift, right after prepare_shift rolls it.
##
## Each type gets its own colour and strength rather than one shared grey:
## rain is a cold blue-grey, fog a flat pale wash (the strongest of the
## three, since fog is the one that genuinely hides the town), snow a
## bright near-white.

const TINTS := {
	GameEnums.WeatherType.RAIN: Color(0.40, 0.46, 0.55, 0.16),
	GameEnums.WeatherType.FOG: Color(0.72, 0.74, 0.78, 0.26),
	GameEnums.WeatherType.SNOW: Color(0.86, 0.90, 0.96, 0.18),
}

var _tint: ColorRect

func _ready() -> void:
	layer = 1 # same environmental layer as DayNightOverlay, added after it so weather sits on top
	_tint = ColorRect.new()
	_tint.color = Color(0.4, 0.46, 0.55, 0.0)
	_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tint)
	refresh()

func refresh() -> void:
	var weather: GameEnums.WeatherType = Simulation.core.weather_manager.current_weather
	_tint.color = TINTS.get(weather, Color(0.4, 0.46, 0.55, 0.0))
