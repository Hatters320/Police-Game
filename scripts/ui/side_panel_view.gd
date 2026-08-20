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

## Drag-anywhere scrolling lives in DragScroll (see that file for why it
## watches _input rather than the ScrollContainer's gui_input, and for the
## flick/threshold tuning real playtesting called for).
var _drag_scroll: DragScroll
var _scrim: ColorRect

## Group every modal detail panel joins, so any panel can ask "is
## something modal open above me?" without needing a reference to each
## one individually.
const MODAL_PANEL_GROUP := "modal_side_panel"

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

	# A modal detail panel gets a full-screen scrim behind it. It dims the
	# scene slightly so the pop-up reads as "the thing you are dealing with
	# now", and -- because it sits above every other layer's content and
	# stops mouse events -- it also stops taps and drags reaching the map
	# and the docked lists underneath. Real playtesting: "when you click on
	# an incident, the scroll screen function still moves the lists of
	# incidents beneath it... this pop up box of the incident needs to take
	# priority until it is closed."
	if _is_modal():
		_scrim = ColorRect.new()
		_scrim.color = Color(0.03, 0.05, 0.09, 0.45)
		_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
		_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
		# Hidden explicitly, and toggled with the panel below, rather than
		# relying on the CanvasLayer's own `visible` to suppress it: it does
		# not, and a real screenshot caught all three modal panels' scrims
		# darkening the entire game -- HUD included -- before any of them
		# had been opened (the top bar measured (39,52,75) before this and
		# (17,25,39) after, i.e. dimmed while supposedly hidden).
		_scrim.visible = false
		# Tapping outside the pop-up dismisses it. Without this the scrim
		# swallowed the tap and did nothing with it, so the only way out was
		# the Close button at the bottom of the panel's own scroll -- real
		# playtesting: "the pop up got stuck on the page and then I couldn't
		# remove it by clicking off of it."
		_scrim.gui_input.connect(_on_scrim_input)
		add_child(_scrim)

	var panel := PanelContainer.new()
	# Rounded translucent card rather than Godot's default opaque grey
	# panel, per the supplied mockup -- the town stays faintly readable
	# behind the docked panels instead of being squared off by them.
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
	var anchor: int = _panel_anchor()
	panel.set_anchors_preset(anchor)
	var width: float = _panel_width()
	match anchor:
		Control.PRESET_TOP_LEFT:
			panel.position = Vector2(8, PANEL_TOP_Y)
		Control.PRESET_CENTER:
			# PRESET_CENTER anchors all four sides at 0.5, so offsets are
			# measured from the middle of the screen -- half the panel's own
			# size back up and left puts its centre on the screen's centre.
			panel.position = Vector2(-width * 0.5, -_panel_height() * 0.5)
		_:
			panel.position = Vector2(-(width + 8.0), PANEL_TOP_Y)
	add_child(panel)
	_panel = panel

	# An always-visible dismiss control, pinned to the panel's own top-right
	# corner rather than living in the scrolling content. The Close button
	# at the end of add_close_button() scrolls away with everything else,
	# which on a long incident pop-up means the exit is off-screen exactly
	# when a player wants it.
	if _is_modal():
		var dismiss := Button.new()
		dismiss.text = "X"
		dismiss.custom_minimum_size = Vector2(22, 20)
		dismiss.add_theme_font_size_override("font_size", 11)
		UiTheme.style_pill_button(dismiss, false)
		dismiss.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		dismiss.position = Vector2(-26, 2)
		dismiss.pressed.connect(close)
		panel.add_child(dismiss)

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
	# A drag anywhere on the panel body scrolls it. The gate stops a
	# *docked* list from scrolling while a modal detail panel is open on
	# top of it -- real playtesting: "when you click on an incident, the
	# scroll screen function still moves the lists of incidents beneath
	# it... this pop up box needs to take priority until it is closed."
	_drag_scroll = DragScroll.attach(self, scroll, panel, _drag_scroll_allowed)
	if _is_modal():
		add_to_group(MODAL_PANEL_GROUP)
	# Rotating a phone, or any other resize, changes how much room a docked
	# panel has -- without this it would keep whatever height the viewport
	# happened to be at startup.
	get_viewport().size_changed.connect(_on_viewport_resized)

	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 4)
	scroll.add_child(content)

## Dismisses the pop-up when the player taps the dimmed area outside it.
func _on_scrim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		close()
	elif event is InputEventScreenTouch and not event.pressed:
		close()

