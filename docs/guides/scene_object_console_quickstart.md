# Scene Object Console Quickstart

The Scene Object Console is part of the optional Development Tools shell. It is
intended for fast runtime inspection and small, reversible changes while testing
a scene.

## 1. Add the development shell

Instance:

```text
res://addons/nucleus/modules/development_tools/development_tools.tscn
```

The shell has no physical toggle binding by default. Open it from game-owned
development input or directly:

```gdscript
$DevelopmentTools.open_palette()
```

## 2. Find the object

Start broad:

```text
scene.nodes
```

Filter by name, path, or class:

```text
scene.nodes boat
scene.nodes CharacterBody3D
scene.nodes debug 20
```

If gameplay already uses groups:

```text
scene.group enemies
scene.group interactables
```

The output uses paths relative to the current scene. Copy those paths into the
next commands.

## 3. Inspect its available values

```text
node.inspect World/Boat
```

Filter large nodes:

```text
node.inspect World/Boat speed
node.inspect World/Boat collision
node.inspect World/Boat visible
```

The console intentionally exposes a narrower surface than Godot's Inspector.
Object/resource references and complex structural values stay out of
`node.set`.

## 4. Tune a value

For scalar/string values:

```text
node.set World/Boat max_speed 22.5
node.set World/Boat debug_draw true
node.set World/Boat display_name "Test Boat"
```

For vectors and colors:

```text
node.set Debug/Marker position "400,250"
node.set Debug/Marker modulate "#ffd166"
```

Enum values can normally be entered by Inspector label when Godot exposes the
enum hint:

```text
node.set World/Boat process_mode disabled
```

If a property is read-only, structural, or unsupported, the command fails
without attempting a write.

## 5. Move an object directly

2D:

```text
node.position2d Player 320 180
node.position2d Player 640 360 global
node.rotation2d Player 45
node.scale2d Player 1.5 1.5
```

3D:

```text
node.position3d World/Boat 100 2 -20 global
node.rotation3d World/Boat 0 90 0
node.scale3d World/Boat 1 1 1
```

These commands are preferable to setting transform matrices manually.

## 6. Isolate behavior

Hide a visual branch:

```text
node.visible Debug/Overlay false
```

Freeze one node's idle and physics callbacks:

```text
node.process Enemies/Boss false
```

Restore it:

```text
node.process Enemies/Boss true
```

This is useful for A/B debugging, but it is not a replacement for a game's pause
or lifecycle system.

## 7. Escalate repeated actions into custom commands

If you keep entering several raw mutations to reproduce the same state, stop
using the generic console for that workflow and register a domain command.

For example, replace:

```text
node.position3d World/Boat 12 0 -4
node.set World/Boat fuel 100
node.set World/Boat invulnerable true
```

with a game-owned command such as:

```text
boat.fixture harbor_start
```

That command can preserve game invariants and become reusable in bug reports,
scenario runners, and performance tests.

Continue with:

```text
docs/guides/custom_development_commands_tutorial.md
```
