# Spline Roads & Paths

Nucleus composes native `Path3D` / `Curve3D` and existing
`NucleusSurfaceSampler3D` contracts. This is an **optional** bounded
ribbon-mesh implementation, not a replacement for Godot curves,
collision, navigation or the terrain generator.

## Components

- `NucleusSplinePathProfile3D`: Resource with width, baked sampling spacing,
  UV repeat length, elevation offset and section budget.
- `NucleusSplinePathMeshBuilder3D.build(curve, profile, curve_to_world,
  mesh_to_world, sampler)`: synchronous read-only geometry builder returning
  `{"error": OK, "mesh": ArrayMesh, "sections": int, "length": float}`
  or `{"error": Error}`. On failure it never exposes partial geometry.
- `NucleusSplineRoad3D`: scene-owned component with explicit `Path3D`,
  `MeshInstance3D`, optional surface sampler and profile. Call `rebuild()`
  after changing the curve/profile; `clear_generated()` only clears meshes
  this component last generated. Build failures preserve the old visible mesh.

With `roadbed_enabled = false` (the backward-compatible default), two
vertices are generated per section; one pair of triangles joins each
neighboring section. With `roadbed_enabled = true`, seven vertices describe
outer shoulders, pavement edges, a raised central crown and two lower edge
vertices. Four lanes form the top, and three strips form the side/bottom
surfaces. `shoulder_width`, `crown_height`, `shoulder_drop` and
`roadbed_thickness` are authored on the optional profile Resource. Normals are derived from those faces. U follows the
path width, V accumulates **world-space distance**, preserving texture
continuity. Sampling the surface at *both edges* supports cross slopes.
All geometry is expressed in target MeshInstance3D-local coordinates.

## Example

Open `res://examples/spline_paths/spline_paths_lab.tscn`:
straight and curved presets (1/2), adjustable width (Q/R), surface following
(T) and crowned roadbed toggle (B). Control points are edited directly
through the example: click and drag handles, Shift+click to add (up to
24), right-click to delete, and +/- to adjust the selected point's elevation. This scene uses the existing plane sampler as
a sloping analytical surface. Godot remains the authority for curves and
rendering.

## Boundaries

The generator is intentionally synchronous, bounded (2–2048 sections)
and rejects missing or degenerate input, invalid resources, unavailable
samplers and collapsed triangles. Bake or precalculate longer roads in
individual regions rather than generating huge meshes each frame.

A simple ribbon can fold over itself at very tight turns, and does not
handle intersections, joins between distinct roads, bevelled shoulders,
end caps, closed watertight solids, automatic mesh collision,
water/terrain carving, terrain heightmap edits,
navigation baking, physics support or spline extrusion for pipes/rails.
Those responsibilities belong to separate existing/native consumers.
For multiplayer, replicate path control points or authoritative parameters,
not full vertex arrays. For persistence store control points, profile IDs,
and stable component IDs through the game's existing save contracts.

The control-point edit UI belongs only to the example. Native `Path3D` and
`Curve3D` remain the authoritative path data; the reusable component
never writes curve handles or implements a second spline algorithm.
The roadbed provides visual thickness and is **not collision geometry**.
Near tight turns or large widths, cross sections can still intersect,
so authored curves should avoid hairpins narrower than the roadbed.

Headless tests: `tests/headless/spline_paths_test.gd` checks geometry,
upward normals, UV distance, transforms, budget, surface use and atomic
rebuild failure. The interactive demo also needs visual verification in
the pinned Godot 4.7.2 editor before release.
