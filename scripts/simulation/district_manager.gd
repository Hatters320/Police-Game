class_name DistrictManager
extends RefCounted
## Owns every district's persistent runtime state (spec section 6). Built
## once from WorldMapData's districts; district state survives across
## shifts (docs/ARCHITECTURE.md section 1-2/47) -- this is never rebuilt
## between shifts the way OfficerManager's roster is.

var districts: Dictionary = {} # district_id -> DistrictState

func setup_from_world(world: WorldMapData) -> void:
	districts.clear()
	for def: DistrictDefinition in world.districts:
		var state := DistrictState.new(def.id)
		state.capture_baseline()
		districts[def.id] = state

func get_state(district_id: String) -> DistrictState:
	return districts.get(district_id)

func tick(ctx: SimulationContext) -> void:
	for district: DistrictState in districts.values():
		district.decay_toward_baseline(ctx.dt_minutes)

func apply_patrol(district_id: String, dt_minutes: float, strength: float = 1.0) -> void:
	var district: DistrictState = get_state(district_id)
	if district:
		district.apply_patrol_presence(dt_minutes, strength)
