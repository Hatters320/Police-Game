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
var _panel: PanelContainer
var _scroll: ScrollContainer

## Drag-to-scroll state. Real playtesting: "the only way of scrolling the
## incident, resources or comms panel is on the side bar. This is too hard
## on the screen." It was -- the scroll bar is a few logical pixels wide,
## an awkward target on a phone, and a drag anywhere else in the panel did
## nothing at all. These track a press so a drag anywhere on the panel
## body scrolls it, the way a native mobile list behaves.
var _drag_active: bool = false
var _drag_started_scroll: int = 0
var _drag_start_pos: Vector2 = Vector2.ZERO
var _drag_exceeded_threshold: bool = false

## Movement past this many screen pixels turns a press into a scroll drag
## rather than a tap -- matched to main.gd's TAP_DRAG_THRESHOLD, which
## makes the same distinction for map gestures, so both surfaces feel the
## same under a thumb.
const DRAG_THRESHOLD := 14.0

## Override to Control.PRESET_TOP_LEFT for a left-docked panel.
func _panel_anchor() -> int:
	return Control.PRESET_TOP_RIGHT

## Just below HudView's now-thin 2-row top bar (HudView.HUD_BOTTOM), with a
## small gap.
const PANEL_TOP_Y := HudView.HUD_BOTTOM + 6.0

## Clear space left between a docked panel's bottom edge and the top of
## the dispatcher feed strip, so the two read as separate pieces of
## chrome. Real playtesting asked for exactly this: the panels "should not
## overlap the comms panel, they should stop short of that with a little
## bit of padding between them to clearly show they are different".
const DOCKED_FEED_GAP := 16.0

## Set by main.gd so a docked panel can measure itself against the feed's
## *current* height -- the feed is player-resizable, so this cannot be a
## constant. Left null for the pop-up detail panels, which don't extend
## far enough down to care.
var _hud_view: HudView

## How tall an always-docked panel can be on this device, measured from
## the real viewport rather than hard-coded.
##
## project.godot stretches canvas_items from a 640x360 base with aspect
## "expand", so the logical *height* stays around 360 on any device while
## the width varies -- which means a hard-coded panel height is really a
## fraction of the whole screen. A first attempt at "taller, by request"
## used a flat 300 and, at 360 logical tall with a panel starting at 58,
## ran the panel straight off the bottom of the screen and through the
## feed. Deriving it satisfies the request (as tall as there is room for)
## without that failure mode, and re-reading the feed's live height means
## expanding the comms box shrinks these panels rather than being
## overlapped by them.
func available_docked_height() -> float:
	var viewport_height: float = get_viewport().get_visible_rect().size.y
	var feed_height: float = _hud_view.feed_total_height() if _hud_view else 78.0
	return maxf(90.0, viewport_height - PANEL_TOP_Y - feed_height - DOCKED_FEED_GAP)

## Called by main.gd for the always-docked panels. Wiring the signal here
## rather than in main keeps "how this panel decides its own height" in
## one place.
func bind_hud(hud_view: HudView) -> void:
	_hud_view = hud_view
	hud_view.feed_height_changed.connect(_on_viewport_resized)
	_on_viewport_resized()

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
	# Rounded translucent card rather than Godot's default opaque grey
	# panel, per the supplied mockup -- the town stays faintly readable
	# behind the docked panels instead of being squared off by them.
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
	var anchor: int = _panel_anchor()
	panel.set_anchors_preset(anchor)
	var width: float = _panel_width()
	panel.position = Vector2(8, PANEL_TOP_Y) if anchor == Control.PRESET_TOP_LEFT else Vector2(-(width + 8.0), PANEL_TOP_Y)
	add_child(panel)
	_panel = panel

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(width, _panel_height())
	# Horizontal scroll left enabled (Godot's ScrollContainer default) lets
	# its child size itself down to its own content-minimum width instead
	# of filling the container -- with autowrap labels inside (which report
	# a near-zero minimum, since they *can* wrap to any width), that
	# collapsed every row to a sliver and wrapped it into a stack of tiny
	# fragments, plus a real horizontal scrollbar nothing needed. Disabling
	# it forces the child to fill the panel's actual width instead.
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_scroll = scroll
	# Rotating a phone, or any other resize, changes how much room a docked
	# panel has -- without this it would keep whatever height the viewport
	# happened to be at startup.
	get_viewport().size_changed.connect(_on_viewport_resized)

	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 4)
	scroll.add_child(content)

## Drag-anywhere scrolling for the panel body.
##
## Handled in _input (which runs before Controls get their own turn)
## rather than on the ScrollContainer's gui_input, because the cards
## inside are Buttons: they consume the press, so a drag starting on a
## card -- i.e. most of the panel's area, which is the whole complaint --
## would never reach the container. Watching here sees every press
## regardless of what sits under it.
##
## Taps still work: nothing is consumed unless the pointer actually moves
## past DRAG_THRESHOLD. Once it has, the release IS consumed, so a drag
## that happens to start on a card scrolls the list instead of also
## opening that card on release -- the same tap-versus-drag arbitration
## main.gd makes for the map.
func _input(event: InputEvent) -> void:
	if not visible or _scroll == null or _panel == null:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _panel.get_global_rect().has_point(event.position):
				_drag_active = true
				_drag_exceeded_threshold = false
				_drag_start_pos = event.position
				_drag_started_scroll = _scroll.scroll_vertical
		else:
			var was_drag: bool = _drag_exceeded_threshold
			_drag_active = false
			_drag_exceeded_threshold = false
			if was_drag:
				get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and _drag_active:
		var delta: Vector2 = event.position - _drag_start_pos
		if not _drag_exceeded_threshold and delta.length() > DRAG_THRESHOLD:
			_drag_exceeded_threshold = true
		if _drag_exceeded_threshold:
			# Content follows the finger 1:1: dragging up scrolls down.
			_scroll.scroll_vertical = _drag_started_scroll - int(delta.y)
			get_viewport().set_input_as_handled()

