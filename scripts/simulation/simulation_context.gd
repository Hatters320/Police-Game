class_name SimulationContext
extends RefCounted
## Bundles per-tick timing plus references to every manager, so manager
## tick() methods take one argument instead of an ever-growing parameter
## list. Built once by SimulationCore; dt_minutes/current_minute are
## refreshed each tick before managers run.

var dt_minutes: int = 0
var current_minute: int = 0

var world: WorldMapData
var road_graph: RoadGraph
var game_clock: GameClock
var shift_manager: ShiftManager
var district_manager: DistrictManager
var officer_manager: OfficerManager
var resource_manager: ResourceManager
var incident_manager: IncidentManager
var event_manager: EventManager
var intelligence_manager: IntelligenceManager
var fatigue_manager: FatigueManager
var community_manager: CommunityManager
var commands: Commands
var debug_commands: DebugCommands
var rng: RandomNumberGenerator
