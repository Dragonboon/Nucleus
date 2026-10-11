# Biome Composer & POI Lab

Open `res://examples/biome_poi/biome_poi_lab.tscn`.

The colors illustrate moisture-based biome selection:
arid (sand), grassland (green) and forest (dark green).
Red and blue pillars show deterministic camp/ruin descriptors.
Press R (or the small UI button) to change the world seed.

This lab renders only demonstration tiles and markers. The reusable modules
return profiles, identifiers and world positions; they never generate a terrain,
spawn authoritative structures or mutate the existing scatter/streaming system.
