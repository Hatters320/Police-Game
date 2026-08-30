class_name DebriefView
extends ShiftScreenView
## End-of-shift debrief (spec section 45/46), rebuilt on ShiftScreenView.
##
## Same story as BriefingView: the information was right, the presentation
## was a flat stack of default Labels while the rest of the game had moved
## onto UiTheme. The five performance dimensions in particular were a row
## of tinted text chips -- "Response: Good" -- which gave no sense of how
## close to the next band anything was.
##
## What's new beyond the styling: headline result tiles, the five
## dimensions drawn as scored meters, a KEY RISKS section (what the next
## shift inherits) and RECOMMENDED ACTIONS (what to do differently),
## both from ShiftAdvisor and both built from the same numbers the scores
## are, plus town conditions as meters rather than a raw numbers line.

signal start_next_shift

func setup(summary: Dictionary) -> void:
	build_frame()

	var shift: ShiftState = Simulation.core.shift_manager.shift_state
	var scores: Dictionary = summary.get("scores", {})

	_add_hero(summary, shift)
	_add_result_section(summary)
	_add_performance_section(scores)
	_add_risks_section(scores)
	_add_recommendations_section(scores)
	_add_response_section(summary, shift)
	_add_conditions_section()
	add_primary_button("START NEXT SHIFT", func(): start_next_shift.emit())

func _add_hero(summary: Dictionary, shift: ShiftState) -> void:
	var shift_number: int = int(summary["shift_number"])
	var season: GameEnums.Season = Simulation.core.current_season()
	var chips: Array[Dictionary] = [
		{"text": "%s SHIFT" % DutyPattern.label(shift_number).to_upper(),
			"color": Color(0.55, 0.70, 1.0) if DutyPattern.is_night_shift(shift_number) else Color(0.95, 0.80, 0.45)},
		{"text": "%s - %s" % [TimeFormat.clock(shift.shift_start_minute), TimeFormat.clock(shift.shift_end_minute)],
			"color": UiTheme.TEXT_DIM},
		{"text": SeasonCycle.label(season).to_upper(), "color": Color(0.55, 0.85, 0.55)},
		{"text": Simulation.core.weather_manager.weather_text().to_upper(),
			"color": Color(0.60, 0.75, 0.95) if Simulation.core.weather_manager.is_adverse() else UiTheme.TEXT_DIM},
	]
	add_hero("WESTFORD POLICE -- SHIFT DEBRIEF", "Shift %d review" % shift_number, chips)

func _add_result_section(summary: Dictionary) -> void:
	var section := add_section("HOW THE SHIFT WENT")
	var narrative: String = String(summary.get("narrative", ""))
	if narrative != "":
		add_body(section, narrative)

	var resolved: int = int(summary["resolved_this_shift"])
	var still_open: int = int(summary["still_open_incidents"])
	var scores: Dictionary = summary.get("scores", {})
	var escalated: int = int(scores["response"]["escalated"]) if scores.has("response") else 0
	var avg_delay: float = float(scores["response"]["avg_delay_minutes"]) if scores.has("response") else 0.0

	add_stat_tiles(section, [
		{"value": "%d" % resolved, "label": "incidents resolved", "color": Color(0.50, 0.85, 0.45)},
		{"value": "%d" % still_open, "label": "left open at shift end",
			"color": Color(0.90, 0.35, 0.30) if still_open > 0 else Color(0.50, 0.85, 0.45)},
		{"value": "%d" % escalated, "label": "escalated before arrival",
			"color": Color(0.90, 0.35, 0.30) if escalated > 0 else Color(0.50, 0.85, 0.45)},
		{"value": "%dm" % roundi(avg_delay), "label": "average time to scene",
			"color": Color(0.90, 0.65, 0.30) if avg_delay > 15.0 else Color(0.50, 0.85, 0.45)},
	])

## The five dimensions as scored meters. The band word is kept -- it is
## what the spec asks for -- but the bar shows how far into the band the
## score actually sits, which a bare "Good" never could.
func _add_performance_section(scores: Dictionary) -> void:
	if scores.is_empty():
		return
	var section := add_section("PERFORMANCE")
	for pair in [["response", "Response"], ["prevention", "Prevention"], ["intelligence", "Intelligence"], ["community", "Community"], ["workforce", "Workforce"]]:
		var key: String = pair[0]
		if not scores.has(key):
			continue
		var entry: Dictionary = scores[key]
		var score: float = float(entry["score"])
		var band: DebriefScorer.Band = entry["band"]
		add_meter(section, String(pair[1]), "%s (%d)" % [DebriefScorer.band_text(band), roundi(score)],
			score / 100.0, _band_color(band))

