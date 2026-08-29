class_name OfficerFactory
extends RefCounted
## Builds a shift roster matching spec section 8's staffing model:
## establishment 16, minus 2 annual leave / 1 training / 1 sickness =
## 12 available (2 sergeants + 10 constables), against a minimum of 10.
## The 4 unavailable officers aren't modelled as Officer objects yet since
## they never participate in the simulation -- Milestone 3's briefing
## screen is what will need to display those counts, not the sim itself.
## 9 of the 12 are driver-qualified and 3 aren't, to exercise the
## single/double-crewing mechanic (spec section 12) from the very first
## shift.

const ESTABLISHMENT := 16
const ANNUAL_LEAVE := 2
const TRAINING := 1
const SICKNESS := 1
const MINIMUM_STAFFING := 10

## Builds this shift's roster. The two optional arguments carry the duty
## pattern (see DutyPattern): every officer comes on already carrying
## `starting_fatigue`, and a night shift drops `staffing_cut` officers off
## the end of the list. Both default to the old behaviour, so callers that
## don't care about the cycle (tests, tooling) are unaffected.
##
## The cut takes the last officers in list order deliberately: PC Kowalski
## and PC Fitzgerald are the two least-deployable of the twelve (neither is
## driver-qualified, and they're the lower-experience end), so a thin night
## crew loses its most marginal pair rather than an arbitrary slice -- and
## 12 - 2 lands exactly on MINIMUM_STAFFING.
static func build_shift_roster(starting_fatigue: float = 0.0, staffing_cut: int = 0) -> Array[Officer]:
	var roster: Array[Officer] = [
		_officer("sgt_ahmed", "Sgt. Ahmed", GameEnums.OfficerRank.SERGEANT, GameEnums.OfficerExperience.HIGH, true,
			{"communication": GameEnums.SkillLevel.HIGH, "response": GameEnums.SkillLevel.HIGH, "investigation": GameEnums.SkillLevel.MEDIUM, "community": GameEnums.SkillLevel.HIGH, "driving": GameEnums.SkillLevel.HIGH}),
		_officer("sgt_whitfield", "Sgt. Whitfield", GameEnums.OfficerRank.SERGEANT, GameEnums.OfficerExperience.HIGH, true,
			{"communication": GameEnums.SkillLevel.HIGH, "response": GameEnums.SkillLevel.HIGH, "investigation": GameEnums.SkillLevel.HIGH, "community": GameEnums.SkillLevel.MEDIUM, "driving": GameEnums.SkillLevel.HIGH}),

		_officer("pc_harris", "PC Harris", GameEnums.OfficerRank.CONSTABLE, GameEnums.OfficerExperience.HIGH, true,
			{"communication": GameEnums.SkillLevel.HIGH, "response": GameEnums.SkillLevel.HIGH, "investigation": GameEnums.SkillLevel.MEDIUM, "community": GameEnums.SkillLevel.MEDIUM, "driving": GameEnums.SkillLevel.HIGH}),
		_officer("pc_lewis", "PC Lewis", GameEnums.OfficerRank.CONSTABLE, GameEnums.OfficerExperience.LOW, true,
			{"communication": GameEnums.SkillLevel.MEDIUM, "response": GameEnums.SkillLevel.MEDIUM, "investigation": GameEnums.SkillLevel.LOW, "community": GameEnums.SkillLevel.MEDIUM, "driving": GameEnums.SkillLevel.MEDIUM}),
		_officer("pc_patel", "PC Patel", GameEnums.OfficerRank.CONSTABLE, GameEnums.OfficerExperience.MEDIUM, true,
			{"communication": GameEnums.SkillLevel.MEDIUM, "response": GameEnums.SkillLevel.MEDIUM, "investigation": GameEnums.SkillLevel.MEDIUM, "community": GameEnums.SkillLevel.MEDIUM, "driving": GameEnums.SkillLevel.MEDIUM}),
		_officer("pc_nkomo", "PC Nkomo", GameEnums.OfficerRank.CONSTABLE, GameEnums.OfficerExperience.MEDIUM, true,
			{"communication": GameEnums.SkillLevel.MEDIUM, "response": GameEnums.SkillLevel.HIGH, "investigation": GameEnums.SkillLevel.LOW, "community": GameEnums.SkillLevel.MEDIUM, "driving": GameEnums.SkillLevel.MEDIUM}),
		_officer("pc_oconnor", "PC O'Connor", GameEnums.OfficerRank.CONSTABLE, GameEnums.OfficerExperience.HIGH, true,
			{"communication": GameEnums.SkillLevel.HIGH, "response": GameEnums.SkillLevel.MEDIUM, "investigation": GameEnums.SkillLevel.HIGH, "community": GameEnums.SkillLevel.MEDIUM, "driving": GameEnums.SkillLevel.HIGH}),
		_officer("pc_singh", "PC Singh", GameEnums.OfficerRank.CONSTABLE, GameEnums.OfficerExperience.MEDIUM, true,
			{"communication": GameEnums.SkillLevel.MEDIUM, "response": GameEnums.SkillLevel.MEDIUM, "investigation": GameEnums.SkillLevel.MEDIUM, "community": GameEnums.SkillLevel.HIGH, "driving": GameEnums.SkillLevel.MEDIUM}),
		_officer("pc_bennett", "PC Bennett", GameEnums.OfficerRank.CONSTABLE, GameEnums.OfficerExperience.LOW, true,
			{"communication": GameEnums.SkillLevel.LOW, "response": GameEnums.SkillLevel.MEDIUM, "investigation": GameEnums.SkillLevel.LOW, "community": GameEnums.SkillLevel.LOW, "driving": GameEnums.SkillLevel.MEDIUM}),

		_officer("pc_adeyemi", "PC Adeyemi", GameEnums.OfficerRank.CONSTABLE, GameEnums.OfficerExperience.MEDIUM, false,
			{"communication": GameEnums.SkillLevel.MEDIUM, "response": GameEnums.SkillLevel.MEDIUM, "investigation": GameEnums.SkillLevel.MEDIUM, "community": GameEnums.SkillLevel.MEDIUM, "driving": GameEnums.SkillLevel.LOW}),
		_officer("pc_kowalski", "PC Kowalski", GameEnums.OfficerRank.CONSTABLE, GameEnums.OfficerExperience.LOW, false,
			{"communication": GameEnums.SkillLevel.LOW, "response": GameEnums.SkillLevel.LOW, "investigation": GameEnums.SkillLevel.LOW, "community": GameEnums.SkillLevel.MEDIUM, "driving": GameEnums.SkillLevel.LOW}),
		_officer("pc_fitzgerald", "PC Fitzgerald", GameEnums.OfficerRank.CONSTABLE, GameEnums.OfficerExperience.MEDIUM, false,
			{"communication": GameEnums.SkillLevel.MEDIUM, "response": GameEnums.SkillLevel.MEDIUM, "investigation": GameEnums.SkillLevel.HIGH, "community": GameEnums.SkillLevel.MEDIUM, "driving": GameEnums.SkillLevel.LOW}),
	]
	if staffing_cut > 0:
		roster = roster.slice(0, maxi(roster.size() - staffing_cut, 0))
	if starting_fatigue > 0.0:
		for officer in roster:
			officer.fatigue = starting_fatigue
	return roster

static func _officer(id: String, name: String, rank: GameEnums.OfficerRank, experience: GameEnums.OfficerExperience, driver_qualified: bool, skills: Dictionary) -> Officer:
	var officer := Officer.new(id, name)
	officer.rank = rank
	officer.experience = experience
	officer.driver_qualified = driver_qualified
	officer.skills = skills
	return officer
