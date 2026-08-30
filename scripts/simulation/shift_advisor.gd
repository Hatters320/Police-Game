class_name ShiftAdvisor
extends RefCounted
## Turns the simulation's own tracked state into the "key risks" and
## "actionable recommendations" the briefing and debriefing screens show.
##
## Stateless, like the other engine classes -- pure functions of the core,
## so both screens can be verified headlessly without a viewport.
##
## Everything here is derived from numbers the game already tracks
## (district variables against their own baselines, the duty pattern, the
## season, the weather, the KPI tracker, the debrief scores). Nothing is
## invented flavour text: every line names the real figure that produced
## it, so a player can act on it and check afterwards whether it was true.

## Severity ranks, used for both ordering and colour. HIGH is reserved for
## things that will visibly cost the player this shift.
enum Severity { LOW, MEDIUM, HIGH }

const MAX_ITEMS := 4

static func severity_color(severity: Severity) -> Color:
	match severity:
		Severity.HIGH: return Color(0.90, 0.35, 0.30)
		Severity.MEDIUM: return Color(0.90, 0.65, 0.30)
	return Color(0.55, 0.75, 0.95)

static func severity_text(severity: Severity) -> String:
	match severity:
		Severity.HIGH: return "HIGH"
		Severity.MEDIUM: return "MED"
	return "LOW"

# --- Briefing ----------------------------------------------------------

## What the player is walking into. Highest severity first, capped so the
## screen shows the few things that matter rather than everything true.
static func briefing_risks(core: SimulationCore) -> Array[Dictionary]:
	var risks: Array[Dictionary] = []
	var shift_number: int = core.shift_manager.shift_state.shift_number
	var roster_size: int = core.officer_manager.officers.size()

	if DutyPattern.is_night_shift(shift_number):
		risks.append(_risk(Severity.MEDIUM, "Night shift: %d officers on, against a minimum of %d. Fewer cars, and no slack if two calls land together." % [roster_size, OfficerFactory.MINIMUM_STAFFING]))

	var starting_fatigue: float = DutyPattern.starting_fatigue(shift_number)
	if starting_fatigue >= 15.0:
		risks.append(_risk(Severity.HIGH, "Crew starts already tired (fatigue %d) -- second night of the pair. Expect break requests earlier than usual." % roundi(starting_fatigue)))
	elif starting_fatigue > 0.0:
		risks.append(_risk(Severity.LOW, "Crew comes on carrying fatigue %d from the previous shift." % roundi(starting_fatigue)))

	var weather: GameEnums.WeatherType = core.weather_manager.current_weather
	if weather != GameEnums.WeatherType.CLEAR:
		var speed_pct: int = roundi((1.0 - core.weather_manager.travel_speed_multiplier()) * 100.0)
		var severity: Severity = Severity.HIGH if weather == GameEnums.WeatherType.SNOW else Severity.MEDIUM
		risks.append(_risk(severity, "%s: response driving is %d%% slower town-wide. Travel time will eat into every target." % [core.weather_manager.weather_text(), speed_pct]))

	var season: GameEnums.Season = core.current_season()
	if season == GameEnums.Season.WINTER:
		risks.append(_risk(Severity.MEDIUM, "Winter: only %.1f hours of daylight, and burglary runs high through the dark evenings." % SeasonCycle.daylight_hours(season)))
	elif season == GameEnums.Season.SUMMER:
		risks.append(_risk(Severity.LOW, "Summer: long light evenings, and disorder around the night-time economy runs above average."))

	var carried: int = core.incident_manager.active_incidents.size()
	if carried > 0:
		risks.append(_risk(Severity.HIGH if carried >= 3 else Severity.MEDIUM, "%d incident(s) carried over unresolved from the last shift -- these start the shift already late." % carried))

	var worst: Dictionary = _worst_district(core, ["asb", "violence", "burglary_risk"])
	if not worst.is_empty():
		risks.append(_risk(Severity.MEDIUM, "%s is running %d points above its own normal for %s." % [worst["name"], roundi(worst["delta"]), worst["variable"]]))

	var low_confidence: Dictionary = _lowest_confidence_district(core)
	if not low_confidence.is_empty() and float(low_confidence["value"]) < 45.0:
		risks.append(_risk(Severity.MEDIUM, "Public confidence in %s is down to %d%%. Visible presence there matters more than usual." % [low_confidence["name"], roundi(low_confidence["value"])]))

	return _top(risks)

