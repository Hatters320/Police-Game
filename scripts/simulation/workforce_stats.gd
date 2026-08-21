class_name WorkforceStats
extends RefCounted
## Shared fatigue/morale averaging, used by both the end-of-shift
## DebriefScorer and the live KPI dashboard so the two numbers are always
## computed the same way rather than two formulas quietly drifting apart.

static func average_fatigue_morale(officers: Array) -> Dictionary:
	var fatigue_sum := 0.0
	var morale_sum := 0.0
	var count := 0
	for officer: Officer in officers:
		fatigue_sum += officer.fatigue
		morale_sum += officer.morale
		count += 1
	var avg_fatigue: float = fatigue_sum / count if count > 0 else 0.0
	var avg_morale: float = morale_sum / count if count > 0 else 80.0
	return {"avg_fatigue": avg_fatigue, "avg_morale": avg_morale}
