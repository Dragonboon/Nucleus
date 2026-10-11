# Modular Building Lab

Open `modular_building_lab.tscn`. Paint/remove contiguous blocks with the mouse.
The `NucleusModularNeighborhood` planner resolves only the changed cell and
its four cardinal neighbors, and a visual-only `NucleusModularVariantBinding3D`
instantiates variants from an allowlisted `NucleusPlacementVariantSet3D`.
Use Z/X to change layers and C to clear. This is an occupancy/visual proof, not
a physics placement or a complete base-building game.
