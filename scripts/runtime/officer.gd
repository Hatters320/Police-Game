class_name Officer
extends RefCounted
## Runtime officer (spec section 13). RefCounted, not Resource -- see
## docs/ARCHITECTURE.md's note on why mutable state is never a Resource.

var id: String
var officer_name: String
var rank: GameEnums.OfficerRank = GameEnums.OfficerRank.CONSTABLE
var experience: GameEnums.OfficerExperience = GameEnums.OfficerExperience.MEDIUM
var driver_qualified: bool = true

## Keyed by skill name ("communication", "response", "investigation",
## "community", "driving") -> GameEnums.SkillLevel.
var skills: Dictionary = {}

var fatigue: float = 0.0
var morale: float = 80.0
var status: GameEnums.OfficerStatus = GameEnums.OfficerStatus.AVAILABLE
var current_unit_id: String = ""

func _init(p_id: String, p_name: String) -> void:
	id = p_id
	officer_name = p_name

func skill_level(skill_name: String) -> GameEnums.SkillLevel:
	return skills.get(skill_name, GameEnums.SkillLevel.MEDIUM)

## Numeric 0..1 view of a skill, for engines that need to blend several
## skills into one weight (e.g. incident outcome resolution).
func skill_value(skill_name: String) -> float:
	match skill_level(skill_name):
		GameEnums.SkillLevel.LOW: return 0.2
		GameEnums.SkillLevel.HIGH: return 0.9
		_: return 0.55

## Fatigue accrual/recovery policy lives in FatigueManager, not here, so
## the tuning is in one place -- this class only stores the resulting
## values and answers simple questions about them.
func is_available() -> bool:
	return status == GameEnums.OfficerStatus.AVAILABLE

func is_elevated_fatigue() -> bool:
	return fatigue >= 70.0
