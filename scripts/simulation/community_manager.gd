class_name CommunityManager
extends RefCounted
## Applies community confidence/tension effects from incident resolution and
## the player's chosen command intent (spec section 26/42/52). Deliberately
## small: the goal is visible consequences, not a sociology simulator.

func apply_incident_resolution_effect(district: DistrictState, incident: Incident) -> void:
	if district == null:
		return
	match incident.command_intent:
		GameEnums.CommandIntent.REASSURE, GameEnums.CommandIntent.GATHER_INTELLIGENCE:
			district.apply_community_effect(2.0, -1.5)
		GameEnums.CommandIntent.RESOLVE:
			district.apply_community_effect(0.5, 1.0)
		_:
			district.apply_community_effect(0.0, 0.0)
