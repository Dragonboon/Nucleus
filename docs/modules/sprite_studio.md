# Nucleus Sprite Studio (optional Godot editor plugin)

Nucleus Sprite Studio converts any **regular grid-based** sprite sheet into
native Godot `SpriteFrames`, an `AnimatedSprite2D` scene, and optionally
`AnimationPlayer` clips. It does not assume any asset-pack-specific layout
or character type. It reuses the native AtlasTexture, SpriteFrames,
AnimatedSprite2D, AnimationPlayer, AnimationLibrary, PackedScene and
ResourceSaver facilities rather than introducing a new playback engine.

## Getting started

1. Enable `res://addons/nucleus_sprite_studio/plugin.cfg` in Project Settings.
2. Create a `NucleusSpriteSheetProfile2D` resource and assign an imported image.
3. Set cell size, optional margin/separation. In the bottom Sprite Studio panel,
   attach the profile, inspect suggested square grid sizes, and edit the profile.
4. Create named `NucleusSpriteClip2D` resources with cell sequences and FPS,
   or use *Generate row clips* once as editable `row_00`, `row_01`, etc.
5. Save a `.tres` SpriteFrames resource or a standalone `.tscn` visual scene.
6. Compose the generated visual scene with existing animation bindings,
   CharacterMotor2D or game-specific movement. Do not let two controllers
   drive the same AnimatedSprite2D playback properties.

## Detection boundary and editing

The grid suggestion checks common square cell sizes that evenly divide the
source image; **it does not claim to infer action names, direction, loop
semantics, frame duration or spritesheet padding**. The author reviews and
edits clips in the standard Godot Resource Inspector. Non-square cells,
irregular frame sequences, repeated cells and clip reordering are supported
by explicit profiles. Variable per-frame durations, packed freeform atlases,
Aseprite metadata and transparent-padding inference are not yet supported.

Source textures remain unmodified. Export refuses to overwrite any existing
file. Generated resources can be edited with native Godot inspectors; the
profile is the reproducible source of truth for regeneration. Godot
UndoRedo is not used for arbitrary scene mutations because generation is
opt-in and creates new resources rather than modifying an existing scene.

## Relationship to prior importer

`character-generator-importer-tool` inspired the AtlasTexture and native
animation conversion. Adult/kid dimensions, fixed animation labels and the
specific pack's body parts are deliberately *not* included here.

## Validation

`tests/headless/sprite_studio_test.gd` tests grid geometry, row clip
idempotency, invalid-cell rejection, AtlasTexture regions and generated
native AnimationPlayer tracks. Real Godot 4.7.2 editor interaction,
imported image settings, scene preview and exporters still require a
live editor verification. No performance or compatibility claim is inferred
from static code inspection.

## Batch importing and protected reimport (PR #3)

The optional bottom panel now accepts a source directory, an output directory
and default X/Y cell sizes. **Preview batch** reports discovered image files,
**Import batch** creates one persistent `.profile.tres`, `.frames.tres` and
`.animations.tres` per image, with relative folders preserved. The profile
keeps editable clip metadata, so developers can adjust each file later.
**Reimport batch** reloads saved profiles and updates only generated clips that
have not changed since the previous import.

The `.profile.tres.sprite-studio.json` sidecar stores signatures of generated
clips. Manually added clips and animations survive. If a generated clip was
edited in Godot, it is reported as a conflict and retained. Clips removed from
the profile are removed only when their prior generated content is unchanged.
The importer **never rewrites existing scenes**. Scenes can reference the
external `SpriteFrames` and `AnimationLibrary` resources; references and
scene-owned parameters are preserved across successful resource reimports.

The batch source and output must be inside `res://`; duplicate filenames in
separate subfolders remain separate. The importer scans at most 2048 images
and uses explicit, user-selected grid sizes. Irregular atlas detection and
human-semantic clip naming remain manual. This is a first editor workflow,
not an unattended semantic AI classifier or an atomic bulk transaction.

For first use, export a scene manually and reference the generated external
resource files where desired. Existing scenes are never silently patched.
There is no automatic replacement of embedded resources in old scenes.

Headless contract tests cover manual clip preservation, conflict detection and
batch output paths. Live Godot 4.7.2 editor verification is still required.
