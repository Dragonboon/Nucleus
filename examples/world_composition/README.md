# World Composition Lab

Run `world_composition_lab.tscn`. Press **Tab** to switch between two
neighboring regions. Tiles show climate-resolved biomes; orange pillars
are deterministic POI descriptors. The existing StreamLifecycle gates region
creation and unloading.

This scene visualizes composition; it does not build actual Scatter MultiMesh
batches. The reusable integration uses `NucleusBiomeSurfaceQuery3D` and the
optional `density_filter` in `NucleusScatterBuildJob3D` /
`NucleusScatterRegion3D`. See
[World Composition](../../docs/components/world_composition.md).
