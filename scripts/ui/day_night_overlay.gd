class_name DayNightOverlay
extends CanvasLayer
## Screen-space companion to the real day/night lighting (spec section 33).
##
## This used to *be* the day/night cycle: one flat blue ColorRect faded to
## 42% alpha over the whole screen. That had two problems -- it dimmed the
## HUD and the incident markers along with the town, and it could never
## show a sunrise, only "day" or "blue". The lighting proper now lives in
## DaylightModel, driving City3DView's real DirectionalLight3D and
## WorldEnvironment, so dawn actually rakes across the buildings.
##
## What survives here is a much lighter tint that does one job the 3D
## lighting can't: cooling the *2D* layer (roads, markers, labels drawn
## over the town) at night so it doesn't float over a dark city looking
## lit from nowhere. Hence the alpha ceiling is now a fifth of what it was.
##
## The gameplay half -- how the mix of incident types shifts across the day
## and the year -- lives in IncidentTypeDefinition.time_band_multipliers /
## season_multipliers and IncidentProbabilityEngine.

const NIGHT_ALPHA := 0.12
const TINT_COLOR := Color(0.05, 0.05, 0.2)

var _tint: ColorRect

func _ready() -> void:
	layer = 1 # above the map (no CanvasLayer, implicit layer 0), below the HUD (layer 2)
	_tint = ColorRect.new()
	_tint.color = Color(TINT_COLOR, 0.0)
	_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tint)
	set_process(true)

## Tracks the same daylight curve the 3D lighting uses, so the two never
## disagree about when dusk is -- and so the tint follows the *season*:
## a 17:00 winter shift is already dark, a 17:00 summer one is not. Driven
## per frame off the same fractional minute the lighting uses, so the two
## fade together rather than one stepping while the other sweeps.
func _process(_delta: float) -> void:
	var clock: GameClock = Simulation.core.game_clock
	var minute_of_day: float = fmod(float(clock.total_minutes) + clock.sub_tick_fraction(), 24.0 * 60.0)
	var season: GameEnums.Season = Simulation.core.current_season()
	var darkness: float = 1.0 - DaylightModel.daylight_factor(minute_of_day, season)
	_tint.color = Color(TINT_COLOR, NIGHT_ALPHA * darkness)
