# Additional 2D crowd and projectile contracts

These extensions add no Autoloads and do not replace scene-owned Nucleus owners.

## NucleusSpatialPointIndex2D

A lightweight, deterministic grid index for points identified by nonnegative
integers. Call `upsert` when an entity moves, `remove` on despawn and
`query_radius` for broad-phase neighbor lookups. Exact physics remain with
Godot. Queries are limited to bounded cell iteration or fall back to an
exact scan if the requested region is too large. IDs are sorted for repeatability.
This is not a replacement for the existing NucleusSpatialRectIndex2D.

## NucleusSpawnPlacement2D

A bounded annulus-based placement policy for wave, encounter, ambient and
pickup spawning. Inputs include excluded rectangles (for example, the visible
camera), an optional walkability Callable and an optional point index for
separation. Failure is explicit; it never silently spawns in an invalid place.
Use NucleusEncounterDirector for wave lifecycles and NucleusSpawner2D for
pooled instance activation. The game owns actor identity and difficulty.

## NucleusProceduralRegionCache2D

A simple LRU cache of procedural grid bytes. Entries are bounded by
maximum_regions and returned as copies to avoid gameplay mutations changing
the cache. Pair it with NucleusWorldStreamLifecycle to control load admission.
The game still owns modified terrain and persistence.

## Resource-based compact bullet emissions

NucleusBulletPattern2D is a configuration Resource for radial and fan bursts.
NucleusBulletActionEffect2D attaches these emissions to an existing
NucleusGameplayAction and checks emission capacity before committing.
The bullet field owns only presentation/simulation: targets, friendly fire,
damage and authority remain game-owned.

## Optional MultiMesh presentation

NucleusBulletMultiMesh2D provides a second renderer for the same compact
bullet simulation. It refreshes instance transforms and visible count through
the native MultiMeshInstance2D. When using it, set bullet_field.draw_enabled
to false to avoid rendering the same projectiles twice. The current
implementation is a reference adapter using individual transform writes;
profile on the final renderer/hardware before deciding whether to use
the CanvasItem drawer, native MultiMesh or a custom bulk upload.

## Proof and limitations

The registered headless suite tests index updates, bounded placement,
procedural cache eviction and resource-authored emissions. The additional
laboratory in examples/bullet_field_2d exercises many active projectiles,
but performance, GPU memory, physics and real visual behavior must be
validated with Godot 4.7.2 and target hardware. No FPS target is guaranteed.
