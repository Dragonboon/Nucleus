# Square Grid Labs

Open `square_grid_2d_lab.tscn` or `square_grid_3d_lab.tscn` from Godot.

The 2D lab supports click-to-paint/erase, R for tile rotation and the
orthogonal/isometric toggle. The 3D lab supports mouse paint/erase and
PageUp/PageDown to change layers. Both are deliberately small validation
scenes. Connection rules are data-only and can be queried by a consuming
game; they do not spawn walls or modify native GridMap assets.

See [the architecture and API guide](../../docs/components/square_grid.md).
