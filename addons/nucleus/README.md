# Nucleus

Enable **Nucleus** in Project Settings > Plugins after copying this folder into
an existing Godot 4.7 project. No new repository or replacement project is needed.

- `core/`: the six established cross-scene services and shared utilities.
- `components/`: reusable scene-owned Nodes, Resources, UI, world and gameplay adapters.
- `modules/`: optional capabilities, composed explicitly by the game.
- `plugin.gd`: editor installation and safe Autoload cleanup.

Host inputs, main scene, renderer, physics, theme, buses and translations remain
project-owned. Automatic display/audio/locale preferences require the explicit
`nucleus/integration/manage_project_preferences=true` project setting.

Disable before deleting. Update the whole folder together, preserving UIDs.
Full docs and migration: https://github.com/Dragonboon/Nucleus/tree/main/docs
License: MIT; see LICENSE. Version: see VERSION.
