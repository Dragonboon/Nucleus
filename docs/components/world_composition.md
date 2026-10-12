# Optional World Composition: Biomes, Scatter, POI and Streaming

## Ownership

| Data or action | Existing owner | Composition point |
| --- | --- | --- |
| Height and normal | `NucleusSurfaceSampler3D` | `NucleusBiomeSurfaceQuery3D` |
| Climate and biome lookup | `NucleusBiomeComposer3D` | `sample_biome(world_xz)` |
| Scatter candidate generation | `NucleusScatterBuildJob3D` | optional density `Callable` |
| Region visual batching | `NucleusScatterRegion3D` | `density_filter` |
| POI descriptors | `NucleusPOIPlanner3D` | `sample_poi(world_xz)` |
| Streaming admission | `NucleusWorldStreamLifecycle` | the game wires load/unload tokens |
| Actual structures, materials, collision, network/save | consuming game | game-owned policy |

No new Autoload, world manager, heightfield renderer or authoritative entity spawner.

## Integration

Create a scene-owned surface sampler (for example,
`NucleusTerrainSurfaceSampler3D`) and a `NucleusBiomeComposer3D`.
Then compose them without duplicating surface queries:

```gdscript
var query := NucleusBiomeSurfaceQuery3D.new(terrain_surface, biome_composer)

# POIs: preserve globally seeded cell IDs through load/unload.
var plan := NucleusPOIPlanner3D.plan(
    region_minimum, region_size, poi_recipe, biome_composer, query.sample_poi
)

# Scatter for one biome. Keep the callback alive while its job runs.
var accepted_biome: StringName = &"forest"
scatter_region.density_filter = func(xz: Vector2) -> float:
    return query.density_for_biome(xz, accepted_biome)
scatter_region.start_build(existing_materialization_queue)
```

The callback accepts world X/Z and returns a numeric multiplier in [0, 1].
Invalid or nonfinite results are treated as zero density (fail closed).
**Importantly, the callback is evaluated both for candidate admission and
for neighboring competition during minimum-separation testing**. Keep it
deterministic and avoid scene mutation or RNG stream advancement inside it.
This preserves scatter seam consistency with the same sampler, biome rules,
filter, seeds and density volumes.

The callback is optional; leaving it unset preserves the original Scatter API.
A callback is a runtime reference, not a serializable Resource. Unload/cancel
the old job before changing its captured query or mutable authoring data.
A surface query is a main-thread adapter; it is not a worker-thread API.

## Sample laboratory

`res://examples/world_composition/world_composition_lab.tscn` uses one
analytical plane, a FastNoiseLite climate field, POI planning and the existing
`NucleusWorldStreamLifecycle` to display and replace bounded region
visualizations. Press Tab to switch regions; unloaded region nodes are freed.
It deliberately draws color tiles and POI markers rather than pretending to
be the full terrain/scatter/materialization pipeline. Use the existing
Scatter example for real MultiMesh batch testing.

## Validation

`tests/headless/world_composition_test.gd` covers the analytical
surface bridge, deterministic filtered scatter across two adjacent regions,
exclusion and POI surface integration. The existing world streaming, scatter
and POI suites remain registered.

This integration does **not** automatically paint biomes into terrain
materials, reserve POI exclusion volumes, create roads between settlements,
or materialize authoritative structures. Those are game policy, possibly
composed with current Placement, masks and World State.

## Integration regression: blank World Composition Lab (2026-10)

The original example set `grid_spacing = 12` but inherited
`minimum_separation = 18`. `NucleusPOIDistributionProfile3D.validate()`
correctly rejected this recipe; the example returned before creating region
geometry and did not show why. The example now explicitly sets separation to
8, reports errors visibly, uses valid Godot node names for region identifiers,
and reframes the camera around the currently resident region.

`tests/headless/world_composition_test.gd` now instantiates the **actual**
PackedScene, checks initial region geometry, and switches regions. This covers
the composition boundary that isolated unit tests missed. The native test and
graphical editor must still be run before treating this as release-verified.
