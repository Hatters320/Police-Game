class_name SidePanelView
extends CanvasLayer
## Shared scaffold for a scrollable info panel, anchored to either side
## (IncidentPanelView/UnitPanelView/NeighbourhoodPanelView on the right,
## ResourcesPanelView on the left, IncidentsListPanelView on the right) --
## the common open/close/refresh shape and small UI-building helpers live
## here so they're not reimplemented per panel. Subclasses override
## _panel_anchor()/_panel_height() to change side/height; right-anchored,
## ~220-tall is the default every existing panel already wants.

signal closed

var content: VBoxContainer

## Override to Control.PRESET_TOP_LEFT for a left-docked panel.
func _panel_anchor() -> int:
	return Control.PRESET_TOP_RIGHT

## Override for a taller panel (e.g. a full-length browsable list) --
## content still scrolls beyond this, it's just the visible window.
func _panel_height() -> float:
	return 174.0

func _ready() -> void:
	layer = 3
	visible = false

	var panel := PanelContainer.new()
	var anchor: int = _panel_anchor()
	panel.set_anchors_preset(anchor)
	# Below HudView's stacked rows (stats ~y12-42, controls ~y38-80,
	# overlay ~y84-124, panels ~y126-166) -- an earlier y=60 sat under the
	# overlay row's buttons, showing them ghosted through every panel's top
	# edge; y=130 later sat under the panels row added alongside it.
	panel.position = Vector2(20, 176) if anchor == Control.PRESET_TOP_LEFT else Vector2(-380, 176)
	add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(360, _panel_height())
	panel.add_child(scroll)

	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
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
	label.add_theme_font_size_override("font_size", 26)
	content.add_child(label)

func add_close_button() -> void:
	var button := Button.new()
	button.text = "Close"
	button.custom_minimum_size = Vector2(0, 52)
	button.pressed.connect(close)
	content.add_child(button)

func add_divider() -> void:
	content.add_child(HSeparator.new())

func add_mini_header(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 17)
	label.modulate = Color(0.75, 0.8, 1.0)
	content.add_child(label)

func add_line(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	content.add_child(label)

func add_dim_line(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = Color(0.6, 0.6, 0.6)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	content.add_child(label)
