class_name KpiTracker
extends RefCounted
## Live, shift-scoped tracking of response-time performance against
## target, by priority band -- feature request: "Percentage of Priority 1
## incidents attended within target response times (15 minutes), Priority
## 2 (60 mins), Priority 3 (3 hours)". Recorded the moment a unit reaches
## an incident (IncidentManager.mark_unit_arrived), so the live KPI
## dashboard reflects the shift in progress rather than only appearing at
## debrief. Reset each shift by SimulationCore.prepare_shift, the same
## lifecycle SpecialistManager/WeatherManager's setup_shift already uses.

## Simulated minutes -- this codebase already expresses every duration
## (IncidentTypeDefinition.state_durations, etc.) in simulated minutes, so
## the spec's real-world targets map directly with no conversion. P1-P3
## are the bands the feature request names explicitly; P4/P5 get sensible
## defaults so the aggregate is complete.
const TARGET_MINUTES := {1: 15.0, 2: 60.0, 3: 180.0, 4: 360.0, 5: 720.0}

const HISTORY_LIMIT := 20

var _attended: Dictionary = {} # priority(int) -> count attended
var _within_target: Dictionary = {} # priority(int) -> count within target
var history: Array[Dictionary] = [] # {priority, delay_minutes, within_target}, newest last

func reset_shift() -> void:
	_attended.clear()
	_within_target.clear()
	history.clear()

func record_arrival(priority: int, delay_minutes: float) -> void:
	var target: float = TARGET_MINUTES.get(priority, 720.0)
	var within: bool = delay_minutes <= target
	_attended[priority] = _attended.get(priority, 0) + 1
	if within:
		_within_target[priority] = _within_target.get(priority, 0) + 1
	history.append({"priority": priority, "delay_minutes": delay_minutes, "within_target": within})
	if history.size() > HISTORY_LIMIT:
		history.pop_front()

## Percentage attended within target for one priority band, or -1.0 if
## nothing of that priority has been attended yet this shift -- the caller
## decides how to render "no data" (see KpiPanelView).
func attainment_pct(priority: int) -> float:
	var attended: int = _attended.get(priority, 0)
	if attended == 0:
		return -1.0
	return 100.0 * float(_within_target.get(priority, 0)) / float(attended)

func attended_count(priority: int) -> int:
	return _attended.get(priority, 0)

func target_minutes(priority: int) -> float:
	return TARGET_MINUTES.get(priority, 720.0)

## Most recent entries of one priority, newest first, capped to `limit`.
func recent_for_priority(priority: int, limit: int = 10) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(history.size() - 1, -1, -1):
		var entry: Dictionary = history[i]
		if int(entry["priority"]) == priority:
			out.append(entry)
			if out.size() >= limit:
				break
	return out
