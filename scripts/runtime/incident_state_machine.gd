class_name IncidentStateMachine
extends RefCounted
## Shared driver for every Incident's state progression -- one class for all
## incident types, per spec section 59 (new incident types are data, not new
## state-machine code). Durations/overrides live on IncidentTypeDefinition.

const ORDER := [
	GameEnums.IncidentState.CREATED,
	GameEnums.IncidentState.REPORTED,
	GameEnums.IncidentState.ASSESSED,
	GameEnums.IncidentState.QUEUED,
	GameEnums.IncidentState.ASSIGNED,
	GameEnums.IncidentState.TRAVELLING,
	GameEnums.IncidentState.ON_SCENE,
	GameEnums.IncidentState.DEVELOPING,
	GameEnums.IncidentState.RESOLVED,
	GameEnums.IncidentState.OUTCOME,
]

var _incident: Incident

func _init(owner_incident: Incident) -> void:
	_incident = owner_incident

## Forward-only, one step at a time along ORDER -- except QUEUED, which can
## be re-entered directly from any pre-resolution state (a unit pulled off,
## or the cross-shift handover rule).
func can_transition_to(target: GameEnums.IncidentState) -> bool:
	if target == GameEnums.IncidentState.QUEUED:
		return _incident.is_open()
	var current_index: int = ORDER.find(_incident.state)
	var target_index: int = ORDER.find(target)
	return target_index == current_index + 1

func transition_to(target: GameEnums.IncidentState) -> bool:
	if not can_transition_to(target):
		return false
	_incident.state = target
	_incident.time_in_current_state = 0.0
	return true

func advance(dt_minutes: float) -> void:
	_incident.time_in_current_state += dt_minutes
