extends Node
## Thin autoload wrapper around one SimulationCore instance -- registered as
## `Simulation` in project.godot. Owns nothing simulation-specific itself;
## every real system lives in SimulationCore (docs/ARCHITECTURE.md section
## 3), which is why the debug harness under tests/ can run the whole
## simulation without this autoload or any scene tree at all.

var core: SimulationCore = SimulationCore.new()

func _process(delta: float) -> void:
	if core.world == null:
		return # not initialized yet (no briefing confirmed / shift started)
	core.advance_real_time(delta)

## Presentation calls these instead of reaching into `core` directly, so
## there's one obvious place to look for "how do I talk to the simulation."
func commands() -> Commands:
	return core.commands

func debug_commands() -> DebugCommands:
	return core.debug_commands
