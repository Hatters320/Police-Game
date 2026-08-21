class_name SimulationCore
extends RefCounted
## Composition root: owns every manager and drives the tick loop. No Node/
## scene dependency, so it's constructible and runnable entirely headlessly
## (see docs/ARCHITECTURE.md section 3) -- the `Simulation` autoload is a
## thin Node wrapper around one instance of this, and the debug harness
## under tests/ builds one directly with no autoload involved at all.

signal shift_ended(summary: Dictionary)
## Emitted at the end of every simulation tick -- for anything that needs a
## hook into "a tick just completed" without adding another manager (e.g.
## the debug harness's auto-dispatch stand-in for a player).
signal tick_completed

var ctx: SimulationContext = SimulationContext.new()

var world: WorldMapData
var road_graph: RoadGraph = RoadGraph.new()
var game_clock: GameClock = GameClock.new()
var shift_manager: ShiftManager = ShiftManager.new()
var district_manager: DistrictManager = DistrictManager.new()
var officer_manager: OfficerManager = OfficerManager.new()
var resource_manager: ResourceManager = ResourceManager.new()
var incident_manager: IncidentManager = IncidentManager.new()
var event_manager: EventManager = EventManager.new()
var intelligence_manager: IntelligenceManager = IntelligenceManager.new()
var fatigue_manager: FatigueManager = FatigueManager.new()
var community_manager: CommunityManager = CommunityManager.new()
var specialist_manager: SpecialistManager = SpecialistManager.new()
var neighbourhood_manager: NeighbourhoodManager = NeighbourhoodManager.new()
var weather_manager: WeatherManager = WeatherManager.new()
var kpi_tracker: KpiTracker = KpiTracker.new()
var commands: Commands = Commands.new()
var debug_commands: DebugCommands = DebugCommands.new()

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

## One-time wiring for a save/game (not per-shift -- district state and
## incident history persist across shifts, so this must run only once per
## save, at game start / on load). rng_seed makes a run reproducible for
## debugging (spec section 64); pass 0 for a random seed.
func initialize(
	p_world: WorldMapData,
	incident_type_defs: Array[IncidentTypeDefinition],
	event_defs: Array[EventDefinition],
	rng_seed: int = 0
) -> void:
	world = p_world
	road_graph.build(world)
	district_manager.setup_from_world(world)
	incident_manager.setup(incident_type_defs, world)
	event_manager.setup(event_defs)
	specialist_manager.setup()
	neighbourhood_manager.setup()

	if rng_seed != 0:
		rng.seed = rng_seed
	else:
		rng.randomize()

	ctx.world = world
	ctx.road_graph = road_graph
	ctx.game_clock = game_clock
	ctx.shift_manager = shift_manager
	ctx.district_manager = district_manager
	ctx.officer_manager = officer_manager
	ctx.resource_manager = resource_manager
	ctx.incident_manager = incident_manager
	ctx.event_manager = event_manager
	ctx.intelligence_manager = intelligence_manager
	ctx.fatigue_manager = fatigue_manager
	ctx.community_manager = community_manager
	ctx.specialist_manager = specialist_manager
	ctx.neighbourhood_manager = neighbourhood_manager
	ctx.weather_manager = weather_manager
	ctx.kpi_tracker = kpi_tracker
	ctx.commands = commands
	ctx.debug_commands = debug_commands
	ctx.rng = rng

	commands.setup(ctx)
	debug_commands.setup(ctx)

## Forms this shift's roster/units and opens the clock window, but leaves
## it unconfirmed -- spec section 16's briefing screen needs the units to
## already exist so the player can task them (patrol location, reserve),
## and needs the clock NOT running while they decide. `roster` is this
## shift's staffing (establishment minus leave/sickness/training, spec
## section 8); district/incident state already exists from initialize()
## or the previous shift and is untouched here.
func prepare_shift(shift_number: int, start_minute: int, duration_minutes: int, roster: Array[Officer]) -> void:
	officer_manager.set_roster(roster)
	var station: LocationDefinition = world.get_location(world.police_station_location_id)
	resource_manager.form_units(officer_manager.available_officers(), station)
	shift_manager.prepare_shift(shift_number, start_minute, duration_minutes)
	specialist_manager.setup_shift(rng)
	weather_manager.setup_shift(rng)
	kpi_tracker.reset_shift()
	game_clock.total_minutes = start_minute

