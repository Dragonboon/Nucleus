# Development Tools Quickstart

Use Development Tools when a project accumulates temporary debug buttons,
one-off keybinds or console-like helpers.

## Setup

Instance:

```text
res://addons/nucleus/modules/development_tools/development_tools.tscn
```

in a development shell or the current world scene. It provides a command registry,
built-in framework commands and a searchable palette.

Open it explicitly with `open_palette()` or assign a game-owned semantic InputMap
action to `toggle_action`. Nucleus intentionally does not reserve a physical key.

## Register a game command

```gdscript
registry.register_command(
    NucleusDevelopmentCommand.build(
        &"player.teleport",
        "Teleport player",
        _teleport_player,
        "Move the active player to an authored marker.",
        &"Game",
        [
            NucleusDevelopmentCommandArgument.build(
                &"marker",
                TYPE_STRING,
            ),
        ],
    )
)
```

Register commands from the scene/system that owns them and unregister them when
that lifetime ends.

## Trust boundary

The palette is an explicit allowlist, not `eval`, an arbitrary method/property
executor, OS shell or production remote-admin system.

## Performance integration

`NucleusPerformanceDevelopmentCommands` can register report/trace/compare commands
against an explicitly assigned sampler. This keeps the command palette as an
adapter rather than a second performance implementation.
