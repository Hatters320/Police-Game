class_name RotatePromptOverlay
extends CanvasLayer
## Web export has no way to lock device orientation the way a native
## mobile export can (spec section 56's mobile-first intent is enforced
## by `window/handheld/orientation="landscape"` in project.godot, which
## only applies to native builds) -- so a phone held in portrait would
## otherwise see this game's fixed-width HUD/panels overflow sideways.
## This blocks play with a clear instruction instead, until the viewport
## reports landscape again.

var _label: Label

func _ready() -> void:
	layer = 10 # above every other CanvasLayer, including DebriefView's layer 5
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.04, 0.06, 0.97)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP # blocks clicks reaching the game underneath
	add_child(dim)

	_label = Label.new()
	_label.text = "Rotate your device to landscape to play Westford."
	_label.add_theme_font_size_override("font_size", 26)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	dim.add_child(_label)

	get_viewport().size_changed.connect(_refresh)
	_refresh()

## get_viewport().get_visible_rect().size reports the project's logical
## viewport size (fixed regardless of actual window/canvas size on Web --
## confirmed empirically against a real exported build), not the real
## displayed size, so orientation has to be read from the actual window.
func _refresh() -> void:
	var size: Vector2i = DisplayServer.window_get_size()
	visible = size.x < size.y
