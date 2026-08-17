class_name EventManager
extends RefCounted
## Tracks which EventDefinitions are currently active and applies/reverts
## their district-variable effects at start/end -- spec section 32.

signal event_started(event_id: String)
signal event_ended(event_id: String)

var _all_events: Array[EventDefinition] = []
var _active_event_ids: Dictionary = {} # event_id -> true

func setup(events: Array[EventDefinition]) -> void:
	_all_events = events
	_active_event_ids.clear()

func active_events() -> Array[EventDefinition]:
	var result: Array[EventDefinition] = []
	for event in _all_events:
		if _active_event_ids.has(event.id):
			result.append(event)
	return result

## Every scheduled event regardless of whether it's currently active --
## the briefing screen needs this to show "here's what's planned today"
## before any of them have started.
func all_events() -> Array[EventDefinition]:
	return _all_events

func tick(ctx: SimulationContext) -> void:
	var minute_of_day: int = ctx.current_minute % (24 * 60)
	for event in _all_events:
		var should_be_active: bool = event.is_active_at(minute_of_day)
		var is_active: bool = _active_event_ids.has(event.id)
		if should_be_active and not is_active:
			_active_event_ids[event.id] = true
			_apply_deltas(event, ctx.district_manager, 1.0)
			event_started.emit(event.id)
		elif is_active and not should_be_active:
			_active_event_ids.erase(event.id)
			_apply_deltas(event, ctx.district_manager, -1.0)
			event_ended.emit(event.id)

func _apply_deltas(event: EventDefinition, district_manager: DistrictManager, sign: float) -> void:
	for district_id in event.affected_district_ids:
		var district: DistrictState = district_manager.get_state(district_id)
		if district == null:
			continue
		for variable_name in event.district_variable_deltas.keys():
			district.apply_delta(variable_name, event.district_variable_deltas[variable_name] * sign)
