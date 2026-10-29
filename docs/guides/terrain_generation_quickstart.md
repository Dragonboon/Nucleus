# Procedural Terrain Generation Quickstart

Use `addons/nucleus/modules/terrain` when the project needs fast generated 3D heightfield
terrain without adopting a manual terrain-painting workflow.

Technical contracts:

- [`../modules/terrain_generation.md`](../modules/terrain_generation.md)
- [`../modules/terrain_heightmap_materials.md`](../modules/terrain_heightmap_materials.md)

Focused tutorials:

- [`tutorials/terrain_preview_and_presets.md`](tutorials/terrain_preview_and_presets.md)
- [`tutorials/procedural_terrain_3d.md`](tutorials/procedural_terrain_3d.md)
- [`tutorials/terrain_heightmap_materials_3d.md`](tutorials/terrain_heightmap_materials_3d.md)
- [`tutorials/terrain_streaming_runtime.md`](tutorials/terrain_streaming_runtime.md)
- [`tutorials/terrain_debugging.md`](tutorials/terrain_debugging.md)

## 1. Add a generator

Create:

```text
World
└── Terrain : NucleusTerrainGenerator3D
```

The node is scene-owned. Do not add it as an Autoload.

## 2. Start from a profile or preset

Create a `NucleusTerrainProfile`, or duplicate one of:

```text
res://addons/nucleus/modules/terrain/presets/gentle_hills.tres
res://addons/nucleus/modules/terrain/presets/lowlands.tres
res://addons/nucleus/modules/terrain/presets/rugged_mountains.tres
res://addons/nucleus/modules/terrain/presets/archipelago_island.tres
```

For a custom noise prototype:

```text
height_source = FAST_NOISE
noise = FastNoiseLite
size = (256, 256)
resolution = 64
base_height = 0
height_scale = 45
collision_mode = HEIGHTMAP
collision_resolution = 32
lod_levels = 2
```

## 3. Preview before committing geometry

Assign the profile to `Terrain` and press:

```text
Refresh Preview
```

Start with:

```text
preview_resolution = 20 to 32
```

Open:

```text
res://examples/terrain/terrain_preview_presets.tscn
```

to compare several terrain families.

## 4. Use prototype/debug views

Select the generator and use:

```text
debug_view
debug_wireframe
debug_height_bands
debug_grid_scale
```

Useful order:

```text
Height bands
→ Slope
→ Layer weights
→ World grid
→ Wireframe
→ Material
```

Run the interactive lab:

```text
res://examples/terrain/terrain_debug_lab.tscn
```

Detailed guide:

[`tutorials/terrain_debugging.md`](tutorials/terrain_debugging.md)

## 5. Generate final terrain

Press:

```text
Generate Terrain
```

Generated hierarchy:

```text
Terrain
└── GeneratedTerrain
    └── TerrainPatch_000
        ├── TerrainMesh
        └── TerrainCollision
            └── CollisionShape3D
```

Heightmap collision now uses uniform collision-node scale and pre-scaled height
data to avoid the non-uniform `CollisionShape3D` warning.

## 6. Create complete, linear, or island layouts

Use `NucleusTerrainLayout`:

```text
SINGLE
GRID
LINEAR
ISLANDS
```

Noise sampling uses patch world positions, so contiguous chunks sample one
continuous source field.

For islands, combine:

```text
shoreline_noise
edge_floor_height
edge_floor_noise
```

to separate coastline shape from submerged-floor variation.

## 7. Scale imported heightmaps to the terrain budget

When physical terrain sizes vary significantly, use:

```text
NucleusTerrainResolutionPolicy
NucleusTerrainHeightmapProcessor
```

Typical flow:

```text
physical size
→ visual/collision resolution
→ prefilter source relief to representable frequency
→ TerrainProfile
```

Do not infer mesh density from source image dimensions.

Detailed guide:

[`terrain_heightmap_materials_quickstart.md`](terrain_heightmap_materials_quickstart.md)

## 8. Add multiple terrain textures

Create a `NucleusTerrainMaterialProfile` and up to four
`NucleusTerrainTextureLayer` resources.

Reference material:

```text
res://examples/terrain/materials/terrain_height_layers.tres
```

Each layer can use the original albedo/tint/scalar PBR contract plus optional:

```text
normal
normal_strength
roughness_texture
roughness_texture_strength
```

If the final result appears to use only one texture/color, switch to:

```text
debug_view = Layer weights
```

Magenta means no configured layer covers that point. Distinct layer colors mean
the rules work and the remaining problem is in texture/tint/projection setup.

## 9. Budget terrain material detail

`NucleusTerrainMaterialProfile` can fade normal/roughness texture detail with
camera distance and expose `MINIMAL / REDUCED / FULL` material quality.

The default Full path preserves the previous authored projection behavior.

Generated built-in materials are reusable through the profile's bounded material
cache when requests are equivalent.

## 10. Stream terrain at runtime

Run:

```text
res://examples/terrain/terrain_streaming.tscn
```

The HUD shows the current chunk, loaded indices, and pending chunk builds.

`NucleusTerrainStreamer3D` exposes the same debug view and wireframe controls as
the editor generator.

Detailed guide:

[`tutorials/terrain_streaming_runtime.md`](tutorials/terrain_streaming_runtime.md)

## 11. Query terrain without a raycast

For static `NucleusTerrainGenerator3D` layouts, add:

```text
Terrain : NucleusTerrainGenerator3D
└── SurfaceSampler : NucleusTerrainSurfaceSampler3D
```

Then query the same analytical height source used to build the terrain:

```gdscript
var sample := surface_sampler.sample(world_position)

if sample != null:
	print(sample.position)
	print(sample.normal)
```

This works even when final terrain geometry has not been generated and avoids
coupling height queries to collision resolution.

For hot paths, reuse one result:

```gdscript
var surface_sample := NucleusSurfaceSample3D.new()

func query_surface(world_position: Vector3) -> bool:
	return surface_sampler.sample_into(
		world_position,
		surface_sample,
	)
```

The static adapter supports translated/yawed/scaled heightfields whose local +Y
remains world-up. Runtime streamer sampling is intentionally a separate future
contract.

See [`../components/world_surfaces.md`](../components/world_surfaces.md) for the
generic analytical-surface API and ownership boundary.

## Performance checklist

Start here on weak hardware:

```text
visual resolution 48–96
collision resolution 24–40
resolution chosen from physical size
heightmap prefiltered to geometry sample budget
LOD 1–3 levels
Top projection
distance-faded PBR detail
terrain shadows disabled while tuning
one streamed patch per update
```

Use `get_debug_snapshot()` and wireframe to estimate topology, but verify real
cost with Godot's Profiler.
