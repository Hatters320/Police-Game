class_name WeatherOverlay
extends CanvasLayer
## Weather you can actually see falling (spec section 34).
##
## This used to be a single flat ColorRect wash -- one translucent grey
## rectangle over the whole screen, which told the player it was raining
## only if they read the HUD chip and noticed the tint. It now draws real
## animated precipitation over the town: rain streaks, drifting snow, and
## slow fog banks, each with its own motion, on top of the same per-type
## tint as before.
##
## Deliberately still not a physical simulation -- the spec's "do not
## build detailed weather simulation" line is about the *model*, and the
## model is unchanged: weather is still one value rolled once per shift by
## WeatherManager. This is presentation only.
##
## Drawn with a single _draw() over a plain array of particle positions
## rather than GPUParticles2D: the target is mobile Web on the
## gl_compatibility renderer, where a couple of hundred draw_line calls in
## one canvas item are predictable and cheap, and there is no per-particle
## node or shader compilation to pay for.

## Per-type screen wash, kept from the previous version.
const TINTS := {
	GameEnums.WeatherType.RAIN: Color(0.40, 0.46, 0.55, 0.16),
	GameEnums.WeatherType.FOG: Color(0.72, 0.74, 0.78, 0.26),
	GameEnums.WeatherType.SNOW: Color(0.86, 0.90, 0.96, 0.18),
}

## Counts and alphas tuned by looking at real captures at phone size: the
## first pass drew correctly but read as too faint once the frame was
## viewed whole rather than zoomed. Still few enough that the entire
## effect is one cheap draw pass.
const RAIN_DROPS := 200
const SNOW_FLAKES := 130
const FOG_BANKS := 5

const RAIN_COLOR := Color(0.74, 0.84, 0.97, 0.52)
const SNOW_COLOR := Color(0.96, 0.98, 1.0, 0.85)
const FOG_COLOR := Color(0.80, 0.83, 0.88, 0.10)

## Pixels per second. Rain falls hard and slightly slanted; snow drifts.
const RAIN_SPEED_MIN := 900.0
const RAIN_SPEED_MAX := 1500.0
const RAIN_SLANT := 0.22
const RAIN_LENGTH_MIN := 14.0
const RAIN_LENGTH_MAX := 30.0
const SNOW_SPEED_MIN := 35.0
const SNOW_SPEED_MAX := 90.0
const SNOW_SWAY_PIXELS := 26.0
const FOG_SPEED_MIN := 6.0
const FOG_SPEED_MAX := 16.0

var _tint: ColorRect
var _canvas: Control
var _weather: GameEnums.WeatherType = GameEnums.WeatherType.CLEAR
var _rng := RandomNumberGenerator.new()
var _time: float = 0.0
## Each entry: {pos: Vector2, speed: float, size: float, phase: float}
var _particles: Array[Dictionary] = []

func _ready() -> void:
	layer = 1 # same environmental layer as DayNightOverlay, added after it so weather sits on top
	_rng.randomize()

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
	var count: int = _particle_count()
	for i in range(count):
		_particles.append({
			"pos": Vector2(_rng.randf() * size.x, _rng.randf() * size.y),
			"speed": _rng.randf_range(_speed_min(), _speed_max()),
			"size": _rng.randf_range(_size_min(), _size_max()),
			"phase": _rng.randf() * TAU,
		})

func _process(delta: float) -> void:
	_time += delta
	var size: Vector2 = _screen_size()
	for particle in _particles:
		var pos: Vector2 = particle["pos"]
		match _weather:
			GameEnums.WeatherType.RAIN:
				pos.y += particle["speed"] * delta
				pos.x += particle["speed"] * RAIN_SLANT * delta
			GameEnums.WeatherType.SNOW:
				pos.y += particle["speed"] * delta
				# Sway, so flakes drift rather than falling on rails.
				pos.x += sin(_time * 0.9 + particle["phase"]) * SNOW_SWAY_PIXELS * delta
			GameEnums.WeatherType.FOG:
				pos.x += particle["speed"] * delta
		# Wrap rather than respawn, so the field never thins out.
		if pos.y > size.y + particle["size"]:
			pos.y = -particle["size"]
			pos.x = _rng.randf() * size.x
		var margin: float = particle["size"] * 2.0
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
				var pos: Vector2 = particle["pos"]
				var length: float = particle["size"]
				_canvas.draw_line(pos, pos + Vector2(RAIN_SLANT * length, length), RAIN_COLOR, 1.6)
		GameEnums.WeatherType.SNOW:
			for particle in _particles:
				_canvas.draw_circle(particle["pos"], particle["size"], SNOW_COLOR)
		GameEnums.WeatherType.FOG:
			var width: float = _screen_size().x
			for particle in _particles:
				var pos: Vector2 = particle["pos"]
				var height: float = particle["size"]
				# Wide soft bands drifting sideways: fog reads as depth
				# across the view, not as falling specks.
				_canvas.draw_rect(Rect2(pos.x - width, pos.y, width * 2.0, height), FOG_COLOR)

func _screen_size() -> Vector2:
	return get_viewport().get_visible_rect().size

func _particle_count() -> int:
	match _weather:
		GameEnums.WeatherType.RAIN: return RAIN_DROPS
		GameEnums.WeatherType.SNOW: return SNOW_FLAKES
		GameEnums.WeatherType.FOG: return FOG_BANKS
	return 0

func _speed_min() -> float:
	match _weather:
		GameEnums.WeatherType.RAIN: return RAIN_SPEED_MIN
		GameEnums.WeatherType.SNOW: return SNOW_SPEED_MIN
		GameEnums.WeatherType.FOG: return FOG_SPEED_MIN
	return 0.0

func _speed_max() -> float:
	match _weather:
		GameEnums.WeatherType.RAIN: return RAIN_SPEED_MAX
		GameEnums.WeatherType.SNOW: return SNOW_SPEED_MAX
		GameEnums.WeatherType.FOG: return FOG_SPEED_MAX
	return 0.0

func _size_min() -> float:
	match _weather:
		GameEnums.WeatherType.RAIN: return RAIN_LENGTH_MIN
		GameEnums.WeatherType.SNOW: return 1.5
		GameEnums.WeatherType.FOG: return 40.0
	return 1.0

func _size_max() -> float:
	match _weather:
		GameEnums.WeatherType.RAIN: return RAIN_LENGTH_MAX
		GameEnums.WeatherType.SNOW: return 3.4
		GameEnums.WeatherType.FOG: return 110.0
	return 1.0
