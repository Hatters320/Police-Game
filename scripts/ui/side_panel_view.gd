class_name SidePanelView
extends CanvasLayer
## Shared scaffold for a scrollable info panel, anchored to either side
## (IncidentPanelView/UnitPanelView/NeighbourhoodPanelView on the right,
## ResourcesPanelView on the left, IncidentsListPanelView on the right) --
## the common open/close/refresh shape and small UI-building helpers live
## here so they're not reimplemented per panel. Subclasses override
## _panel_anchor()/_panel_height()/_panel_width() to change side/height/
## width; right-anchored, ~220-tall, 360-wide is the default every
## existing detail panel (Incident/Unit/Neighbourhood) already wants.
## ResourcesPanelView/IncidentsListPanelView additionally override
## _panel_width() down to a slim always-docked strip (spec's mockup asked
## for both permanently visible, matching desktop position, just sized
## for a phone) and _panel_layer() stays at the default so the wider
## detail panels -- overridden to a higher layer -- draw on top of them
## when both are visible.

signal closed

var content: VBoxContainer

## Override to Control.PRESET_TOP_LEFT for a left-docked panel.
func _panel_anchor() -> int:
	return Control.PRESET_TOP_RIGHT

## Just below HudView's now-thin 2-row top bar (HudView.HUD_BOTTOM), with a
## small gap.
const PANEL_TOP_Y := HudView.HUD_BOTTOM + 6.0

## Override for a taller panel (e.g. a full-length browsable list) --
## content still scrolls beyond this, it's just the visible window.
func _panel_height() -> float:
	return 200.0

## Override for a narrower panel -- the always-docked Resources/Incidents
## panels use a slim width so the map stays visible between them; every
## detail panel keeps this default, wide enough for its dispatch/welfare
## controls without dominating the screen (a real player screenshot found
## the old 360 -- unchanged since before every other panel in this pass
## shrank -- reading as "way too big... needs to just overlay the incident
## box").
func _panel_width() -> float:
	return 240.0

## Override to a higher layer so this panel draws on top of the always-
## docked Resources/Incidents panels when both are visible -- every
## existing detail panel does this; the docked panels stay at the default.
func _panel_layer() -> int:
	return 3

func _ready() -> void:
	layer = _panel_layer()
	visible = false

	var panel := PanelContainer.new()
	var anchor: int = _panel_anchor()
	panel.set_anchors_preset(anchor)
	var width: float = _panel_width()
	panel.position = Vector2(8, PANEL_TOP_Y) if anchor == Control.PRESET_TOP_LEFT else Vector2(-(width + 8.0), PANEL_TOP_Y)
	add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(width, _panel_height())
	panel.add_child(scroll)

	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	scroll.add_child(content)

func close() -> void:
	visible = false
	closed.emit()

func is_open() -> bool:
	return visible

func _show_panel() -> void:
	visible = true

func clear_content() -> void:
	for child in content.get_children():
		child.queue_free()

func add_title(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 19)
	content.add_child(label)

func add_close_button() -> void:
	var button := Button.new()
	button.text = "Close"
	button.custom_minimum_size = Vector2(0, 34)
	button.pressed.connect(close)
	content.add_child(button)

func add_divider() -> void:
	content.add_child(HSeparator.new())

func add_mini_header(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.modulate = Color(0.75, 0.8, 1.0)
	content.add_child(label)

## Content font used by every plain-text helper below -- without an
## explicit override these all inherited the project's 22px theme default
## (main.gd's DEFAULT_FONT_SIZE), which was a real contributor to panels
## reading as oversized alongside the deliberately-shrunk chrome around
## them.
const CONTENT_FONT_SIZE := 12

func add_line(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", CONTENT_FONT_SIZE)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	content.add_child(label)

func add_dim_line(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", CONTENT_FONT_SIZE)
	label.modulate = Color(0.6, 0.6, 0.6)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	content.add_child(label)

## Styled title strip (dark navy fill + bold caps label) for the always-
## docked Resources/Incidents panels -- closer to the mockup's header bars
## than add_title()'s plain label. Kept separate from add_title so every
## existing detail panel is untouched.
const HEADER_BAR_COLOR := Color(0.09, 0.16, 0.28)
func add_header_bar(text: String) -> void:
	var bar := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = HEADER_BAR_COLOR
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	bar.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text.to_upper()
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	bar.add_child(label)
	content.add_child(bar)

## Compact status card -- a colour accent strip plus a bold primary line
## and a dim secondary line, standing in for the mockup's colour-coded
## unit/incident rows since real per-type icon art isn't available this
## pass. on_pressed, when given, makes the whole card tappable (a button
## for the primary line); omit it for an informational-only row.
func add_card(accent_color: Color, primary_text: String, secondary_text: String, on_pressed: Callable = Callable()) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	content.add_child(row)

	var accent := ColorRect.new()
	accent.color = accent_color
	accent.custom_minimum_size = Vector2(5, 0)
	row.add_child(accent)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)

	if on_pressed.is_valid():
		var button := Button.new()
		button.text = primary_text
		button.flat = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 11)
		button.pressed.connect(on_pressed)
		col.add_child(button)
	else:
		var label := Label.new()
		label.text = primary_text
		label.add_theme_font_size_override("font_size", 11)
		col.add_child(label)

	var sub := Label.new()
	sub.text = secondary_text
	sub.add_theme_font_size_override("font_size", 9)
	sub.modulate = Color(0.65, 0.7, 0.8)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD
	col.add_child(sub)
