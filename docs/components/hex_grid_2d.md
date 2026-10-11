# Hex Grid 2D + shared axial topology (Godot 4.7.x)

Nucleus owns **one topology**, not a universal hex-grid game engine.

| Concern | Owner |
| --- | --- |
| Axial math, pointy/flat projection, corners, neighbors, bounded line and BFS | `NucleusHexLayout` (pure `RefCounted`) |
| Old XZ API | `NucleusHexLayout3D` delegates to the shared owner |
| Canvas rendering, occupancy, selection, orientation, corner/edge events | `NucleusHexBoard2D` (scene-owned `Node2D`) |
| Native 3D mesh previews, layers, collisions out of scope | `NucleusHexBoard3D` (scene-owned `Node3D`) |
| Input, permissions, terrain, sprites, TileMapLayer/TileSet, save slots, path costs | Consumer scene/game |

## Geometry and coordinates

- `Vector2i(q, r)` are axial coordinates; `s = -q-r`. Stored identity is
  independent of world position, radius or board rotation.
- `NucleusHexLayout.axial_to_pixel(cell, radius, flat_top)` and
  `pixel_to_axial(point, radius, flat_top)` provide center conversion.
- `corner_offset(index, radius, flat_top)` gives physical corner offsets.
- `corner_key(Vector3i(q, r, layer), index)` yields **integer vertex identity**.
  The third key component prevents contacts between different 3D layers.
  Individual tile facing does **not** change the regular hex footprint.
- `neighbor`, `edge_neighbor`, `diagonal_neighbor`, `distance`,
  `rotate_axial`, `cells_in_radius`, `line` are reusable for both dimensions.
- `shortest_path(start, goal, can_enter, maximum=2048)` runs **uniform-cost BFS**.
  The consumer provides the passability predicate. It is not weighted A*,
  navigation or an authority check. It returns an empty path when unreachable
  or after the configured bounded search limit.

## 2D board API

```gdscript
var board := NucleusHexBoard2D.new()
add_child(board)
board.cell_radius = 24.0
board.set_flat_top(true)
var cell := board.world_to_cell(get_global_mouse_position())
if board.paint_cell(cell):
    board.rotate_tile(cell, 1)
```

`NucleusHexBoard2D` uses batched `CanvasItem._draw()` calls for visual cells
and ghost outlines. It does not spawn `Sprite2D` nodes per tile or mandate
`TileMapLayer`; a game with a `TileSet` can consume the same axial math and
store and render its own assets. The reference board allows up to 1024 tiles,
with at most 24 rings. Paint/move/delete reject invalid occupancy.

Signals: `tile_painted`, `tile_erased`, `tile_moved`, `tile_rotated`,
`corner_connected`, `corner_disconnected`, `edge_connected`,
`edge_disconnected`. A neighboring pair shares **two vertex contacts and one
edge contact**. The pairs are emitted once, when the second tile joins or the
first leaves. Signals indicate topology, not physical welds or connectors.

`highlight_selection`, `set_hover`, `set_cell_radius`, `set_ring_count`,
`set_flat_top` configure the runtime visuals without rewriting axial IDs.
A selected tile displays an orientation marker; other tiles have uniform faces.

## 3D compatibility and extension

The previous `NucleusHexLayout3D` signatures still accept their original
parameters; the new `flat_top` parameter is optional, **false by default**.
The 3D board exposes a matching `flat_top` property and `set_flat_top()` and
adds matching edge signals. Existing 3D saved coordinates `(q, r, layer)` and
`rotate_tile` direction steps remain unchanged. Ghost outlines now draw shared
interior edges once, avoiding unnecessary doubled alpha and rendering work.

The board remains a **visual authoring component with no colliders**. Attach
physics-aware placeables through the established Placement3D solver rather than
assuming painted cells grant authority or physical support. A full 3D terrain
materialization/chunking system is intentionally excluded.

## Verification

Run `python scripts/ci/static_checks.py` after extracting this overlay;
`tests/headless/test_manifest.gd` registers the **existing** 3D suite and the
**new** 2D suite. Both files are included. Run:

```bash
godot --headless --path . --import
godot --headless --path . --script res://examples/hex_grid/hex_grid_smoke.gd
godot --headless --path . --script res://examples/hex_grid_2d/hex_grid_2d_smoke.gd
```

For graphics and input, use F6 with
`res://examples/hex_grid_2d/hex_grid_2d_lab.tscn` and
`res://examples/hex_grid/hex_grid_lab.tscn`.

Test a pointy/flat toggle after painting, select + rotate one tile, drag fast
across the board (no gaps), and confirm edge and corner signals pair correctly.
No Godot executable was available in the packaging environment; static checks
are not a substitute for compiling the scripts and running the two scenes.

## External research

Source-inspired feature choices (no source code copied):
- `jeremyz/godot-hexgrid` (MIT): axial/range/path fundamentals; do not copy its
  tactical combat LOS and movement costs into a generic grid.
- `davepruitt/hex_map_godot` (MIT): clearly separated cells and scalable 3D
  visuals; avoid duplicating Nucleus terrain/scatter/chunk rendering.
- `esbudylin/HexChess` (MIT code, extra asset constraints): 2D tile overlays and
  visual orientation; avoid chess rules, Rust/Godot3.5 integration and assets.
- `HugoEnzo/HexGrid_Godot_4.0` (MIT): pointy/flat layouts, neighbors, cube
  rotation; keep Nucleus typed contracts and compatibility instead of plugin UI.
