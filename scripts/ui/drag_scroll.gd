class_name DragScroll
extends Node
## Makes a ScrollContainer scrollable by dragging anywhere on its body,
## the way a native mobile list behaves, instead of only via its scroll
## bar.
##
## Real playtesting drove every detail here. First: "the only way of
## scrolling the incident, resources or comms panel is on the side bar.
## This is too hard on the screen" -- the bar is a few logical pixels
## wide, an awkward thumb target. Then, after a first pass: "the scroll
## function in the comms panel is still very glitchy - it's hard to move
## even when made big", which is what the tuning below is for.
##
## Why _input rather than the ScrollContainer's own gui_input: the rows
## inside these panels are Buttons, which consume the press. A drag
## starting on a row -- i.e. most of the panel's area, which is the whole
## complaint -- would never reach the container. Watching input before
## Controls get their turn sees every press regardless of what sits under
## it.
##
## Taps are preserved: nothing is consumed until the pointer actually
## moves past DRAG_THRESHOLD, and only then is the release swallowed, so a
## drag that happens to begin on a row scrolls the list instead of also
## activating that row -- the same tap-versus-drag arbitration main.gd
## makes for map gestures.

## Deliberately small. The first version used 14 (matching main.gd's map
## threshold) and that is too much on a phone: a short thumb flick did
## nothing at all, which reads as "hard to move". A map pan can afford to
## wait longer before committing because a mis-read tap there is costly;
## in a list, responsiveness matters more.
const DRAG_THRESHOLD := 5.0

## Flick inertia. Without it the list stops dead the instant the finger
## lifts, which feels stiff and means browsing a long feed takes many
## small drags rather than one flick.
const FRICTION := 6.0
const MIN_FLICK_VELOCITY := 40.0
const MAX_FLICK_VELOCITY := 3000.0

var _scroll: ScrollContainer
var _hit_rect_source: Control
## Optional gate: return false to ignore input entirely this frame (used
## so a modal detail panel can stop the lists behind it from scrolling).
var _enabled_check: Callable = Callable()

var _active: bool = false
var _exceeded: bool = false
var _start_pos: Vector2 = Vector2.ZERO
var _start_scroll: int = 0
var _last_pos: Vector2 = Vector2.ZERO
var _velocity: float = 0.0

static func attach(owner: Node, scroll: ScrollContainer, hit_rect_source: Control, enabled_check: Callable = Callable()) -> DragScroll:
	var helper := DragScroll.new()
	helper._scroll = scroll
	helper._hit_rect_source = hit_rect_source
	helper._enabled_check = enabled_check
	owner.add_child(helper)
	return helper

func _ready() -> void:
	set_process(true)

## Coasts after a flick, easing to a stop rather than halting dead.
func _process(delta: float) -> void:
	if _active or is_zero_approx(_velocity) or _scroll == null:
		return
	_scroll.scroll_vertical = int(_scroll.scroll_vertical - _velocity * delta)
	_velocity = move_toward(_velocity, 0.0, FRICTION * absf(_velocity) * delta + 20.0 * delta)

## Buttons neutralised for the duration of a drag, with the mouse_filter
## each one had before, so they can be restored exactly.
var _suppressed: Dictionary = {}

func _suppress_buttons() -> void:
	if _scroll == null:
		return
	_collect_buttons(_scroll)

func _collect_buttons(node: Node) -> void:
	for child in node.get_children():
		if child is BaseButton:
			var button := child as BaseButton
			if not _suppressed.has(button):
				_suppressed[button] = button.mouse_filter
				# Un-press it first: a Button already holding a press would
				# otherwise stay visually held for the rest of the gesture.
				button.set_pressed_no_signal(false)
				button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_collect_buttons(child)

func _restore_buttons() -> void:
	for button in _suppressed:
		if is_instance_valid(button):
			button.mouse_filter = _suppressed[button]
	_suppressed.clear()

func _usable() -> bool:
	if _scroll == null or _hit_rect_source == null:
		return false
	if not _hit_rect_source.is_visible_in_tree():
		return false
	if _enabled_check.is_valid() and not _enabled_check.call():
		return false
	return true

func _input(event: InputEvent) -> void:
	if not _usable():
		return

	# Real touch devices deliver ScreenTouch/ScreenDrag; Godot's touch
	# emulation (left on -- see main.gd) also produces mouse events on
	# web/mobile. Handling both means this works on a desktop browser and
	# under a real thumb, rather than only where the emulation happens to
	# fire.
	var pressed_event := false
	var released_event := false
	var moved_event := false
	var pos := Vector2.ZERO

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
		pressed_event = event.pressed
		released_event = not event.pressed
	elif event is InputEventScreenTouch:
		pos = event.position
		pressed_event = event.pressed
		released_event = not event.pressed
	elif event is InputEventMouseMotion or event is InputEventScreenDrag:
		pos = event.position
		moved_event = true
	else:
		return

	if pressed_event:
		if _hit_rect_source.get_global_rect().has_point(pos):
			_active = true
			_exceeded = false
			_start_pos = pos
			_last_pos = pos
			_start_scroll = _scroll.scroll_vertical
			_velocity = 0.0 # a new touch stops any coast, like a real list
		return

	if released_event:
		var was_drag: bool = _exceeded
		_active = false
		_exceeded = false
		_restore_buttons()
		if was_drag:
			if absf(_velocity) < MIN_FLICK_VELOCITY:
				_velocity = 0.0
			get_viewport().set_input_as_handled()
		return

	if moved_event and _active:
		var delta_from_start: Vector2 = pos - _start_pos
		if not _exceeded and delta_from_start.length() > DRAG_THRESHOLD:
			_exceeded = true
			# Consuming the release is not enough on its own: the Buttons
			# inside already received the press, and a Button that has been
			# pressed will still fire when the pointer comes up. Real
			# playtesting: "when you scroll through the incidents they are
			# very sensitive so one opens up whilst you are scrolling even
			# though you didn't want it to." Making them ignore the mouse
			# for the rest of the gesture un-presses them and guarantees no
			# row can activate from a scroll; _restore_buttons puts them
			# back on release.
			_suppress_buttons()
		if _exceeded:
			_scroll.scroll_vertical = _start_scroll - int(delta_from_start.y)
			# Track instantaneous velocity for the flick, smoothed a little
			# so one jittery sample can't fling the list.
			var step: float = pos.y - _last_pos.y
			var frame_time: float = maxf(get_process_delta_time(), 0.0001)
			_velocity = clampf(lerpf(_velocity, step / frame_time, 0.4), -MAX_FLICK_VELOCITY, MAX_FLICK_VELOCITY)
			_last_pos = pos
			get_viewport().set_input_as_handled()
