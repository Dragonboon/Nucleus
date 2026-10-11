# Runtime Placement 3D Contract

## Purpose and ownership

`components/gameplay/movement/placement_3d` provides an optional scene-owned
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
straight line; three or more use sampled Catmull-Rom and near-constant arc
length spacing. The result is a collection of rigid pieces; curved meshes,
corner connectors, sockets and spline-mesh deformation are not generated.
When a chain uses `BoxShape3D` clearance envelopes, their horizontal oriented
box overlaps are rejected as `chain_self_overlap`. For non-box shapes, games
must supply their own chain self-overlap policy before authorizing placement.
Curvature can therefore leave small visible connector gaps: choose shorter
segments or author game-owned joins for a finished fence appearance.

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
shapes for pairwise overlap checks. An internally stacked group is rejected:
its preview temporarily disables the supporting member colliders, so it cannot
be considered a valid support without a future virtual-support contract.
Single-object editing remains available for such assets. `request_removal()` checks
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
  (default **32**) bounds the pairwise group-overlap work.
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
replication, socket graphs, mesh extrusion along splines, internal-stack group
editing, asset catalogs, cost systems, automated chunk-stream awareness or
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
