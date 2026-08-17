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
var resolved_at_minute: int
var outcome_id: String
