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

## Automatic character workflow: SunnyLand-style frame folders

You **do not need to create Nodes yourself**. Enable the optional Sprite Studio
plugin, expand its bottom panel and use the **Automatic characters** section:

1. Copy the pack's `Assets/SPRITES` directory into your Godot project under
   `res://assets/SPRITES`. Ignore the macOS metadata, GIF previews, PSD files,
   Demo/JavaScript and unrelated tileset files.
2. Set **Source folder** to `res://assets/SPRITES` and **Output folder** to
   `res://generated/characters`.
3. Select **Detect characters**. The panel lists inferred characters, clips and
   frame counts. Detection requires numbered PNGs such as `player-idle-1.png`;
   simple static PNGs are not interpreted as animations.
4. Select **Generate scenes**. For each recognized group, it writes:
   `<character>.profile.tres`, `<character>.frames.tres`,
   `<character>.animations.tres`, `<character>.sprite-studio.json`, and
   a ready-made `<character>.tscn` with AnimatedSprite2D and AnimationPlayer.
   Nested directories are retained to distinguish characters.
5. Drag an exported `.tscn` from the filesystem into your game scene. This
   remains the native Godot workflow; no manually assembled sprite nodes are
   necessary.
6. Later, change a persistent profile in Godot's Inspector and run **Generate
   scenes** again. Generated external resources are updated when unmodified.
   Modified clips are retained and reported as conflicts. Scenes are **never
   overwritten**, protecting authored nodes and scene-specific settings.

For SunnyLand, `SPRITES/player/idle/player-idle-1.png` through `-8.png`
become one `player` scene with an `idle` clip. The same player grouping
includes `run`, `jump`, `hurt`, and `crouch`. Enemy frame sequences can
be discovered separately. These are **filename/folder suggestions**, not
AI-derived semantic truth; review detected groups and refine the profile.

### Supported inputs and known gaps

The original sheet importer continues to accept uniform spritesheets. The
new **Automatic characters** path supports numbered, individually sliced PNG,
WEBP or JPEG frame sequences. SunnyLand's Demo atlas uses a **trimmed
TexturePacker JSON**, which is not yet imported: it requires reconstruction of
sprite source padding and pivot metadata, not naïve grid slicing. PSDs,
previews, environment tilemaps and standalone props are excluded.

Automatic scene generation creates **external** SpriteFrames and
AnimationLibrary resources; the generated scene references them so subsequent
reimports do not require deleting/recreating nodes. This first version scans
synchronously and has explicit file-count/depth limits. Large imported packs,
complex renaming, UndoRedo, resource write failures and sprite pivot alignment
require further Godot editor acceptance tests. Treat it as a non-atomic editor
operation and keep your project under version control.

SunnyLand package inspected: 12 numbered frame sequences (49 individual PNG
frames); the provided license PDF says CC0. No assets were committed to Nucleus.

## SunnyLand validation: avoid the two import modes at once

The delivered SunnyLand user output contains **six** character scenes in
`res://generated/characters/` but also **34 individual grid profiles** under
`res://generated/sprites/`. This happens when the same numbered PNG frame
folder is processed as separate grids. **Do not run Sheet Mode on folders of
numbered PNG animation frames.** Use **Character Mode** instead.

1. Put `Assets/SPRITES` at `res://assets/SPRITES`.
2. Open **Sprite Studio > CHARACTER MODE** and set source to that path.
3. Set destination to `res://generated/characters`; press **Detect characters**.
4. Review groups: `player` has idle/run/jump/hurt/crouch; the sibling
   `grasshopper-idle`, `grasshopper-jump`, `grasshopper-fall` folders should
   now be grouped into the single `enemies/grasshopper` scene.
5. Press **Generate scenes**; inspect the colored operation status, progress bar,
   success/skip summary and resulting output directory.
6. Drag an existing generated `.tscn` into the scene tree. Do not create
   AnimatedSprite2D/AnimationPlayer manually. Both nodes are generated.
7. Edit a character's `.profile.tres` to change FPS or clips and regenerate.
   Scene files are kept intact; only external generated resources are updated.

**Sheet Mode** is for actual single-image spritesheets with regular cells,
not pre-sliced PNGs. It still exports resources, rather than scenes. The
progress display reports how many items have been attempted; it is not a
promise that every resource was imported successfully. Keep backups under
version control before bulk operations.

Known limitations: the current panel is a functional workflow with
status colors and progress but not a full timeline editor or an atlas
selection overlay. It still needs visual/live Godot editor validation and
additional UI feedback on individual save failures.

## Editor layout and usability (Godot 4.7.2)

The editor panel uses native `EditorDock` and appears by default in the
**right lower dock** rather than reserving a tall area at the bottom.
Use Godot's native dock menu to move it to either side, the bottom, or a
floating window. The placement can be remembered by the editor.

The main workflow is divided into three compact tabs:

- **Characters** (default): Detect characters, review them, generate scenes.
- **Spritesheets**: import grid-based sheets in batches or reimport resources.
- **Single profile**: edit and export an individually authored profile.

Each tab scrolls independently to avoid clipping controls in a short panel.
The big empty single-profile texture preview is hidden until a profile has a
texture, and action buttons wrap in narrow layouts. A shared compact footer
keeps the operation status, progress and result counts visible.

Batch processing yields to the editor once for each file/group so progress
can be painted rather than staying frozen until completion. A completed
attempt may still be skipped or conflict; inspect the final status. This does
not make resource saving asynchronous or guarantee hitch-free imports.

For the earlier screenshot: after updating the plugin, disable and re-enable
it in Project Settings > Plugins if the previous bottom-panel instance
is still open. Find Sprite Studio in the right-side docks, or move it to
a floating window using Godot's dock controls.
