# Optional Procedural Terrain Generation Module

## Status

`addons/nucleus/modules/terrain` is optional and is not loaded by default.

It is designed for projects that want to generate heightfield terrain quickly
from reusable data rather than make manual sculpting/painting the primary
workflow.

The module keeps Godot-native primitives visible:

```text
FastNoiseLite / Texture2D / heightmaps
ArrayMesh
MeshInstance3D
HeightMapShape3D / StaticBody3D
ShaderMaterial
scene-owned Nodes and Resources
```

It does not introduce a global terrain manager or replace dedicated terrain
editors such as Terrain3D or TerraBrush when hand sculpting/painting is the main
requirement.

## Public types

```text
NucleusTerrainProfile
NucleusTerrainLayout
NucleusTerrainTextureLayer
NucleusTerrainMaterialProfile
NucleusTerrainGenerator3D
NucleusTerrainStreamer3D
NucleusTerrainSurfaceSampler3D
```

## Ownership model

A normal authored terrain is scene-owned:

```text
World
└── Terrain : NucleusTerrainGenerator3D
    profile = TerrainProfile.tres
    layout = TerrainLayout.tres
    material_profile = TerrainMaterial.tres
```

Runtime linear streaming is also scene-owned:

```text
World
├── Player
└── TerrainStream : NucleusTerrainStreamer3D
```

There is no terrain Autoload.

## Height sources

`NucleusTerrainProfile` supports:

```text
FAST_NOISE
    FastNoiseLite sampled in world-space coordinates

HEIGHTMAP
    image sampling with optional source-range normalization

IMAGE
    generic grayscale image/noise texture sampling
```

Images can be stretched over each patch or repeated in world space.

An optional `Curve` remaps the normalized source before height scaling.

## Shape policy

The generated geometry remains a heightfield.

`RECTANGLE` keeps the complete patch.

`ISLAND` applies an elliptical shoreline mask. The mask can be perturbed by a
second `FastNoiseLite` to avoid perfectly round coasts. Outside the shoreline,
vertices descend toward `edge_floor_height`.

For ocean games this gives a cheap island contract:

```text
water plane at Y = 0
terrain edge_floor_height = -10 to -30
island interior rises above Y = 0
rectangular patch boundary remains hidden underwater
```

This does not create caves or overhangs. Those require non-heightfield geometry
and should be game-specific or use another terrain solution.

## Layouts

`NucleusTerrainLayout` separates shape generation from world placement.

```text
SINGLE
    one complete terrain patch

GRID
    contiguous authored terrain split into cullable patches

LINEAR
    fixed strip of patches along X or Z

ISLANDS
    deterministic scattered island patches with size variation and separation
```

`NucleusTerrainStreamer3D` provides a separate runtime path for a moving linear
window. It keeps only the requested number of chunks behind/ahead of a tracked
node.

The static layout and runtime streamer intentionally share the same
`NucleusTerrainProfile`.

## Editor preview

`NucleusTerrainGenerator3D` is a `@tool` node and exposes Inspector buttons:

```text
Refresh Preview
Generate Terrain
Clear Generated Terrain
```

Preview uses the exact same sampler as final generation but caps mesh density to
`preview_resolution` and creates no collision or LOD data.

Preview nodes have no scene owner and are not saved. Generated terrain receives
normal scene ownership when generation is executed in the editor.

`auto_preview_on_change` is disabled by default because rebuilding meshes on
every Inspector edit can make complex scenes unpleasant to author.

## Mesh generation and LOD

Terrain patches are built directly into `ArrayMesh` arrays:

```text
height samples
→ vertices / normals / UVs / indices
→ ArrayMesh
```

There is no intermediate `PlaneMesh -> SurfaceTool -> MeshDataTool` conversion.

Optional LOD levels reuse the full vertex buffer while supplying progressively
reduced index buffers to `ArrayMesh.add_surface_from_arrays()`.

This lowers distant triangle count without maintaining several copies of the
height samples.

Keep patch sizes reasonable. LOD does not make a single enormous CPU-generated
mesh free to build, upload, cull, or collide. Adjacent patches can choose different
LOD levels, so very small/high-relief chunks may expose edge seams. Increase patch
size, reduce LOD levels, or disable terrain LOD when that artifact matters more than
distant triangle savings.

## Collision

The default collision mode is:

```text
HEIGHTMAP
```

It creates a native `HeightMapShape3D` at an independently configurable
`collision_resolution`. The shape is scaled to the patch cell size. Nucleus uses
Jolt Physics by default; projects that switch to another 3D physics backend should
validate non-uniform heightmap scaling on their target platforms.

This is the preferred path for normal heightfield terrain and lets low-end
profiles use a much cheaper physics grid than the visual mesh.

`TRIMESH` is available as an explicit fallback but should not be the default for
terrain because concave triangle collision is more expensive.

`DISABLED` is useful for distant visual-only terrain or server/client policies
where collision is owned elsewhere.

