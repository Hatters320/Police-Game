extends Node
## Screenshot harness for the two full-screen shift screens.
##
## Boots the real game scene, captures the briefing in scrolled sections,
## confirms it through the view's own handler, fast-forwards to shift end
## and captures the debrief the same way. Exists because those two screens
## are otherwise slow to reach for a visual check: a shift is twelve
## simulated hours, so the debrief is well beyond what a browser
## screenshot pass can sit through, and keyboard input does not reliably
## reach the Godot canvas through a headless browser.
##
## Run it with a virtual display, since it needs real rendering:
##
##     xvfb-run -a godot4 --rendering-driver opengl3 \
##         --resolution 892x412 tests/capture_shift_screens.tscn
##
## PNGs land in /tmp/shots. Companion to run_shift_debug.gd, which covers
## the simulation side headlessly.

var _shots := 0
var _out := "/tmp/shots"
var _main: Node

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	get_window().size = Vector2i(892, 412)
	await get_tree().create_timer(3.0).timeout
	_main = get_parent().get_node_or_null("Main")
	print("main node: ", _main)
	await _capture_scroll("briefing", 10)
	# Confirm the briefing through the view's own signal path.
	var briefing = _main.get("_briefing_view")
	if briefing != null:
		briefing._on_confirm_pressed()
	await get_tree().create_timer(1.5).timeout
	Simulation.core.fast_forward_shift()
	await get_tree().create_timer(2.0).timeout
	await _capture_scroll("debrief", 12)
	print("DONE")
	get_tree().quit()

func _capture_scroll(prefix: String, frames: int) -> void:
	var view = _main.get("_briefing_view") if prefix == "briefing" else _main.get("_debrief_view")
	for i in range(frames):
		await RenderingServer.frame_post_draw
		await get_tree().process_frame
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png("%s/%s_%02d.png" % [_out, prefix, i])
		if view != null and view.has_method("scroll_down_for_capture"):
			view.scroll_down_for_capture(300)
		await get_tree().create_timer(0.15).timeout
