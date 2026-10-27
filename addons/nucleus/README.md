# Nucleus editor addon (experimental)

Enable **Nucleus** in Project Settings > Plugins. The bottom-panel dock retrieves a
GitHub package catalog and displays optional modules, documentation links and
release status. Catalog fetching requires network access.

## Current status

- The existing baseline project and six Autoloads remain in `res://core/` for compatibility.
- This is a first scaffold of an installable editor addon, **not yet a portable Core**.
- Module downloads are deliberately disabled until per-package release archives,
  SHA-256 verification, dependency resolution and transactional rollback are implemented.
- The included ZIP installer refuses overwrites and validates paths/extensions,
  but is not production ready and is not connected to the UI.
- Updating the Core from inside the editor is not enabled. The dock checks the
  latest GitHub release and displays its tag.
- This plugin is independent of the existing localization editor addon.

## Next migration checkpoint

Move `core/` to `addons/nucleus/core/` only together with a repo-wide rewrite
of resource paths, tracked Godot UIDs, six Autoload paths and all tests. Validate
both the full repository and an empty Godot project containing only
`addons/nucleus/`. Do not duplicate `class_name` scripts at both paths.

## Packaging

The distributable archive should contain only `addons/nucleus/` plus the necessary
license/metadata. CI needs separate archive builds for optional packages at
immutable release tags; never install arbitrary moving-branch content.
