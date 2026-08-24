class_name OfficerInteractionManager
extends RefCounted
## Queue of pending officer-initiated pop-ups (feature request: "officers
## ask the player for guidance... requesting breaks due to fatigue or
## hunger... reporting concerns about workload, morale"). Purely reactive
## -- populated by FatigueManager's fatigue_warning/morale_concern signals
## (main.gd wires this), never ticked itself. Only one prompt is ever
## shown at a time (OfficerInteractionPanelView is a single modal), so a
## FIFO queue is enough even if several officers cross a threshold in the
## same tick.

var _queue: Array[Dictionary] = [] # {officer_id: String, kind: String}

func enqueue(officer_id: String, kind: String) -> void:
	_queue.append({"officer_id": officer_id, "kind": kind})

func has_pending() -> bool:
	return not _queue.is_empty()

func pop_next() -> Dictionary:
	return _queue.pop_front()
