# World Scalar Fields 3D

Target engine: Godot 4.7.2. Component: `addons/nucleus/components/world/fields/world_mask_3d.gd`.

`NucleusWorldMask3D` is a **scene-owned** scalar field sampled in world space.
It samples authored scalar data without depending on terrain generation,
weather, world streaming, or scatter rendering.

> [!TIP]
> **Use for:** authored spatial weights such as placement density or ambient intensity.
> **Not for:** collision, weather simulation, or authoritative world generation.

## Basic use

1. Add a `Node3D` using `world_mask_3d.gd` to a level.
2. Assign a `Texture2D` containing authored **data**, not a lit/albedo image.
3. Set `coverage_size` (local X/Z metres), `channel`, and `outside_value`.
4. Place, rotate or scale the node; pass a reference explicitly to consumers.

```gdscript
@export var density_mask: NucleusWorldMask3D

func get_spawn_weight(at_position: Vector3) -> float:
    if density_mask == null:
        return 1.0
    return density_mask.sample_world(at_position)
```

A consuming game decides whether the result represents spawn density,
footstep wetness, vegetation cover, exposure, paint weight, or another signal.
Nucleus never makes a gameplay decision from the sampled value.

## Spatial mapping

- Local X/Z covers `(-size.x/2, -size.y/2)` to `(size.x/2, size.y/2)`.
- The local Y coordinate is ignored. A tilted mask is sampled in the node's
  local plane, **not** projected along global vertical or through physics.
- `world_to_uv` uses the full inverse affine transform, including parents,
  nonuniform scale and mirroring, provided the transform is invertible.
- UV `(0,0)` maps to the first image pixel. UV `(1,1)` includes the last pixel.
- Sampling uses **nearest texel** (`floor(uv * dimensions)`), without
  interpolation, wrap, mip selection or hidden gamma conversion.

`local_to_uv` and `world_to_uv` return nonfinite coordinates on invalid inputs;
`sample_world` instead returns `outside_value` clamped to `[0,1]`.

## Source and cache lifecycle

`texture.get_image()` is called once per invalidation and the returned Image
is duplicated into a component-owned CPU snapshot. Readable compressed Images
are decompressed. Failed reads are cached too: there is no repeated GPU readback
for every world query.

- Assigning a new texture disconnects the previous `changed` signal and resets
  the cache.
- A source emitting `Texture2D.changed` invalidates the snapshot.
- `invalidate_cache()` supports textures changed without a signal.
- `refresh_cache()` forces a read and returns its success status.

Changing `channel`, `inverse`, or `coverage_size` does not fetch the image again.
`inverse` applies only to valid pixels; the fallback is never inverted.
Values are clamped to `[0,1]`; luminance weights are `0.2126/0.7152/0.0722`
on raw stored channel values.

The entire decoded image remains in RAM per component; large masks and multiple
instances must have an explicit memory budget. Work with `Node`/`Texture2D`
on the main thread. For worker jobs, copy immutable data yourself.

## Bounded footprint

```gdscript
var density := density_mask.sample_world_average(position, 2.0)
```

This performs nine fixed point samples: centre, four cardinal offsets and
four diagonal offsets on a world-X/Z circle. Samples falling outside coverage
contribute `outside_value`. It is a constant-cost smoothing approximation,
**not** exact area integration, a conservative intersection test, or raycasting.

## Failure and compatibility contract

Nonfinite coordinates, nonpositive coverage, singular transforms, unreadable
textures, and nonfinite pixel channels all resolve to the configured fallback.
`@tool` configuration warnings describe invalid assignments and read failures.
No Autoload or per-frame polling is introduced.

Regression coverage is registered in `tests/headless/world_mask_test.gd`.

## Use cases

| Scenario | Scalar-field role | Game policy |
| --- | --- | --- |
| Paint vegetation density in a terrain editor | Sample red or luminance at an X/Z point | Decide species, spawning and weights |
| Zones with contamination, heat or exposure | Read a stable authored channel | Choose gameplay consequences |
| Restrict building on authored ground | Sample region average as one decision input | Check actual collision and placement rules |
| Ambient sound or particles that vary by location | Sample normalized intensity | Select clips, visuals and accessibility limits |

This is a **read-only authored data sampler**, not a climate model, GPU compute
service, collision replacement or world-generation authority. Prewarm the image
cache before large synchronous queries when appropriate.
