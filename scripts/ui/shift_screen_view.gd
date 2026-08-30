class_name ShiftScreenView
extends CanvasLayer
## Shared chrome for the two full-screen shift screens -- the pre-shift
## briefing and the end-of-shift debrief.
##
## Why a base class: those two screens were the only part of the game still
## rendering as raw default Labels stacked on a flat dim rectangle, while
## everything else (HUD, docked panels, KPI dashboard) had moved onto
## UiTheme's navy police palette with cards, accents and chips. They were
## also the first and last thing a player sees each shift, so they were the
## worst place in the build for that to be true. This puts them on the same
## design language as the rest of the game rather than inventing a third
## look for them.
##
## Everything here is built from UiTheme's existing primitives
## (panel_style/card_style/header_style/badge_style) -- no new palette. The
## metrics are larger than SidePanelView's, because these are full-screen
## reading surfaces rather than a compact docked strip, but the shapes,
## radii and colours are deliberately identical so the two read as one
## product.

## Content column width. Matches the value the previous briefing/debrief
## arrived at through real phone playtesting -- wider forced a second,
## horizontal scroll on a real phone's logical viewport.
const CONTENT_WIDTH := 600

const TITLE_FONT := 30
const SECTION_FONT := 17
const BODY_FONT := 14
const SMALL_FONT := 12

var content: VBoxContainer
var _scroll: ScrollContainer

## Builds the backdrop, scroll area and content column. Call once from the
## subclass's setup() before adding anything.
func build_frame() -> void:
	layer = 5

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.04, 0.06, 0.10, 0.96)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_left = 24
	_scroll.offset_top = 18
	_scroll.offset_right = -24
	_scroll.offset_bottom = -18
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)

	content = VBoxContainer.new()
	content.custom_minimum_size = Vector2(CONTENT_WIDTH, 0)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	_scroll.add_child(content)

	# Drag-anywhere scrolling, the same helper every docked panel and the
	# dispatcher feed already use. Without it these screens could only be
	# scrolled by their few-pixels-wide scroll bar, which is exactly the
	# complaint real playtesting raised about the docked panels long ago
	# ("the only way of scrolling... is on the side bar. This is too hard
	# on the screen") -- and these are longer screens than any of those.
	# It also arbitrates tap versus drag, so a thumb flick that starts on
	# a priority button scrolls instead of selecting it.
	DragScroll.attach(self, _scroll, _scroll)

## The screen's masthead: an eyebrow line, the big title, and a row of
## context chips (shift type, season, weather, time window). Replaces what
## used to be a bare 34px Label.
func add_hero(eyebrow: String, title: String, chips: Array[Dictionary]) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.panel_style())
	content.add_child(card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)

	var eyebrow_label := Label.new()
	eyebrow_label.text = eyebrow
	eyebrow_label.add_theme_font_size_override("font_size", SMALL_FONT)
	eyebrow_label.add_theme_color_override("font_color", UiTheme.TEXT_ACCENT)
	col.add_child(eyebrow_label)

	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", TITLE_FONT)
	title_label.add_theme_color_override("font_color", UiTheme.TEXT_PRIMARY)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	col.add_child(title_label)

	if chips.is_empty():
		return
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 4)
	col.add_child(row)
	for chip: Dictionary in chips:
		row.add_child(_chip(String(chip["text"]), chip.get("color", UiTheme.TEXT_DIM)))

## A titled section card. Returns the column to add rows into, so callers
## compose their own content rather than this needing a variant per
## section.
func add_section(title: String) -> VBoxContainer:
	var header := Label.new()
	header.text = title
	header.add_theme_font_size_override("font_size", SECTION_FONT)
	header.add_theme_color_override("font_color", UiTheme.TEXT_ACCENT)
	content.add_child(header)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.panel_style())
	content.add_child(card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 7)
	card.add_child(col)
	return col

## A row of headline numbers -- the "operational summary at a glance" the
## old screens had no equivalent of. Each tile is
## {value: String, label: String, color: Color}.
func add_stat_tiles(parent: Node, tiles: Array[Dictionary]) -> void:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	parent.add_child(row)
	for tile: Dictionary in tiles:
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", UiTheme.card_style(tile.get("color", UiTheme.TEXT_ACCENT)))
		box.custom_minimum_size = Vector2(132, 0)
		row.add_child(box)

		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		box.add_child(col)

		var value := Label.new()
		value.text = String(tile["value"])
		value.add_theme_font_size_override("font_size", 22)
		value.add_theme_color_override("font_color", tile.get("color", UiTheme.TEXT_PRIMARY))
		col.add_child(value)

		var caption := Label.new()
		caption.text = String(tile["label"])
		caption.add_theme_font_size_override("font_size", SMALL_FONT)
		caption.add_theme_color_override("font_color", UiTheme.TEXT_DIM)
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD
		caption.custom_minimum_size = Vector2(118, 0)
		col.add_child(caption)

