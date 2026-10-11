# Runtime Placement 3D Contract

## Purpose and ownership

`components/gameplay/movement/placement_3d` provides an optional scene-owned
runtime placement interaction: spatial admission, editable previews, and a
bounded straight-line chain of independently editable instances.

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
| `NucleusPlacementChain3D` | Pure bounded straight-line layout and segment heading |
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
resources, create undo entries, save or dispatch server RPCs. The session
re-checks physics immediately before `confirm()`. `placement_confirmed` emits
new root scenes or an edited root, along with `was_edit`.

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
consumer-level verification. This is **not** a fence/road generator or a curve
solver. Curved paths and automatic socket matching require a separate proven
use case; do not assume they are implemented here.

MultiMesh is inappropriate for individual persistent editable instances, so
this path uses independent PackedScene instances. Games may batch decorative,
noninteractive visuals after acceptance if they want.

## Editing and cancellation

`begin_edit(existing_placeable)` checks `can_move` or `can_rotate` profile flags, captures
the original transform and original materials/collision layers, and activates
a preview. `cancel()` restores the exact transform and visual/physics state.
`confirm()` validates and commits the move/rotation. `request_removal()` checks
`can_remove` and merely emits a
request; the game decides whether to delete or undo. During preview, colliders
are temporarily removed from collision layers; rigid bodies are frozen and
restored on completion. Complex dynamic assemblies should use a game-owned
editor that temporarily controls their simulation lifecycle.

When not editing, cancel frees only unconfirmed new instances. No globally
registered asset is silently removed. Do not edit a placeable simultaneously
from this session and another transform writer.

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
mutual stack permissions, chain bounds, invalid context and edit cancellation.
A consuming project should additionally test **real colliders** on steep,
uneven, obstructed and tiled terrain after physics has synchronized; test
multiplayer race conditions and save/reload using its own content and rules.

This release does not support surface-conforming mesh deformation, network
replication, spatial socket graphs, arbitrary spline chains, asset catalogs,
cost systems, automated chunk-stream awareness or prefab ownership transfer.

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
