class_name SidePanelView
extends CanvasLayer
## Shared scaffold for a right-anchored, scrollable info panel
## (IncidentPanelView, UnitPanelView) -- the common open/close/refresh
## shape and small UI-building helpers live here so they're not
## reimplemented per panel.

signal closed

var content: VBoxContainer

func _ready() -> void:
	layer = 3
	visible = false

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-380, 140) # below all 3 of HudView's stacked rows
	add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(360, 440)
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
	label.add_theme_font_size_override("font_size", 20)
	content.add_child(label)

func add_close_button() -> void:
	var button := Button.new()
	button.text = "Close"
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