## A panel accepts drag-scrolling only when nothing modal sits above it.
func _drag_scroll_allowed() -> bool:
	return _is_modal() or not _any_modal_panel_open()

## Whether this panel takes over the screen when open: dimming what is
## behind it and owning input until closed.
##
## Declared explicitly by each panel rather than inferred from
## _panel_layer(). A first version inferred it (layer > 2) and got it
## wrong: the always-docked Resources/Incidents lists do not override
## _panel_layer, so they sit at the same default 3 as the detail panels
## and were treated as modal too. Since those two are open for the whole
## shift, their scrims dimmed the entire game permanently -- the HUD's own
## top bar measured (39,52,75) before and (12,18,29) after, which is
## exactly one 0.45 scrim composited over it.
func _is_modal() -> bool:
	return false

func _any_modal_panel_open() -> bool:
	for node in get_tree().get_nodes_in_group(MODAL_PANEL_GROUP):
		var panel_view := node as SidePanelView
		if panel_view != null and panel_view.visible:
			return true
	return false

## Re-sizes the panel when the viewport changes (rotation) or when the
## player resizes the dispatcher feed, so a docked panel keeps clear of it.
func _on_viewport_resized() -> void:
	if _scroll:
		_scroll.custom_minimum_size = Vector2(_panel_width(), _panel_height())

func close() -> void:
	visible = false
	if _scrim:
		_scrim.visible = false
	closed.emit()

func is_open() -> bool:
	return visible

func _show_panel() -> void:
	visible = true
	if _scrim:
		_scrim.visible = true

func clear_content() -> void:
	for child in content.get_children():
		child.queue_free()

## One type scale for every panel, so a single panel can't end up mixing
## four different sizes the way the incident pop-up did before real
## playtesting called it out ("this pop up box needs better UI as well.
## All the text is different sizes etc."). TITLE for the one panel title,
## SECTION for group headers, CONTENT for body text, SMALL for supporting
## detail. Nothing should introduce a size outside this scale.
const TITLE_FONT_SIZE := 15
const SECTION_FONT_SIZE := 11
const SMALL_FONT_SIZE := 10

func add_title(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	label.add_theme_color_override("font_color", UiTheme.TEXT_PRIMARY)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	content.add_child(label)

func add_close_button() -> void:
	var button := Button.new()
	button.text = "Close"
	button.custom_minimum_size = Vector2(0, 26)
	button.add_theme_font_size_override("font_size", CONTENT_FONT_SIZE)
	UiTheme.style_pill_button(button, false)
	button.pressed.connect(close)
	content.add_child(button)

func add_divider() -> void:
	var line := ColorRect.new()
	line.color = UiTheme.PANEL_BORDER
	line.custom_minimum_size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(line)

func add_mini_header(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", SECTION_FONT_SIZE)
	label.add_theme_color_override("font_color", UiTheme.TEXT_ACCENT)
	content.add_child(label)

## A short piece of advice, tinted by how strongly it is meant: green for
## "this is the sensible next move", amber for "this needs attention".
func add_advice(text: String, urgent: bool = false) -> void:
	var row := PanelContainer.new()
	var accent: Color = Color(0.95, 0.65, 0.3) if urgent else Color(0.5, 0.85, 0.5)
	row.add_theme_stylebox_override("panel", UiTheme.card_style(accent))
	content.add_child(row)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", CONTENT_FONT_SIZE)
	label.add_theme_color_override("font_color", UiTheme.TEXT_PRIMARY)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)

## Coloured priority chip ("P1 CRITICAL") for the pop-up header.
func add_badge(text: String, color: Color) -> void:
	var row := HBoxContainer.new()
	content.add_child(row)
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UiTheme.badge_style(color))
	badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(badge)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", SMALL_FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	badge.add_child(label)

## Label + action button on one row, at the shared type scale -- every
## deploy/request row in the incident pop-up goes through here so they
## can't drift apart from each other again.
func add_action_row(text: String, button_text: String, on_pressed: Callable, highlight: bool = false) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	content.add_child(row)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", CONTENT_FONT_SIZE)
	label.add_theme_color_override("font_color", Color(0.55, 0.9, 0.55) if highlight else UiTheme.TEXT_PRIMARY)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(0, 24)
	button.add_theme_font_size_override("font_size", SMALL_FONT_SIZE)
	UiTheme.style_pill_button(button, highlight)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(on_pressed)
	row.add_child(button)

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
