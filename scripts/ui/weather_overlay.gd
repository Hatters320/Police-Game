class_name WeatherOverlay
extends CanvasLayer
## Visual half of the weather system (spec section 34) -- a single
## semi-transparent grey-blue wash shown only while it's raining, deliberately
## not a particle/rain-streak simulation per spec's "do not build detailed
## weather simulation." Weather is fixed for the whole shift (WeatherManager),
## so this doesn't tick continuously like DayNightOverlay -- refresh() is
## called explicitly once per shift, right after prepare_shift rolls it.

const RAIN_ALPHA := 0.16
const TINT_COLOR := Color(0.4, 0.46, 0.55)

var _tint: ColorRect

func _ready() -> void:
	layer = 1 # same environmental layer as DayNightOverlay, added after it so rain sits on top
	_tint = ColorRect.new()
	_tint.color = Color(TINT_COLOR, 0.0)
	_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tint)
	refresh()

func refresh() -> void:
	var raining: bool = Simulation.core.weather_manager.is_raining()
	_tint.color = Color(TINT_COLOR, RAIN_ALPHA if raining else 0.0)
