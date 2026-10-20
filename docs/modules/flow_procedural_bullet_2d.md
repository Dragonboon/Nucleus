# Optional 2D flow navigation, procedural grids and high-count projectiles

These independent components are intended for more than bullet-hell games.
None creates a default Autoload or replaces Godot native physics, TileMapLayer,
NavigationServer2D or rendering.

## Shared flow navigation

NucleusFlowField2D stores a bounded grid of passable cells and computes a
multi-source breadth-first distance field. Many agents may query the same
field. Obstacle masks and goals are caller-owned; rebuild after changes.

NucleusFlowFieldMotionSource2D optionally converts the field's direction into
a NucleusMotionSource2D intent. NucleusCharacterMotor2D still owns movement,
collision and move_and_slide(). TileMapLayer, when assigned, converts
world positions to grid cells; otherwise a regular cell-size mapping applies.

Flow fields are appropriate for many pursuers sharing goals. Use native
NavigationAgent2D for detailed per-agent navigation. BFS is unweighted and
8-way movement is an approximation, not an exact Euclidean shortest path.
Keep field sizes bounded and schedule rebuilds through existing scene-owned
NucleusUpdateScheduler for moving targets.

## Seeded 2D region generation

NucleusProceduralGrid2D returns 1-byte-per-cell deterministic region data.
The caller configures a region size, seed and an optional FastNoiseLite resource.
If FastNoiseLite is supplied, its seed/configuration is owned by the caller.
Without one, the built-in deterministic hash uses the generator seed.

Regions are addressed in global integer cell coordinates (including negatives).
The consuming game owns cell meaning, collision, terrain rules, visualization
with TileMapLayer, modifications and persistence. Compose region IDs with
NucleusWorldStreamLifecycle and persistent changes with NucleusWorldStateService.
Generation does not allocate scene nodes and should be called only within
explicit work budgets.

## High-count lightweight bullets

NucleusBulletField2D is an optional Node2D that stores positions, previous
positions, velocities and remaining lifetimes in packed arrays. It has one
_physics_process and one _draw rather than one per bullet. Spawns are bounded
by a maximum active capacity and a per-physics-tick admission budget.
Swap removal is O(1) but does not preserve list ordering; identify bullets
using their monotonically increasing IDs.

For example:

```gdscript
var field := NucleusBulletField2D.new()
add_child(field)
field.spawn_radial(Vector2.ZERO, 160.0, 40, 2.0)
field.spawn_fan(Vector2(50, 0), 180.0, 12, 1.5, PI, PI / 3.0)
```

query_swept_circle() performs a bounded linear sweep against a circular target.
It returns bullet IDs and does not apply damage, decide teams, destroy hits or
claim to be Godot's PhysicsServer2D. The game owns those rules. This simple
query is suitable for a small set of important targets; for thousands of
targets, benchmark a game-owned spatial broad phase first. Rendering is based
on CanvasItem draw_circle for portability; extreme counts may benefit from
MultiMeshInstance2D, GPU particles or custom shaders as an alternative,
not an automatic assumption.

## Validation and limits

A headless contract suite checks obstacle routing, stable region output,
negative indexing, admission limits, compact removal and swept detection.
Use real Godot scenes and profiling before claiming a projectile count or frame
rate target; per-device GPU/CPU limits and material use change the outcome.
