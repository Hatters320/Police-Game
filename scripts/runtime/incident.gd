class_name Incident
extends RefCounted
## A live incident (spec section 22-30). RefCounted, never Resource.
## Persists across shifts if still open at shift-end (docs/ARCHITECTURE.md).

var id: String
var type_id: String
var district_id: String
var location_id: String

var priority: int = 4 # 1 = critical .. 5 = non-urgent (spec section 24)
var threat: float = 0.0
var harm: float = 0.0
var vulnerability: float = 0.0
var immediacy: float = 0.0
var opportunity: float = 0.0

var state: GameEnums.IncidentState = GameEnums.IncidentState.CREATED
## Orthogonal to state -- see docs/ARCHITECTURE.md section 4/6 for why
## escalation isn't modelled as a state-machine node.
var escalation_level: int = 0
var time_in_current_state: float = 0.0 # simulated minutes

var known_facts: Array[String] = []
var unknown_facts: Array[String] = []

var assigned_unit_ids: Array[String] = []
var command_intent: GameEnums.CommandIntent = GameEnums.CommandIntent.NONE

var created_at_minute: int = 0
var first_on_scene_minute: int = -1
var resolved_at_minute: int = -1
var outcome_id: String = ""

var state_machine: IncidentStateMachine

func _init(p_id: String, p_type_id: String, p_district_id: String, p_location_id: String, p_created_at_minute: int) -> void:
	id = p_id
	type_id = p_type_id
	district_id = p_district_id
	location_id = p_location_id
	created_at_minute = p_created_at_minute
	state_machine = IncidentStateMachine.new(self)

func is_open() -> bool:
	return state != GameEnums.IncidentState.RESOLVED and state != GameEnums.IncidentState.OUTCOME

## Cross-shift handover: clears assignment and steps back no further forward
## than QUEUED, since the officers who were on it go off duty even though
## the incident itself doesn't disappear. No-op for incidents already
## resolved, or not yet past QUEUED. See docs/ARCHITECTURE.md.
func apply_shift_handover() -> void:
	if not is_open():
		return
	assigned_unit_ids.clear()
	if int(state) > int(GameEnums.IncidentState.QUEUED):
		state_machine.transition_to(GameEnums.IncidentState.QUEUED)

func reveal_unknown_fact() -> String:
	if unknown_facts.is_empty():
		return ""
	var fact: String = unknown_facts.pop_front()
	known_facts.append(fact)
	return fact

func to_history_entry() -> IncidentHistoryEntry:
	var entry := IncidentHistoryEntry.new()
	entry.incident_id = id
	entry.type_id = type_id
	entry.district_id = district_id
	entry.location_id = location_id
	entry.priority = priority
	entry.escalation_level = escalation_level
	entry.created_at_minute = created_at_minute
	entry.resolved_at_minute = resolved_at_minute
	entry.outcome_id = outcome_id
	return entry
