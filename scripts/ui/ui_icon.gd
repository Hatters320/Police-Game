class_name UiIcon
extends Control
## A single small vector icon, drawn in code via _draw().
##
## The supplied design mockup leans heavily on icons -- a clock beside the
## shift time, a rain cloud beside the weather, a car on each unit row, a
## house/magnifier/hand per incident type, chevrons on collapsible panel
## headers. The project has no icon art at all and no .tscn authoring (see
## main.gd's header for why), and pulling in an icon font would mean a new
## binary asset plus licence tracking for what amounts to a dozen simple
## shapes. Drawing them with Godot's own primitives keeps them resolution-
## independent, recolourable per-instance (every unit row tints the same
## CAR glyph to its own status colour), and costs no import step.
##
## Deliberately simple silhouettes, not detailed illustrations: these
## render at 10-14px on a phone, where anything more detailed turns to
## mush. Each is drawn inside a normalised 0..1 box and scaled to size, so
## one glyph definition works at any icon size.

enum Kind {
	CLOCK,
	RAIN,
	CLEAR,
	SHIELD,
	PEOPLE,
	FATIGUE,
	CAR,
	HOUSE,
	MAGNIFIER,
	HAND,
	ALERT,
	CHEVRON_DOWN,
	CHEVRON_UP,
	LAYERS,
	PLUS,
	RING,
}

var kind: Kind = Kind.CLOCK
var color: Color = UiTheme.TEXT_PRIMARY
## Filled ring vs outline ring, for the mockup's per-unit status circles.
var filled: bool = false

func _init(icon_kind: Kind = Kind.CLOCK, icon_color: Color = UiTheme.TEXT_PRIMARY, icon_size: float = 12.0) -> void:
	kind = icon_kind
	color = icon_color
	custom_minimum_size = Vector2(icon_size, icon_size)
	# Icons are decorative labels beside real text/controls -- they must
	# never eat a tap meant for the row or button they sit inside.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Containers stretch a plain Control to fill the axis they lay out
	# against -- an HBox row as tall as a three-line card would stretch
	# this to match, and since every glyph below is authored in normalised
	# 0..1 coordinates, that stretched the artwork with it (a real
	# screenshot showed the CAR glyph pulled tall with its wheels detached
	# below the body as two stray dots). Shrinking on both axes keeps the
	# control at its own square custom_minimum_size instead.
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER

func set_icon_color(new_color: Color) -> void:
	color = new_color
	queue_redraw()

## Normalised (0..1) point -> real pixel position inside this control.
##
## Every glyph is authored against a square reference box so its
## proportions never depend on how the surrounding container happened to
## size this node: the box is the largest square that fits, centred, and
## _draw's own line widths derive from the same edge length. Belt and
## braces alongside the SIZE_SHRINK_CENTER flags above -- those stop the
## stretch, this makes a stretch harmless if one ever gets through.
func _p(x: float, y: float) -> Vector2:
	var edge: float = minf(size.x, size.y)
	var origin := Vector2((size.x - edge) * 0.5, (size.y - edge) * 0.5)
	return origin + Vector2(x * edge, y * edge)

