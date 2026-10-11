# Spline Roads & Paths Lab

Open `res://examples/spline_paths/spline_paths_lab.tscn`.

The lab uses a compact, right-aligned HUD to keep the terrain visible.\nPress **H** (or the **Tools** button) to expand/collapse the controls;\nthey start collapsed and never block the central editing area.\n\nThe native `Path3D.curve` is editable in the running lab:
- Left click a visible cyan point to select, then drag it along its elevation plane.
- Shift + left click to append a new point (maximum 24 per demo).
- Right click a point to remove it, preserving at least two control points.
- `+` / `-`: raise/lower the selected point.
- `1` / `2`: replace the editable path with a straight/curved preset.
- `Q` / `R`: narrow/widen the road.
- `T`: toggle following the existing surface sampler.
- `B`: toggle the optional crowned roadbed cross-section.

Roadbed profile properties are configured on
`NucleusSplinePathProfile3D` and remain optional. Its shoulders, crown and
thickness make the road look three-dimensional without terrain edits.
See `docs/components/spline_paths.md` for its performance and geometry
limits. The scene demonstrates editing and visual mesh creation only.
