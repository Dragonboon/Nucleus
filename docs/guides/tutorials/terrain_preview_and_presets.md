# Tutorial: terrain preview and presets

This tutorial is the fastest way to learn the optional terrain module without
committing final meshes or collision to a scene.

## What you are building

You will:

```text
start from a reusable profile preset
preview it at low resolution
change seed / scale / relief
inspect four presets side by side
switch from preview to final generation only when the shape is useful
```

Reference scene:

```text
res://examples/terrain/terrain_preview_presets.tscn
```

## 1. Add the generator

Create:

```text
World
└── Terrain : NucleusTerrainGenerator3D
```

Do not add Terrain to Autoloads.

## 2. Choose a starting profile

Nucleus ships normal Resource presets:

```text
res://addons/nucleus/modules/terrain/presets/gentle_hills.tres
res://addons/nucleus/modules/terrain/presets/lowlands.tres
res://addons/nucleus/modules/terrain/presets/rugged_mountains.tres
res://addons/nucleus/modules/terrain/presets/archipelago_island.tres
```

Duplicate the closest preset into your game content folder. Do not edit the
template copy if several scenes should share the original defaults.

Suggested intent:

```text
Gentle Hills
    traversal terrain, fields, rolling landscape

Lowlands
    plains, wetlands, wide combat spaces

Rugged Mountains
    strong relief, distant mountain masses, steep traversal

Archipelago Island
    ocean gameplay, isolated land masses, irregular submerged floor
```

## 3. Preview at low resolution

Assign the duplicated profile to `Terrain`.

Use:

```text
preview_resolution = 20 to 32
```

Press **Refresh Preview**.

The preview uses the same height sampler as final generation but skips:

```text
collision
LOD buffers
scene-owned generated output
```

That is the correct loop for changing shape.

## 4. Tune the three scales separately

A common source of artificial terrain is changing everything together.

Tune in this order:

### World footprint

```text
profile.size
```

This decides the physical patch footprint.

### Source feature scale

```text
FastNoiseLite.frequency
```

Lower values create broader forms. Higher values create denser terrain detail.

### Vertical relief

```text
base_height
height_scale
```

Do not use noise frequency to solve a vertical-scale problem.

## 5. Tune naturality

Useful levers:

```text
fractal_octaves
fractal_lacunarity
fractal_gain
elevation_curve
```

A practical workflow is:

```text
1. establish large forms with frequency
2. add 3–5 octaves
3. tune gain before adding more geometry
4. use elevation_curve only when the distribution of heights needs art direction
```

Adding mesh resolution does not create better procedural structure. It only
samples the structure more densely.

## 6. Preview islands

For an island profile:

```text
shape_mode = ISLAND
island_inner_radius ≈ 0.45–0.60
island_falloff ≈ 0.25–0.45
shoreline_noise_strength ≈ 0.08–0.16
```

`shoreline_noise` perturbs the horizontal coastline.

For the underwater area, optionally assign:

```text
edge_floor_noise
edge_floor_noise_strength
```

This perturbs the deep floor that the island falls toward. It does not remove the
rectangular heightfield boundary, but it prevents the submerged region from
becoming one perfectly flat square shelf.

For transparent/deep water, the strongest disguise is still:

```text
make the patch larger than the visible island
place edge_floor_height well below useful visibility
add low-frequency edge_floor_noise
```

A heightfield cannot create arbitrary overhangs or a truly radial mesh boundary
without giving up the cheap regular-grid topology.

## 7. Add the material only after shape reads correctly

Assign a `NucleusTerrainMaterialProfile`.

The supplied material demo is:

```text
res://examples/terrain/materials/terrain_height_layers.tres
```

Start with **Top projection** on weak GPUs.

Use Triplanar only when cliff stretching is visible enough to justify the extra
fragment samples.

## 8. Compare presets in one scene

Open:

```text
res://examples/terrain/terrain_preview_presets.tscn
```

The four profiles are spatially separated but all use the same preview and
material pipeline.

This is useful for answering questions such as:

```text
Is the mountain preset too dense for the game scale?
Are lowlands actually flatter, or merely lower?
Does the island still read from the target camera distance?
Does the material banding work across very different relief?
```

## 9. Generate only when ready

When the preview is useful, press:

```text
Generate Terrain
```

Final generation adds the configured LOD and collision policies.

If the final terrain looks different from preview, check:

```text
preview_resolution versus profile.resolution
collision debug overlay
material projection mode
camera distance / active LOD
```

## Common mistakes

```text
Increasing resolution to fix bad noise
Using Triplanar everywhere before profiling
Generating collision while only tuning silhouette
Making the island patch barely larger than the island
Expecting a heightfield to produce caves or undercuts
Editing the shared preset instead of duplicating it
```

## Continue

For a complete island-chain workflow:

[`procedural_terrain_3d.md`](procedural_terrain_3d.md)

For runtime chunk streaming:

[`terrain_streaming_runtime.md`](terrain_streaming_runtime.md)
