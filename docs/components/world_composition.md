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
Invalid, nonfinite or expired callback results are treated as zero density (fail closed).
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

`res://examples/world_composition/world_composition_lab.tscn` composes the actual
terrain, biome, Scatter and streaming owners. A small resident terrain patch has
an analytical `NucleusTerrainSurfaceSampler3D`; POIs and decoration query that
same surface. Wet biomes use primitive green trees, dry biomes ochre rocks, and
orange markers visualize POI descriptors. Replace these meshes in each biome's
`scatter_profile` with your own content.

Each streamed region creates one `NucleusScatterRegion3D` per biome and binds
`query.density_for_biome.bind(biome.biome_id)` before starting its build through
the scene-owned `NucleusMaterializationQueue`. Completion is acknowledged only
when **all** native MultiMesh batches are ready. Press **Tab** (or the button)
to switch regions. Switching while loading cancels obsolete jobs; unloading
removes batches; returning regenerates the same decoration from the same seed.
The status label distinguishes loading from residency and shows instance count.

The terrain stays resident in this bounded example; only decoration streams.
Tree/rock meshes are visualization content without collision. Terrain material
is uniform: biome material painting and POI clearings are not implemented here.

## Validation

`tests/headless/world_composition_test.gd` covers the analytical
surface bridge, deterministic filtered scatter across two adjacent regions,
exclusion and POI surface integration. The existing world streaming, scatter
and POI suites remain registered.

This integration does **not** automatically paint biomes into terrain
materials, reserve POI exclusion volumes, create roads between settlements,
or materialize authoritative structures. Those are game policy, possibly
composed with current Placement, masks and World State.

## Try and verify

Run the lab with F6, switch twice with Tab, then switch rapidly during loading.
The first region should return with the same decoration, and no old region
should remain. The terrain relief and scatter heights share one height source.

```bash
godot --headless --path . res://tests/smoke/world_composition_smoke.tscn
```

This smoke scene exercises real frame processing and cancellation. A graphical
run additionally checks every native MultiMesh transform against the biome and
terrain query. The headless suite checks the CPU transforms, ownership, valid
POI recipe, instance counts, reload determinism and expired density callbacks.

## Seed compatibility

The Scatter cell hash now mixes each random channel independently. The previous
linear salt offset correlated X/Z jitter, rotation and density into visible rows.
Seeds remain repeatable across load order and region seams, but regenerated
**decoration positions change** from older revisions. Pin the generator revision
for saved worlds or preserve game-owned generated descriptors when upgrading.
This change does not move existing persisted Nodes or modify authored Resources.
