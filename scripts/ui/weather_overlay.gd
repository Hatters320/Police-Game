class_name WeatherOverlay
extends CanvasLayer
## Weather you can actually see falling (spec section 34).
##
## This began as a single flat ColorRect wash -- one translucent rectangle
## over the whole screen, which told the player it was raining only if
## they read the HUD chip. It now draws animated precipitation over the
## town.
##
## Deliberately still not a physical simulation -- the spec's "do not
## build detailed weather simulation" line is about the *model*, and the
## model is unchanged: weather is still one value rolled once per shift by
## WeatherManager. This is presentation only.
##
## Drawn with a single _draw() over a plain array of particles rather than
## GPUParticles2D: the target is mobile Web on the gl_compatibility
## renderer, where a couple of hundred draw calls in one canvas item are
## predictable and cheap, with no per-particle node or shader compilation
## to pay for.
##
## Two things learned from looking at real captures:
##
##   * Fog was first drawn as wide flat draw_rect bands. Every band had a
##     hard top and bottom edge, so on screen it read as "lines across the
##     screen" rather than as fog -- reported exactly that way. Fog is now
##     soft radial blobs drawn from a gradient texture, heavily
##     overlapping, with no hard edge anywhere in it.
##   * Everything was drawn in one uniform layer, which looks flat. Each
##     particle now carries a depth: near ones are bigger, faster,
##     brighter, far ones smaller, slower, fainter. That parallax is most
##     of what makes falling weather read as three-dimensional.

## Per-type screen wash sitting under the particles. Fog's is lower than
## it was, because the blobs now supply most of its density and stacking a
## heavy flat wash on top of them just greys the town out.
const TINTS := {
	GameEnums.WeatherType.RAIN: Color(0.40, 0.46, 0.55, 0.16),
	GameEnums.WeatherType.FOG: Color(0.70, 0.73, 0.78, 0.17),
	GameEnums.WeatherType.SNOW: Color(0.86, 0.90, 0.96, 0.16),
}

const RAIN_DROPS := 220
const SNOW_FLAKES := 140
## Few, but each is enormous and soft, so they overlap into a continuous
## haze instead of reading as separate objects.
const FOG_BLOBS := 16

const RAIN_COLOR := Color(0.76, 0.86, 0.98, 0.55)
const SNOW_COLOR := Color(0.97, 0.99, 1.0, 0.92)
const FOG_COLOR := Color(0.82, 0.85, 0.90, 0.30)

## Pixels per second, given at the near (depth 1.0) extreme; far
## particles are scaled down from these by _lerp_depth.
const RAIN_SPEED_NEAR := 1650.0
const RAIN_SPEED_FAR := 750.0
const RAIN_LENGTH_NEAR := 34.0
const RAIN_LENGTH_FAR := 11.0
const RAIN_WIDTH_NEAR := 2.0
const RAIN_WIDTH_FAR := 0.9
const RAIN_SLANT := 0.22

const SNOW_SPEED_NEAR := 105.0
const SNOW_SPEED_FAR := 28.0
const SNOW_RADIUS_NEAR := 3.6
const SNOW_RADIUS_FAR := 1.2
const SNOW_SWAY_PIXELS := 30.0

const FOG_SPEED_NEAR := 26.0
const FOG_SPEED_FAR := 7.0
const FOG_RADIUS_NEAR := 340.0
const FOG_RADIUS_FAR := 150.0
## How far a blob bobs vertically over its cycle -- fog that only slides
## sideways looks like a conveyor belt.
const FOG_BOB_PIXELS := 26.0

var _tint: ColorRect
var _canvas: Control
var _weather: GameEnums.WeatherType = GameEnums.WeatherType.CLEAR
var _rng := RandomNumberGenerator.new()
var _time: float = 0.0
## Each entry: {pos: Vector2, depth: float, phase: float}
var _particles: Array[Dictionary] = []
## Soft round falloff, built once. Used for fog blobs and snowflakes so
## neither has a hard edge.
var _soft_blob: GradientTexture2D

func _ready() -> void:
	layer = 1 # same environmental layer as DayNightOverlay, added after it so weather sits on top
	_rng.randomize()
	_soft_blob = _build_soft_blob()

	_tint = ColorRect.new()
	_tint.color = Color(0.4, 0.46, 0.55, 0.0)
	_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tint)

	# A separate Control does the drawing so the tint stays a plain,
	# cheap rect underneath it.
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_weather)
	add_child(_canvas)

	get_viewport().size_changed.connect(_seed_particles)
	refresh()

## A white disc fading to fully transparent at its rim. Drawing this
## stretched is what gives fog its soft edge -- the thing hard draw_rect
## bands could never have.
func _build_soft_blob() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_offset(0, 0.0)
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_offset(1, 1.0)
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	# An extra mid stop pulls the falloff inwards so the blob has a soft
	# core rather than a linear ramp, which reads much more like haze.
	gradient.add_point(0.45, Color(1.0, 1.0, 1.0, 0.55))

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	return texture

## Weather is rolled once per shift, so this is called explicitly at shift
## start rather than ticking.
func refresh() -> void:
	_weather = Simulation.core.weather_manager.current_weather
	_tint.color = TINTS.get(_weather, Color(0.4, 0.46, 0.55, 0.0))
	_seed_particles()
	# Nothing to animate on a clear shift -- stop processing entirely
	# rather than running an empty loop every frame.
	var active: bool = _weather != GameEnums.WeatherType.CLEAR
	set_process(active)
	_canvas.visible = active
	_canvas.queue_redraw()