func _draw() -> void:
	var w: float = minf(size.x, size.y)
	var line_width: float = maxf(1.0, w * 0.12)
	match kind:
		Kind.CLOCK:
			draw_arc(_p(0.5, 0.5), w * 0.42, 0.0, TAU, 20, color, line_width)
			draw_line(_p(0.5, 0.5), _p(0.5, 0.26), color, line_width)
			draw_line(_p(0.5, 0.5), _p(0.70, 0.58), color, line_width)
		Kind.RAIN:
			# Cloud lobes plus two falling strokes.
			draw_circle(_p(0.36, 0.42), w * 0.18, color)
			draw_circle(_p(0.60, 0.40), w * 0.21, color)
			draw_rect(Rect2(_p(0.30, 0.42), Vector2(w * 0.42, w * 0.16)), color)
			draw_line(_p(0.38, 0.68), _p(0.32, 0.86), color, line_width)
			draw_line(_p(0.62, 0.68), _p(0.56, 0.86), color, line_width)
		Kind.CLEAR:
			# Sun: disc plus four cardinal rays (kept to four, not eight --
			# at 12px eight rays merge into a blur).
			draw_circle(_p(0.5, 0.5), w * 0.24, color)
			draw_line(_p(0.5, 0.06), _p(0.5, 0.20), color, line_width)
			draw_line(_p(0.5, 0.80), _p(0.5, 0.94), color, line_width)
			draw_line(_p(0.06, 0.5), _p(0.20, 0.5), color, line_width)
			draw_line(_p(0.80, 0.5), _p(0.94, 0.5), color, line_width)
		Kind.SHIELD:
			draw_colored_polygon(PackedVector2Array([
				_p(0.5, 0.08), _p(0.88, 0.26), _p(0.88, 0.56),
				_p(0.5, 0.92), _p(0.12, 0.56), _p(0.12, 0.26),
			]), color)
		Kind.PEOPLE:
			# Two overlapping head+shoulder silhouettes.
			draw_circle(_p(0.34, 0.32), w * 0.15, color)
			draw_circle(_p(0.66, 0.32), w * 0.15, color)
			draw_rect(Rect2(_p(0.14, 0.55), Vector2(w * 0.34, w * 0.30)), color)
			draw_rect(Rect2(_p(0.52, 0.55), Vector2(w * 0.34, w * 0.30)), color)
		Kind.FATIGUE:
			# A struck-through circle -- reads as "none flagged" at a glance
			# and matches the mockup's crossed-out fatigue chip.
			draw_arc(_p(0.5, 0.5), w * 0.38, 0.0, TAU, 18, color, line_width)
			draw_line(_p(0.24, 0.76), _p(0.76, 0.24), color, line_width)
		Kind.CAR:
			# Body, cabin, two wheels -- the smallest shape that still reads
			# as a car rather than a generic box at this size.
			draw_rect(Rect2(_p(0.08, 0.46), Vector2(w * 0.84, w * 0.26)), color)
			draw_colored_polygon(PackedVector2Array([
				_p(0.26, 0.46), _p(0.36, 0.26), _p(0.66, 0.26), _p(0.76, 0.46),
			]), color)
			draw_circle(_p(0.28, 0.76), w * 0.11, color)
			draw_circle(_p(0.72, 0.76), w * 0.11, color)
		Kind.HOUSE:
			draw_colored_polygon(PackedVector2Array([
				_p(0.5, 0.12), _p(0.92, 0.48), _p(0.08, 0.48),
			]), color)
			draw_rect(Rect2(_p(0.20, 0.48), Vector2(w * 0.60, w * 0.40)), color)
		Kind.MAGNIFIER:
			draw_arc(_p(0.42, 0.42), w * 0.28, 0.0, TAU, 20, color, line_width)
			draw_line(_p(0.62, 0.62), _p(0.88, 0.88), color, line_width * 1.2)
		Kind.HAND:
			# Palm plus three fingers -- the mockup's "on scene / hands on"
			# marker.
			draw_rect(Rect2(_p(0.30, 0.44), Vector2(w * 0.42, w * 0.42)), color)
			draw_rect(Rect2(_p(0.32, 0.18), Vector2(w * 0.10, w * 0.30)), color)
			draw_rect(Rect2(_p(0.46, 0.12), Vector2(w * 0.10, w * 0.36)), color)
			draw_rect(Rect2(_p(0.60, 0.20), Vector2(w * 0.10, w * 0.28)), color)
		Kind.ALERT:
			draw_colored_polygon(PackedVector2Array([
				_p(0.5, 0.10), _p(0.94, 0.86), _p(0.06, 0.86),
			]), color)
		Kind.CHEVRON_DOWN:
			draw_line(_p(0.22, 0.38), _p(0.5, 0.66), color, line_width)
			draw_line(_p(0.5, 0.66), _p(0.78, 0.38), color, line_width)
		Kind.CHEVRON_UP:
			draw_line(_p(0.22, 0.62), _p(0.5, 0.34), color, line_width)
			draw_line(_p(0.5, 0.34), _p(0.78, 0.62), color, line_width)
		Kind.LAYERS:
			# Three stacked diamonds, echoing the isometric town below.
			for i in 3:
				var y: float = 0.28 + i * 0.22
				draw_polyline(PackedVector2Array([
					_p(0.5, y - 0.14), _p(0.86, y), _p(0.5, y + 0.14), _p(0.14, y), _p(0.5, y - 0.14),
				]), color, line_width)
		Kind.PLUS:
			draw_line(_p(0.5, 0.18), _p(0.5, 0.82), color, line_width)
			draw_line(_p(0.18, 0.5), _p(0.82, 0.5), color, line_width)
		Kind.RING:
			if filled:
				draw_circle(_p(0.5, 0.5), w * 0.34, color)
			else:
				draw_arc(_p(0.5, 0.5), w * 0.34, 0.0, TAU, 20, color, maxf(1.5, w * 0.16))
