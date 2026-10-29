# Smart Decals Quickstart

## Use case

`NucleusSmartDecal3D` is intended for runtime projected marks such as bullet
holes, blood, footprints, scorch marks, paint, and temporary world feedback.

It extends Godot `Decal`, so native Inspector properties remain available.

## Minimal scene

Create:

```text
SmartDecal3D : Decal
```

Attach:

```text
addons/nucleus/components/gameplay/decals/smart_decal_3d.gd
```

Assign at least:

```text
Textures > Albedo
```

or an emission texture.

For a hard-surface impact decal, a useful starting point is:

```text
size              = (0.25, 0.05, 0.25)
normal_fade       = 0.5
upper_fade        = 0.0
lower_fade        = 0.0
surface_offset    = 0.001
randomize_roll    = true
```

Tune projection depth (`size.y`) for the geometry in your game.

## Place from a raycast / collision result

```gdscript
var decal := decal_scene.instantiate() as NucleusSmartDecal3D
get_tree().current_scene.add_child(decal)

var error := decal.place_on_surface(
	collision_position,
	collision_normal,
)

if error != OK:
	decal.queue_free()
```

You do not need to calculate Euler angles.

## Preserve directional orientation

For a footprint, slash, skid, or directional mark, pass a tangent hint:

```gdscript
decal.place_on_surface(
	collision_position,
	collision_normal,
	movement_direction,
)
```

The tangent is flattened onto the hit surface before orientation.

Disable `randomize_roll` when the texture direction must remain meaningful.

## Curved geometry

Do not tessellate or bend the decal yourself.

Godot projects the decal through its AABB onto intersecting mesh geometry. The
SmartDecal only aligns that projector with the local hit normal.

For curved surfaces:

- make X/Z large enough for the visible mark;
- make Y deep enough to intersect the curvature;
- use `normal_fade` to prevent projection onto sharply opposing faces.

## Avoid decal bleeding

If a wall impact also paints a nearby character or the reverse side of a thin
wall:

1. reduce `size.y`;
2. raise `normal_fade`;
3. set `upper_fade` / `lower_fade` appropriately;
4. use the native Decal `cull_mask` and mesh visibility layers.

## Random size

Enable:

```text
randomize_planar_scale
```

and configure:

```text
minimum_planar_scale
maximum_planar_scale
uniform_planar_scale
```

Only X/Z change. Projection depth remains fixed.

## Automatic fade

Example:

```text
fade_after   = 8.0
fade_duration = 2.0
```

A zero `fade_after` disables automatic expiration.

## Pool large numbers of impact decals

Recommended reusable scene:

```text
ImpactDecal : NucleusSmartDecal3D
└── Poolable : NucleusPoolable
```

Assign the Poolable to `SmartDecal.poolable` or let SmartDecal resolve its direct
child.

With:

```text
release_poolable_on_expire = true
```

the finished decal returns to its `NucleusObjectPool`.

This is preferable for sustained gunfire or effects that create many decals.

## Visual validation

Open:

```text
examples/validation/smart_decal_3d.tscn
```

and press F6.

The fixture places decals against both a flat surface and a curved sphere so
surface-basis behavior can be inspected visually.
