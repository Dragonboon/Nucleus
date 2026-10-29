# PackedScene Preflight (P05)

Target engine: Godot 4.7.2. Source:
`addons/nucleus/modules/development_tools/validation/packed_scene_preflight.gd`.

`NucleusPackedScenePreflight.inspect()` reads a `PackedScene`'s stored
`SceneState` without calling `instantiate()` or entering the SceneTree.
It is an **optional authoring preflight**, particularly for `@tool` plugins
that need to inspect candidate scene modules before previewing, compiling,
or placing them.

```gdscript
var report := NucleusPackedScenePreflight.inspect(
    visual_scene,
    PackedStringArray(["SocketFront", "SocketBack"]),
    true,  # root derives from Node3D
    true,  # forbid serialized scripts
    true,  # forbid stored collision nodes
    1024,  # maximum stored nodes examined
)
if not report["ok"]:
    push_warning("\n".join(report["errors"]))
```

Results contain `ok`, `node_count`, `direct_markers`, `errors`, and `warnings`.
A required marker is a **direct child** `Marker3D` stored under that name; a
nested marker does not count. Script detection examines serialized node
properties. Collision checks cover native 2D/3D collision objects, shapes,
and polygons. A maximum stored-node count keeps editor validation bounded.

> [!CAUTION]
> **Preflight does not sandbox untrusted scenes.** It checks stored
> declarations without instantiation; later loading or execution remains risky.

## Scope and limitations

- Works with already loaded, **trusted authored** `PackedScene` resources.
  Loading the resource itself, inherited scenes, external subresources, or
  scripts may have side effects outside the scope of this inspection.
- Does not inspect recursively instantiated child scenes, runtime-generated
  descendants, script side effects, or the final physics shape geometry.
- A passing report is **not** a safe sandbox, security guarantee, full
  accessibility audit, or proof that geometry is physically traversable.
- The caller validates custom sockets and normalized transforms, art rules,
  ownership restrictions, and resulting compiled geometry as appropriate.
- Continue to use `NucleusDevelopmentValidation.validate_scene()` when the
  actual instantiated node tree must be checked; this is a distinct operation.

## Safe editor transaction pattern

The recommended editor-authoring workflow is:

1. Prepare a candidate by deep-copying the authored model/data.
2. Run pure topology, resource, scene-preflight and physical validations **on
   the candidate**, leaving the original scene unchanged.
3. Build/pack any transient previews before entering a commit phase; use
   deferred editor actions rather than mutating the Inspector synchronously.
4. Call `EditorInterface.get_editor_undo_redo()` for scene/document mutations,
   register matching `do`/`undo` operations, and commit **one logical action**.
5. Preserve original scene ownership, stable IDs, user-authored nodes and
   existing resource paths. Reject failed candidates without destructive edits.

Nucleus deliberately does **not** wrap `EditorUndoRedoManager` in a new global
transaction manager. This document is the reusable contract; editor tooling
remains owned by each addon.

## Use cases

| Scenario | Recommended use | Mandatory follow-up |
| --- | --- | --- |
| Art-module palette with named direct sockets | Inspect stored marker declarations before preview | Check socket positions, orientation and geometry |
| Visual-only scene which must not carry collision nodes | Reject stored native collision shapes/objects | Review nested PackedScenes and actual final scene |
| Prevent scripts in a trusted prefab catalog | Check stored script properties | Do not treat this as untrusted-code sandboxing |
| Check actual runtime configuration warnings | Not sufficient | Use `NucleusDevelopmentValidation.validate_scene()` |

Keep editor operations transactional: inspect, validate a candidate, build a
preview, then commit one native Undo/Redo action after every step passes.
