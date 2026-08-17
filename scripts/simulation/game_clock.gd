class_name GameClock
extends RefCounted
## Converts real elapsed time into simulated minutes via a fixed-timestep
## accumulator, decoupled from frame rate -- docs/ARCHITECTURE.md section 8.
## 1 tick = TICK_MINUTES simulated minutes, fired once per
## REAL_SECONDS_PER_TICK real seconds at 1x speed (so a 12h/720min shift
## plays in 12 real minutes at 1x, 3 at 4x).

signal minute_advanced(dt_minutes: int)

const REAL_SECONDS_PER_TICK := 1.0
const TICK_MINUTES := 1

var total_minutes: int = 0
var speed_multiplier: float = 1.0
var paused: bool = false

var _accumulator: float = 0.0

## Called from _process(delta) with real elapsed seconds. Returns the
## number of ticks that should fire (normally 0 or 1; more if a frame
## hitched badly) -- does NOT itself advance total_minutes, so the caller
## (SimulationCore) can interleave advance_one_tick() with running the
## simulation one tick at a time. That matters when more than one tick
## fires in a single call: each tick's clock advance must happen
## immediately before that tick's simulation step, not all at once before
## any of them, or every tick would see the same (final) current_minute.
func advance_real_time(delta_seconds: float) -> int:
	if paused or speed_multiplier <= 0.0:
		return 0
	_accumulator += delta_seconds * speed_multiplier
	var ticks_fired := 0
	while _accumulator >= REAL_SECONDS_PER_TICK:
		_accumulator -= REAL_SECONDS_PER_TICK
		ticks_fired += 1
	return ticks_fired

func advance_one_tick() -> void:
	total_minutes += TICK_MINUTES
	minute_advanced.emit(TICK_MINUTES)

## For the headless debug harness / fast-forward: advances sim time
## directly, bypassing the real-time accumulator.
func force_advance_minutes(minutes: int) -> void:
	total_minutes += minutes
	minute_advanced.emit(minutes)

## Fraction of the way through the current tick, for Presentation-side
## render interpolation (docs/ARCHITECTURE.md section 5/7).
func sub_tick_fraction() -> float:
	return clampf(_accumulator / REAL_SECONDS_PER_TICK, 0.0, 1.0)
