class_name UnitMarker
extends Node2D
## Visual for one PoliceUnit (spec section 36). Purely a renderer -- all
## click handling lives in MapView, which owns selection state. Position
## is interpolated between the last two simulation-tick positions using
## GameClock.sub_tick_fraction(), so movement reads as smooth even though
## the simulation itself only updates once per simulated minute
## (docs/ARCHITECTURE.md section 5/7's fixed-tick-plus-render-interpolation
## pattern).

var unit_id: String

var _prev_position: Vector2
var _next_position: Vector2
var _body: Polygon2D
var _selection_ring: Polygon2D

func setup(unit: PoliceUnit) -> void:
	unit_id = unit.id
	_prev_position = unit.current_position
	_next_position = unit.current_position
	position = unit.current_position

	_selection_ring = MapView.make_circle(22.0, Color(1.0, 1.0, 1.0, 0.35))
	_selection_ring.visible = false
	add_child(_selection_ring)

	_body = MapView.make_circle(14.0, _color_for_status(unit.status))
	add_child(_body)

	var label := Label.new()
	label.text = unit.callsign
	label.position = Vector2(16, -8)
	label.add_theme_font_size_override("font_size", 15)
	label.modulate = Color(0.9, 0.9, 1.0)
	add_child(label)

## Called once per simulation tick (via MapView, connected to
## SimulationCore.tick_completed) -- reads the unit's new position and
## shifts the interpolation window forward by one tick.
func on_tick() -> void:
	var unit: PoliceUnit = Simulation.core.resource_manager.get_unit(unit_id)
	if unit == null:
		return
	_prev_position = _next_position
	_next_position = unit.current_position
	_body.color = _color_for_status(unit.status)

func _process(_delta: float) -> void:
	var t: float = Simulation.core.game_clock.sub_tick_fraction()
	position = _prev_position.lerp(_next_position, clampf(t, 0.0, 1.0))

func set_selected(value: bool) -> void:
	_selection_ring.visible = value

func _color_for_status(status: GameEnums.UnitStatus) -> Color:
	match status:
		GameEnums.UnitStatus.AVAILABLE:
			return Color(0.15, 0.35, 0.85)
		GameEnums.UnitStatus.TRAVELLING:
			return Color(0.85, 0.65, 0.15)
		GameEnums.UnitStatus.ON_SCENE:
			return Color(0.85, 0.25, 0.25)
		GameEnums.UnitStatus.ON_BREAK:
			return Color(0.5, 0.5, 0.55)
		_:
			return Color(0.4, 0.4, 0.45)