## One risk or recommendation: a severity badge and the wrapped text beside
## it, so severity is scannable down the left edge.
func add_flagged_row(parent: Node, badge_text: String, badge_color: Color, text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UiTheme.badge_style(badge_color))
	badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	badge.custom_minimum_size = Vector2(46, 0)
	row.add_child(badge)

	var badge_label := Label.new()
	badge_label.text = badge_text
	badge_label.add_theme_font_size_override("font_size", SMALL_FONT)
	badge_label.add_theme_color_override("font_color", badge_color)
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(badge_label)

	row.add_child(_body_label(text, UiTheme.TEXT_PRIMARY))

## A labelled 0-100 bar -- used for the debrief's five performance
## dimensions and the briefing's town-conditions readout. Far quicker to
## read than the raw "ASB 20, tension 20, visibility 30" text line these
## replace.
func add_meter(parent: Node, label_text: String, value_text: String, fraction: float, color: Color) -> void:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 2)
	parent.add_child(wrap)

	var row := HBoxContainer.new()
	wrap.add_child(row)

	var name_label := Label.new()
	name_label.text = label_text
	name_label.add_theme_font_size_override("font_size", BODY_FONT)
	name_label.add_theme_color_override("font_color", UiTheme.TEXT_PRIMARY)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var value := Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", BODY_FONT)
	value.add_theme_color_override("font_color", color)
	row.add_child(value)

	# Drawn as a track with two stretch-weighted children rather than a
	# ProgressBar: a themed ProgressBar needs its own StyleBox pair anyway,
	# and splitting the row by stretch ratio keeps the fill on UiTheme's
	# palette with no extra theme plumbing and no anchor arithmetic.
	var track := PanelContainer.new()
	var track_style := StyleBoxFlat.new()
	track_style.bg_color = Color(0.13, 0.18, 0.27, 0.9)
	track_style.set_corner_radius_all(4)
	track.add_theme_stylebox_override("panel", track_style)
	track.custom_minimum_size = Vector2(0, 8)
	wrap.add_child(track)

	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 0)
	track.add_child(split)

	var filled: float = clampf(fraction, 0.0, 1.0)
	var fill := PanelContainer.new()
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = color
	fill_style.set_corner_radius_all(4)
	fill.add_theme_stylebox_override("panel", fill_style)
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# A zero ratio would collapse to nothing and read as "no bar drawn"
	# rather than "zero" -- a hairline is the honest rendering of 0.
	fill.size_flags_stretch_ratio = maxf(filled, 0.01)
	split.add_child(fill)

	if filled < 1.0:
		var rest := Control.new()
		rest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rest.size_flags_stretch_ratio = 1.0 - filled
		split.add_child(rest)

func add_body(parent: Node, text: String) -> void:
	parent.add_child(_body_label(text, UiTheme.TEXT_PRIMARY))

func add_dim(parent: Node, text: String) -> void:
	parent.add_child(_body_label(text, UiTheme.TEXT_DIM))

func add_bullet(parent: Node, text: String) -> void:
	parent.add_child(_body_label("•  %s" % text, UiTheme.TEXT_PRIMARY))

## The screen's single primary action (confirm the plan / start the next
## shift), styled as an accented pill rather than a default grey Button.
func add_primary_button(text: String, on_pressed: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 54)
	button.add_theme_font_size_override("font_size", SECTION_FONT)
	UiTheme.style_pill_button(button, true)
	button.pressed.connect(on_pressed)
	content.add_child(button)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	content.add_child(spacer)

func _body_label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", BODY_FONT)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _chip(text: String, color: Color) -> Control:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UiTheme.badge_style(color))
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", SMALL_FONT)
	label.add_theme_color_override("font_color", color)
	chip.add_child(label)
	return chip

## Scrolls the content column, used by the offscreen screenshot harness to
## capture these long screens in sections without a real pointer.
func scroll_down_for_capture(pixels: int) -> void:
	if _scroll:
		_scroll.scroll_vertical += pixels
