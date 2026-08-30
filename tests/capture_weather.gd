extends Node
## Weather + day/night animation harness.
##
## Forces each weather type in turn, captures two frames a short interval
## apart, and reports how much the screen actually changed between them --
## so "the rain animates" is a measured claim rather than an eyeballed
## one. Also sweeps the clock across a dawn to capture the light changing.
##
## Needs real rendering, so run it on a virtual display:
##
##     xvfb-run -a godot4 --rendering-driver opengl3 \
##         --resolution 892x412 tests/capture_weather.tscn

const OUT := "/tmp/weather"

var _main: Node

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	await get_tree().create_timer(3.0).timeout
	_main = get_parent().get_node_or_null("Main")
	var briefing = _main.get("_briefing_view")
	if briefing != null:
		briefing._on_confirm_pressed()
	await get_tree().create_timer(2.0).timeout

	for pair in [
		[GameEnums.WeatherType.CLEAR, "clear"],
		[GameEnums.WeatherType.RAIN, "rain"],
		[GameEnums.WeatherType.SNOW, "snow"],
		[GameEnums.WeatherType.FOG, "fog"],
	]:
		Simulation.core.weather_manager.current_weather = pair[0]
		_main.weather_overlay.refresh()
		await get_tree().create_timer(0.6).timeout
		var a: Image = await _grab()
		await get_tree().create_timer(0.35).timeout
		var b: Image = await _grab()
		await get_tree().create_timer(1.8).timeout
		var c: Image = await _grab()
		a.save_png("%s/%s_a.png" % [OUT, pair[1]])
		b.save_png("%s/%s_b.png" % [OUT, pair[1]])
		# Two intervals, because the three effects move at wildly different
		# speeds: rain crosses the screen in under a second while fog drifts
		# a few pixels, so a single short interval would understate fog to
		# the point of looking static when it is not. The town's own traffic
		# animates regardless of weather, so "clear" is the noise floor
		# these are read against, not zero.
		print("%-6s change over 0.35s: %5.2f%%   over 2.15s: %5.2f%%" % [
			pair[1], _diff_percent(a, b), _diff_percent(a, c)])

	# Per-weather frame cost. The browser FPS A/B can only measure whatever
	# weather happened to roll that shift, and fog -- the most expensive of
	# the three, since its blobs are very large -- is also the rarest. This
	# forces each in turn and counts real frames over a fixed wall-clock
	# window, so the costs are directly comparable.
	for pair in [
		[GameEnums.WeatherType.CLEAR, "clear"],
		[GameEnums.WeatherType.RAIN, "rain"],
		[GameEnums.WeatherType.SNOW, "snow"],
		[GameEnums.WeatherType.FOG, "fog"],
	]:
		Simulation.core.weather_manager.current_weather = pair[0]
		_main.weather_overlay.refresh()
		await get_tree().create_timer(0.5).timeout
		var frames := 0
		var started: int = Time.get_ticks_msec()
		while Time.get_ticks_msec() - started < 4000:
			await get_tree().process_frame
			frames += 1
		var elapsed: float = float(Time.get_ticks_msec() - started) / 1000.0
		print("%-6s %.1f fps (%d frames in %.1fs)" % [pair[1], frames / elapsed, frames, elapsed])

	# Dawn sweep: same shift, clock walked across sunrise.
	Simulation.core.weather_manager.current_weather = GameEnums.WeatherType.CLEAR
	_main.weather_overlay.refresh()
	for hour in [4, 6, 7, 9, 13, 18, 20, 22]:
		Simulation.core.game_clock.total_minutes = hour * 60
		await get_tree().create_timer(0.25).timeout
		var img: Image = await _grab()
		img.save_png("%s/light_%02d00.png" % [OUT, hour])
	print("DONE")
	get_tree().quit()

func _grab() -> Image:
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()

## Percentage of pixels that changed noticeably between two frames.
func _diff_percent(a: Image, b: Image) -> float:
	var changed := 0
	var total := 0
	# Sampled on a grid -- a full per-pixel walk in GDScript is far slower
	# than it needs to be for a "did this move" check.
	for y in range(0, a.get_height(), 3):
		for x in range(0, a.get_width(), 3):
			total += 1
			var ca: Color = a.get_pixel(x, y)
			var cb: Color = b.get_pixel(x, y)
			if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > 0.06:
				changed += 1
	return 100.0 * float(changed) / float(maxi(total, 1))
