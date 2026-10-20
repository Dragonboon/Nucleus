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
