# Terrain profile presets

These are normal `NucleusTerrainProfile` resources, not a separate preset API.

Duplicate a preset into the consuming game's content folder before changing it.

```text
gentle_hills.tres
    broad low-cost rolling terrain

lowlands.tres
    flatter traversal spaces and plains

rugged_mountains.tres
    higher relief and denser source detail

archipelago_island.tres
    irregular shoreline plus varied submerged floor
```

A preset is only a starting scale/seed. The game should still tune patch size,
resolution, collision density, material, and noise against its actual art scale
and target hardware.
