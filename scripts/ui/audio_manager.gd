class_name AudioManager
extends Node
## Minimal MVP audio (spec section 55): a notification sound and an
## incident alert, both short synthesized tones -- no voice acting, no
## radio dialogue, no ambient/vehicle sound (optional per spec, skipped to
## keep this genuinely minimal). Purely presentational: hooks existing
## simulation signals, never touches simulation state itself.

var _alert_player: AudioStreamPlayer
var _notification_player: AudioStreamPlayer

func _ready() -> void:
	_alert_player = AudioStreamPlayer.new()
	_alert_player.stream = load("res://audio/incident_alert.wav")
	add_child(_alert_player)

	_notification_player = AudioStreamPlayer.new()
	_notification_player.stream = load("res://audio/notification.wav")
	add_child(_notification_player)

	var core: SimulationCore = Simulation.core
	core.incident_manager.incident_created.connect(func(_id): _alert_player.play())
	core.incident_manager.incident_resolved.connect(func(_id, _outcome): _notification_player.play())
	core.fatigue_manager.fatigue_warning.connect(func(_id): _notification_player.play())
	core.specialist_manager.specialist_committed.connect(func(_id, _incident_id): _notification_player.play())
	core.neighbourhood_manager.officer_task_completed.connect(func(_id): _notification_player.play())