func _band_color(band: DebriefScorer.Band) -> Color:
	match band:
		DebriefScorer.Band.POOR: return Color(0.90, 0.35, 0.30)
		DebriefScorer.Band.DEVELOPING: return Color(0.90, 0.65, 0.30)
		DebriefScorer.Band.GOOD: return Color(0.85, 0.85, 0.40)
		DebriefScorer.Band.STRONG: return Color(0.50, 0.85, 0.40)
		DebriefScorer.Band.EXCELLENT: return Color(0.40, 0.85, 0.70)
	return Color.WHITE

func _add_risks_section(scores: Dictionary) -> void:
	var section := add_section("WHAT THE NEXT SHIFT INHERITS")
	var risks: Array[Dictionary] = ShiftAdvisor.debrief_risks(Simulation.core, scores)
	if risks.is_empty():
		add_dim(section, "Nothing outstanding -- the town is handed over clean.")
		return
	for risk: Dictionary in risks:
		var severity: ShiftAdvisor.Severity = risk["severity"]
		add_flagged_row(section, ShiftAdvisor.severity_text(severity), ShiftAdvisor.severity_color(severity), String(risk["text"]))

func _add_recommendations_section(scores: Dictionary) -> void:
	if scores.is_empty():
		return
	var section := add_section("RECOMMENDED ACTIONS")
	for item: Dictionary in ShiftAdvisor.debrief_recommendations(Simulation.core, scores):
		add_bullet(section, String(item["text"]))

func _add_response_section(summary: Dictionary, shift: ShiftState) -> void:
	var section := add_section("CALLS THIS SHIFT")
	var shown := 0
	for entry: IncidentHistoryEntry in Simulation.core.incident_manager.history:
		if entry.resolved_at_minute < shift.shift_start_minute:
			continue
		var type_def: IncidentTypeDefinition = Simulation.core.incident_manager.get_type_definition(entry.type_id)
		var display_name: String = type_def.display_name if type_def else entry.type_id
		add_dim(section, "%s   %s -> %s" % [TimeFormat.clock(entry.resolved_at_minute), display_name, entry.outcome_id.replace("_", " ")])
		shown += 1
	if shown == 0:
		add_dim(section, "No calls resolved this shift.")

	if not shift.priorities.is_empty():
		add_dim(section, "Priorities you set:")
		for p in shift.priorities:
			add_bullet(section, p)
	add_dim(section, "%d intelligence item(s) recorded across the game so far." % int(summary["intelligence_items"]))

func _add_conditions_section() -> void:
	var section := add_section("WESTFORD NOW")
	add_dim(section, "District state carries into the next shift -- this is what you are handing over.")
	for district_id in Simulation.core.district_manager.districts.keys():
		var district: DistrictState = Simulation.core.district_manager.districts[district_id]
		var def: DistrictDefinition = Simulation.core.world.get_district(district_id)
		var display_name: String = def.display_name if def else district_id
		var risk: float = (district.asb + district.violence + district.burglary_risk
			+ district.vehicle_crime_risk + district.theft_risk) / 5.0
		add_meter(section, display_name, "confidence %d%%" % roundi(district.community_confidence),
			district.community_confidence / 100.0, _confidence_color(district.community_confidence))
		add_meter(section, "    risk level", "%d" % roundi(risk), risk / 100.0, _risk_color(risk))

func _confidence_color(value: float) -> Color:
	if value >= 65.0:
		return Color(0.50, 0.85, 0.45)
	if value >= 45.0:
		return Color(0.90, 0.65, 0.30)
	return Color(0.90, 0.35, 0.30)

func _risk_color(value: float) -> Color:
	if value <= 25.0:
		return Color(0.50, 0.85, 0.45)
	if value <= 45.0:
		return Color(0.90, 0.65, 0.30)
	return Color(0.90, 0.35, 0.30)
