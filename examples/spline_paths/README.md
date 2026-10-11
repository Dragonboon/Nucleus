# Spline Roads & Paths Lab

Open `res://examples/spline_paths/spline_paths_lab.tscn`.

- `1/2`: straight or curved Godot `Curve3D`
- `Q/R`: adjust path width
- `T`: toggle adaptation to `NucleusPlaneSurfaceSampler3D`

The sample composes a native `Path3D` with
`NucleusSplineRoad3D` and an optional existing surface sampler. The
generated ribbon is visual-only; it does not modify terrain, create
collision or navigation, or replace native Godot curves.

See `docs/components/spline_paths.md`.