## What to actually do about it. Deliberately concrete -- each line names a
## district, a number or a control the player can act on before pressing
## confirm.
static func briefing_recommendations(core: SimulationCore) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var shift_number: int = core.shift_manager.shift_state.shift_number
	var unit_count: int = core.resource_manager.units.size()

	var carried: int = core.incident_manager.active_incidents.size()
	if carried > 0:
		out.append(_advice("Clear the %d carried-over call(s) first -- they are already past their response target." % carried))

	if core.weather_manager.current_weather != GameEnums.WeatherType.CLEAR or DutyPattern.is_night_shift(shift_number):
		out.append(_advice("Hold back at least %d unit(s) as response reserve; slower travel and a thin crew both punish over-committing to patrol." % maxi(2, unit_count / 3)))
	else:
		out.append(_advice("With %d cars available, committing two to directed patrol still leaves a workable response reserve." % unit_count))

	var worst: Dictionary = _worst_district(core, ["asb", "violence", "burglary_risk"])
	if not worst.is_empty():
		out.append(_advice("Direct a patrol into %s -- presence there suppresses the %s it is currently running hot on." % [worst["name"], worst["variable"]]))

	var low_confidence: Dictionary = _lowest_confidence_district(core)
	if not low_confidence.is_empty() and float(low_confidence["value"]) < 50.0:
		out.append(_advice("Pick a community-facing priority: confidence in %s (%d%%) recovers through reassurance, not arrests." % [low_confidence["name"], roundi(low_confidence["value"])]))

	# On a clean slate -- every district at its own baseline, nothing
	# carried over -- the data-driven lines above legitimately have
	# nothing to say. Rather than leave the section nearly empty, fall
	# back to steers that are always true and still concrete about which
	# control to use.
	if out.size() < 2:
		var season: GameEnums.Season = core.current_season()
		if season == GameEnums.Season.WINTER or season == GameEnums.Season.AUTUMN:
			out.append(_advice("Watch the residential districts after dark -- burglary and vehicle crime both peak overnight this time of year."))
		else:
			out.append(_advice("Watch the town centre through the evening -- disorder and assaults both peak around the night-time economy."))
	if out.size() < 3:
		out.append(_advice("Dispatch from the top of each incident's suggested list: it is already ranked by crew skill and travel time, so it beats picking by hand."))

	return _top(out)

# --- Debrief -----------------------------------------------------------

static func debrief_risks(core: SimulationCore, scores: Dictionary) -> Array[Dictionary]:
	var risks: Array[Dictionary] = []
	if scores.has("response"):
		var response: Dictionary = scores["response"]
		var still_open: int = int(response["still_open"])
		if still_open > 0:
			risks.append(_risk(Severity.HIGH if still_open >= 3 else Severity.MEDIUM, "%d incident(s) go into the next shift unresolved, and keep ageing overnight." % still_open))
		var escalated: int = int(response["escalated"])
		if escalated > 0:
			risks.append(_risk(Severity.HIGH, "%d incident(s) escalated before anyone got there -- each one costs public confidence." % escalated))
		var avg_delay: float = float(response["avg_delay_minutes"])
		if avg_delay > 20.0:
			risks.append(_risk(Severity.MEDIUM, "Average time to scene was %d minutes. Anything over 15 is outside the P1 target." % roundi(avg_delay)))

	if scores.has("workforce"):
		var workforce: Dictionary = scores["workforce"]
		var fatigue: float = float(workforce["average_fatigue"])
		if fatigue >= 60.0:
			risks.append(_risk(Severity.HIGH, "Crew finished on average fatigue %d. Tired officers make slower, worse decisions." % roundi(fatigue)))
		elif fatigue >= 40.0:
			risks.append(_risk(Severity.LOW, "Average fatigue ended at %d -- manageable, but worth watching." % roundi(fatigue)))
		var morale: float = float(workforce["average_morale"])
		if morale < 55.0:
			risks.append(_risk(Severity.MEDIUM, "Morale ended at %d. It recovers slowly once it drops this far." % roundi(morale)))

	var low_confidence: Dictionary = _lowest_confidence_district(core)
	if not low_confidence.is_empty() and float(low_confidence["value"]) < 45.0:
		risks.append(_risk(Severity.MEDIUM, "%s ends the shift at %d%% confidence -- the next shift inherits that." % [low_confidence["name"], roundi(low_confidence["value"])]))

	var worst: Dictionary = _worst_district(core, ["asb", "violence", "burglary_risk"])
	if not worst.is_empty():
		risks.append(_risk(Severity.LOW, "%s is carrying elevated %s into the next shift." % [worst["name"], worst["variable"]]))

	return _top(risks)

