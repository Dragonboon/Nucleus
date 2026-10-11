# Biome Composer & POI Distribution

Optional deterministic **data-only** world composition. No global manager,
autoload, terrain or scatter duplication. Native FastNoiseLite owns climate
fields; Nucleus owns Resource-based classification and landmark descriptors.

## Biomes

`NucleusBiomeProfile3D` defines stable IDs, priority, ranges for temperature,
moisture and height, a maximum slope, and optional references to the existing
`NucleusScatterProfile3D` and `NucleusTerrainMaterialProfile`.
`NucleusBiomeComposer3D` resolves four world attributes to an existing
biome without mutating any Resource. Its optional FastNoiseLite fields are
sampled at *global* world X/Z locations with authored seeds.

`resolve_values(temperature, moisture, height, slope)` is the direct integration
point for games that already own weather/climate. `resolve_at(world_xz,
height, slope)` uses its optional noise resources. Highest priority matching
biome wins; authored list order resolves ties. No match returns an empty
Dictionary. Temperature and moisture are normalized [0, 1]; slope is degrees.

## Points of interest

`NucleusPOIType3D` defines stable IDs, weights, biome restrictions, height
intervals and slope limits. `NucleusPOIDistributionProfile3D` defines seeded
global jittered cells, a density probability, separation and fixed budgets.
`NucleusPOIPlanner3D.plan(minimum, size, recipe, biomes, surface)` returns
`{"error": OK, "points": Array[Dictionary]}` with stable cell IDs, POI IDs,
biome IDs and positions. The surface callback takes world X/Z and returns a
Dictionary `{"height": float, "slope": float}`; use your existing analytical
terrain sampler or other game-owned surface adapter.

Regions are half-open world X/Z rectangles. A fixed 1-cell halo and consistent
hash ranking reject too-close neighbors identically on either side of a region
seam (assuming shared recipe, climate and surface). The minimum separation
must not exceed grid_spacing. Up to 4096 cells and 1024 accepted descriptors
per region are supported, subject to the authored lower limits. A budget
overflow fails explicitly instead of silently truncating results.

The planner does not instantiate assets, author collision, check accessibility,
solve roads, persist entities, or replicate coordinates. The consuming game
owns the mapping of stable POI IDs to permitted scenes, site suitability
(policy beyond height/slope), world persistence and network authority.
Visual decoration continues to use NucleusScatterRegion3D and its existing
queue. For changing climate fields, regenerate affected regions using
game-owned invalidation.

## Validation

`tests/headless/biome_poi_test.gd` exercises climate classification,
invalid input, stable seeds, split-region continuity and budget overflow.
`examples/biome_poi/biome_poi_lab.tscn` is a small visual laboratory with
color-coded biome cells and camp/ruin markers. Press R to change the seed.
Neither example is a runtime dependency.

Run the pinned 4.7.2 headless runner and inspect the lab visually. POI
spacing and distribution are a bounded jittered grid, not a complete
Poisson-disc sampler or a procedural village generator.
