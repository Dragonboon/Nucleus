# Runtime Optimization Contract

## Scope

This is the canonical Nucleus contract for general runtime-efficiency tools
outside terrain and world streaming.

```text
components/gameplay/timing
components/gameplay/lifecycle
components/gameplay/pooling
modules/ai integration
modules/performance audits
core/loading warmup
core/audio one-shot budgeting
components/ui/data refresh coalescing
core/save capture budgeting
```

No `OptimizationManager` or optimization Autoload exists. Godot remains
authoritative for frame scheduling, rendering, physics, navigation, resources and
profiling.

## Staggered update scheduling

`NucleusUpdateScheduler` is scene-owned and intended only for approximate-cadence
work such as Utility AI decisions, awareness checks, target rescoring, ambient
simulation and low-frequency diagnostics.

Tasks declare interval, optional phase and priority. Negative phase uses automatic
staggering. The scheduler caps callbacks per frame and may enforce a wall-clock
admission budget.

A delayed task executes once and schedules its next run from the current clock;
missed intervals are not replayed. Therefore it must not own fixed-step gameplay,
input, movement integration, hit resolution or frame-exact animation events.

`NucleusScheduledUpdate` exposes one task as an Inspector-friendly `tick(elapsed)`
component.

## Activity gating

`NucleusActivityGate` applies an explicit active/inactive state to a project-owned
target. It does not infer camera distance, combat state or network relevance.

Process mode is managed by default. Visibility, particle emission and rigid-body
sleep are opt-in. The component captures authored baseline state and restores it
on reactivation.

## Incremental object-pool prewarm

`NucleusObjectPool.prewarm()` remains synchronous. For larger capacities use
`prewarm_incremental(target_total, instances_per_frame)` or the matching
auto-prewarm export.

`prewarm_progress` exposes loading progress without polling. Pooling is still
optional: do not pool rare objects merely because the API exists.

## Utility AI scheduling

`NucleusAIUtilityBrain` may use a `NucleusUpdateScheduler`. With scheduler +
positive evaluation interval, automatic evaluation leaves per-physics polling and
uses the scheduled cadence. Auto phase prevents many simultaneously spawned
brains from aligning future decisions.

Context-change requests can make the task eligible for the next dispatch. Without
a scheduler, existing physics-driven behavior remains available.

## Render audit

`NucleusRenderAudit.inspect(root)` returns `NucleusPerformanceDiagnostic` findings
for structural candidates such as large repeated mesh/material groups, broad
shadow casting and missing visibility-range ends.

A finding is not an instruction to mutate the scene. Confirm rendering pressure
with the sampler/native tooling before changing MultiMesh, LOD, visibility or
shadow policy.

## Physics audit

`NucleusPhysicsAudit.inspect(root)` reports broad candidates such as many awake
rigid bodies, disabled sleeping, widespread contact monitoring and actively
monitoring Areas.

It never changes collision masks, sleep, monitoring, physics tick rate or Jolt
configuration.

## First-use warmup

`NucleusWarmupPlan` contains `NucleusWarmupEntry` resources and is executed by a
scene-owned `NucleusWarmupSequence` with bounded instances per rendered frame.

Modes:

```text
INSTANTIATE_ONLY
ENTER_TREE_INACTIVE
```

The second mode executes normal tree/ready lifecycle and is therefore safe only
for explicitly warmup-compatible scenes.

Hidden instantiation cannot guarantee GPU pipeline compilation. A renderer-first
hitch may require a project-authored rendered warmup after profiler/pipeline
evidence identifies that cause.

## Audio voice budgeting

The shared non-positional one-shot pool accepts integer voice priorities.
`NucleusAudioCue.voice_priority` carries authored policy. At capacity, the pool
chooses the oldest voice among the lowest active priority; a lower-priority new
request is rejected rather than stealing a more important voice.

Default priority `0` preserves equal-priority oldest-first behavior. Positional
2D/3D audio remains scene-owned.

## UI refresh coalescing

`NucleusUIRefreshCoalescer` collapses several same-frame invalidations into one
deferred `refresh_due`. `flush_now()` provides an explicit immediate path.

Do not coalesce focus, confirmation or modal ownership when one-frame latency
changes correctness. `NucleusUIResourceLoadBinding` exposes optional progress
coalescing for noisy loading updates.

## Save capture budgeting

`NucleusSaveCaptureJob` snapshots the participant callback set and captures a
bounded number of participants per step. `capture_snapshot_incremental()` and the
incremental save helpers yield between batches.

Participant capture remains on the main thread because callbacks may read Nodes.
Application pause/quit autosaves remain synchronous because another frame is not
guaranteed.

## Measurement contract

Use `NucleusPerformanceSampler` and native Godot profilers to establish evidence.
The preferred loop is:

```text
repeatable workload
→ capture baseline
→ identify subsystem pressure
→ apply one bounded primitive
→ repeat same workload
→ compare report
```

Architecture alone is never a performance result.

## Physics workload integration (0.37)

Ownership: native Godot bodies/navigation remain authoritative. Existing Nucleus
pooling, spatial indices, targeting, navigation followers and scheduler provide
adapters; the game owns collision masks, combat relevance, damage, despawn rules
and acceptable decision latency. No new Autoload or global physics setting is used.

### Defaults and compatibility

