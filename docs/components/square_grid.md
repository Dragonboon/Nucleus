# Square Grid and Modular Construction Rules

Optional Godot 4.7 components, built to complement rather than replace native
`TileMapLayer`, `TileSet`, and `GridMap`.

## Ownership
- `NucleusSquareLayout`: pure cell math, cardinal neighbors, exact shared corners, 2D orthogonal/isometric projections, bounded strokes and BFS.
- `NucleusSquareBoard2D`: bounded scene-owned integer occupancy and lightweight CanvasItem rendering for validation or editor-like gameplay.
- `NucleusSquareBoard3D`: bounded noncolliding 3D placeholder meshes and horizontal layer projection. Visuals are NOT placement physics or terrain collision.
- `NucleusModularRule` and `NucleusModularRuleSet`: Resource-driven four-sided connection masks and stable variant IDs. No scene instantiation.
- **Game**: inputs, authoritative construction, catalogs, asset scenes, attachment constraints, inventory costs, persistence, placement solver and networking.

The bitmask is North=1, East=2, South=4, West=8. Resolve a mask
with `rule_set.resolve(mask)`, or use
`NucleusModularRuleSet.neighbor_mask(cell, occupied_callable)`.
Any source of occupied cells is valid: square boards, Godot GridMap, a
TileMapLayer, or game-owned logical construction data.

```gdscript
var variant: StringName = rules.resolve(
    NucleusModularRuleSet.neighbor_mask(cell, board.has_tile)
)
# The game maps this stable ID to its own PackedScene or TileSet alternative.
```

The rules intentionally do not resolve placement collisions or automatically
update surrounding cells: the consuming game should re-evaluate the changed cell
and its four neighbors, then apply variants through its own authorized catalog.

## Interactive examples
- `res://examples/square_grid/square_grid_2d_lab.tscn`:
  orthogonal/isometric switch, left-click paint, right-click erase and R rotate.
- `res://examples/square_grid/square_grid_3d_lab.tscn`:
  click paint/erase, Shift+click selection, Q/R rotation, Z/X layer\n  change, a bounded ghost grid, hover outline and orientation indicator.

Both labs use no assets, Autoloads, plugin installation, or generated colliders.
They are demonstrations, not production construction controllers.

## Limits and verification
Both boards are bounded to 1024 tiles. 2D extents are capped at 24 per axis;
3D is a small yaw-oriented XZ grid with explicit elevation layers.
The isometric option changes projection only, never cardinal topology.
Re-evaluate occupancy when generating variants: the rule solver is stateless.
No terrain draping, physical snap, multi-cell placements, or global mutable world
manager is introduced.

`tests/headless/square_grid_test.gd` covers orthogonal/isometric round trips,
negative coordinates, BFS, exact edge sharing, rotation, 3D layers and rules.
Run the registered headless manifest and both scenes graphically before release.
