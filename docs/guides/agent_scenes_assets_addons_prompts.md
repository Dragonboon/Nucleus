# Agent prompts: scenes, existing assets and addons

Use the [task preamble](agent_prompt_playbook.md#task-preamble) and
[AGENTS.md](../../AGENTS.md). **Inventory before generating.** The Nucleus
development repository has examples under `examples/`; installed addons do not include them. A consuming
game has an `assets/` or `addons/` directory. Paths and licenses must
be observed in the current project, not invented.

## Inventory gate

| Resource | Check before use |
| --- | --- |
| PackedScenes | `.tscn`, inherited scenes, instancing and NodePath references |
| 2D | SpriteFrames, texture atlas, TileSet/TileMapLayer, scale and collision |
| 3D | GLB/glTF, materials, skeletons, animations, import and collision |
| UI/audio | Existing Theme, fonts, audio streams and buses |
| Addons | `addons/*/plugin.cfg`, `.gdextension`, enabled editor plugins and call sites |
| Provenance | License, author credit, allowed distribution and dependencies |
| Identity | `res://` paths, tracked `.uid` and imported resource references |

Directory presence does not imply an addon is enabled or compatible. Reuse
authored resources, preserve imported scenes and avoid rewriting vendor code.

## Scene creation prompts

### S1. Audit scene ingredients

~~~text
For [gameplay scenario], inventory existing scenes, Resources, textures,
models, animation, audio, Theme and enabled addons. Output exact paths,
technical fit, attribution/license status and missing prerequisites.
Read the relevant native Godot/Nucleus APIs. Propose one minimal scene tree
and playable acceptance check; distinguish found assets from proposed art.
Do not download or generate new assets yet.
~~~

### S2. Assemble a small playable level

~~~text
Build [one room/arena/board segment] under the game's game/ directory.
Instance available PackedScenes, preserve imports, UIDs, layers and
authored scripts, and wire existing Nucleus movement, interactions and
scene-flow only where needed. Add game-owned layout and rules.
Acceptance: enter → perform [interaction] → receive feedback → exit/retry.
Test missing resources, collision and old scenes. Do not replace the
project's main scene or Nucleus framework.
~~~

### S3. Reuse 2D tiles and sprites

~~~text
Inspect actual sprite sheets, SpriteFrames, TileSets and TileMapLayer
scenes before building [2D level]. Preserve filtering, tile dimensions,
atlas regions, animation, collision and native navigation. Compose with
the existing 2D movement/AI contracts. Validate visual seams, collision,
camera bounds, restart and missing references in a real Godot scene.
Do not redraw already-suitable assets.
~~~

### S4. Reuse 3D modular assets

~~~text
Inventory actual GLB/glTF models, PackedScenes, material overrides,
collision, animation and navigation settings. Build one navigable 3D
space from instances instead of recreating imported meshes. Wire
existing camera/character/interaction owners. Verify scale, orientation,
spawn clearance, interaction reach, material appearance and export
resource dependencies. Report missing art rather than inventing paths.
~~~

### S5. Integrate animation, sound and UI

~~~text
Use existing AnimationTree/AnimationPlayer, SpriteFrames, audio buses,
streams and native UI Theme for [feature]. Inspect real animation names,
parameter paths and Resource references. Keep GameplayAction/state as
the authority and animation/audio as feedback. Test accepted/rejected
inputs, controller focus, readable contrast and reduced-motion choices.
Avoid a second audio or animation manager.
~~~

### S6. Create a second variant safely

~~~text
Add [variation] to [scene] while preserving the original. Choose an
inherited scene, instanced PackedScene or game-owned layout with a
parameterized Resource. Keep UID identity and shared Resource semantics:
duplicate mutable runtime data only where needed. Check both variants
and rollback paths before calling it complete.
~~~

## Asset and addon prompts

### A1. Choose assets already in the repository

~~~text
Find candidate [sprite/model/audio/UI asset] resources with real paths,
dimensions, format, animation/collision compatibility and permitted use.
Compare candidates before adding new art. Reuse the best approved asset;
do not assume a license or download from unknown sources. Document any
missing evidence and explain how it connects to the existing scene.
~~~

### A2. Audit an addon already installed

~~~text
Look for addons/*/plugin.cfg, .gdextension, project.godot enabled plugins,
autoload declarations, licenses, vendor docs and actual call sites.
Compare its public API, Godot version compatibility and maintenance with
native Godot/Nucleus responsibilities. Report REUSE, ADAPT or REJECT with
specific evidence and risk. Do not enable/install/execute an unapproved
addon; absent means absent, not an invitation to fabricate one.
~~~

### A3. Integrate an approved addon

~~~text
Integrate [approved addon/version/path] for [one purpose] in [game scene].
Keep one writable owner; introduce a thin game-owned adapter only when
required. Preserve optionality, configuration, UID paths, imports,
licensing notices and rollback. Test addon enabled, disabled/missing,
scene disposal and export compatibility. Do not patch vendor code
or add Autoloads by default.
~~~

### A4. Repair an upgrade or broken imported resource

~~~text
Investigate [exact import/UID/plugin error]. Record prior and current
versions, path, logs, resource dependencies and local vendor edits.
Fix only the broken reference or API change. Preserve tracked .gd.uid,
scenes and import settings; do not blanket-delete .godot/ or overwrite
customizations. Verify editor, runtime and exports where relevant.
~~~

## Worked scenario prompts

**Existing 2D enemy**

~~~text
Locate real enemy sprites, animations and scenes in [game repo].
Compose one enemy in the existing arena with AICharacterSetup2D,
TargetingAgent, GameplayAction and EncounterCombatant where applicable.
Prove perception, chase, attack, defeat reporting and teardown using the
actual asset/map. Do not add a second enemy motor or invent sprite paths.
~~~

**Existing 3D environment**

~~~text
Locate existing modular floors, walls, doors, materials and collision.
Build one 3D room using PackedScene instances and documented
Nucleus interaction/camera owners. Prove entrance, exit, collision,
interaction, save/reload and rendering on the target device.
Do not flatten models into replacement procedural meshes.
~~~

For each task report **reused paths, licensing/compatibility evidence,
ownership, modified scenes, checks run, known gaps and rollback**. A parser
pass alone does not certify artwork, navigation or export quality.

**Next:** [Playbook](agent_prompt_playbook.md) ·
[Debug/testing prompts](agent_debug_testing_prompts.md) ·
[Selective upgrades](upgrading_and_dependencies.md).