## Confirms the briefing (spec section 16's "confirm the shift plan") --
## the clock starts ticking from this point on.
func confirm_briefing(priorities: Array[String], reserve_target: int) -> void:
	shift_manager.confirm_briefing(priorities, reserve_target)

## Convenience for callers that don't need a real briefing pause (the
## headless harness): prepares and confirms in one call.
func start_shift(
	shift_number: int,
	start_minute: int,
	duration_minutes: int,
	roster: Array[Officer],
	priorities: Array[String],
	reserve_target: int
) -> void:
	prepare_shift(shift_number, start_minute, duration_minutes, roster)
	confirm_briefing(priorities, reserve_target)

## Called from the Simulation autoload's _process(delta). Presentation
## never calls this or _tick_sim directly -- only through Commands.
func advance_real_time(delta_seconds: float) -> void:
	var ticks: int = game_clock.advance_real_time(delta_seconds)
	for i in range(ticks):
		game_clock.advance_one_tick()
		_tick_sim(GameClock.TICK_MINUTES)
		if shift_manager.is_over():
			_end_shift()
			break

## For the headless debug harness: runs whole simulated minutes without
## the real-time accumulator, stopping automatically at shift end.
func fast_forward_shift() -> void:
	while not shift_manager.is_over():
		game_clock.advance_one_tick()
		_tick_sim(GameClock.TICK_MINUTES)
	_end_shift()

## Advances every manager by exactly one clock tick's worth of simulated
## minutes, in a fixed order: units move before incidents are evaluated, so
## an arrival this tick is already visible to incident state changes the
## same tick.
func _tick_sim(dt_minutes: int) -> void:
	ctx.dt_minutes = dt_minutes
	ctx.current_minute = game_clock.total_minutes
	shift_manager.advance(ctx)
	district_manager.tick(ctx)
	event_manager.tick(ctx)
	resource_manager.tick(ctx)
	incident_manager.tick(ctx)
	fatigue_manager.tick(ctx)
	specialist_manager.tick(ctx)
	neighbourhood_manager.tick(ctx)
	tick_completed.emit()

func _end_shift() -> void:
	incident_manager.apply_shift_handover()
	# Stops the Simulation autoload from ticking (it gates on
	# briefing_confirmed) until the next prepare_shift/confirm_briefing --
	# without this, the very next frame's tick would push current_minute
	# past shift_end_minute again and re-trigger _end_shift() every tick
	# forever.
	shift_manager.shift_state.briefing_confirmed = false
	shift_manager.end_shift()
	shift_ended.emit(compile_shift_summary())

## Debrief-shaped summary (spec section 45/46): raw counters plus the
## 5-dimension Poor/Developing/Good/Strong/Excellent rating and a short
## narrative, both from DebriefScorer.
func compile_shift_summary() -> Dictionary:
	var resolved_this_shift := 0
	for entry: IncidentHistoryEntry in incident_manager.history:
		if entry.resolved_at_minute >= shift_manager.shift_state.shift_start_minute:
			resolved_this_shift += 1
	var scores: Dictionary = DebriefScorer.score_shift(self, shift_manager.shift_state.shift_start_minute)
	return {
		"shift_number": shift_manager.shift_state.shift_number,
		"resolved_this_shift": resolved_this_shift,
		"still_open_incidents": incident_manager.active_incidents.size(),
		"total_history_count": incident_manager.history.size(),
		"intelligence_items": intelligence_manager.items.size(),
		"scores": scores,
		"narrative": DebriefScorer.narrative_summary(scores),
	}