func _on_viewport_resized() -> void:
	if _scroll:
		_scroll.custom_minimum_size = Vector2(_panel_width(), _panel_height())

func close() -> void:
	visible = false
	_drag_active = false
	_drag_exceeded_threshold = false
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

## Styled title strip for the always-docked Resources/Incidents panels --
## the mockup's "Unit Management" / "Dispatch Queue" header rows: a
## rounded fill, title-case (not shouted caps) label, and a chevron on the
## right hinting the panel is collapsible. Kept separate from add_title so
## every existing detail panel is untouched.
const HEADER_BAR_COLOR := UiTheme.HEADER_BG
func add_header_bar(text: String) -> void:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UiTheme.header_style())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	bar.add_child(row)
	# 10px, not the body's 11: a docked panel is only _panel_width() wide
	# and loses ~12 more to the scroll bar, so at 11px "Unit Management"
	# ellipsised to "Unit Manageme..." in a real screenshot. The header is
	# the one label that should always read in full -- it names the panel.
	var label := _clipping_label(text, 10, UiTheme.HEADER_TEXT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(UiIcon.new(UiIcon.Kind.CHEVRON_DOWN, UiTheme.TEXT_DIM, 10.0))
	content.add_child(bar)

## A single-line Label that reports (almost) no minimum width, ellipsising
## instead of forcing its container wider.
##
## This matters because these docked panels set
## horizontal_scroll_mode = DISABLED (see _ready above), which makes the
## ScrollContainer adopt its child's own horizontal minimum size. Any
## non-wrapping Label inside therefore *pushes the whole panel wider than
## _panel_width()* -- and since a right-anchored panel is positioned at
## -(width + 8), growing it slides it straight off the right edge of the
## screen. A real screenshot caught exactly that: the "Dispatch Queue"
## header ran the panel off-screen, hiding its own incident rows. Every
## fixed-line label in a docked panel goes through here so no single long
## callsign, district name, or header can do that again.
func _clipping_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.custom_minimum_size = Vector2(0, 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

## Multi-line supporting text. Safe to widen a panel with (autowrap makes
## the reported minimum width near-zero), so this is the right choice
## wherever the full string genuinely matters.
func _wrapping_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

## Compact status card, matching the mockup's colour-coded unit/incident
## rows: a rounded raised fill with a coloured left edge, a status ring on
## the left, a bold primary line over a dim secondary line, and an
## optional type glyph on the right.
##
## The whole card is one tap target when on_pressed is given -- previously
## only the primary line was a Button, so tapping the (visually identical)
## second line or the accent strip did nothing, which on a phone is most
## of the row's area. A flat Button holding the layout, with every child
## set to MOUSE_FILTER_IGNORE, is what makes the entire card respond.
##
## `leading_icon`/`trailing_icon` default to RING/none so existing callers
## that pass neither still get the previous shape.
func add_card(
	accent_color: Color,
	primary_text: String,
	secondary_text: String,
	on_pressed: Callable = Callable(),
	trailing_icon: int = -1,
	status_text: String = "",
) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.card_style(accent_color))
	content.add_child(card)

	# A flat Button *behind* the content gives the whole card a single tap
	# target without the layout having to live inside the Button itself
	# (Godot Buttons size to their own text, not to added children).
	if on_pressed.is_valid():
		var hit := Button.new()
		hit.flat = true
		hit.set_anchors_preset(Control.PRESET_FULL_RECT)
		hit.pressed.connect(on_pressed)
		card.add_child(hit)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)

	var ring := UiIcon.new(UiIcon.Kind.RING, accent_color, 13.0)
	row.add_child(ring)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)

	# Title clips: a callsign is a short identifier, and truncating one is
	# far better than letting it widen (and so slide off-screen) the whole
	# panel. The lines below it wrap instead -- an autowrapping Label
	# reports a near-zero minimum width, so it is already safe from the
	# overflow described on _clipping_label, and wrapping shows a district
	# name or queue state in full rather than cutting it short.
	col.add_child(_clipping_label(primary_text, 11, UiTheme.TEXT_PRIMARY))
	col.add_child(_wrapping_label(secondary_text, 9, UiTheme.TEXT_DIM))

	# The mockup's third line ("On Scene", "Assigned") -- the row's live
	# state, tinted to the same accent as its edge so state and colour
	# reinforce each other rather than the colour being the only cue.
	if status_text != "":
		col.add_child(_wrapping_label(status_text, 9, accent_color))

	if trailing_icon >= 0:
		row.add_child(UiIcon.new(trailing_icon as UiIcon.Kind, UiTheme.TEXT_DIM, 13.0))
