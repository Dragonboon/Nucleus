## Optional related asset variants

Use `NucleusPlacementVariantSet3D` to group alternatives such as different
windows, walls or roofs. Each `NucleusPlacementVariant3D` entry contains a
unique `variant_id` and a `PackedScene` rooted at a valid 3D placeable.

Assign the catalog to the placement session (or pass it to
`begin_variants(catalog, optional_variant_id)`). The first entry is used
by default unless `default_variant_id` selects another.

```gdscript
@onready var placement: NucleusPlacementSession3D = $PlacementSession

func select_roof(catalog: NucleusPlacementVariantSet3D) -> void:
    var error := placement.begin_variants(catalog)
    if error != OK:
        push_warning(error_string(error))

func next_roof() -> void:
    placement.cycle_variant(1)

func previous_roof() -> void:
    placement.cycle_variant(-1)

func choose_roof(variant_id: StringName) -> void:
    placement.select_variant(variant_id)
```

The game owns input bindings, selection UI, costs, permissions and save schema.
`variant_changed(variant_id, index)` can refresh a HUD. The confirmed
`NucleusPlaceable3D.variant_id` records the chosen stable identifier.
A consuming game should persist this identifier together with its own asset
catalog identifier, stable instance ID and transform, not a transient index.

**Safety and compatibility:** This is opt-in and currently limited to SINGLE
(new-placement) previews; edit groups, duplication and chains retain existing
behavior. Each replacement instantiates a different scene while preserving
the preview pose and rotation, disables its collision during preview, and
revalidates the new scene's clearance/support constraints. Switching during
an outstanding confirmation is refused. Invalid replacement scenes leave the
existing preview untouched. A variant might be selected while its position is
invalid; `confirm()` still performs the existing final physical validation.
Keep the catalog on the session/UI rather than embedding a self-referencing
catalog inside the PackedScenes it contains.

# Runtime Placement 3D Contract

## Purpose and ownership

`addons/nucleus/components/gameplay/movement/placement_3d` provides an optional scene-owned
runtime placement interaction: spatial admission, editable previews, and bounded straight or curved chains of independently editable instances and
multi-object editing.

It is **not** a construction game, an item catalog, a persistent world manager,
a multiplayer authority or a terrain geometry modifier. The consuming game
chooses scenes and materials, maps inputs, owns world limits/costs/inventory,
commits save records and authorizes network mutations.

Native Godot owns raycasting, shapes, physics layers and transforms. The solver
**reuses** `NucleusPlacementQueries3D.is_transform_free()` for occupancy and
`NucleusSurfaceResolver3D` for optional semantic tags. Analytical
`NucleusSurfaceSampler3D` remains a separate contract; no implicit water/terrain
sampling or terrain collision import is performed.

## Components

| Class | Owner / contract |
| --- | --- |
| `NucleusPlacementProfile3D` | Resource defining clearance shape, slope, footprint, grid, allowed supports and chain limit |
| `NucleusPlaceable3D` | Composed metadata node with target and optional persistent ID; no manager or global registry |
| `NucleusPlacementSolver3D` | Stateless physics validation from a ray hit or an authored world point |
| `NucleusPlacementChain3D` | Pure bounded straight/curved path layouts, headings and box-overlap checks |
| `NucleusPlacementGeometry3D` | Stateless local mesh bounds and optional visual-bottom support correction |
| `NucleusPlacementBrush3D` | Stateless-to-world, stroke-local bounded candidate spacing and seeded radial jitter |
| `NucleusPlacementSession3D` | A single temporary session: preview, edit, confirm, cancel; emits results |

## Example scene assembly

```text
GameWorld (Node3D; game-owned, stable lifetime)
├── PlacementSession (NucleusPlacementSession3D; world_parent = GameWorld)
├── TerrainCollision (StaticBody3D; supports mask 1)
└── placed instances…

FenceSegment.tscn (Node3D root)
├── Visual (MeshInstance3D)
├── SolidBody (StaticBody3D + CollisionShape3D)
└── Placeable (NucleusPlaceable3D; target = FenceSegment root)
        profile = FenceProfile.tres
```

