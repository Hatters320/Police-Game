class_name DayNightOverlay
extends CanvasLayer
## Visual half of the day/night cycle (spec section 33). The gameplay half
## -- night-time incident weighting -- has existed since Milestone 1 via
## IncidentTypeDefinition.night_weighted; this is a single full-screen
## tint whose alpha follows time of day. No per-building lighting, since
## there's no art to light yet -- see MapView's header comment on where
## this build's visuals stand.

const NIGHT_ALPHA := 0.42
const TINT_COLOR := Color(0.05, 0.05, 0.2)

var _tint: ColorRect

func _ready() -> void:
	layer = 1 # above the map (no CanvasLayer, implicit layer 0), below the HUD (layer 2)
	_tint = ColorRect.new()
	_tint.color = Color(TINT_COLOR, 0.0)
	_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tint)
	Simulation.core.tick_completed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	var minute_of_day: int = Simulation.core.game_clock.total_minutes % (24 * 60)
	_tint.color = Color(TINT_COLOR, _alpha_for_minute(minute_of_day))

## 07:00-18:00 full daylight, 18:00-20:00 dusk fading in, 20:00-05:00
## night at full tint, 05:00-07:00 dawn fading out.
func _alpha_for_minute(m: int) -> float:
	if m >= 420 and m < 1080:
		return 0.0
	if m >= 1080 and m < 1200:
		return lerpf(0.0, NIGHT_ALPHA, float(m - 1080) / 120.0)
	if m >= 1200 or m < 300:
		return NIGHT_ALPHA
	return lerpf(NIGHT_ALPHA, 0.0, float(m - 300) / 120.0)