static func debrief_recommendations(core: SimulationCore, scores: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var weakest: String = _weakest_dimension(scores)
	match weakest:
		"response":
			out.append(_advice("Dispatch sooner. The suggested unit at the top of each incident's list is already ranked by skill and travel time -- taking it beats picking by hand."))
		"prevention":
			out.append(_advice("Use directed patrol in the briefing. Presence in a hot district actively suppresses its risk variables while a car sits there."))
		"intelligence":
			out.append(_advice("Set a GATHER INTELLIGENCE intent on suitable calls -- burglaries and suspicious-activity calls both reward it, and intel feeds the next briefing."))
		"community":
			out.append(_advice("Use REASSURE on lower-priority calls in low-confidence districts. Confidence recovers through visible, unhurried contact."))
		"workforce":
			out.append(_advice("Grant breaks when officers ask. A short break now costs less than an exhausted crew for the rest of the shift."))
	if scores.has("response") and int(scores["response"]["still_open"]) > 0:
		out.append(_advice("Start the next shift by clearing what is already open before taking anything new on."))
	var low_confidence: Dictionary = _lowest_confidence_district(core)
	if not low_confidence.is_empty() and float(low_confidence["value"]) < 50.0:
		out.append(_advice("Make %s a priority next shift -- it is the district furthest behind on confidence." % low_confidence["name"]))
	return _top(out)

# --- Shared helpers ----------------------------------------------------

static func _risk(severity: Severity, text: String) -> Dictionary:
	return {"severity": severity, "text": text}

static func _advice(text: String) -> Dictionary:
	return {"severity": Severity.LOW, "text": text}

## Highest severity first, then capped. Sorting before the cap means a
## HIGH risk is never pushed off the list by three LOW ones that happened
## to be appended earlier.
static func _top(items: Array[Dictionary]) -> Array[Dictionary]:
	items.sort_custom(func(a, b): return int(a["severity"]) > int(b["severity"]))
	return items.slice(0, mini(items.size(), MAX_ITEMS))

## The district furthest above its own captured baseline on any of the
## given variables -- deviation from its own normal, not a town-wide
## midpoint, matching how the incident engine weights districts.
static func _worst_district(core: SimulationCore, variables: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_delta := 8.0 # ignore noise-level deviations
	for district: DistrictState in core.district_manager.districts.values():
		for variable_name in variables:
			var delta: float = district.get_variable(variable_name) - district.get_baseline_variable(variable_name)
			if delta > best_delta:
				best_delta = delta
				best = {
					"name": _district_name(core, district.district_id),
					"variable": String(variable_name).replace("_", " "),
					"delta": delta,
				}
	return best

static func _lowest_confidence_district(core: SimulationCore) -> Dictionary:
	var out: Dictionary = {}
	var lowest := 1000.0
	for district: DistrictState in core.district_manager.districts.values():
		if district.community_confidence < lowest:
			lowest = district.community_confidence
			out = {"name": _district_name(core, district.district_id), "value": district.community_confidence}
	return out

static func _district_name(core: SimulationCore, district_id: String) -> String:
	var def: DistrictDefinition = core.world.get_district(district_id)
	return def.display_name if def else district_id

static func _weakest_dimension(scores: Dictionary) -> String:
	var weakest := ""
	var lowest := 1000.0
	for key in scores.keys():
		var score: float = float(scores[key]["score"])
		if score < lowest:
			lowest = score
			weakest = String(key)
	return weakest
