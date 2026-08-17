class_name SaveManager
extends RefCounted
## Local save/load of persistent town state (spec section 47/67):
## district variables, still-open (carried-over) incidents, incident
## history, and intelligence. No online accounts, no cloud save -- a
## single JSON file in Godot's per-user data directory.
##
## Officers and units are deliberately never saved: they're rebuilt fresh
## from the staffing model every shift regardless (spec section 8), so
## nothing about them persists even across a shift boundary within one
## running session, let alone across a save/reload.

const SAVE_PATH := "user://westford_save.json"
const SAVE_VERSION := 1

static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

static func save(core: SimulationCore, next_shift_number: int) -> void:
	var districts := {}
	for district_id in core.district_manager.districts.keys():
		var district: DistrictState = core.district_manager.districts[district_id]
		districts[district_id] = district.to_save_dict()

	var active_incidents := []
	for incident: Incident in core.incident_manager.active_incidents.values():
		active_incidents.append(incident.to_save_dict())

	var history := []
	for entry: IncidentHistoryEntry in core.incident_manager.history:
		history.append(entry.to_save_dict())

	var data := {
		"version": SAVE_VERSION,
		"next_shift_number": next_shift_number,
		"districts": districts,
		"active_incidents": active_incidents,
		"history": history,
		"intelligence_items": core.intelligence_manager.items,
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: could not open save file for writing (%s)" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(data))
	file.close()

## Applies a save file's persistent state onto an already-initialize()'d
## SimulationCore (district_manager must already hold baseline district
## objects built from the world -- this only overwrites their values, it
## doesn't create new ones). Returns the shift number the next briefing
## should start at, or 1 if there's no save (a fresh game).
static func load_into(core: SimulationCore) -> int:
	if not has_save():
		return 1

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("SaveManager: could not open save file for reading (%s)" % SAVE_PATH)
		return 1
	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("SaveManager: save file is not valid JSON, ignoring it")
		return 1
	var data: Dictionary = parsed

	var districts: Dictionary = data.get("districts", {})
	for district_id in districts.keys():
		var district: DistrictState = core.district_manager.get_state(district_id)
		if district:
			district.apply_save_dict(districts[district_id])
			district.capture_baseline() # loaded values are the new "normal" to decay toward

	core.incident_manager.active_incidents.clear()
	var max_incident_number := 0
	for entry_data: Dictionary in data.get("active_incidents", []):
		var incident: Incident = Incident.from_save_dict(entry_data)
		core.incident_manager.active_incidents[incident.id] = incident
		max_incident_number = maxi(max_incident_number, _trailing_number(incident.id))

	core.incident_manager.history.clear()
	for entry_data: Dictionary in data.get("history", []):
		var entry: IncidentHistoryEntry = IncidentHistoryEntry.from_save_dict(entry_data)
		core.incident_manager.history.append(entry)
		max_incident_number = maxi(max_incident_number, _trailing_number(entry.incident_id))
	core.incident_manager.ensure_next_incident_number_above(max_incident_number + 1)

	core.intelligence_manager.items.clear()
	for item: Dictionary in data.get("intelligence_items", []):
		core.intelligence_manager.items.append(item)

	return int(data.get("next_shift_number", 1))

## "incident_7" -> 7. Used to keep newly generated incident ids from
## colliding with ones restored from the save.
static func _trailing_number(id: String) -> int:
	var parts: PackedStringArray = id.split("_")
	if parts.size() < 2:
		return 0
	return int(parts[parts.size() - 1])
