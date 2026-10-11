# Optional destructible meshes (3D)

This module replaces an intact object with **real Godot rigid-body fragments**.
It is optional, written in GDScript and requires no .NET, Autoload or third-party
runtime dependency. A bounded planar slicer supports a subset of closed triangle meshes.

## Composition

Create a `StaticBody3D` or `RigidBody3D` containing a `MeshInstance3D` and
add `NucleusDestructibleMesh3D` as a child. Set its `source_mesh`, a
`NucleusFracturePattern3D` Resource with at least two
`NucleusFractureShard3D` Resources, and optionally a
`NucleusFractureProfile3D` Resource.

Shard meshes and local transforms are authored relative to the original
`MeshInstance3D`. Each shard may specify a `Shape3D` collision proxy;
otherwise Godot builds a convex collision hull on first fracture. Bake convex
proxies for performance and ensure meshes and collisions align.

For simple block-style objects, generate a pattern with:

```gdscript
var pattern := NucleusBoxFractureBuilder3D.build(
    Vector3(2, 2, 2), Vector3i(2, 2, 2)
)
$Destructible.pattern = pattern
```

The builder generates subdivided box meshes with box collision proxies; it
**does not slice arbitrary imported geometry**. For complex props, create the
pieces in Blender or another authoring tool and assign their meshes and local
transforms to the pattern.

## Dynamic planar mesh slicing

`NucleusMeshSliceBackend3D.slice(mesh, local_plane_point, local_normal, cap_material)`
returns either `{"reason": &"ok", "positive": ArrayMesh, "negative": ArrayMesh}`
or a failure reason. This is an allocation-heavy synchronous operation; apply it
on isolated destructibles with a small mesh complexity budget, not on every
physics tick. Both output meshes have separate triangles and interior cap faces.

```gdscript
var result := NucleusMeshSliceBackend3D.slice(
    $Crate/MeshInstance3D.mesh, Vector3.ZERO, Vector3.RIGHT
)
if result.get("reason") == &"ok":
    $Crate/Destructible.pattern = NucleusMeshSliceBackend3D.to_pattern(result)
```

Or use the runtime integration point with **world-space** plane normal and
impact position:

```gdscript
$Crate/Destructible.fracture_with_plane(
    world_hit_point, world_impulse, world_cut_normal, inside_material
)
```

The intact mesh remains in place on failure. Each half becomes a fragment,
with convex collision generated through Godot unless collision proxies were
provided separately. The source mesh must be a non-skinned triangle mesh
with **one simple planar cut contour**. Normals and primary UVs are interpolated;
surface materials are retained, while the optional cap material applies to
the cut faces. Secondary UVs, tangents, vertex colors, custom vertex channels,
blend shapes, holes, multiple disconnected cut loops, vertices directly on
the cut plane and nonmanifold topology are **not supported**. Unsupported
attributes or ambiguous contours are rejected rather than silently discarded.
There is a limit of 8192 input triangles, 4096 intersection segments and
32 surfaces per operation.

This is not equivalent to the source C# slicer with advanced triangulation
and multiple arbitrary cut loops. Use authored prefractured assets for irregular
props that require those capabilities.

## Runtime

```gdscript
# Only after game-owned damage/authority checks:
$Destructible.fracture(world_hit_point, world_impulse)
# After resetting the game object:
$Destructible.restore()
```

Signals: `fractured(fragments)`, `fracture_rejected(reason)`, `restored`.
The profile controls impulse threshold, per-object fragment cap, impulse
scaling and lifetime (0 = no timeout). The original visual is hidden and
the source body's collision layer/mask are disabled upon successful fracture;
restore re-enables them and clears generated rigid bodies.

## Ownership and limits

Godot owns rendering, physics and collision. Nucleus owns the lightweight
breakable adapter and Resource contracts. The game remains responsible for
damage admission, persistence, network authority, fragment art and world-wide
budgets. In multiplayer, replicate a semantic fracture event or deterministic
preset selection; do not make client-side debris authoritative.

This implementation provides bounded plane cutting and interior caps but not
arbitrary multi-loop or hole-cap triangulation, deformable meshes,
joint/rebar graphs, pooling or a global fragment budget. It limits shards per object, but developers should
also limit concurrent fractured objects. Avoid using scaled rigid bodies with
inconsistent collision dimensions.

## Technical inspiration

The uploaded **RuptureCore** C# project, copyright Kextex (2026), includes
prefractured assets, plane cutting, capping with LibTessDotNet, shard backends,
physics clustering and global budgets. Its plugin LICENSE.txt is MIT.
This GDScript module is an independently designed subset of those ideas rather
than a source-level C# port. Godot 4.7.2 is Nucleus's target, whereas the
uploaded demo's csproj targets Godot .NET 4.6.3.

Tests: `tests/headless/destructible_mesh_test.gd` and
`tests/headless/mesh_slice_test.gd` in the normal headless manifest. Physics feel, real imported meshes, collision performance, exports,
and behavior during network replication require further hands-on validation.
