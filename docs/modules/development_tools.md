# Optional Development Tools Module

`addons/nucleus/modules/development_tools` is optional, debug-oriented and scene-owned by
default. It provides an explicit command registry plus a searchable command
palette without turning text input into arbitrary code execution.

## Public shape

The module supplies typed command arguments, stable command IDs, aliases/tags,
bounded local history, result normalization, a ready-to-instance palette and
adapters for existing Nucleus owners such as Scene Flow and Performance.

A command is registered by the scene/system that owns the behavior:

```gdscript
var command := NucleusDevelopmentCommand.build(
    &"player.teleport",
    "Teleport player",
    _teleport_player,
    "Move the active player to an authored marker.",
    &"Game",
    [NucleusDevelopmentCommandArgument.build(&"marker", TYPE_STRING)],
)
registry.register_command(command)
```

Unregister scene-owned commands when their owner leaves scope.

## Trust boundary

The registry deliberately does not expose:

```text
eval / Expression execution
arbitrary Object.call() by user text
arbitrary property mutation
OS.execute()
remote console transport
production administration APIs
```

Only explicitly registered callbacks are callable. The ready shell is debug-only
by default; release/QA use is an explicit product decision.

## Built-in ownership

The default shell provides conservative development commands for command help,
context/history and scene inspection/reload/navigation. Scene changes route
through `NucleusSceneFlow`.

`NucleusPerformanceDevelopmentCommands` is an optional adapter that calls the
existing performance report/trace/compare APIs rather than implementing a second
sampler.

## Extension rule

Use commands for bounded development operations such as loading a profiling
scenario, spawning an authored test encounter, granting an item or forcing a
known world/time fixture. Keep complex configuration in Resources/data and keep
production moderation/admin tooling outside this module.