- `NucleusPoolable` now includes the target root in its managed baseline and
  caches the managed node list. Released rigid bodies have velocity reset and
  are put to sleep; authored sleep state is restored only on acquire. Shapes are
  still changed deferred, including releases from physics callbacks. Call
  `recapture_baseline()` while inactive after intentionally changing scene structure.
  Keep `manage_process_modes` enabled for ordinary pooled scenes. Sleep alone is
  not a permanent freeze against external contacts or forces.
- `NucleusSpatialRectIndex2D.query_region_into(region, result, scratch,
  include_borders=true, sorted_results=true)` clears caller-owned containers,
  collects the complete region result and preserves legacy ordering by default.
  `sorted_results=false` is opt-in; use it only where ordering has no meaning.
  Reusing containers reduces container construction, not a promise of zero allocation.
- `NucleusBulletTargetBatch2D.query_bullet_hits_into(field, results,
  maximum_pairs=0)` reuses per-batch query scratch. Zero means **all pairs**;
  positive values retain the legacy limit of at most 16384. The old
  `query_bullet_hits(field, maximum_pairs=4096)` keeps its prior zero/negative
  empty-result behavior and deterministic ordering. Neither cap is a CPU budget.
  For authoritative damage use all pairs and author a sustainable workload;
  uncapped output can grow to bullets × overlapping targets. Do not silently
  truncate combat under machine pressure. Batch queries have no callbacks and
  are not reentrant or thread-safe. Coordinates remain field-local.
- `NucleusSpatialPointIndex2D.query_radius_bounded(center, radius,
  maximum_results=24, maximum_candidates=96, maximum_cells=64, excluded_id=-1)`
  samples center-first rings and stable bucket membership without sorting.
  This is approximate, not nearest-N; clustered agents and insertion history can
  bias selection. Both visited cells and inspected candidates are bounded.
  Exact `query_radius()` is unchanged.
- `NucleusCrowdSeparation2D.calculate(..., maximum_candidates=0)` and
  `NucleusCrowdMotionSource2D.maximum_candidates` keep legacy selection at zero.
  Use 96 as a starting point for approximate steering. Never use this query for
  damage, area attacks or authoritative visibility.

### Ready-to-compose conservative configuration

Place one `NucleusUpdateScheduler` in the workload scene (not one per actor).
Its existing defaults are 32 callbacks/frame and 1500 microseconds admission
budget. A single callback may exceed that budget; it is not a preemptive CPU cap.
Assign the same scheduler before adding these components to the tree:

| Component | Configuration | Scheduling boundary |
| --- | --- | --- |
| `NucleusAIUtilityBrain` | `update_scheduler`, interval 0.25 s | Intention evaluation |
| `NucleusTargetingAgent` | `update_scheduler`, interval 0.10 s | Candidate rescoring |
| `NucleusNavigationFollower2D` / `3D` | `update_scheduler`, minimum interval 0.20 s | Permission to request paths |
| `NucleusObjectPool` | `auto_prewarm_instances_per_frame=4`, explicit capacity | Incremental instance warmup |
| `NucleusCrowdMotionSource2D` | `maximum_candidates=96` | Approximate separation only |

Without a scheduler, existing fixed-step polling remains. Assign scheduler and
intervals before tree entry; re-enter the tree to re-register changed cadence.
Keep the scheduler alive for its consumers' lifetime. Scheduler registration is
scene-owned and removed on exit. Targeting invalidations request an earlier
budgeted dispatch; explicit `refresh_selection()` remains synchronous. Scheduled
callbacks respect disabled processing. Navigation still follows its current path
at the physics rate; it waits for initial path admission and coalesces new
requests. Thus scheduling can add decision/path latency under load. Do not put
movement integration, hit resolution or frame-exact attack events on this scheduler.
Native navigation may also recalculate paths internally after map/path changes;
this adapter bounds only Nucleus-authored target requests.

Physics tick rate remains authored by the project (normally 60 Hz). No automatic
collision-mask changes, camera-based enemy suspension, avoidance disabling or
hardware-dependent hit dropping occurs. Configure relevance with the existing
`NucleusActivityGate` only when the game guarantees an entity can be suspended.

### Live measurement fixture

Run `res://examples/physics_workload_2d/physics_workload_lab.tscn` with F6.
It composes packed bullets + MultiMesh, complete indexed hits, moving target
circles, utility brains, targeting, native navigation + the existing character
motor, and a 64-instance rigid-body pool with incremental warmup/recycling.
Cyan dots are native moving characters; orange circles are query targets.

- Space switches clustered/dispersed target layouts and clears sampler history.
- S saves a uniquely named `user://physics_workload_*.json` report and shows its
  absolute path. Reports include native sampler statistics and workload settings.
- Inspector exports select counts, scheduled decisions and approximate separation.
  Restart for A/B runs; allow warmup, use the same layout/counts/duration and an
  exported build on the target device. Start with 128 targets / 4096 bullet capacity.
- The displayed query+steering time covers those sections only. It is not total
  physics CPU time. The sampler includes frame timing and native physics monitors.
  Targets are synthetic and no game damage is applied; visual overlap counts are
  not an assertion about Feraloom combat balancing.

CI exercises the fixture and separate native lifecycle/navigation checks. These
prove behavior, not FPS, GPU quality or low-end hardware suitability. Profile
before changing renderer, tick rate, collision complexity or native avoidance.