Author the profile with: `clearance_shape`, `clearance_offset` matching the
solid volume, `support_mask`, `obstacle_mask`, `support_half_extents`, and
`max_height_spread`. Make sure the physical collision geometry and the authored
clearance envelope agree. Do not rely on a point ray or a material alone to
block invalid positions. A profile missing its clearance shape fails closed.

The component can also be the scene root (`NucleusPlaceable3D` with target=self).
For a child component, assign **target to the scene root** explicitly. A
misconfigured target rejects `begin_new()` rather than moving part of a scene.

## Basic caller flow

```gdscript
# Game-owned input/router, not a Nucleus Autoload.
@onready var placement: NucleusPlacementSession3D = $PlacementSession

func select_placeable(scene: PackedScene) -> void:
    var err := placement.begin_new(scene)
    if err != OK:
        push_warning("Invalid authored placeable: %s" % error_string(err))

func rotate_selected() -> void:
    placement.rotate_step(1)

func confirm_selected() -> void:
    placement.confirm()

func cancel_selected() -> void:
    placement.cancel()
```

Set `camera` to enable cursor raycasting each physics frame. Or leave it null
and feed any game-supplied `intersect_ray` dictionary via `update_from_hit()`
(for touch/VR/controller/AI). No input action names are invented or consumed.

`admission` must be a **side-effect-free** gate; final game state changes belong
to the placement confirmation listener/server transaction.

`admission` is an optional `Callable` accepting `(Array[Transform3D],
Array[NucleusPlaceable3D]) -> Error`. It should reject unauthorized sessions,
insufficient resources or game-owned quantity caps. Only the game may deduct
resources, create undo entries, save or dispatch server RPCs. `confirm()` begins a fresh **bounded physics revalidation** and returns `OK`
when the request is admitted for checking. The operation may complete on a
later physics tick: listen for `placement_confirmed` or `placement_rejected`,
not the immediate `Error` return, to know the result. `placement_confirmed`
emits all new/edited roots together with `was_edit`. Once confirmation is
pending, cursor motion and new control points are ignored until resolution or
`cancel()`. No partial chain/group is committed.

## Terrain fitting and rejection

The position is derived from an actual collision hit, optionally grid-snapped
in X/Z, then re-sampled vertically at its center and four authored footprint
corners. The solver rejects missing support, excess height difference,
unsupported/steep normals, forbidden semantic tags, incompatible stacking and
colliding clearance shapes. `align_to_surface` tilts the **whole transform**
toward the mean support normal; it does not deform meshes to match terrain.
`surface_offset` adjusts the authored pivot relative to ground contact.
Unowned terrain support accepts native `StaticBody3D` by default; supporting
other body types requires opting in to `allow_nonstatic_support`.

Collision geometry must be ready when evaluated. On streamed/procedural terrain
with no active physics collider, admission fails closed even when an analytical
height source is available. A game can explicitly implement a distinct
analytical adapter, but must still validate overlap and surface readiness.

## Optional grid snap: session default and per-asset policy

Snap is **world-X/Z quantization**, not a terrain-height snap or a substitute
for collision checks. After X/Z has been quantized, the native physics solver
samples support again at the new cell center and the footprint corners. It
rechecks slope, stacking permission, and clearance; it may therefore reject a
visually close grid cell rather than moving it onto unsuitable terrain.
World Y remains dictated by the actual surface plus `surface_offset`.

`NucleusPlacementSession3D` owns only the **default** grid for the active
placement/edit session:

```gdscript
@onready var placement: NucleusPlacementSession3D = $PlacementSession

func _ready() -> void:
    placement.set_snap_defaults(true, Vector2(0.5, 0.5), Vector2.ZERO)

func set_grid_from_ui(enabled: bool) -> void:
    var error := placement.set_snap_defaults(
        enabled, placement.snap_grid_step, placement.snap_grid_origin,
    )
    if error != OK:
        push_warning(error_string(error))
```

