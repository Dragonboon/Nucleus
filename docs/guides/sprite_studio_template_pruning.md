# Nucleus Sprite Studio controls and template pruning

## Sprite Studio: plugin status versus workspace visibility

With the optional plugin enabled in Project Settings > Plugins, a colored
**Sprite Studio** toolbar button appears. Its ON label means the plugin is
enabled. Click it to close/reopen its `EditorDock` without unloading the
importer or forcing a different editor layout. The editor's standard Dock
menu still controls placement. Disabling the plugin under Project Settings
removes the toolbar action and dock entirely.

The source and generated-resource ownership rules are unchanged. The logo is
an original simple vector mark stored in the plugin; no external fonts/assets
are required.

## Pruning a newly cloned Nucleus template

The `scripts/template/prune_template.py` command is intentionally
**conservative**: because Nucleus has shared Core services, scenes,
autoloads and tests, blindly deleting entire `components/` or `modules/`
would produce invalid dependencies.

Run these commands in a NEW checkout, ideally with a clean git status:

```bash
python scripts/template/prune_template.py 3d
python scripts/template/prune_template.py 2d
python scripts/template/prune_template.py addons
```

By default the tool is a **dry-run**: it prints JSON with files that are safe
candidates for pruning, and any references that block deletions.

After reviewing, use `--apply` (never automatic), optionally writing
`--report report.json`. When blockers are present it refuses deletion by
default. `--allow-blocked` retains blocked files and deletes only the
unreferenced portion.

```bash
python scripts/template/prune_template.py 3d --apply --report prune-3d.json
python scripts/template/prune_template.py addons --apply
```

**Important:** a mode removes only explicitly tagged paths and cannot
promise complete removal of every 2D/3D subsystem. Untagged files,
dynamically assembled resource paths, generated `class_name` dependencies,
project settings, editor scripts, optional scene references and test-manifest
entries still require manual review. This first version does NOT rewrite
`project.godot` or remove common Nucleus Core, and must not be used to
claim a working 2D-only or 3D-only distribution until Godot import and CI
pass for the pruned checkout.

The command does not try to remove folders in the active repository while
running editor tools. Use version control for easy reversal; do not operate
on a project with uncommitted work. No cleanup runs merely by opening the
template.

### Recommended workflow

1. Clone Nucleus into a new project.
2. Choose a profile and inspect dry-run JSON.
3. Inspect `blocked`; keep shared dependencies until they are migrated.
4. Apply the safe subset only if appropriate.
5. Reopen the clone in the pinned Godot version, execute headless suites and
   correct remaining dimension-specific project wiring manually.
6. Commit and document the resulting project-specific configuration.
