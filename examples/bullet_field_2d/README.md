# Continuous bullet field lab

Open `bullet_field_lab.tscn` in Godot 4.7.2. Change `target_bullet_count`,
`emission_per_frame`, `projectile_speed`, `projectile_lifetime`, `pattern_mode`
and `petals` before running the scene. The fixture composes BulletField2D with
reserved storage, BulletEmitter2D and native BulletMultiMesh2D; fallback circle
drawing is disabled. Capacity and per-physics-tick admission remain bounded.

RADIAL, FAN, LINE, LOTUS and SPIRAL share the same simulation. Inspect their
geometry at a low count first. The lab logs live count and instantaneous FPS;
this is a visual profiling fixture, not a minimum-FPS certification. It does not
apply damage or model multiplayer authority.

See [bullet pattern contracts](../../docs/components/bullet_hell_2d.md) for the
formulae, cadence, lifecycle and bounds. Use BulletTargetBatch2D for indexed swept
circle candidates and measure it with the intended target population. Use native
physics and pooled actors when per-projectile bodies or complex behavior matter.