`set_snap_defaults(enabled, step, origin, free_override = null)` rejects
zero/negative/nonfinite steps and origins and returns `ERR_BUSY` while
confirmation is already pending. The optional fourth argument is a `bool`
(or omitted). It applies the session's explicit free policy atomically,
without two successive physics validations. Existing three-argument callers
retain their previous behavior.

For an actual **free placement mode**, pass `free_override = true`:

```gdscript
# OFF: free cursor movement even when the profile forces snap/legacy grid.
placement.set_snap_defaults(false, Vector2.ONE, Vector2.ZERO, true)
# ON: session grid plus authored asset preferences and opt-outs.
placement.set_snap_defaults(true, Vector2(0.5, 0.5), Vector2.ZERO, false)
```

`force_free_placement` defaults to `false` for backward compatibility. When
`true` it takes precedence over `snap_mode = ENABLED` and legacy
`snap_to_grid = true`, returning `source = &"free_override"` from
`get_snap_settings()`. **This never mutates the shared `.tres` profile.**
A consuming game may keep the original inherited/asset-forced behavior by
omitting the fourth argument.

The free cursor preview for a single object (or a group that fits within one
validation tick) bypasses `preview_interval_ms` and uses a 1 mm change
threshold. The old 65 ms limiter made free motion appear to jump at roughly
15 updates per second. Long chains and larger groups keep their bounded
throttle and `max_checks_per_tick` budget. This is not an unrestricted
high-cost collision scan: free candidates still validate only when the
physics cursor hit actually changes.
When used during a preview it **invalidates and revalidates** the candidate;
never rely on an earlier green result. All commits still perform a fresh
bounded physics verification.

Each `NucleusPlacementProfile3D` may override that default with `snap_mode`:

| `snap_mode` | Behavior |
| --- | --- |
| `INHERIT` (default) | Follows session default; optionally uses asset's grid when `use_custom_snap_grid` is true |
| `ENABLED` | Forces snap on, using asset `grid_step` / `grid_origin` |
| `DISABLED` | Forces snap off even when the session default is enabled |

**Backward compatibility:** pre-existing `.tres` profiles using
`snap_to_grid = true` still force their authored `grid_step` and `grid_origin`
when `snap_mode = INHERIT`. `snap_mode = DISABLED` explicitly overrides that
legacy flag. For new authored profiles prefer `snap_mode` instead of setting
`snap_to_grid`; the older property remains for unchanged resources.

`grid_step` is a `Vector2` of strictly positive X/Z spacing (world units).
`grid_origin` is a world-X/Z offset, useful for aligning cells to a foundation's
corner or architectural grid. It does **not** make two unrelated meshes flush:
account for their authored pivots, footprint sizes, and intended edge offsets.
Gizmos, sockets, and rotation-aware edge snapping are separate asset-specific
mechanisms and are intentionally not invented by this grid contract. Rotation
remains the explicit `rotation_increment_degrees` input step.

**Stacking:** center and corners must still land on one permitted support.
The snapped X/Z cell may move off a supporting platform and will then be
rejected rather than accepting stale cursor-hit metadata.

**Chains:** the default snap applies to each independent segment only when its
profile inherits it. For continuous fences/curved layouts prefer
`snap_mode = DISABLED` unless segment spacing, grid and bends are designed to
quantize together. `chain_max_count` remains independently configurable (the
example fence is authored as 20, not a fixed Nucleus limit).

**Group edits:** the first selected piece determines the group's effective
snap policy. Only the shared pivot is quantized, preserving the exact relative
positions of all members; each member's own grid is not independently imposed.
Existing support-stack/group safety restrictions still apply.

## Mutually authorized stacks

A shelf placed on a foundation requires both:

```text
ShelfProfile.supported_by_kinds = ["foundation"]
FoundationProfile.accepts_on_top_kinds = ["shelf"]
```

Empty arrays mean **no permission**; they are not wildcard grants. Support is
located through the actual hit collider and its owner. A second verification is
performed at footprint samples. The occupancy envelope still must not overlap
the supporting object (do not exclude its collider to force a fit).

