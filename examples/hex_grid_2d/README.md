# Nucleus hexagonal 2D lab

Run `res://examples/hex_grid_2d/hex_grid_2d_lab.tscn` with F6.

- **P**: paint continuously with left mouse; strokes interpolate across missed frames.
- **X**: erase; **I**: select; **Shift + left click**: select immediately.
- **M**: move tile (source then destination); **Q/R**: rotate selected by 60°.
- **[ / ]**: rotate board without rotating individual tile orientation.
- **T**: select two painted cells and draw an unweighted shortest route through
  painted tiles. Empty route means blocked or unreachable.
- **Middle mouse drag**: pan; **wheel**: zoom; **Esc**: clear selection/path.
- Inspector/UI: radius, rings, orientation pointy/flat, ghost visibility.

A tile shows a facing arrow only when selected; unselected hexagons remain
visually symmetric. Corner signals and edge signals are displayed separately.

This demo does not save worlds or invent an alternative persistence service.
Games can persist `{q, r, facing, content_id}` using the existing NucleusSave
contract and resolve the visual content through a closed asset catalog.

Smoke: `godot --headless --path . --script res://examples/hex_grid_2d/hex_grid_2d_smoke.gd`.
