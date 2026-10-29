# Terrain Heightmap and Material Quality

Target engine: Godot 4.7.x.

This contract extends `addons/nucleus/modules/terrain` with reusable policies proven by a real
heightmap-driven world consumer:

```text
source-image preprocessing
physical-size resolution budgets
optional PBR terrain detail
distance-based detail sampling
quality-aware triplanar policy
bounded generated-material reuse
```

It does not move biome, coastline, island-shape, water, or art-direction policy
into Nucleus.

## Public types

```text
NucleusTerrainHeightmapProcessor
NucleusTerrainResolutionPolicy
NucleusTerrainTextureLayer
NucleusTerrainMaterialProfile
```

The last two are existing public Resources with backward-compatible PBR and
quality additions.

## Heightmap preprocessing

`NucleusTerrainHeightmapProcessor` operates on `Image` data and always returns a
new image.

It provides:

```text
deterministic quarter-turn rotation
optional X/Y mirroring
resolution-aware prefiltering
Texture2D → processed ImageTexture convenience
```

A typical pipeline is:

```text
authored relief image
        ↓
game-owned composition/masking
        ↓
NucleusTerrainHeightmapProcessor.transformed()
        ↓
NucleusTerrainHeightmapProcessor.prefilter_for_resolution()
        ↓
ImageTexture
        ↓
NucleusTerrainProfile.image
```

Game-specific operations such as bay masks, erosion styles, volcano shapes, or
biome recipes remain outside Nucleus.

### Why prefilter before sampling

A 2048×2048 source texture does not mean a terrain mesh with 96 cells can
represent 2048 independent height samples.

Sampling high-frequency relief directly into a much coarser geometry grid can
produce:

```text
single-cell spikes
harsh normals
unstable silhouette detail
visual/collision disagreement
noisy analytical surface queries
```

`prefilter_for_resolution()` first downsamples toward the representable sample
budget with Lanczos filtering. It can then resize back to the original image
dimensions with cubic interpolation so existing image-mapping code can continue
to consume the texture normally.

The target sample count is based on:

```text
terrain resolution + 1
```

because an N-cell heightfield contains N+1 vertex samples per axis.

## Resolution policy

`NucleusTerrainResolutionPolicy` derives visual and collision resolution from
physical terrain size.

It exposes three neutral quality tiers:

```text
MINIMAL
REDUCED
FULL
```

Each tier defines target meters per visual cell.

Default values are intentionally conservative examples:

```text
Minimal  6.0 m/cell
Reduced  4.0 m/cell
Full     2.5 m/cell
```

The result is rounded upward to an authored step and clamped to configured
minimum/maximum bounds.

Example:

```gdscript
var resolved := resolution_policy.resolve(
	Vector2(600.0, 450.0),
	NucleusTerrainResolutionPolicy.Quality.REDUCED,
)

print(resolved["visual_resolution"])
print(resolved["collision_resolution"])
```

Use `apply_to_profile()` only when the caller owns the Resource being mutated.

If several terrain actors share one `NucleusTerrainProfile`, duplicate it before
applying per-instance quality:

```gdscript
var local_profile := shared_profile.duplicate(true) as NucleusTerrainProfile
resolution_policy.apply_to_profile(local_profile, quality)
```

Nucleus does not silently mutate shared terrain profiles.

## PBR terrain layers

`NucleusTerrainTextureLayer` still supports the original contract:

```text
albedo
tint
UV scale
height range
slope range
roughness scalar
metallic scalar
```

It now also accepts optional:

```text
normal
normal_strength
roughness_texture
roughness_texture_strength
```

All new fields are optional.

A layer without these textures follows the previous scalar material path.

### Normal maps

The built-in terrain shader samples the red/green channels of normal maps and
perturbs the geometric world normal.

Use Godot/OpenGL-style normal maps. If source art is DirectX-style, use Godot's
normal-map import conversion rather than introducing per-material Y inversion
logic.

