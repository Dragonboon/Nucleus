# Development Validation Quickstart

Instance the existing Development Tools shell:

```text
res://addons/nucleus/modules/development_tools/development_tools.tscn
```

Then open the palette and run:

```text
validation.run
```

This validates the current scene using the same configuration-warning contracts
Godot exposes in the editor. Exported Resources that expose
`get_validation_errors()` are included automatically.

Validate an authored scene without switching to it:

```text
validation.scene res://world/test_harbor.tscn
```

Validate data directly:

```text
validation.resource res://data/items/catalog.tres
```

For CI or local headless checks:

```bash
godot --headless --path . \
  --script res://scripts/validation/run_validation.gd -- \
  --scene=res://world/test_harbor.tscn
```

Add only targets your game expects to be valid in isolation. Deliberately broken
fixtures or editor demonstration scenes should not be promoted into the gate.
