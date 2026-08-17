class_name ShiftState
extends RefCounted
## Current shift's plan and clock position (spec section 15/16).

var shift_number: int = 1
var shift_start_minute: int = 0
var shift_end_minute: int = 0
var current_minute: int = 0

var priorities: Array[String] = [] # up to 3 -- free-form tags chosen at briefing
var speed_multiplier: float = 1.0
var paused: bool = false
var reserve_target: int = 0

var briefing_confirmed: bool = false

func is_over() -> bool:
	return current_minute >= shift_end_minute

func minutes_remaining() -> int:
	return maxi(shift_end_minute - current_minute, 0)

func time_of_day_string() -> String:
	var minute_of_day: int = current_minute % (24 * 60)
	var hour: int = minute_of_day / 60
	var minute: int = minute_of_day % 60
	return "%02d:%02d" % [hour, minute]
