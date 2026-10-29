# Hex Grid 3D — optional runtime composition

**Reference:** Godot 4.7.2. **Status:** initial hex authoring foundation, not a replacement for the physical placement solver.

## Why this is in Nucleus

The existing `NucleusPlacementSession3D` handles physical admission, terrain support, preview, editing, and chains. It does not represent an **axial hexagonal topology**, exact corner connectivity, or a ghost hex grid. Those concepts are useful to independent games (board games, modular world builders and strategy/survival systems), so they are a small optional component under `addons/nucleus/components/world/hex_grid`.

| Ownership | Responsibility |
|---|---|
| Godot | Node3D transforms, Mesh, camera ray projection, physics |
| `NucleusHexLayout3D` | Pure pointy-top axial coordinates (q, r), XZ projection, cube rounding, corner identity, bounded rings |
| `NucleusHexBoard3D` | Scene-owned occupied cells, tile geometry, ghost outlines, hover, editing, and corner connection signals |
| Consuming game | Input, camera, asset catalogs, editing UI, authorization, collision acceptance, networking, save slot |

There are **no new Autoloads** and no hard dependency on Scatter, Terrain, or WorldState.

## Coordinates, dimensions and transforms

- `Vector2i(q, r)` is the integer axial address of a hexagon.
- `Vector3i(q, r, layer)` is the occupied slot of a tile; equal q/r on distinct layers are independent.
- A **pointy-top** hexagon lies in local XZ; its corners start at local -Z.
- `cell_radius` is the distance from center to corner **in world units before the board transform**.
- `ring_count` is the maximum axial distance from (0, 0) displayed and accepted, bounded 1–24.
- `tile_height` is the visual extrusion of the demo tile. `layer_step` is the distance between consecutive layers.
- Move and rotate `NucleusHexBoard3D` using native `Node3D.position` / `.rotation.y`. All cell coordinates remain stable; mapping uses native `to_local` / `to_global`.

Example:

```gdscript
@onready var hex_board: NucleusHexBoard3D = $HexBoard

var world_point: Vector3 = hex_board.cell_to_world(Vector3i(2, -1, 0))
var cell: Vector3i = hex_board.world_to_cell(world_point, 0)
assert(cell == Vector3i(2, -1, 0))

hex_board.set_cell_radius(2.0)
hex_board.set_tile_height(0.7)
hex_board.set_layer_step(1.25)
hex_board.set_ring_count(9)
hex_board.set_active_layer(1)
```

Use the `set_*` methods for runtime changes so visual geometry and placement coordinates refresh. Changes to `ring_count` do not delete older painted cells outside the newly reduced extent: painting/moving to those locations is simply rejected until the bounds include them again.

## Painting, selecting and moving

```gdscript
var cell := Vector3i(1, 0, 0)
if hex_board.paint_cell(cell):
    print("Tile created")

hex_board.rotate_tile(cell, 1) # +60 degrees
hex_board.move_tile(cell, Vector3i(1, -1, 0))
hex_board.erase_cell(Vector3i(1, -1, 0))
```

- `paint_cell()` creates one small **visual placeholder** using a shared hex-prism Mesh.
- Paint fails for occupied cells, out-of-range cells and when the 1024-tile safety limit is reached.
- `move_tile()` transfers one tile atomically between free cells, preserving rotation. This is not a collision-tested operation.
- `rotate_tile()` stores an integer 0..5 to avoid accumulating angle drift. The placeholder prism has a contrasting top wedge so its orientation is visible.
- `clear_tiles()` erases all cells and triggers the normal disconnect lifecycle.
- `intersect_cursor(camera, viewport_mouse_pos, layer)` casts a ray onto the board's active horizontal plane (no physics dependency), returns `{cell, world_position}` or `{}` when outside.
- `NucleusHexLayout3D.stroke_cells()` fills the axial cells crossed by rapid cursor movement, up to 64 cells per update.
- `set_hover(cell)` highlights the cell; the ghost outline mesh rebuilds **only** when dimensions/layers change, not on mouse movement.

## Corner connections

