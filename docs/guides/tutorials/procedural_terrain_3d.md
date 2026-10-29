# Tutorial: Build a Procedural Island Chain

This tutorial demonstrates the optional heightfield terrain module with a bounded
archipelago example. Island placement here is an example of `NucleusTerrainLayout`,
not a claim that Nucleus owns a game's world/biome/progression policy.

## Scene

```text
OceanWorld : Node3D
├── Terrain : NucleusTerrainGenerator3D
├── Ocean : MeshInstance3D
└── Player : CharacterBody3D
```

Keep ocean rendering, buoyancy, biome/content placement and progression outside
the terrain module.

## Profile and preview

Duplicate `res://addons/nucleus/modules/terrain/presets/archipelago_island.tres` into game-owned
content and assign it to `Terrain.profile`. Tune noise, coastline falloff,
shoreline perturbation and submerged floor while using a low preview resolution.

The regular heightfield mesh remains a grid; shoreline/floor noise changes sampled
height/shape rather than removing the patch boundary.

## Example deterministic layout

Create a `NucleusTerrainLayout` with `mode = ISLANDS`, an authored island count,
spread, scale range, minimum separation and seed. The same seed/layout parameters
produce the same placement under the supported runtime.

These descriptors are terrain layout primitives. A consuming game decides how
many land masses exist, which are important, their biome/content identity and how
they participate in progression.

## Material, LOD and collision

Use the example height-layer material as a starting point. Keep projection,
texture-layer count, shadows, mesh resolution and collision resolution within the
measured hardware budget. Heightmap collision can be lower resolution than visual
geometry when gameplay permits.

For submerged visual terrain that should not collide, use the profile's collision
hole policy around the authored water level.

## Heightmap/image sources

Known shapes can use `HEIGHTMAP` or `IMAGE` sources while retaining preview,
layout, material, LOD and collision composition.

## What stays game-owned

```text
ocean rendering / waves
biome simulation and palettes
foliage / settlements / POIs / objectives
roads / rivers / erosion simulation
procedural-world save descriptor
network authority / replication
navigation bake policy
runtime deformation policy
```

Use [`terrain_preview_and_presets.md`](terrain_preview_and_presets.md) for editor
iteration and [`terrain_streaming_runtime.md`](terrain_streaming_runtime.md) only
when a moving linear terrain window is actually the right world shape.
