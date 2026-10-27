# Experimental Nucleus modular-addon architecture

Branch: `feat/modular-addon-package-manager`.

The repository remains the development and integration test source of truth.
The eventual Asset Library artifact will contain `addons/nucleus/` (runtime
Core, editor integration, documentation and usage instructions). Optional
components/modules remain at repository root and are downloaded on demand.

## Dependency invariants

1. Core/editor never refer to optional `class_name` types or preload absent modules.
2. Every package has a unique stable ID, declared dependencies, minimum Core/Godot
   versions, an immutable release asset and SHA-256.
3. A package install must be atomic: preflight every path and dependency, stage
   files, detect modified project files, back up changes, then commit.
4. Never execute downloaded scripts during preview; document remote packages
   as untrusted executable code.
5. Upgrades preserve Godot UIDs and public Resource/scene paths or ship migrations.
6. On uninstall, check dependents and references first.
7. A core upgrade must not delete independent packages or user-owned game code.

## Current implementation

The editor dock displays the remote catalog and links documentation, and checks
the latest GitHub release. Installation/update buttons are not operational.
The initial installer prototype exists separately but should not be used until
dependency resolution, hash checks and rollback are available.

## Full migration tasks

- Inventory existing `res://core/` paths, `class_name` dependencies,
  Autoload contracts and serialized Resources.
- Relocate Core and any truly mandatory resources under `addons/nucleus/`.
- Move addon-scoped documentation/agent instructions to `addons/nucleus/`.
- Convert `project.godot` baseline Autoloads to new paths.
- Update all scenes/resources/scripts/tests and preserve tracked UIDs.
- Build isolated Core-only smoke and module integration fixtures.
- Publish signed/hashed (at least SHA-256 checked) per-package release archives.
- Enable install, uninstall and safe update from the dock after CI passes.

Keep the legacy project fully functional during this staged experiment.
