# Optional 3D Scatter Generation (Godot 4.7.x)

`addons/nucleus/modules/scatter` fills the gap between world-space placement rules and low-cost
native rendering. It is **optional**, scene-owned and game-agnostic.

## Source inspirations and what is deliberately excluded

- **ProtonScatter:** composable distribution and spatial MultiMesh batching.
- **ScatterShot (Evan Todd):** jittered deterministic cell sampling, density
  masks, bounded chunk creation and independent weighted variants.
- **Zylann Scatter (Marc Gilleron):** artist-owned placement and erase/undo as a
  future editor-only workflow, **not** a runtime dependency.

This is a new implementation, not copied source. Do not install the source
plugins to use this module.

## Public API

```text
NucleusScatterVariant3D       Resource; mesh, weight, shadows, visibility range
NucleusScatterProfile3D       Resource; deterministic placement recipe
NucleusScatterDensityVolume3D Node3D; scene-owned world-space density modifier
NucleusScatterBuildJob3D      incremental main-thread candidate generator
NucleusScatterBatch3D         bounded native MultiMeshInstance3D
NucleusScatterRegion3D        optional scene-owned region adapter
```

The game owns **which** meshes are present, biome masks, point-of-interest
placement, authoritative world state, multiplayer region interest and gameplay
collisions. Generated visual foliage/rocks are not authoritative game objects.

## Pipeline

```text
consumer's desired region IDs + bounds
    -> NucleusScatterRegion3D.start_build(existing MaterializationQueue)
    -> ScatterBuildJob3D (fixed cells_per_step, main thread)
    -> analytical NucleusSurfaceSampler3D.sample_into()
    -> slope / height / density / minimum-spacing filters
    -> weighted mesh-variant groups
    -> spatial tiles and capped MultiMeshInstance3D batches
    -> region_ready, or explicit failure
```

`NucleusScatterBuildJob3D` is also usable without `NucleusScatterRegion3D`.
The job returns world-space `Transform3D` arrays grouped by variant index.
This makes headless generation possible without creating any renderer objects.

## Determinism and streaming boundaries

Generation is indexed by global X/Z grid coordinates, using a bounded integer
mix of `profile.seed`, cell coordinates and a per-decision salt. It does not
advance a per-region RNG stream. The same global cell has the same jitter,
acceptance, orientation, size and variant regardless of the region processing
order.

Regions own **half-open** X/Z rectangles: `[minimum, minimum + size)`.
Neighbour candidate checks include global cells across the region boundary.
Minimum-separation decisions use consistent hash priority, yielding matching
results for adjoining regions versus a larger joined region when they share the
same profile, surface, volumes and coordinate system.

This is a deterministic **jittered-grid with competitive thinning**, not a
perfect Poisson disk/blue-noise distribution. It deliberately prefers bounded
work and stable streaming seams over maximum packing density.

A job has a hard `262144` cell guard. Large worlds must be split into regions.
Avoid changing the authored profile or density volumes while a job runs.

## Density and surfaces

`NucleusScatterDensityVolume3D` is a scene-owned oriented X/Z box whose
multiplier lies in `[0, 1]`. Several volumes multiply together; a `0` volume
excludes candidates. There is no global registry or every-frame volume scan.

The sampler is native to the existing Nucleus surface query contract; terrain
heightfields can use `NucleusTerrainSurfaceSampler3D` without physics raycasts.
Generic collidable meshes would need a separate, game-owned physics adapter;
this module never queries `PhysicsDirectSpaceState3D` in background threads.

The `minimum_height`, `maximum_height`, `maximum_slope`, random yaw, uniform
scale interval, normal alignment and vertical offset are explicitly authored.
The generator samples one reusable `NucleusSurfaceSample3D` object to avoid one
allocation per candidate.

## Rendering and physics

One `NucleusScatterBatch3D` draws **one Mesh** with `MultiMeshInstance3D`.
The region groups accepted transforms by species and spatial tile, then further
splits each tile by `batch_size_limit` (never exceeding 512 instances).
Each batch calculates a conservative custom AABB including rotated/scaled mesh
bounds. This enables native culling of whole spatial batches, not individual
objects within a MultiMesh.

Batch creation is capped via `batches_per_frame`. RenderingServer allocations
and native Mesh work remain on the main thread. No per-frame transforms, no
extra renderer, no compute shaders, no hidden thread safety suppression, no
mandatory Autoload and **no physical shapes for visual-only scatter**.

When a game needs interactable rocks, buildings, destructible trees, etc., it
owns a separate gameplay scene/collider placement flow. Do not attach gameplay
scripts to invisible MultiMesh instances or replicate foliage transforms.

`visibility_end` and `cast_shadows` are native rendering controls on each
variant. The game may choose different variants/profiles for `MINIMAL`,
`REDUCED`, and `FULL`; no shadow-quality manager is introduced here.

## Ownership, cancellation and failure

`NucleusScatterRegion3D.start_build(queue)` requires a scene-entered region and
an explicit `NucleusMaterializationQueue`. It cancels any older job, advances a
generation token and ignores stale callbacks. Previous rendered content remains
visible during regeneration until new generation completes. `unload()` cancels
work and removes generated batches. `region_failed` reports errors rather than
spinning/retrying automatically.

The consuming game determines region load priority/eviction using its own
`NucleusWorldStreamLifecycle`. The region helper does not discover cameras or
change network interest.

## Performance gates

Measure representative scenes and target hardware:

- 1k/10k/50k visual instances spread across many regions.
- CPU sampling cost and p95 update hitches, especially native batch uploads.
- GPU geometry and shadows; compare with individual `MeshInstance3D` placement.
- Culling versus batch size, distance settings and different species counts.
- Reload/teleport cancellation, memory reclamation and headless behavior.

**No absolute speedup is claimed without benchmark measurements.** The default
caps are conservative starting points, not universal production budgets.

## Exclusions and future work

No editor painting suite yet; Zylann-style brush strokes should operate on an
artist-owned authored override layer with proper `EditorUndoRedoManager`, scene
ownership and non-destructive exclusion masks. No automatic cross-session cache
until invalidation rules and actual generation costs warrant one. No generic
arbitrary modifier stack, GPU compute, physics-per-grass or network replication
of decorative placements.
