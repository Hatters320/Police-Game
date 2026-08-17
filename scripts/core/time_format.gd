class_name TimeFormat
extends RefCounted
## Shared "absolute simulated minute -> HH:MM" formatting, so this isn't
## reimplemented slightly differently in every UI script that needs it.

static func clock(total_minute: int) -> String:
	var minute_of_day: int = total_minute % (24 * 60)
	return "%02d:%02d" % [minute_of_day / 60, minute_of_day % 60]
