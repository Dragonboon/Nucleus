# Sustained 2D bullet patterns

Added in `0.36.0-dev.1`, extending the existing field, pattern, MultiMesh and
indexed hit-query contracts. No per-bullet Node, global manager, replacement
physics engine or game-owned damage rule is introduced.

## Ownership

| Need | Owner |
| --- | --- |
| Reusable scene actors, complex colliders and effects | Existing ObjectPool/Poolable and Spawner2D; native physics |
| Dense lightweight bullet simulation and admission | NucleusBulletField2D |
| Pattern geometry | NucleusBulletPattern2D Resource |
| Optional repeating emission | NucleusBulletEmitter2D |
| Drawing many instances | Native MultiMesh through NucleusBulletMultiMesh2D |
| Swept hit candidates | Existing BulletTargetBatch2D and SpatialRectIndex2D |
| Damage, teams, piercing, hit deduplication, encounter policy | Consuming game |

Use pooled scenes for entities that need native collision bodies, independent
animations or behavior. Use the lightweight field for large sets of straight,
constant-velocity bullets. A visual particle effect is not an authoritative hit.

## Pattern mathematics

All positions and velocities are field-local. Angles are radians, clockwise in
Godot's positive-Y-down 2D coordinates. `count` always means total bullets in one
burst. Direction, `angle_offset` and an optional emission `phase` rotate a pattern.

Let `i` be the sample index, `N=count`, `a` the combined angle and `v=speed`.
`u(angle) = Vector2(cos(angle), sin(angle))`.

| Mode | Construction |
| --- | --- |
| RADIAL | `velocity = v * u(a + TAU*i/N)`; the seam is not duplicated |
| FAN | `t=i/(N-1)`, angle `a+(t-0.5)*spread`; one pellet uses `t=0.5` |
| LINE | Parallel velocities `v*u(a)`; origin offset `(i-(N-1)/2)*line_spacing*u(a+PI/2)` |
| LOTUS | `theta=TAU*i/N`; speed ratio `m+(1-m)*abs(cos(petals*theta/2))`; velocity follows `a+theta` |
| SPIRAL | `t=i/(N-1)`; angle `a+TAU*spiral_turns*t`; speed ratio `m+(1-m)*t` |

Here `m=minimum_speed_ratio`. LOTUS produces exactly the configured number of
radial lobes in the expanding envelope. SPIRAL produces an expanding spiral
snapshot; neither makes individual bullets follow curved trajectories. Rotate
successive bursts with the emitter for moving spiral/flower streams. FAN is a
deterministic shotgun spread; random pellet deviations are not implicit.

`velocity_at(index, direction, phase)` and `offset_at(index, direction, phase)`
expose allocation-free samples for other consumers. Validate the Resource with
`is_valid()` and keep indices in `[0, count)` before sampling. `emit_into` performs
validation and returns the number actually admitted. Invalid input emits nothing.
It only evaluates samples that fit the remaining field budget. A partial burst
uses the first samples of the original pattern; it does not redistribute them.

Existing enum values RADIAL=0 and FAN=1 are unchanged. The existing
BulletActionEffect2D still checks room for the whole pattern before an action;
use it when partial admission is inappropriate for a weapon/cooldown transaction.

## Continuous emission

Compose a field, renderer and `NucleusBulletEmitter2D` in a scene. Assign the same
field to both adapters and a pattern Resource to the emitter. Emitter position
and its local +X axis are converted from world to field coordinates. Bullet speed
and line spacing remain field-local; nonuniform field scaling affects world speed.

- `interval` is seconds per burst; `angular_speed` is radians/second.
- `emitting` gates new shots; existing bullets continue their field simulation.
- `maximum_bursts_per_tick` caps catch-up after a hitch (1–64). Excess elapsed
  bursts are dropped, not queued for later frames. This is intentional load
  shedding, not deterministic offline replay across differing frame schedules.
- Each admitted burst respects the field's capacity and remaining tick budget.
  `burst_emitted(admitted, requested)` reports partial/zero admission.
- Pausing field simulation also pauses emission cadence. Native SceneTree pause
  still follows the nodes' process modes.
- `reset_emission()` resets elapsed cadence and phase, without clearing bullets.
- `advance(delta)` is available for manual simulation; disable the node's native
  physics processing when calling it yourself to avoid advancing twice.
- Default priorities: field 0, emitter 10, consumer hit-query phase after emission.
  Preserve this ordering if overriding priorities; the field resets admission at
  its physics tick boundary. The field's legacy `max_spawns_per_frame` name denotes
  a **physics tick**, not a render frame.

The first burst occurs after one interval. Keep the pattern Resource immutable
during a burst; it may be shared by many emitters with independent cadence/phase.

## Storage and drawing

Call `field.reserve_storage()` before a dense encounter to allocate up to its
configured capacity (maximum 200,000). Without explicit warmup, storage grows in
bounded geometric steps as required. `storage_count()` exposes reserved slots;
`active_count()` exposes live bullets. Slots hold packed numeric data only.

Expiry, swap removal and `clear_bullets()` reuse storage instead of shrinking all
arrays. Clear does not reset monotonic IDs or the current tick's admission budget.
Lowering capacity does not kill existing bullets or shrink storage; new admission
waits for room. Free the field to release its buffers. IDs remain signed 32-bit
for existing query APIs; exhaustion rejects further admission rather than wrapping.

Optional `cull_outside_bounds` reclaims bullets outside `simulation_bounds`, a
field-local Rect2 supplied by the game. It is off by default. Use a margin around
the relevant world region; camera visibility must not silently decide damage.
Lifetime/bounds removals publish `bullet_expired` after the simulation traversal,
so observers may clear/spawn/remove without corrupting dense iteration. Explicit
`remove_at` retains its synchronous notification. Indices are unstable after a
swap; retain IDs for gameplay identity.

For MultiMesh rendering, set `field.draw_enabled = false` to avoid drawing each
bullet twice, and size `renderer.max_instances` for the field capacity. The
renderer now reads packed positions directly and computes the field-to-renderer
transform once per sync, eliminating per-bullet Dictionary creation. Hidden
renderers skip automatic syncing; an absent field clears visible instances.
Simulation keeps running regardless of renderer visibility. `sync_bullets()` is
still O(active bullets) and performs native instance-transform updates; this is
not a claim of constant-time rendering or GPU simulation.

## Verification and measurement

`bullet_patterns_test` verifies geometry, symmetry, capacity, retained storage,
expiry callbacks, bounded catch-up and renderer cleanup. Existing swept-hit and
action-effect tests remain active.

`tests/smoke/bullet_hell_smoke.tscn` runs 180 real physics ticks of continuous
emission, recycling 4,096 reserved slots, checks renderer counts and indexed hit
budgets, and clears the composed scene. It reports actual admissions. This is a
lifecycle/workload regression, not a rendering benchmark.

Open `examples/bullet_field_2d/bullet_field_lab.tscn` to inspect patterns and
measure the renderer on your hardware. The fixture uses MultiMesh, a repeating
emitter and reserved buffers. Compare frame times, allocations, material/texture
cost and hit-query cost on each target platform before committing to a bullet
count. CI export success does not certify GPU throughput or gameplay readability.
