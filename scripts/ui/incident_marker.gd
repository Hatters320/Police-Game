class_name IncidentMarker
extends Node2D
## Visual for one Incident (spec section 37) -- a diamond coloured by
## priority (red=critical/orange=urgent/yellow=important/green=routine,
## matching spec's colour scheme), dimmed while it's still being assessed
## and not yet a valid dispatch target (see Commands.assign_unit_to_incident's
## QUEUED guard). Purely a renderer; MapView owns click handling.

var incident_id: String

var _body: Polygon2D
var _label: Label

func setup(incident: Incident, world_position: Vector2) -> void:
	incident_id = incident.id
	position = world_position

	_body = MapView.make_circle(12.0, _color_for(incident), 4) # 4 segments -> diamond
	add_child(_body)

	_label = Label.new()
	_label.position = Vector2(14, 6)
	_label.add_theme_font_size_override("font_size", 14)
	_label.modulate = Color(0.95, 0.95, 0.85)
	add_child(_label)

	refresh()

func refresh() -> void:
	var incident: Incident = Simulation.core.incident_manager.get_incident(incident_id)
	if incident == null:
		return
	_body.color = _color_for(incident)
	var not_yet_actionable: bool = int(incident.state) < int(GameEnums.IncidentState.QUEUED)
	_label.text = "%s P%d%s" % [incident.type_id, incident.priority, " (assessing)" if not_yet_actionable else ""]
	modulate.a = 0.5 if not_yet_actionable else 1.0

func _color_for(incident: Incident) -> Color:
	return MapView.PRIORITY_COLORS.get(incident.priority, Color(0.6, 0.6, 0.6))