Two occupied slots in the same layer emit `corner_connected(cell, corner, other, other_corner, world_point)` once for each **shared vertex** when the second tile appears. Neighbors typically share **two** vertices (one per endpoint of their common edge). When an endpoint tile is erased or moves, `corner_disconnected` is emitted for the corresponding shared vertices. Different layers never connect.

Vertex keys are **integer topology**, not rounded world positions. They remain stable through board rotation and radius changes. Signals indicate a coincidence of corners, **not** a structural joint, socket orientation match, permissions, weld, network replication or physical support.

Consumers may implement "on vertex connection, build a post" or "trigger a wall corner" after applying their own rules. To avoid duplicate posts, key the shared vertex by `NucleusHexLayout3D.corner_key(cell, corner)`.

## Physics placement and networking

This initial module deliberately does **not** automatically call `NucleusPlacementSolver3D`. The standalone demo paints noncolliding placeholder prisms to prove topology, editing and UX. For physical assets, use `cell_to_world(cell)` as a **candidate position** for the existing `NucleusPlacementSession3D` / solver, validate support and clearance there, and only then record an authoritative tile. Do not call `paint_cell()` as evidence that a building or vehicle can safely exist on that surface.

On multiplayer: the server validates coordinates, asset permissions and physical placement. Corner signals are local notifications derived from committed cell state. Save `q`, `r`, `layer`, rotation steps, radius and layer dimensions as data; use `NucleusSave`/`NucleusSaveSession` for durable world storage, and `WorldState` only when regional persistent entities are needed. Never persist Node pointers or emit authoritative construction RPCs directly from the demo.

## Bounds and performance

- 24 rings = 1801 ghost cells, 10806 line segments. Only one `ImmediateMesh` rebuild per changed size/layer.
- Tile count is capped at 1024. The board creates `MeshInstance3D` tile nodes with one shared `ArrayMesh` and one shared material.
- Connections use a dictionary indexed by **exact integer vertex keys**, so painting/erasing one tile touches six keys, not every tile in the scene.
- `clear_tiles()` deliberately emits disconnect signals: listeners can remove decorations they own.
- No per-frame collision sampling, remeshing or scene scan is performed by this module.

## Known limitations (next iteration)

- Only **pointy-top** grids on a plane; no automatic uneven terrain draping/height-field sampling.
- Tile visuals are placeholders. There is no authored PackedScene socket graph or edge/vertex orientation policy yet.
- No optional 3D snap provider wired into `NucleusPlacementSession3D` in this first slice; the existing system remains unchanged.
- The lab does not implement save/load for painted hex cells or group undo. Introduce this by composing existing Nucleus save/history services, not parallel file IO.
- Board transforms are expected to be **yaw-only with unit scale**. Skew/pitch/roll and nonuniform scale are not supported as editing configurations.
- Hex ring size is a radius in cells. It is distinct from `cell_radius` and `tile_height`.

## Validation

```bash
godot --headless --path . --import
godot --headless --path . --script res://examples/hex_grid/hex_grid_smoke.gd
```

The smoke checks axial coordinate round trips, exact vertices, layer isolation, connections, edit transforms, dimensional changes and bounds. Also open `res://examples/hex_grid/hex_grid_lab.tscn` (F6) to validate mouse input and appearance.


## Selection direction marker

The hex tile mesh is intentionally rotationally symmetric. Individual yaw is
stored in `_angles` and applied to the tile node (`rotate_tile`), independent
of the board's transform. To make orientation visible, the board owns one
shared `SelectedOrientation` gizmo: it tracks only the highlighted tile, not
all painted cells. `set_show_selected_orientation(bool)` toggles this purely
visual marker; it does not modify tiles, corner keys, rotation steps or events.
The shared hex prism no longer colours a top-face wedge.

## Shared 2D/3D topology extension

From this overlay, `NucleusHexLayout3D` is a compatibility wrapper around
`NucleusHexLayout`; it adds a final optional `flat_top` argument to projection
and corner functions. `NucleusHexBoard3D` adds `flat_top` and `set_flat_top`,
`edge_connected` and `edge_disconnected` while retaining the original vertex
signals and axial `(q,r,layer)` identity. Ghost grid edges are drawn once.

See `docs/components/hex_grid_2d.md` for the shared ownership and 2D consumer.
