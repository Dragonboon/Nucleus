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

## Modular building: rotated rules and bounded neighborhood updates

`NucleusModularRule.allow_rotations` lets a north-oriented authored rule
match east/south/west orientations without duplicating asset entries.
`NucleusModularRuleSet.resolve_variant(mask)` returns `variant_id`,
`rotation_steps`, `matched` and `neighbor_mask`. Existing
`resolve(mask)` keeps returning a `StringName` for compatibility.
Higher rule priority wins; exact/unrotated wins on equal priority; finally
the first authored rule wins. Rules are capped at 64 for deterministic cost.

`NucleusModularNeighborhood.resolve_around(changed, occupied, rules)`
returns five descriptors in stable order: changed, north, east, south, west.
The callback accepts a `Vector3i` so other elevation layers are never
used to determine connections. For erased cells, the descriptor has
`occupied=false`, allowing the presenter to dispose visuals.
This planner is pure and does not alter grid occupancy or game authority.

An optional `NucleusModularVariantBinding3D` accepts that result and
an explicitly assigned `NucleusPlacementVariantSet3D` with an allowlisted
`PackedScene` per variant. This is a visual-only example adapter:
it does not invoke `PlacementSession3D.confirm()`, spawn authoritative
entities, or validate building support. Do not use scenes with live physics
or gameplay scripts as visual assets. Such construction scenes must instead
go through the established Placement solver and game admission policy.

Open `res://examples/modular_building/modular_building_lab.tscn` to
paint/remove neighbor-connected pieces on a bounded 3D SquareGrid with
Z/X layer selection. The demonstration owns input and art, and the core
remains unaware of survival-game or architecture-specific rules.
