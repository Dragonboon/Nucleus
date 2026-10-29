# Nucleus

Enable **Nucleus** in Project Settings > Plugins after copying this folder into
an existing Godot 4.7 project. No new repository or replacement project is needed.

- `core/`: the six established cross-scene services and shared utilities.
- `components/`: reusable scene-owned Nodes, Resources, UI, world and gameplay adapters.
- `modules/`: optional capabilities, composed explicitly by the game.
- `editor/`: the Nucleus dock, dimensional profile manager, verified main updater
  and integrated localization tools.
- `plugin.gd`: one editor entry, parser registration and safe Autoload cleanup.

Host inputs, main scene, renderer, physics, theme, buses and translations remain
project-owned. Automatic display/audio/locale preferences require the explicit
`nucleus/integration/manage_project_preferences=true` project setting.

Disable before deleting. Update the whole folder together, preserving UIDs.
Full docs and migration: https://github.com/Dragonboon/Nucleus/tree/main/docs
License: MIT; see LICENSE. Version: see VERSION.

The dock previews physical removal of unrelated 2D/3D code and refuses changes
when host references or local vendor edits need attention. Shared UI remains in
both profiles. Full source caches and rollback copies live in `.nucleus/` outside
the addon, excluded from imports with `.gdignore`.

Updates use the latest successful main push for `nucleus-ci.yml`, verify that the
commit remains in main history, pin downloads to that SHA and check every source
file against its inventory. No network calls run until you ask. After applying,
reopen the editor. Old main revisions without `addon_manifest.json` are unsupported.