### Roughness maps

When a roughness texture exists, the sampled value blends from the authored
scalar fallback according to:

```text
roughness_texture_strength
```

This lets a project keep a robust low-detail fallback while still using authored
surface variation nearby.

## Distance detail fade

`NucleusTerrainMaterialProfile` exposes:

```text
distance_detail_fade
detail_distance_start
detail_distance_end
```

Albedo remains stable at distance.

Only optional PBR detail work fades:

```text
normal-map perturbation
roughness-texture variation
```

This is deliberate. The terrain does not change silhouette, collision, or base
surface identity when detail sampling is reduced.

Example:

```text
0–25 m
    full PBR detail

25–100 m
    progressive fade

100 m+
    albedo + scalar roughness/metallic
```

Set `distance_detail_fade = false` when a project deliberately wants PBR detail
at all distances.

## Terrain material quality

`NucleusTerrainMaterialProfile.Quality` provides:

```text
MINIMAL
REDUCED
FULL
```

`FULL` preserves authored projection and PBR detail.

By default:

```text
REDUCED
    top projection
    PBR detail textures remain enabled

MINIMAL
    top projection
    PBR detail textures disabled
```

Projects can change:

```text
reduced_uses_triplanar
reduced_uses_detail_textures
minimal_uses_triplanar
minimal_uses_detail_textures
```

The default `quality` is `FULL`, so existing terrain profiles preserve their
previous projection behavior.

`create_material()` also accepts an optional quality override as its final
argument.

## Triplanar is a budget

Triplanar projection improves steep-surface texture continuity but multiplies
texture sampling.

Treat it as a presentation feature, not an unconditional terrain requirement.

A reasonable low-end mapping can be:

```text
Full
    authored top/triplanar mode

Reduced
    top projection
    normal/roughness detail if affordable

Minimal
    top projection
    scalar roughness only
```

Profile on the target renderer and hardware.

## Generated material reuse

Built-in terrain materials can now be reused by one shared
`NucleusTerrainMaterialProfile`.

When `reuse_generated_materials` is true, equivalent `create_material()` calls
return the same generated `ShaderMaterial`.

The cache key includes:

```text
height range
debug mode
quality
projection/detail policy
base color
layer textures and scalar settings
```

This prevents incorrect reuse across incompatible terrain instances.

The cache is bounded by `material_cache_limit`. When the bound is reached,
Nucleus clears the small generated cache rather than allowing unbounded Resource
growth.

Use:

```gdscript
material_profile.clear_material_cache()
```

when tooling deliberately wants to discard generated variants.

Custom materials are returned directly and are not duplicated by this cache.

The cache is owned by the material-profile Resource instance. Generated cached
materials should be treated as shared presentation data; do not mutate their
shader parameters per terrain actor after retrieval.

## Relationship to rendering-quality components

This terrain policy complements:

```text
NucleusMaterialQualityController3D
NucleusGeometryQualityController3D
```

but does not depend on them.

Terrain material quality changes shader sampling policy inside the built-in
terrain shader.

Geometry quality changes native mesh LOD, visibility, and shadows.

They can be mapped from the same game-owned graphics preset.

## Low-end example

A consuming game might choose:

```text
Terrain FULL
    2.5 m/cell
    full PBR
    triplanar on cliff-heavy biomes

Terrain REDUCED
    4 m/cell
    top projection
    nearby normal/roughness detail

Terrain MINIMAL
    6 m/cell
    top projection
    albedo + scalar roughness
    cheaper collision grid
```

The exact numbers remain product policy.

## What stays game-owned

```text
which heightmaps compose a biome
island/continent dimensions
shoreline wetness
snow/lava/mud semantics
which terrain receives which quality tier
runtime streaming radius
terrain content placement
artistic texture scale and color treatment
```

Nucleus provides the mechanism and bounded policies only.
