class_name GameEnums
## Shared enums referenced across the simulation layer. Centralised so
## managers, runtime state, and UI can all reference e.g. GameEnums.UnitStatus
## without circular script dependencies.

enum OfficerRank { CONSTABLE, SERGEANT }
enum OfficerExperience { LOW, MEDIUM, HIGH }
enum SkillLevel { LOW, MEDIUM, HIGH }

enum OfficerStatus {
	AVAILABLE,
	ON_UNIT,
	ON_BREAK,
	UNAVAILABLE_SICK,
	UNAVAILABLE_LEAVE,
	UNAVAILABLE_TRAINING,
	OFF_DUTY,
}

enum UnitStatus {
	AVAILABLE,
	PATROL,
	TRAVELLING,
	ON_SCENE,
	ON_BREAK,
	UNAVAILABLE,
}

enum PatrolMode {
	GENERAL,
	DIRECTED,
	COMMUNITY_ENGAGEMENT,
	PROACTIVE_TASK,
	RESERVE,
}

## Linear progression only; escalation is tracked separately as
## Incident.escalation_level rather than as a state, since an incident can
## escalate from several different base states without changing what it's
## fundamentally waiting on. See docs/ARCHITECTURE.md section 4/6.
enum IncidentState {
	CREATED,
	REPORTED,
	ASSESSED,
	QUEUED,
	ASSIGNED,
	TRAVELLING,
	ON_SCENE,
	DEVELOPING,
	RESOLVED,
	OUTCOME,
}

enum CommandIntent {
	NONE,
	RESPOND,
	CONTAIN,
	LOCATE,
	REASSURE,
	GATHER_INTELLIGENCE,
	RESOLVE,
}

enum CommandResultCode { OK, REJECTED }
