# 2D crowd steering and indexed bullet hits

This integration deliberately reuses existing Nucleus ownership. The new
NucleusBulletTargetBatch2D uses NucleusSpatialRectIndex2D to accelerate
candidate selection for swept bullets against circular targets. It does
not own authoritative damage, knockback, collision layers, or health.
Register/update/remove targets as they move and query after physics updates.
All coordinates must be local to the bullet field; consuming games transform
world-space target coordinates explicitly.

NucleusCrowdSeparation2D reads the existing NucleusSpatialPointIndex2D.
NucleusCrowdMotionSource2D composes that steering with an existing
NucleusMotionSource2D; CharacterMotor2D remains the only physics owner.
The game updates spatial memberships, chooses navigation intent, and controls
crowd density. Use the existing EncounterDirector for waves, Spawner2D for
pooled actors, GameplayAction for weapons and cooldowns, LootTable for drops,
ProgressionTrack for leveling, and UpdateScheduler for approximate AI cadence.

These components are optional. Querying bullets still takes one iteration
over active projectiles and indexed candidate checks, not constant time;
the target index must be maintained when target positions change. For more
complex hit shapes, use native Godot physics. Benchmark MultiMesh and
CanvasItem against the intended platforms before claiming throughput.
