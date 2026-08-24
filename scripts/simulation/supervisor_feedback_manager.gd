class_name SupervisorFeedbackManager
extends RefCounted
## Feature request's "Supervisor Feedback System": AI-driven (see this
## codebase's established meaning of that -- deterministic, templated from
## real numbers, not a live generative call) Chief Inspector commentary
## when performance is genuinely poor. Ticked but internally gated so the
## real evaluation only runs every CHECK_INTERVAL_MINUTES simulated
## minutes, not every tick -- cheap, and matches how infrequently this
## should actually have something new to say.

signal feedback_issued(message: String)

const CHECK_INTERVAL_MINUTES := 30
const COOLDOWN_MINUTES := 60

## Below this attainment percentage, with enough attended calls to be a
## real read rather than one lucky/unlucky call, P1/P2 response is
## flagged.
const POOR_ATTAINMENT_PCT := 50.0
const MIN_ATTENDED_FOR_READ := 2
const TOO_MANY_OPEN := 4
const TOO_MANY_ESCALATIONS := 3

var _next_check_minute: int = 0
var _last_feedback_minute: int = -COOLDOWN_MINUTES
var _escalations_this_shift: int = 0

func setup(incident_manager: IncidentManager) -> void:
	incident_manager.incident_escalated.connect(_on_incident_escalated)

func reset_shift() -> void:
	_next_check_minute = 0
	_last_feedback_minute = -COOLDOWN_MINUTES
	_escalations_this_shift = 0

func tick(ctx: SimulationContext) -> void:
	if ctx.current_minute < _next_check_minute:
		return
	_next_check_minute = ctx.current_minute + CHECK_INTERVAL_MINUTES
	if ctx.current_minute - _last_feedback_minute < COOLDOWN_MINUTES:
		return
	var message: String = _evaluate(ctx)
	if message != "":
		_last_feedback_minute = ctx.current_minute
		feedback_issued.emit(message)

func _on_incident_escalated(_incident_id: String) -> void:
	_escalations_this_shift += 1

## Checked in this order -- response time is the most actionable/direct
## signal, backlog size next, escalation count last (it's somewhat implied
## by the other two, so only worth its own message when it's the clearest
## story).
func _evaluate(ctx: SimulationContext) -> String:
	var tracker: KpiTracker = ctx.kpi_tracker
	for priority in [1, 2]:
		var attended: int = tracker.attended_count(priority)
		if attended < MIN_ATTENDED_FOR_READ:
			continue
		var pct: float = tracker.attainment_pct(priority)
		if pct < POOR_ATTAINMENT_PCT:
			return "Chief Inspector: Your Priority %d response times are slipping -- only %d%% attended within target. I need to see this improve." % [priority, roundi(pct)]

	var still_open: int = ctx.incident_manager.active_incidents.size()
	if still_open >= TOO_MANY_OPEN:
		return "Chief Inspector: You've got %d incidents still outstanding. Let's get some of these cleared before they pile up further." % still_open

	if _escalations_this_shift >= TOO_MANY_ESCALATIONS:
		return "Chief Inspector: %d incidents have escalated this shift under your watch. Review your dispatch priorities." % _escalations_this_shift

	return ""
