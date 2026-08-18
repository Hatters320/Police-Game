class_name DebriefView
extends CanvasLayer
## End-of-shift debrief (spec section 45/46): a short narrative summary,
## the 5-dimension Poor/Developing/Good/Strong/Excellent rating
## (DebriefScorer), what happened this shift, and the district snapshot
## the town carries into the next one -- the "town remembers" persistence
## decision's visible payoff. Built via code -- see MapView's header
## comment for why.

signal start_next_shift

func setup(summary: Dictionary) -> void:
	layer = 5

	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.05, 0.07, 0.92)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 60
	scroll.offset_top = 30
	scroll.offset_right = -60
	scroll.offset_bottom = -30
	add_child(scroll)

	var content := VBoxContainer.new()
	# See BriefingView's setup() for why this isn't 900 any more -- that
	# forced a second, horizontal scroll on top of the vertical one on a
	# real phone's much narrower logical viewport.
	content.custom_minimum_size = Vector2(600, 0)
	content.add_theme_constant_override("separation", 16)
	scroll.add_child(content)

	var shift: ShiftState = Simulation.core.shift_manager.shift_state

	_add_title(content, "SHIFT %d DEBRIEF" % int(summary["shift_number"]))
	_add_dim(content, "%s - %s" % [TimeFormat.clock(shift.shift_start_minute), TimeFormat.clock(shift.shift_end_minute)])

	_add_line(content, String(summary.get("narrative", "")))
	_add_performance_ratings(content, summary.get("scores", {}))

	_add_section_header(content, "RESPONSE")
	_add_line(content, "%d incident(s) resolved this shift." % int(summary["resolved_this_shift"]))
	if int(summary["still_open_incidents"]) > 0:
		_add_line(content, "%d incident(s) still open at shift end -- carried into the next shift, not discarded." % int(summary["still_open_incidents"]))
	else:
		_add_line(content, "No incidents left outstanding.")
	_add_resolved_list(content, shift.shift_start_minute)

	_add_section_header(content, "PRIORITIES YOU SET")
	if shift.priorities.is_empty():
		_add_dim(content, "(none selected)")
	else:
		for p in shift.priorities:
			_add_line(content, "•  %s" % p)

	_add_section_header(content, "INTELLIGENCE")
	_add_line(content, "%d item(s) recorded across the game so far." % int(summary["intelligence_items"]))

	_add_section_header(content, "WESTFORD NOW")
	_add_district_snapshot(content)

	var next_button := Button.new()
	next_button.text = "START NEXT SHIFT"
	next_button.custom_minimum_size = Vector2(300, 58)
	next_button.pressed.connect(func(): start_next_shift.emit())
	content.add_child(next_button)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	content.add_child(spacer)

func _add_performance_ratings(parent: Node, scores: Dictionary) -> void:
	if scores.is_empty():
		return
	_add_section_header(parent, "PERFORMANCE")
	var row := HFlowContainer.new()
	parent.add_child(row)
	for pair in [["response", "Response"], ["prevention", "Prevention"], ["intelligence", "Intelligence"], ["community", "Community"], ["workforce", "Workforce"]]:
		var key: String = pair[0]
		var label_text: String = pair[1]
		if not scores.has(key):
			continue
		var s: Dictionary = scores[key]
		var chip := Label.new()
		chip.text = "%s: %s" % [label_text, DebriefScorer.band_text(s["band"])]
		chip.add_theme_font_size_override("font_size", 18)
		chip.modulate = _band_color(s["band"])
		row.add_child(chip)

func _band_color(band: DebriefScorer.Band) -> Color:
	match band:
		DebriefScorer.Band.POOR: return Color(0.9, 0.35, 0.3)
		DebriefScorer.Band.DEVELOPING: return Color(0.9, 0.65, 0.3)
		DebriefScorer.Band.GOOD: return Color(0.85, 0.85, 0.4)
		DebriefScorer.Band.STRONG: return Color(0.5, 0.85, 0.4)
		DebriefScorer.Band.EXCELLENT: return Color(0.4, 0.85, 0.7)
		_: return Color.WHITE

func _add_resolved_list(parent: Node, shift_start_minute: int) -> void:
	var shown := 0
	for entry: IncidentHistoryEntry in Simulation.core.incident_manager.history:
		if entry.resolved_at_minute < shift_start_minute:
			continue
		var type_def: IncidentTypeDefinition = Simulation.core.incident_manager.get_type_definition(entry.type_id)
		var display_name: String = type_def.display_name if type_def else entry.type_id
		_add_dim(parent, "  %s -- %s -> %s" % [TimeFormat.clock(entry.resolved_at_minute), display_name, entry.outcome_id])
		shown += 1
	if shown == 0:
		_add_dim(parent, "  (none)")

func _add_district_snapshot(parent: Node) -> void:
	for district_id in Simulation.core.district_manager.districts.keys():
		var d: DistrictState = Simulation.core.district_manager.districts[district_id]
		var def: DistrictDefinition = Simulation.core.world.get_district(district_id)
		var display_name: String = def.display_name if def else district_id
		_add_line(parent, "%s -- ASB %d, tension %d, visibility %d, confidence %d" % [
			display_name, int(d.asb), int(d.community_tension), int(d.police_visibility), int(d.community_confidence),
		])

func _add_title(parent: Node, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 34)
	parent.add_child(label)

func _add_section_header(parent: Node, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	label.modulate = Color(0.75, 0.8, 1.0)
	parent.add_child(label)

func _add_line(parent: Node, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	parent.add_child(label)

func _add_dim(parent: Node, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = Color(0.6, 0.6, 0.6)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	parent.add_child(label)
