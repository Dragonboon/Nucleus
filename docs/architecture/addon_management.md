# Addon management ownership

| Requirement | Godot owner | Existing Nucleus contract | Integration policy |
| --- | --- | --- | --- |
| Single editor entry | EditorPlugin, dock, translation parser | Nucleus plugin and localization panel/parser | Embed localization in the Nucleus dock |
| 2D/3D selection | Filesystem and script/resource dependencies | Existing independent components/modules | Deterministic inventory and dependency-closed profiles |
| Safe mutation | DirAccess, FileAccess | Existing public paths and UIDs | Preview host references, preserve backups and roll back failed swaps |
| Stable update | HTTPRequest, ZIPReader | Current package version and CI workflow | Pin successful main commit, verify inventory, stage before applying |

The former `feat/modular-addon-package-manager` dock is the interaction reference.
Its disabled installer is not reused: it cannot prune, replace, or roll back.
The six existing runtime services remain the only baseline Autoloads.