A game may enforce additional policy using `admission`. Nucleus has no universal
stack category list and does not assume surfaces are suitable because their
collision layers match.

## Chain mode

`begin_chain(fence_scene, anchor_world_position)` uses a straight horizontal
path toward the current cursor-hit position, with authored spacing and count.
The tool keeps separate, individually editable preview instances. Every
segment is checked against world collision/support before a single `confirm()`.
If any segment is invalid, no segment is committed. The path is capped rather
than silently truncating long requests. The end pointer is a direction/extent,
not an additional segment if it falls between regular spacing marks.

`chain_spacing` must account for actual geometry and connectors. The profile
rejects spacing shorter than twice its authored forward support footprint, but
complex meshes, diagonal overlaps and decorative connectors still require
consumer-level verification. The pure `NucleusPlacementChain3D.path_layout()` supports *curved* routes
from an ordered list of control points. `begin_path(scene, first_point)` starts
one; `add_path_control(point)` inserts a bend; `remove_last_path_control()`
removes the last bend. The current cursor hit is the live endpoint.
`confirm()` validates and commits the entire sequence. Two controls form a
straight line; three or more use bounded, centripetal Catmull-Rom interpolation
with near-constant arc length spacing and orientation based on each rigid
segment's physical chord. Per-profile `chain_curve_tension` in 0..1 sets how
smoothly corners transition (0 = polyline, 1 = full centripetal curvature).
Sampling density adapts to the section length; the per-segment tessellation
still has a cap to avoid unbounded CPU work. The result is a collection of rigid pieces; curved meshes,
corner connectors, sockets and spline-mesh deformation are not generated.
When a chain uses `BoxShape3D` clearance envelopes, their horizontal oriented
box overlaps are rejected as `chain_self_overlap`. For non-box shapes, games
must supply their own chain self-overlap policy before authorizing placement.
A rigid straight mesh cannot cover an arbitrary spline perfectly: tight bends
may still produce visible connector gaps or invalid overlaps. Set a realistic
`chain_spacing` for the model length, adjust its collision shape and support
footprint, and reduce section length at tight bends; author game-owned sockets,
corner joints or deformable meshes for visually gap-free walls.

MultiMesh is inappropriate for individual persistent editable instances, so
this path uses independent PackedScene instances. Games may batch decorative,
noninteractive visuals after acceptance if they want.

## Editing and cancellation

`begin_edit(existing_placeable)` or `begin_edit_many(Array[NucleusPlaceable3D])`
checks authored edit flags and captures each original transform and
materials/collision layers. For multiple items, movement translates the group
and yaw rotates relative to its centroid while keeping individual orientations.
`cancel()` restores **every** original transform and physics/visual state.
`confirm()` revalidates and commits the complete group. A group edit currently
requires all components to support movement and uses `BoxShape3D` clearance
shapes for pairwise overlap checks. For group edits containing mutually permitted support relationships, the
session identifies supports **before** disabling preview collision layers.
Supported pieces preserve their relative transform to the already-validated
support, and their new envelope is checked against unselected geometry.
Only the **direct original support** is modeled: hinged assemblies, dynamic
joints and previously invalid or partially supported stacks require a dedicated
game-owned edit adapter. Group movement remains a single commit or cancellation. `request_removal()` checks
`can_remove` and merely emits a
request; the game decides whether to delete or undo. During preview, colliders
are temporarily removed from collision layers; rigid bodies are frozen and
restored on completion. Complex dynamic assemblies should use a game-owned
editor that temporarily controls their simulation lifecycle.

When not editing, cancel frees only unconfirmed new instances. No globally
registered asset is silently removed. Do not edit a placeable simultaneously
from this session and another transform writer.

## Bounded preview: frame responsiveness

Prior chain preview evaluated every candidate on every physics tick and created
all missing instances at once, producing frame spikes for long chains.
`NucleusPlacementSession3D` now separates cursor projection from world
validation:

- `max_checks_per_tick` (default **3**) bounds support + occupancy evaluations,
  instantiation and excess-preview removal per physics tick. `max_group_count`
  (default **32**) caps group size independently (the lab configures up to
  **384**). `max_pairs_per_tick` (default **512**) bounds the final
  clearance comparisons so even large groups do not finish with one giant
  frame spike.
