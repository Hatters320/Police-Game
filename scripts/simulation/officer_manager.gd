class_name OfficerManager
extends RefCounted
## Owns every officer for the current shift (spec section 8/13). Rebuilt at
## each shift's briefing from the staffing model. Fatigue accrual policy
## lives in FatigueManager, not here -- this only owns "who are my officers
## and are they available."

var officers: Dictionary = {} # officer_id -> Officer

func set_roster(roster: Array[Officer]) -> void:
	officers.clear()
	for officer in roster:
		officers[officer.id] = officer

func get_officer(officer_id: String) -> Officer:
	return officers.get(officer_id)

func available_officers() -> Array[Officer]:
	var result: Array[Officer] = []
	for officer: Officer in officers.values():
		if officer.is_available():
			result.append(officer)
	return result

func count_by_status(status: GameEnums.OfficerStatus) -> int:
	var count := 0
	for officer: Officer in officers.values():
		if officer.status == status:
			count += 1
	return count
