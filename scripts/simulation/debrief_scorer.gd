class_name DebriefScorer
extends RefCounted
## Milestone 5's 5-dimension shift rating (spec section 46) --
## Response/Prevention/Intelligence/Community/Workforce, each banded into
## Poor/Developing/Good/Strong/Excellent from a simple, transparent 0-100
## score built entirely from data the simulation already tracks. The
## point of the debrief is being honest about what happened, not a
## precisely-tuned leaderboard metric -- these formulas are deliberately
## simple and legible, not hidden.

enum Band { POOR, DEVELOPING, GOOD, STRONG, EXCELLENT }

static func band_text(band: Band) -> String:
	match band:
		Band.POOR: return "Poor"
		Band.DEVELOPING: return "Developing"
		Band.GOOD: return "Good"
		Band.STRONG: return "Strong"
		Band.EXCELLENT: return "Excellent"
		_: return "Unknown"

static func score_shift(core: SimulationCore, shift_start_minute: int) -> Dictionary:
	return {
		"response": _score_response(core, shift_start_minute),
		"prevention": _score_prevention(core),
		"intelligence": _score_intelligence(core, shift_start_minute),
		"community": _score_community(core),
		"workforce": _score_workforce(core),
	}

## Narrative summary (spec section 45) -- 2-4 sentences picked from the
## scores, more useful to the player than the raw numbers alone.
static func narrative_summary(scores: Dictionary) -> String:
	var lines: Array[String] = []

	var response: Dictionary = scores["response"]
	if int(response["still_open"]) > 0:
		lines.append("%d incident(s) went unresolved and will carry into the next shift." % int(response["still_open"]))
	elif int(response["escalated"]) > 0:
		lines.append("Response was solid overall, though %d incident(s) escalated before help arrived." % int(response["escalated"]))
	elif int(response["resolved"]) > 0:
		lines.append("Every incident this shift was dealt with cleanly, with nothing left outstanding.")
	else:
		lines.append("A quiet shift -- little demand came in.")

	var prevention: Dictionary = scores["prevention"]
	if prevention["band"] == Band.POOR or prevention["band"] == Band.DEVELOPING:
		lines.append("Underlying crime pressure across Westford remains a concern -- proactive patrol tasking next shift may help.")
	else:
		lines.append("Crime pressure across the town stayed manageable.")

	var community: Dictionary = scores["community"]
	if community["band"] == Band.POOR:
		lines.append("Community confidence has taken a hit -- reassurance-focused policing may help rebuild it.")
	elif community["band"] == Band.EXCELLENT or community["band"] == Band.STRONG:
		lines.append("The community's confidence in local policing held up well.")

	var workforce: Dictionary = scores["workforce"]
	if workforce["band"] == Band.POOR:
		lines.append("Your officers are running fatigued -- consider more breaks next shift.")

	var text: String = ""
	for i in range(lines.size()):
		if i > 0:
			text += " "
		text += lines[i]
	return text

static func _band_for_score(score: float) -> Band:
	if score >= 85.0: return Band.EXCELLENT
	if score >= 70.0: return Band.STRONG
	if score >= 50.0: return Band.GOOD
	if score >= 30.0: return Band.DEVELOPING
	return Band.POOR

## Slower response, more escalations, and incidents left open all count
## against this -- the three things spec section 63's acceptance test
## actually asks the player to manage.
static func _score_response(core: SimulationCore, shift_start_minute: int) -> Dictionary:
	var delay_sum := 0.0
	var delay_count := 0
	var escalated_count := 0
	var resolved_count := 0
	for entry: IncidentHistoryEntry in core.incident_manager.history:
		if entry.resolved_at_minute < shift_start_minute:
			continue
		resolved_count += 1
		if entry.first_on_scene_minute >= 0:
			delay_sum += float(entry.first_on_scene_minute - entry.created_at_minute)
			delay_count += 1
		if entry.escalation_level > 0:
			escalated_count += 1
	var avg_delay: float = delay_sum / delay_count if delay_count > 0 else 0.0
	var still_open: int = core.incident_manager.active_incidents.size()

	var score: float = clampf(100.0 - avg_delay * 1.5 - escalated_count * 10.0 - still_open * 8.0, 0.0, 100.0)
	return {
		"score": score, "band": _band_for_score(score),
		"resolved": resolved_count, "avg_delay_minutes": avg_delay,
		"escalated": escalated_count, "still_open": still_open,
	}

## District risk levels at shift end, inverted (lower risk = better) --
## the end state is what the next shift actually inherits, so it's a
## fairer proxy than a start/end delta would be without adding new
## snapshot tracking for a Milestone 5 nice-to-have.
static func _score_prevention(core: SimulationCore) -> Dictionary:
	var risk_sum := 0.0
	var count := 0
	for district: DistrictState in core.district_manager.districts.values():
		risk_sum += (district.asb + district.violence + district.burglary_risk + district.vehicle_crime_risk + district.theft_risk) / 5.0
		count += 1
	var avg_risk: float = risk_sum / count if count > 0 else 50.0
	var score: float = clampf(100.0 - avg_risk, 0.0, 100.0)
	return {"score": score, "band": _band_for_score(score), "average_risk": avg_risk}

static func _score_intelligence(core: SimulationCore, shift_start_minute: int) -> Dictionary:
	var gained := 0
	for item: Dictionary in core.intelligence_manager.items:
		if int(item.get("created_at_minute", 0)) >= shift_start_minute:
			gained += 1
	var score: float = clampf(gained * 20.0, 0.0, 100.0)
	return {"score": score, "band": _band_for_score(score), "items_gained": gained}

static func _score_community(core: SimulationCore) -> Dictionary:
	var confidence_sum := 0.0
	var tension_sum := 0.0
	var count := 0
	for district: DistrictState in core.district_manager.districts.values():
		confidence_sum += district.community_confidence
		tension_sum += district.community_tension
		count += 1
	var avg_confidence: float = confidence_sum / count if count > 0 else 50.0
	var avg_tension: float = tension_sum / count if count > 0 else 50.0
	var score: float = clampf(avg_confidence - avg_tension * 0.3, 0.0, 100.0)
	return {"score": score, "band": _band_for_score(score), "average_confidence": avg_confidence, "average_tension": avg_tension}

static func _score_workforce(core: SimulationCore) -> Dictionary:
	var stats: Dictionary = WorkforceStats.average_fatigue_morale(core.officer_manager.officers.values())
	var avg_fatigue: float = stats["avg_fatigue"]
	var avg_morale: float = stats["avg_morale"]
	var score: float = clampf(100.0 - avg_fatigue + (avg_morale - 80.0) * 0.5, 0.0, 100.0)
	return {"score": score, "band": _band_for_score(score), "average_fatigue": avg_fatigue, "average_morale": avg_morale}