- `preview_interval_ms` (default **60 ms**) limits expensive new validation
  requests while the cursor moves. `cursor_tolerance` ignores tiny jitter.
- While validating, `last_reason == &"checking"`, `is_candidate_valid == false`
  and `pending_preview_material` may display an amber/unverified preview.
  `get_validation_progress() -> Vector2i` reports processed/total operations
  to game-owned HUDs without adding a new profiler.
- The solver reuses its vertical ray-query object and reuses the center sample;
  overlap remains delegated to `NucleusPlacementQueries3D`.
- `confirm()` performs a fresh bounded batch; the owner receives its success
  only via `placement_confirmed`. Rejecting one candidate rejects the batch.
  It never approves a stale visual position as authoritative.
- `update_from_hit()` is retained as a **synchronous** API for small explicit
  queries and tests, not for per-frame long-chain previews. The camera-driven
  `update_from_screen()` is the incremental path.

The budget limits *how many* jobs run per tick; it does not bound the wall time
of an individual Godot native raycast, instantiation or physics synchronization.
Profile with Godot's profiler on a target device; tune budget to terrain density
and visual latency, not just the object count. The default 3 per physics tick
may take several frames to approve a 20-piece chain.

## Persistence and multiplayer

`stable_id` is optional metadata, not a UUID allocator. The game is responsible
for stable identity, scene factory lookup, save migration, undo/redo, and
atomic world records. Do not persist previews. In online games, validate the
intent and final shape placement on the **authoritative server**, using
`NucleusNetworkIntentChannel` as transport if appropriate. Preview transforms
received from a client are untrusted and are not sufficient to spawn objects.
Server reconciliation, resource costs and anti-spam limits remain game-owned.

## Verification and limits

`tests/headless/runtime_placement_3d_test.gd` checks profile admission,
mutual stack permissions, chain bounds, curved layouts, overlap decisions,
invalid context, single/group edit cancellation and collision-layer restoration.
A consuming project should additionally test **real colliders** on steep,
uneven, obstructed and tiled terrain after physics has synchronized; test
multiplayer race conditions and save/reload using its own content and rules.

This release does not support surface-conforming mesh deformation, network
replication, socket graphs, mesh extrusion along splines, arbitrary articulated
group edits, asset catalogs, cost systems, automated chunk-stream awareness or
prefab ownership transfer.

## Game-owned chain and edit controls

```gdscript
# The game chooses which authored scene and world hit are valid to request.
func start_fence_drag(fence_scene: PackedScene, anchor: Vector3) -> Error:
    return placement.begin_chain(fence_scene, anchor)

func edit_existing(placed_scene_root: Node3D) -> Error:
    var component := NucleusPlaceable3D.find_in(placed_scene_root)
    return placement.begin_edit(component)

func remove_existing(placed_scene_root: Node3D) -> Error:
    var component := NucleusPlaceable3D.find_in(placed_scene_root)
    return placement.request_removal(component)
```

Connect `placement_confirmed` to an authoritative game-owned commit operation.
Record all chain instances in one save/undo transaction when applicable.

## Consumidor: creación de mundos en runtime

El laboratorio opcional `examples/placement` muestra cómo construir herramientas
de autoría alrededor de esta API **sin añadir un servicio global**:

- **Autoridad de transformaciones:** `NucleusPlacementSession3D` acepta/rechaza
  colocaciones y ediciones; el juego confirma los cambios en el árbol.
- **Historial:** reutilizar `NucleusValidatedActionHistory` para documentos
  de estado sin referencias a Node. Una confirmación de cadena/grupo equivale
  a una única acción. Validar y preparar todo antes de confirmar un undo/redo.
- **Documento persistente:** versionar `{stable_id, catalog_kind, transform}`,
  escoger escenas solo desde un catálogo explícito y aplicar límites de
  archivos, entidades y geometría. El ejemplo mantiene su codec en
  `examples/placement/placement_world_document.gd`; **no es un formato de save
  universal de Nucleus**.
