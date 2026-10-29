# Migrating the root layout to the addon (0.39)

This pre-1.0 minor version intentionally changes serialized resource paths.
Public `Nucleus*` classes, methods, signals, exported properties and the six
service names stay unchanged. Existing Godot UID files are moved intact.

| Previous path | Addon path |
| --- | --- |
| `res://core/` | `res://addons/nucleus/core/` |
| `res://components/` | `res://addons/nucleus/components/` |
| `res://modules/` | `res://addons/nucleus/modules/` |
| `res://default_bus_layout.tres` | `res://addons/nucleus/core/audio/default_bus_layout.tres` |

For a game using the old layout:

1. Commit/back up the project and stop the editor/game.
2. Move the three source trees into `addons/nucleus/`, preserving existing UIDs.
3. Install the new plugin files. Update `res://` strings in game scripts, scenes,
   resources and `project.godot` according to the table. Update relative preloads too.
4. Update the six Autoload paths in place, preserving order. The plugin can reuse
   these entries but will not remove them on disable because the game owned them.
5. Remove old duplicate trees, reopen and enable Nucleus. Never retain two copies
   of its globally registered classes.
6. To retain previous automatic display/audio/locale behavior, set
   `nucleus/integration/manage_project_preferences=true` explicitly.
7. Keep existing InputMap, translations, bus layout, theme and main scene. Update
   their paths only when they point to moved Nucleus resources.
8. Import and test the actual game scenes, saves, options, navigation and audio.

The repository updates all its fixtures and documentation to the addon paths.
A consuming game's private scripts/resources require their own migration;
Godot UID remapping alone does not update arbitrary strings. Old path shims are
not included because duplicate global classes and two framework roots make
installation and upgrades ambiguous.

## Unified dock (0.39.0-dev.2)

Localization is now internal to `addons/nucleus/editor/localization/`. The main
plugin owns its parser, dock tab, dialogs and teardown. If an older installation
still enables `nucleus_localization`, Nucleus disables that legacy entry on load.
Remove the old `addons/nucleus_localization/` directory after disabling it; the
addon does not delete a separately installed folder automatically. Existing
Python/POT preferences retain their editor metadata keys.

Copy only the main addon folder for fresh installations. Dimensional profiles
and main updates are described in [addon management](addon_management.md).
