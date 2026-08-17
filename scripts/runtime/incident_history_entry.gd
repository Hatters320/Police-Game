class_name IncidentHistoryEntry
extends RefCounted
## Lightweight, effectively-immutable snapshot appended to
## IncidentManager.history once an incident reaches OUTCOME. Deliberately
## not a full Incident -- this list grows for the life of the save file.
## See docs/ARCHITECTURE.md's cross-shift incident history decision.

var incident_id: String
var type_id: String
var district_id: String
var location_id: String
var priority: int
var escalation_level: int
var created_at_minute: int
var first_on_scene_minute: int = -1
var resolved_at_minute: int
var outcome_id: String

func to_save_dict() -> Dictionary:
	return {
		"incident_id": incident_id, "type_id": type_id, "district_id": district_id, "location_id": location_id,
		"priority": priority, "escalation_level": escalation_level, "created_at_minute": created_at_minute,
		"first_on_scene_minute": first_on_scene_minute, "resolved_at_minute": resolved_at_minute, "outcome_id": outcome_id,
	}

static func from_save_dict(data: Dictionary) -> IncidentHistoryEntry:
	var entry := IncidentHistoryEntry.new()
	entry.incident_id = String(data["incident_id"])
	entry.type_id = String(data["type_id"])
	entry.district_id = String(data["district_id"])
	entry.location_id = String(data["location_id"])
	entry.priority = int(data["priority"])
	entry.escalation_level = int(data["escalation_level"])
	entry.created_at_minute = int(data["created_at_minute"])
	entry.first_on_scene_minute = int(data.get("first_on_scene_minute", -1))
	entry.resolved_at_minute = int(data["resolved_at_minute"])
	entry.outcome_id = String(data["outcome_id"])
	return entry