- **Multijugador:** los permisos de colocación, economía, propiedad, prevención
  de abuso y validación de servidor siguen siendo del producto. Ni el JSON
  local ni la previsualización del cliente conceden autoridad.
- **Límites editoriales:** la edición de conjuntos apilados con soporte directo
  identificado puede mantener la estructura relativa; no supone un solver de
  uniones, bisagras o sistemas físicos articulados. Las copias complejas
  requieren que el juego compruebe también la validez interna del conjunto.

La nueva herramienta de mundo se construye enteramente con Godot,
`NucleusPlacementSession3D` y `NucleusValidatedActionHistory`. No introduce
Autoload, un controlador de cámara genérico ni gestión paralela de escenas.

## Authoring workflow improvements

`NucleusPlacementSession3D.begin_duplicate(detached_roots)` accepts **detached**
scenes staged by the consuming game's approved catalog, and owns their temporary
preview only if the call succeeds. The game assigns new stable IDs **after**
`placement_confirmed`, not while duplicating. Cancel frees copies and preserves
the source; confirmed copies are a *new placement*, never an edit of the source.
Do not pass already-parented or shared live world nodes to this method.

Repeat placement is deliberately a **consumer interaction policy** implemented
in `examples/placement/placement_lab.gd`: the lab observes a successful
single-piece commit and starts a new session preview on a deferred call. This
requires no separate Nucleus manager, button map or change to single-instance
session semantics. `Esc` cancels, and `Ctrl+A` switches back to group selection.

The example uses the existing `NucleusSave` service for versioned slots, backup
rotation, integrity and codec selection. The example-owned
`placement_world_document.gd` still validates the **application payload**
(`id`, `kind`, rigid `transform`) and stages reconstruction atomically. This is
not the same as `addons/nucleus/modules/world_state`: there is no persistent region or runtime
spawning service in the lab. A real multi-scene game may use `WorldStateService`
with `SaveSession`, and must recheck final placement on its authority.

### Example: curved placement mouse controls

The session does not own input mappings. The optional
`examples/placement/placement_lab.gd` deliberately binds:

- `C`, then **left click**: choose the first path anchor;
- **right click** while in `Mode.PATH`: call `add_path_control()` for one bend;
- **left click** while in `Mode.PATH`: capture the clicked ray position and call
  `confirm()` to place the whole chain;
- `Alt` + right drag: orbit the lab camera without adding a control point;
- `Backspace`: remove the last bend; `Escape`: cancel the entire draft.

`confirm()` returns `OK` when validation is **requested**, not necessarily when
placement has completed. The only authoritative success signal is
`placement_confirmed`; `placement_rejected` reports a failed final validation.
The preview's last green result cannot replace the final verification. A lab
UI must not overwrite the success message emitted by `placement_confirmed`
with a subsequent generic "checking" message if a short chain completes
synchronously. Changing mouse bindings requires no changes to the core solver.

## Visual-bottom placement for meshes with centered/offset pivots (opt-in)

`NucleusPlacementProfile3D.origin_mode` has two settings:

- `AUTHORED_ORIGIN` (default): preserve all existing scene pivots and save data.
  The surface hit plus `surface_offset` is the resulting root origin.
- `VISUAL_BOTTOM`: after support/slope evaluation, translate the final root
  transform along its resolved up axis so the lowest corner of its **local
  visual bounding box** touches the sampled support plane. `surface_offset`
  is still applied separately. The adjusted transform is then checked against
  the *same existing* physics clearance query before admission.

`NucleusPlacementGeometry3D.get_visual_bounds(root)` traverses only
`MeshInstance3D` children and combines their `Mesh.get_aabb()` corners using
child transforms relative to the root. `NucleusPlaceable3D.get_visual_bounds()`
**caches** that result per instance: the solver does not traverse meshes per
cursor movement. If meshes are changed at runtime, call
`placeable.invalidate_visual_bounds()` explicitly before the next validation.
`VISUAL_BOTTOM` rejects a placeable with no usable visual geometry with
`no_visual_bounds`. This mode does not change real physics collision shapes,
rigid-body mass, mesh geometry or support classification.

