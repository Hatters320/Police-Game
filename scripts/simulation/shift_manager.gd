class_name ShiftManager
extends RefCounted
## Owns the current ShiftState and the start/end-of-shift lifecycle (spec
## section 15/16/45). Full 5-dimension debrief scoring is Milestone 5 --
## this exposes the raw shift clock/state a debug harness or briefing UI
## can read.

signal shift_started
signal shift_ended

var shift_state: ShiftState = ShiftState.new()

## Sets up a new shift's clock window but leaves it unconfirmed -- the
## Simulation autoload only ticks once briefing_confirmed is true (see
## docs/ARCHITECTURE.md), so the player can spend as long as they want on
## the briefing screen (which needs units already formed to task them,
## hence this happening before confirmation, not after).
func prepare_shift(shift_number: int, start_minute: int, duration_minutes: int) -> void:
	shift_state = ShiftState.new()
	shift_state.shift_number = shift_number
	shift_state.shift_start_minute = start_minute
	shift_state.shift_end_minute = start_minute + duration_minutes
	shift_state.current_minute = start_minute
	shift_state.briefing_confirmed = false

func confirm_briefing(priorities: Array[String], reserve_target: int) -> void:
	shift_state.priorities = priorities
	shift_state.reserve_target = reserve_target
	shift_state.briefing_confirmed = true
	shift_started.emit()

## Convenience for callers that don't need a real briefing pause (the
## headless harness) -- prepares and confirms in one call.
func start_shift(shift_number: int, start_minute: int, duration_minutes: int, priorities: Array[String], reserve_target: int) -> void:
	prepare_shift(shift_number, start_minute, duration_minutes)
	confirm_briefing(priorities, reserve_target)

func advance(ctx: SimulationContext) -> void:
	shift_state.current_minute += ctx.dt_minutes

func is_over() -> bool:
	return shift_state.is_over()

func end_shift() -> void:
	shift_ended.emit()