For islands, `collision_holes_below_height` can replace samples below a chosen
height with `NAN`. Godot treats those samples as holes in `HeightMapShape3D`,
which is useful when underwater terrain does not need collision.

## Analytical surface sampling

`NucleusTerrainSurfaceSampler3D` adapts a static
`NucleusTerrainGenerator3D` to the generic `NucleusSurfaceSampler3D` contract.

Typical composition:

```text
Terrain : NucleusTerrainGenerator3D
└── SurfaceSampler : NucleusTerrainSurfaceSampler3D
```

The adapter reuses the same internal height source and layout descriptors used
for generated mesh/collision:

```text
TerrainProfile + TerrainLayout
        ↓
shared analytical height source
   ├── ArrayMesh
   ├── HeightMapShape3D
   └── SurfaceSampler3D result
```

No physics raycast is required and generated geometry does not need to exist.
This is useful for server-side world queries, procedural placement, camera rules,
and future physics systems that should sample the authored field rather than a
lower-resolution collision representation.

The sampler returns world-space:

```text
position
normal
zero surface velocity
```

Normals are estimated from nearby analytical samples. Configure
`normal_sample_distance` according to the terrain scale: too small can amplify
high-frequency noise; too large smooths small features.

The adapter respects translation, yaw, scale, and static `SINGLE`, `GRID`,
`LINEAR`, and `ISLANDS` descriptors. It returns `null` outside patch coverage.
Pitch/roll are intentionally rejected because the transformed terrain would no
longer be a single-valued surface over world X/Z.

Use `sample_into()` with a reusable `NucleusSurfaceSample3D` for high-frequency
queries such as future buoyancy loops.

Runtime `NucleusTerrainStreamer3D` is intentionally not covered by this first
adapter. Streaming introduces loaded/unloaded chunk policy and moving ownership;
that contract should be added only when a production consumer requires it.

See `docs/components/world_surfaces.md` for the generic sampler contract.

## Materials

`NucleusTerrainMaterialProfile` provides a small default procedural material,
not a complete terrain shading framework.

Up to four `NucleusTerrainTextureLayer` resources can blend by:

```text
normalized terrain height
surface slope
soft transition range
```

Each layer exposes:

```text
albedo texture or tint-only color
UV scale
height range
slope range
roughness
metallic
```

Two projection modes exist:

```text
Top projection
    one texture lookup per active layer; cheaper for low-spec hardware

Triplanar
    three projections per textured layer; better on cliffs/steep surfaces
```

Assign `custom_material` when the project needs a different shader, normal-map
workflow, biome system, virtual texturing, or another presentation stack.

## Runtime generation

`NucleusTerrainGenerator3D.generate_terrain()` is synchronous and best for the
editor, loading screens, or modest terrain counts.

`generate_terrain_async()` spreads multiple patch builds across frames using
`patches_per_frame`. Individual patch construction is still CPU work and should
be profiled on target hardware.

For continuous traversal, use `NucleusTerrainStreamer3D` instead of repeatedly
regenerating a whole world.

## Navigation

The module does not bake NavigationMesh data automatically.

Use Godot `NavigationRegion3D` normally and choose whether navigation should
parse generated static colliders or authored source geometry.

Navigation ownership, bake timing, agents, and region lifetime are game policy.

## Executable examples

The module ships small scenes under `res://examples/terrain/` for preview,
single-patch, grid, linear, island, and runtime-streaming workflows. They are
kept asset-light so they double as parser/regression fixtures in headless tests.

They are examples only. Generated terrain remains scene-owned by the consuming
game and none of the example scenes is loaded by default.

## Terrainy migration

The original Terrainy concepts map naturally:

```text
TerrainNoiseConfiguration.noise
    → NucleusTerrainProfile.noise

TerrainNoiseTextureConfiguration.noise_texture
    → height_source = IMAGE + image

TerrainHeightmapConfiguration.heightmap_image
    → height_source = HEIGHTMAP + image

mesh_resolution
    → resolution

size_width / size_depth
    → size

max_terrain_height
    → height_scale

elevation_curve
    → elevation_curve

falloff_texture
    → falloff_texture

radial_shape
    → shape_mode = ISLAND

procedural grid
    → NucleusTerrainLayout.GRID

infinite linear renderer
    → NucleusTerrainStreamer3D

create_trimesh_collision()
    → HEIGHTMAP collision by default
```

Terrainy's runtime brush and bundled image assets are intentionally not part of
this Nucleus module.

## When to use another terrain solution

Use a dedicated terrain editor when the game primarily needs:

```text
manual sculpting and paint workflows
large persistent painted splatmaps
terrain holes/caves/overhangs
very large clipmap worlds
32+ texture layers
foliage/object painting suites
specialized GPU/GDExtension terrain pipelines
```

Nucleus terrain generation is aimed at fast procedural worlds, authored seeds,
heightmap-driven levels, routes, and islands where generation policy matters
more than manual painting.