Important: a visual AABB is an approximation, not an exact triangle contact
shape. Decorative overhangs, invisible MeshInstances, animated/skinned geometry
and nonuniformly scaled root transforms require an authored pivot or a
product-specific support anchor instead. The asset's `clearance_shape` and
`clearance_offset` **remain authored** in root-local coordinates, and must
agree with its real collision volume. Do not use the visual AABB as a second
physics solver. Neither snap nor save/load re-applies this offset to an
already committed transform. It is computed only during a fresh placement/edit.

For a live example, open `examples/placement/assets/totem.tscn` and
`examples/placement/profiles/totem_profile.tres`. The totem has its visual and
physics origin near its geometric centre. Its `origin_mode = VISUAL_BOTTOM`
places its base on the ground. The other five lab profiles are unchanged.

## Bounded runtime brush candidate generator

`NucleusPlacementBrush3D` is a pure `RefCounted` helper. It is **not** an
`EditorPlugin`, global manager, Godot `Scatter` replacement or physics solver.

```gdscript
var brush := NucleusPlacementBrush3D.new()
brush.begin(1.5, 0.5, 64, 12345)  # spacing, jitter radius, max, seed
var candidates: Array[Vector3] = brush.add_cursor(world_pointer_position)
# Consumer must raycast/validate each candidate using PlacementSession3D.
brush.end()
```

The generator interpolates across skipped pointer positions at a fixed X/Z
arc-length step (no frame-time dependence), optionally jitters each candidate
in a bounded circular radius using a seeded native `RandomNumberGenerator`,
and caps output to 256 points per stroke (64 in the lab). It never instantiates
nodes, touches physics, returns validated transforms or commits the world.
Circle jitter does **not** guarantee pairwise minimum separation; the ordinary
collision solver is responsible for rejecting overlaps. An identical seed and
identical sequence of cursor points yield identical candidate positions, but
not necessarily identical physics results in different world states.

The lab owns the scene catalogue, mouse input, queue, world raycasts, stable
IDs, and the single `NucleusValidatedActionHistory` entry per completed drag.
It uses `NucleusPlacementSession3D.begin_new`, `update_from_hit` and `confirm`
**one candidate per physics tick**. The session independently rechecks each
candidate before committing it. Failed candidates are skipped and counted;
valid candidates commit progressively. A stroke is one undo transaction, not
an all-or-nothing placement admission: rejected points do not erase previous
valid stamps. `Esc` while drawing or draining a stroke cancels the entire
stroke and restores its initial world document. This is safe only because the
lab owns and can atomically reconstruct that data-only world document; a
production multiplayer game must perform transactions on its own authority.

`NucleusScatter*` should still handle large numbers of visual-only instances
(MultiMesh). The runtime brush is for separately editable/persistent scenes
with real collision shapes and stable IDs. No gameplay cost is charged in the
pure helper. Keep expensive scene instantiation on the main thread and profile
p95/p99 physics frame time before increasing batch sizes.

### Verification

- Run `res://tests/headless/test_runner.tscn` for geometry bounds, pivot
  correction and deterministic capped brush sampling tests.
- Run `godot --headless --path . --script res://examples/placement/placement_lab_smoke.gd`
  for the sixth placeholder, palette and UI wiring.
- Open `examples/placement/placement_lab.tscn`, press `6`, place a totem on
  flat ground, rotate it and compare `origin_mode` on/off in Inspector.
- With that same asset selected, press `P`, drag slowly and rapidly on ground,
  then release. Confirm there is exactly one Undo action for the whole stroke,
  rejected positions do not spawn, and `Esc` cancels a pending stroke.
- Switch to a crate and verify `G` still toggles truly free vs 1 m snap,
  fences retain curved mode, and saving/restoring preserves placed transforms.

This integration is an original implementation of the ideas reviewed in
Godot Asset Placer / GoPlacer / QuickPlace; it does not include or depend on
any third-party plugin code or editor APIs.