func _seed_particles() -> void:
	_particles.clear()
	var size: Vector2 = _screen_size()
	for i in range(_particle_count()):
		_particles.append({
			"pos": Vector2(_rng.randf() * size.x, _rng.randf() * size.y),
			"depth": _rng.randf(),
			"phase": _rng.randf() * TAU,
		})

func _process(delta: float) -> void:
	_time += delta
	var size: Vector2 = _screen_size()
	for particle in _particles:
		var pos: Vector2 = particle["pos"]
		var depth: float = particle["depth"]
		match _weather:
			GameEnums.WeatherType.RAIN:
				var speed: float = _lerp_depth(RAIN_SPEED_FAR, RAIN_SPEED_NEAR, depth)
				pos.y += speed * delta
				pos.x += speed * RAIN_SLANT * delta
			GameEnums.WeatherType.SNOW:
				pos.y += _lerp_depth(SNOW_SPEED_FAR, SNOW_SPEED_NEAR, depth) * delta
				# Sway, so flakes drift rather than falling on rails.
				pos.x += sin(_time * 0.9 + particle["phase"]) * SNOW_SWAY_PIXELS * delta
			GameEnums.WeatherType.FOG:
				pos.x += _lerp_depth(FOG_SPEED_FAR, FOG_SPEED_NEAR, depth) * delta
				# Slow vertical bob on top of the drift.
				pos.y += sin(_time * 0.25 + particle["phase"]) * FOG_BOB_PIXELS * delta

		var margin: float = _wrap_margin(depth)
		# Wrap rather than respawn, so the field never thins out.
		if pos.y > size.y + margin:
			pos.y = -margin
			pos.x = _rng.randf() * size.x
		elif pos.y < -margin:
			pos.y = size.y + margin
		if pos.x > size.x + margin:
			pos.x = -margin
		elif pos.x < -margin:
			pos.x = size.x + margin
		particle["pos"] = pos
	_canvas.queue_redraw()

func _draw_weather() -> void:
	match _weather:
		GameEnums.WeatherType.RAIN:
			for particle in _particles:
				var depth: float = particle["depth"]
				var pos: Vector2 = particle["pos"]
				var length: float = _lerp_depth(RAIN_LENGTH_FAR, RAIN_LENGTH_NEAR, depth)
				var color: Color = RAIN_COLOR
				# Distant rain is fainter, which is what stops the field
				# reading as one flat sheet of identical strokes.
				color.a *= lerpf(0.35, 1.0, depth)
				_canvas.draw_line(
					pos, pos + Vector2(RAIN_SLANT * length, length), color,
					_lerp_depth(RAIN_WIDTH_FAR, RAIN_WIDTH_NEAR, depth))
		GameEnums.WeatherType.SNOW:
			for particle in _particles:
				var depth: float = particle["depth"]
				var radius: float = _lerp_depth(SNOW_RADIUS_FAR, SNOW_RADIUS_NEAR, depth)
				var color: Color = SNOW_COLOR
				color.a *= lerpf(0.40, 1.0, depth)
				# Soft-edged rather than a hard disc: flakes are small
				# enough that a crisp circle reads as a dot of UI, not snow.
				_blob(particle["pos"], radius * 2.4, color)
		GameEnums.WeatherType.FOG:
			for particle in _particles:
				var depth: float = particle["depth"]
				var radius: float = _lerp_depth(FOG_RADIUS_FAR, FOG_RADIUS_NEAR, depth)
				var color: Color = FOG_COLOR
				color.a *= lerpf(0.45, 1.0, depth)
				# Gentle breathing so a static screenshot and a live one
				# don't look the same.
				color.a *= 0.85 + 0.15 * sin(_time * 0.35 + particle["phase"])
				_blob(particle["pos"], radius, color)

## Draws the soft falloff texture centred on a point.
func _blob(center: Vector2, radius: float, color: Color) -> void:
	var size := Vector2(radius * 2.0, radius * 2.0)
	_canvas.draw_texture_rect(_soft_blob, Rect2(center - size * 0.5, size), false, color)

func _lerp_depth(far_value: float, near_value: float, depth: float) -> float:
	return lerpf(far_value, near_value, depth)

## How far off-screen a particle must travel before it wraps -- large
## enough that a fog blob's soft rim never pops in at the edge.
func _wrap_margin(depth: float) -> float:
	match _weather:
		GameEnums.WeatherType.FOG:
			return _lerp_depth(FOG_RADIUS_FAR, FOG_RADIUS_NEAR, depth) * 1.2
		GameEnums.WeatherType.RAIN:
			return RAIN_LENGTH_NEAR
	return SNOW_RADIUS_NEAR * 4.0

func _screen_size() -> Vector2:
	return get_viewport().get_visible_rect().size

func _particle_count() -> int:
	match _weather:
		GameEnums.WeatherType.RAIN: return RAIN_DROPS
		GameEnums.WeatherType.SNOW: return SNOW_FLAKES
		GameEnums.WeatherType.FOG: return FOG_BLOBS
	return 0
