# Installing the Nucleus Godot Addon

Nucleus installs into **new or existing Godot projects**. You do not clone a
starter, replace `project.godot`, or create another game repository.

## Requirements and installation

Use the engine declared in [Godot compatibility](../policies/godot_compatibility.md):
Godot **4.7.2-stable** is the tested reference.

1. Download the versioned addon ZIP and verify its SHA-256 checksum.
2. Extract it into the existing project root. It contains `addons/` directly.
3. Open the project and enable **Nucleus** in **Project > Project Settings > Plugins**.
4. The plugin registers the six existing core Autoloads in dependency order.
5. Compose components and optional modules from `res://addons/nucleus/` in your scenes.

When using a source checkout, copy only `addons/nucleus/`. Localization authoring
is integrated into the **Nucleus dock > Localization** tab; there is one plugin
to enable. Python and GNU gettext are needed only for catalog creation/update.

Use **Nucleus dock > Manage** to preview and apply the **Full**, **2D only** or
**3D only** profile, check stable `main`, download/verify an update and apply it.
See [addon management](addon_management.md) for dependency checks and recovery.

The repository's `project.godot`, `AGENTS.md`, `docs/`, `examples/`, `tests/`,
`scripts/`, `tools/` and any development labs are development material.
They are not required by the addon and are excluded from the installation ZIP.
The root project is a validation workspace, with authored sample inputs and buses.

## Existing project ownership

Installation leaves the host's main scene, InputMap, renderer, physics backend,
theme, audio bus layout and translations intact. Bind exported action names to
your InputMap; apply the supplied theme explicitly to selected UI if desired.
Use your buses, or explicitly adopt the optional bus layout from
`addons/nucleus/core/audio/default_bus_layout.tres`. Missing named buses use
existing audio fallback behavior; they are not created by installation.

The six services retain their API names: `NucleusApp`, `NucleusSettings`,
`NucleusInput`, `NucleusAudio`, `NucleusSave`, `NucleusSceneFlow`. Existing matching
entries are reused. Conflicting names abort activation before adding any entries;
resolve them explicitly and enable again. Do not install two Nucleus versions:
Godot's global `class_name` registry is shared across the project.

Automatic display, locale and audio preference application is **off** in consuming
projects. To delegate those responsibilities to the existing Nucleus appliers,
add this project setting and restart the game:

```ini
[nucleus]
integration/manage_project_preferences=true
```

This applies the Nucleus catalog and persisted settings, including Master volume.
Review defaults first. Explicit calls to Nucleus APIs still perform their documented
operations. App lifecycle/logging, input rebinding persistence, save service and
scene-flow APIs remain the established baseline; avoid competing owners in the game.

## Disable, upgrade and remove

Disable Nucleus in Plugins before deleting its folder. Only Autoload entries
created by the plugin and still pointing to their original paths are removed.
Pre-existing matching entries and user replacements remain owned by the project.
Closing the editor does not uninstall services. Stop a running game before disabling.
The localization parser, panel and cancellable jobs follow the same plugin lifecycle.

Pin a release or commit. Upgrade by replacing the addon directories, preserving
`.uid` files; keep game content outside them. Before deleting or upgrading, inspect
scene/resource references and follow [migration](addon_migration.md).
