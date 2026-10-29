# Terrain Heightfield Slope Constraints

Target engine: Godot 4.7.2. Owner: `addons/nucleus/modules/terrain/terrain_heightmap_processor.gd`.

Nucleus extends its **existing** `NucleusTerrainHeightmapProcessor` rather than
introducing another terrain system. It owns only the numeric slope constraint;
island outlines, noise, ridge profiles, erosion styles, climate, and art direction
remain game-owned.

> [!WARNING]
> **Apply the limit after all height edits and elevation curves.**
> Later normalization or resampling can reintroduce excessive slopes.

## Public API

```gdscript
static func limit_heightmap_slopes(
    source: Image,
    terrain_size_m: Vector2,
    height_scale_m: float,
    maximum_slope_degrees: float,
) -> Image

static func limit_sample_slopes(
    values: PackedFloat32Array,
    sample_size: Vector2i,
    meters_per_cell: Vector2,
    height_scale_m: float,
    maximum_slope_degrees: float,
) -> PackedFloat32Array
```

Both operations are synchronous, pure with respect to their inputs, and intended
for **generation/load time**, not every render frame. Invalid images or numeric
parameters yield `null` (`Image`) or an empty float array (sample API).

`limit_heightmap_slopes` reads the source image's **red channel** and returns a
new `Image.FORMAT_RF` image of the same dimensions. Any other source channels
are intentionally discarded. It does not mutate its source or change its
resolution. The lower-level `limit_sample_slopes` accepts a row-major array;
`sample_size.x * sample_size.y` must equal its length.

## Example pipeline

```gdscript
var authored := NucleusTerrainHeightmapProcessor.transformed(source_image)
var filtered := NucleusTerrainHeightmapProcessor.prefilter_to_sample_limit(
    authored, 65, false)
var corrected := NucleusTerrainHeightmapProcessor.limit_heightmap_slopes(
    filtered, Vector2(400.0, 280.0), 70.0, 36.0)
if corrected == null:
    return ERR_INVALID_DATA

var profile := NucleusTerrainProfile.new()
profile.height_source = NucleusTerrainProfile.HeightSource.HEIGHTMAP
profile.size = Vector2(400.0, 280.0)
profile.height_scale = 70.0
profile.normalize_heightmap = false
profile.elevation_curve = null
profile.image = ImageTexture.create_from_image(corrected)
```

The profile must already reflect the final authored physical size and vertical
scale. For **existing** terrain profiles, update a duplicated Resource owned by
the consuming game rather than mutating a shared profile.

**Important:** Apply the slope limit after height-curve baking, prefiltering,
resampling and artistic height edits. An additional `elevation_curve`, dynamic
normalization, or overshooting resampler can invalidate the slope guarantee.
Use the final normalised heightfield with `normalize_heightmap = false` and no
post-processing elevation curve. A game that applies an island falloff or other
final height changes must validate the resulting terrain again.

## Algorithm and physical meaning

Each source height `h` corresponds to a vertical world height `h * height_scale_m`.
The physical grid spacing is determined by `terrain_size_m / (resolution - 1)`
per axis (or passed as `meters_per_cell` for packed arrays).

For a maximum slope angle `theta`, horizontal neighbour differences are capped
by `tan(theta) * cell_m / (height_scale_m * sqrt(2))` per axis. Two monotone,
forward/backward **min-plus** sweeps reduce excessive local maxima. The method:

- never raises a sample or alters the supplied input;
- has deterministic row-major traversal and O(width × height) work;
- works on rectangular grids and unequal physical X/Z spacing;
- caps both partial derivatives conservatively, so bilinear interpolation on
  the resulting grid respects the requested slope magnitude in the horizontal
  plane, within float precision;
- does not promise topological preservation, hydraulic erosion realism,
  correct collision on arbitrary non-heightmap meshes, or identical output on
  every possible processor/driver.

The bound is conservative: a purely one-axis incline may become shallower than
`theta` because the allowance is divided by `sqrt(2)`.

Parameters require positive finite spacing and vertical scale, sample counts at
least 2×2 and a finite maximum angle in `[0, 89.9)` degrees. Pixel values must
be finite. Non-RF source images are accepted by reading their red channel.

## Validation

`tests/headless/terrain_heightfield_constraints_test.gd` covers rectangular
samples, zero-degree limits, preservation of the input, invalid parameters,
image conversion, and final interpolation using the existing
`terrain_height_sampler.gd` from Nucleus.

For a production island workflow, also run the consumer's actual generation,
mesh/collision and visual tests with its chosen post-processing. A unit test of
one elevation filter does **not** prove island morphology or graphics quality.

## Use cases

| Scenario | Use the constraint | Still owned by the game |
| --- | --- | --- |
| Procedural terrain generates needle-like peaks | Bound neighbor differences after the artistic shaping stage | Desired silhouette and relief volume |
| Designer-authored heightmap exceeds a walkable slope goal | Limit source-grid height gradients with physical dimensions | Gameplay navigation and traversability checks |
| Terrain collision and preview disagree after resampling | Use one final profile and test the actual sampler | Resolution/LOD decisions and physical QA |

Do not apply a steep elevation curve or aggressive resampling *after* enforcing
the limit without validating the final surface again. Source slope limiting is
not erosion, anti-aliasing, or a guaranteed maximum for every world-space
normal under arbitrary external transformations.
