class_name UiTheme
## Shared visual language for the whole HUD -- palette, corner radii, and
## StyleBoxFlat factories, in one place so every panel/chip/pill reads as
## part of one designed interface rather than each view inventing its own
## colours and margins (which is exactly what the pre-mockup HUD did: raw
## default Buttons up top, one ad-hoc StyleBoxFlat in hud_view for the
## feed, another in side_panel_view for header bars, no relationship
## between them).
##
## Built from a real design mockup the player supplied, not invented:
## rounded translucent navy cards, a thin light border, colour-coded
## accents (unit status / incident priority), and icon+label chips instead
## of bare text. What the mockup could NOT dictate is size -- it's a wide
## desktop frame, whereas this game's sizing was driven down hard by real
## phone playtesting ("the sizes of all the menus and panel boxes needs to
## be reduced... top menu should be long and thin along the top", see
## HudView's own header). So this pass takes the mockup's *look* (shape,
## colour, hierarchy, icons) while keeping the hard-won compact metrics --
## the fonts and bar heights stay where phone testing put them.

## Panel/card fills. Translucent so the 3D town still reads behind the
## chrome (the mockup's panels are visibly see-through over the city),
## with the raised variant for cards sitting *inside* a panel so they
## separate from their own container without a second border.
const PANEL_BG := Color(0.07, 0.10, 0.16, 0.88)
const PANEL_BG_RAISED := Color(0.11, 0.15, 0.23, 0.92)
const PANEL_BORDER := Color(0.30, 0.42, 0.60, 0.55)

## Header strips inside a panel (the mockup's "Unit Management" /
## "Dispatch Queue" title rows).
const HEADER_BG := Color(0.10, 0.15, 0.24, 0.95)
const HEADER_TEXT := Color(0.88, 0.92, 0.98)

## Body text tiers -- primary for a card's own name/title, dim for the
## supporting line under it, accent for the "Dispatcher:" speaker prefix
## and any other interactive/emphasised text.
const TEXT_PRIMARY := Color(0.93, 0.95, 1.0)
const TEXT_DIM := Color(0.58, 0.65, 0.76)
const TEXT_ACCENT := Color(0.45, 0.70, 1.0)

## Speed/segmented controls: a flat translucent pill, brightening on hover
## and switching to a clearly-outlined accent fill when it's the active
## choice -- the mockup shows the current speed ("1x") and the current
## panel ("Inc") both called out this way, which the old HUD had no way of
## showing at all (every speed button looked identical whatever was
## actually selected).
const PILL_BG := Color(0.13, 0.18, 0.27, 0.85)
const PILL_BG_HOVER := Color(0.18, 0.24, 0.35, 0.9)
const PILL_BG_ACTIVE := Color(0.16, 0.33, 0.55, 0.95)
const PILL_BORDER_ACTIVE := Color(0.45, 0.70, 1.0, 0.9)

## Corner radii -- panels are the roundest, chips/pills slightly less, so
## nested elements don't fight the container's own curve.
const RADIUS_PANEL := 10
const RADIUS_CARD := 8
const RADIUS_PILL := 7

## Rounded translucent container, the base shape everything else sits in.
static func panel_style(bg: Color = PANEL_BG, radius: int = RADIUS_PANEL) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = PANEL_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

## Card inside a panel -- no border (the fill alone separates it from the
## panel behind), and an optional coloured left edge standing in for the
## mockup's status stripe down each unit/incident row.
static func card_style(accent: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG_RAISED
	style.set_corner_radius_all(RADIUS_CARD)
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	if accent != Color.TRANSPARENT:
		style.border_color = accent
		style.border_width_left = 3
	return style

## Title strip at the top of a docked panel.
static func header_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = HEADER_BG
	style.set_corner_radius_all(RADIUS_CARD)
	style.content_margin_left = 8
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style

## One state of a pill button. `active` is the selected/current choice
## (accent fill + bright outline); `hover` is the pointer-over variant of
## whichever of those two applies.
static func pill_style(active: bool, hover: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if active:
		style.bg_color = PILL_BG_ACTIVE
		style.border_color = PILL_BORDER_ACTIVE
		style.set_border_width_all(1)
	else:
		style.bg_color = PILL_BG_HOVER if hover else PILL_BG
		style.border_color = Color(0.30, 0.42, 0.60, 0.35)
		style.set_border_width_all(1)
	style.set_corner_radius_all(RADIUS_PILL)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style

## Applies the full normal/hover/pressed/focus set to a Button in one call
## -- Godot styles those independently, and leaving any of them unset
## means that state silently falls back to the engine's default grey box,
## which would show through the moment a player actually touched a
## control.
static func style_pill_button(button: Button, active: bool) -> void:
	button.add_theme_stylebox_override("normal", pill_style(active))
	button.add_theme_stylebox_override("hover", pill_style(active, true))
	button.add_theme_stylebox_override("pressed", pill_style(true))
	button.add_theme_stylebox_override("focus", pill_style(active))
	button.add_theme_color_override("font_color", TEXT_PRIMARY if active else TEXT_DIM)
	button.add_theme_color_override("font_hover_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_pressed_color", TEXT_PRIMARY)

## Small solid rounded badge -- the mockup's "P1"/"P5" priority chips.
static func badge_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.22)
	style.border_color = color
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	return style
