# Scatter Generation Quickstart

Target: Godot 4.7.x. Read `docs/modules/scatter_generation.md` for the contract.

## Setup

1. Create `NucleusScatterVariant3D` resources with a **Mesh**, optional material,
   relative weight, shadow setting and visibility range.
2. Create one `NucleusScatterProfile3D`, assign the variants, and configure
   `grid_spacing`, `density`, `jitter`, `maximum_slope`, seed and scale range.
3. Put a `NucleusTerrainSurfaceSampler3D` under your terrain generator or use a
   `NucleusPlaneSurfaceSampler3D` for a flat prototype.
4. Add a `NucleusMaterializationQueue` to your world scene (only if none already
   exists) and a `NucleusScatterRegion3D` for each desired streaming region.
5. Set `profile`, `surface`, `region_id` and `region_size` on each region.
6. Build explicitly:

```gdscript
var build_error: Error = scatter_region.start_build(materialization_queue)
if build_error != OK:
    push_error("Scatter build could not start: %s" % error_string(build_error))
```

Listen to `region_ready(region_id, instance_count)` and
`region_failed(region_id, error)` to drive loading UI or diagnostics.

Use `scatter_region.unload()` when that game-owned region becomes undesired.
The region helper itself never polls camera distance.

## Optional density modulation

Add `NucleusScatterDensityVolume3D` nodes, set `size` and `density_multiplier`,
then add explicit references to the region's `density_volumes` array. A `0`
multiplier excludes points in the oriented X/Z rectangle. This is useful for
roads, harbors, buildings and authored no-foliage spaces.

## Game-specific integration

For Nautica, the game's biome/spawn system decides which profiles belong to an
island and which height/slope ranges count as vegetation. Supply that choice to
Nucleus; do not hard-code grass, biome IDs, coast bands, player cameras, or
network ownership into `addons/nucleus/modules/scatter`.

## Suggested profiling

Start with small region sizes (e.g. 32 by 32 world units), `candidates_per_step`
of 128, `batch_size_limit` around 256 and `batches_per_frame` at 1 or 2. Measure
before raising budgets or shrinking tile size. Test camera teleports, streamed
region unloading, shadows and GPU cost on low-end target hardware.
