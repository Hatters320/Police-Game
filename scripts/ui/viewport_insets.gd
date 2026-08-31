class_name ViewportInsets
extends RefCounted
## How much of the game canvas the browser is covering up.
##
## Reported from a real phone: "on this particular web page provider... the
## dispatcher comments are off the bottom of the screen, but when I use
## other providers it is ok". That is browser chrome, not a layout bug in
## the game. Godot's Web export sizes its canvas to the *layout* viewport
## (`window.innerHeight`), but Safari -- and any browser with an
## overlaying bottom toolbar -- keeps the layout viewport at full height
## while painting its toolbar on top of the bottom of it. So the canvas is
## genuinely taller than the part of it you can see, and anything the game
## pins to the very bottom edge (the dispatcher feed, `offset_bottom = 0`)
## is drawn underneath the toolbar.
##
## The browser will tell us, if asked: `window.visualViewport` reports the
## actually-visible region, and the difference against `window.innerHeight`
## is exactly how much is hidden. The export's `head_include` publishes
## that continuously (it changes as the toolbar hides and shows on
## scroll); this reads it and converts to Godot's logical pixels, which is
## what the UI is laid out in.
##
## Values are cached statically and refreshed by HudView on a timer, so
## every caller sees one consistent number without each of them paying for
## its own JavaScript round trip.

## Safety cap. If a browser ever reported something absurd, better to lose
## a sensible strip of screen than to push the whole HUD out of view.
const MAX_INSET_RATIO := 0.25

static var _bottom: float = 0.0
static var _top: float = 0.0

static func bottom() -> float:
	return _bottom

static func top() -> float:
	return _top

## Re-reads the browser and updates the cache. Returns true if either
## inset actually changed, so callers can skip a relayout when nothing
## moved (which is the common case -- the toolbar is usually stable).
static func poll(viewport: Viewport) -> bool:
	var previous_bottom: float = _bottom
	var previous_top: float = _top
	var measured: Vector2 = _measure(viewport)
	_bottom = measured.y
	_top = measured.x
	return not (is_equal_approx(previous_bottom, _bottom) and is_equal_approx(previous_top, _top))

static func _measure(viewport: Viewport) -> Vector2:
	if viewport == null or not OS.has_feature("web"):
		return Vector2.ZERO
	var payload: Variant = JavaScriptBridge.eval("""
		(function () {
			var i = window.__westfordInsets;
			if (!i) { return "0,0,0"; }
			return i.top + "," + i.bottom + "," + i.cssHeight;
		})()
	""", true)
	if typeof(payload) != TYPE_STRING:
		return Vector2.ZERO
	var parts: PackedStringArray = String(payload).split(",")
	if parts.size() < 3:
		return Vector2.ZERO
	var css_height: float = parts[2].to_float()
	if css_height <= 0.0:
		return Vector2.ZERO
	# The canvas is css_height CSS pixels tall and logical_height Godot
	# units tall, so this is the scale between the browser's numbers and
	# the ones the UI is positioned in.
	var logical_height: float = viewport.get_visible_rect().size.y
	var scale: float = logical_height / css_height
	var cap: float = logical_height * MAX_INSET_RATIO
	return Vector2(
		clampf(parts[0].to_float() * scale, 0.0, cap),
		clampf(parts[1].to_float() * scale, 0.0, cap),
	)
