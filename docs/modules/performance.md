# Optional Performance / Diagnostics Module

## Status

`modules/performance` is optional and is not loaded by default.

It is development tooling around Godot's native performance APIs. It does not
replace the Godot Profiler, Network Profiler, Video RAM panel, external GPU
profilers, or platform-specific tooling.

The module is scene-owned by default.

## Purpose

The native Godot debugger exposes detailed measurements, but a project still
needs a low-cost control surface that can answer repeatable questions while the
game is running:

```text
Are we sustaining the frame target?
Is frame pacing stable?
Which subsystem is consuming the configured budget?
Did this workload regress after a change?
What changed near a spike?
Which native profiler should we open next?
```

Nucleus adds:

```text
sampling
short history
frame-pacing windows
target profiles
budget checks
human-readable diagnostics
trace markers
JSON reports
report comparison / regression hints
custom game probes
Debugger custom-monitor integration
compact development dashboard
```

The engine remains authoritative for engine-owned measurements.

## Public types

```text
NucleusPerformanceMetricIds
NucleusPerformanceProfile
NucleusPerformanceSnapshot
NucleusPerformanceDiagnostic
NucleusPerformanceAdvisor
NucleusPerformanceSampler
NucleusPerformanceReportComparator
NucleusPerformancePanel
```

The ready-to-instance development panel is:

```text
res://modules/performance/performance_panel.tscn
```

## Ownership

A normal development scene can own the tooling directly:

```text
World
├── ...
└── PerformancePanel
    └── Sampler
```

Or a persistent development shell can own a sampler while scenes change:

```text
DevelopmentSession
├── PerformanceSampler
└── GameRoot
```

Do not promote the module to a baseline Autoload. A consuming game decides
whether performance history should survive scene replacement.

The default panel contains its own sampler for the lowest-friction setup.

## Native and derived measurements

`NucleusPerformanceSampler` reads Godot `Performance` monitors for engine-owned
counters and derives wall-clock frame-pacing windows from monotonic process-frame
timestamps.

Current sampled groups include:

```text
time
    native FPS
    native TIME_PROCESS (informational)
    effective window FPS
    frame interval average
    frame interval p50
    frame interval p95
    frame interval maximum
    physics time
    navigation time

memory / objects
    static memory
    message-buffer high-water mark
    object count
    resource count
    node count
    orphan-node count

rendering
    rendered objects
    primitives
    draw calls
    video / texture / buffer memory

physics 2D / 3D
    active rigid bodies
    collision pairs
    islands

navigation 2D / 3D
    regions
    avoidance agents
    obstacles

render pipelines
    canvas
    mesh
    surface
    draw
    specialization compilation counters
```

Time monitors are normalized to milliseconds in Nucleus snapshots.

Some Godot monitors are debug-only and report zero in release builds. Some are
updated less frequently than every frame. Nucleus does not hide those engine
limitations.

## Frame health

Raw `Performance.TIME_PROCESS` is not treated as an authoritative CPU budget.
Synchronization, frame limiting, and execution environment can make it unsafe to
interpret that value as pure application work.

Frame health instead uses recent windows of:

```text
effective FPS
frame interval p95
```

The sampler measures frame intervals from `Time.get_ticks_usec()` so time scale
and smoothed simulation delta do not masquerade as frame-pacing changes.

The dashboard also exposes p50 and maximum frame intervals. A representative
healthy 60 FPS workload should show p50 and p95 close to the 16.67 ms cadence,
while occasional spikes appear mainly in the maximum series.

## History and trend access

The sampler keeps bounded snapshots in memory. Consumers can inspect statistics:

```gdscript
var stats := sampler.get_metric_statistics(
    NucleusPerformanceMetricIds.FRAME_INTERVAL_P95_MS,
    60,
)
```

Or retrieve an ordered series for visualization or project-specific tooling:

```gdscript
var recent_p95 := sampler.get_metric_series(
    NucleusPerformanceMetricIds.FRAME_INTERVAL_P95_MS,
    60,
    true,
)
```

`sample_count = 0` means the complete retained history.

The development dashboard uses this same API for its pacing sparkline. It does
not maintain a parallel UI-only history.

## Performance profiles

`NucleusPerformanceProfile` is game-owned policy.

The only universal default is a 60 FPS development target. Optional subsystem
budgets remain disabled until a consuming game enables them.

Supported optional budgets include:

```text
physics time
navigation time
draw calls
rendered objects
primitives
video memory
static memory
node count
orphan nodes
2D/3D active physics objects
2D/3D collision pairs
2D/3D navigation agents
```

Zero means "not budgeted" for these maxima. `max_orphan_nodes = -1` disables the
orphan-node check. Set it to `0` when any debug orphan should be reviewed.

Hardware tiers belong to product requirements. Nucleus deliberately does not
invent universal Low/Medium/High budgets.

## Diagnostics

`NucleusPerformanceAdvisor` evaluates measurements only when there is enough
evidence for a bounded recommendation.

Examples include:

```text
sustained FPS target loss
unstable p95 frame pacing
physics/navigation time budget exceeded
render draw/object/primitive budget exceeded
video/static memory budget exceeded
unexpected orphan nodes
physics body/pair budget exceeded
navigation-agent budget exceeded
render pipeline compilation after warmup
```

A diagnostic contains:

```text
severity
stable code
title
summary
evidence
suggested next steps
```

Recommendations route the developer toward evidence and native profilers. They
do not automatically change renderer, physics, quality, or gameplay policy.

## Trace markers

Game code can mark authored events:

```gdscript
sampler.mark_trace(
    &"island_streamed",
    {
        "island_id": island_id,
        "entities": spawned_count,
    },
)
```

Use traces to correlate scene streaming, spawning, VFX, inventory, network
population, or other authored events with performance changes.

Trace markers are not function-level CPU traces. Use Godot's Profiler for that.

## Reports

The current history, traces, diagnostic events, target profile, engine/platform
information, and metric summaries can be saved:

```gdscript
var error := sampler.save_report(
    "user://performance_report.json"
)
```

Report schema 3 contains both the compact compatibility summary and a generic
`metric_summary` keyed by stable `NucleusPerformanceMetricIds` strings.

Reports are intended for development comparison, bug reports, CI/lab tooling,
or sharing a reproducible workload snapshot. They are not a production analytics
backend.

## Regression comparison

A report can be captured before a risky change and compared afterwards:

```gdscript
var baseline := NucleusPerformanceReportComparator.load_report(
    "user://baseline.json"
)

var comparison := sampler.compare_report(
    baseline,
    0.10,
    0.25,
)
```

The two ratios are relative warning and critical thresholds. The default helper
values are 10% and 25%, but a project should choose tolerances that match its
benchmark stability.

The result contains:

```text
comparable_context
context_warnings
changes
regressions
improvements
```

Comparison rules currently cover frame timing, physics/navigation time,
rendering workload, video/static memory, and node count.

Context is intentionally visible. Different operating systems, renderer methods,
editor-embedding state, target FPS, or Godot major/minor versions can invalidate
a direct benchmark comparison. Nucleus still returns the metric deltas, but marks
the capture context as non-equivalent instead of pretending the numbers are
strictly comparable.

This is regression assistance, not a universal benchmark gate. CI may consume
the comparison result, but each game decides which workloads and thresholds are
release-critical.

## Native Debugger integration

When enabled, the sampler publishes summary monitors through
`Performance.add_custom_monitor()`:

```text
Nucleus/FrameBudget
Nucleus/FrameP95
Nucleus/Warnings
Nucleus/Criticals
```

Games can also register cheap numeric custom probes. Published game probes use
the `NucleusGame` monitor category while snapshot/report IDs retain the original
game-owned identifier.

## Relationship with Godot profilers

Use Nucleus to answer "where should I look?" and "did this workload change?"

Then use the native specialist:

```text
CPU/script/frame investigation
    Godot Debugger > Profiler

high-level multiplayer traffic
    Godot Debugger > Network Profiler

GPU resource memory
    Godot Debugger > Video RAM

long-lived monitor trends
    Godot Debugger > Monitors
    Nucleus history/report

GPU-specific bottlenecks
    platform/vendor GPU profiler
```

## Debug/release behavior

`NucleusPerformanceSampler.debug_build_only` defaults to `true`.

`NucleusPerformancePanel.hide_in_release` defaults to `true`.

A representative exported debug build is often a better profiling target than
an editor-embedded run. If captures are compared, keep execution context as
similar as possible.

## Cost model

Sampling defaults to every `0.5` seconds, not every frame. Per-frame work is
limited to recording one monotonic frame interval while sampling is active.

The history defaults to 120 snapshots and the trace buffer to 128 events.

The dashboard trend defaults to 30 seconds and reuses sampler history. It does
not create another high-frequency collector.

Do not lower the sampling interval aggressively without measurement:
observability itself can become part of the workload.

## Non-goals

The module is not:

```text
a replacement for Godot's Profiler
a GPU profiler
a packet sniffer
an automatic optimizer
a universal benchmark database
a hardware tier detector
a remote analytics SDK
a promise that one budget fits every game
```

## Related documentation

- `docs/guides/performance_quickstart.md`
- `docs/guides/tutorials/performance_profiling.md`
- `docs/guides/project_configuration.md`
- `docs/guides/validation_ci_quickstart.md`

## Adaptive Performance Controller (optional, observation-only)

`NucleusAdaptivePerformanceProfile` is an authored Resource describing
60 FPS by default, an 80% lower render-scale recommendation, 100% ceiling,
5% steps, progressive recovery, minimum evidence, consecutive-window
hysteresis and a cooldown between changes.

`NucleusAdaptivePerformancePolicy` is a pure `RefCounted` evaluator.
It consumes **existing** `NucleusPerformanceSnapshot` metrics:
`WINDOW_FPS`, `FRAME_INTERVAL_P95_MS`, `FRAME_INTERVAL_SAMPLES`.
No new profiler is introduced. Each decision contains a suggested scale,
whether it changed, the reason, evidence counters and a cooldown counter.
Stale sequences, missing metrics, invalid values and undersampled
windows cannot lower quality. Low FPS **and** slow p95 must persist before
reducing a recommendation. Recovery requires a higher FPS threshold,
acceptable pacing and more consecutive stable windows.

`NucleusAdaptivePerformanceController` is an optional scene-owned subscriber.
Assign its `sampler` to an existing `NucleusPerformanceSampler`; it listens
to `snapshot_sampled` and emits `decision_observed` and
`render_scale_recommended`. The controller does not write to
`Viewport`, `RenderingServer`, `Engine.max_fps` or `NucleusSettings`.
Disable it or call `reset_observation()` to reset counters and recommendations.
This first iteration **only observes and recommends**: FPS improvements are
not guaranteed or claimed. No competing settings writer or Autoload exists.

Example: `res://examples/adaptive_performance/adaptive_quality_lab.tscn`
sends reproducible synthetic good/slow/neutral windows, so the hysteresis
and recovery can be verified without deliberately overloading a real GPU.
The demonstration does **not** modify graphics settings.

Run `tests/headless/adaptive_performance_test.gd` through the registered
manifest. Test cases cover limits, degraded windows, recovery, stale and
missing snapshots, insufficient evidence, disabled recovery and node
lifetime. End-to-end real-frame reaction and user-approved temporary
application belong to the subsequent quality-binding iteration.

## Adaptive Quality Binding (opt-in, temporary)

`NucleusAdaptiveQualityBinding` connects the existing
`NucleusAdaptivePerformanceController.render_scale_recommended` signal to
the **sole** rendering scale writer,
`NucleusDisplaySettingsApplier.request_temporary_render_scale(requester, scale)`.
Set its `controller` and `display_applier` references explicitly; no new
autoload or sampler is introduced.

`NucleusDisplaySettingsApplier` now supports a **single scene-owned
temporary owner**: `request_temporary_render_scale()`,
`release_temporary_render_scale()`, `get_temporary_render_scale()`
and `get_effective_render_scale()`. It always applies the *smaller* of
the player's authored scale and the adaptive recommendation. The persisted
`graphics/render_scale` setting is not changed, and this temporary request
does not mark settings dirty.

Enabling is an explicit user action (`start_enabled=false` by default).
Disabling, freeing the binding, or exiting the scene releases the temporary
override. A manual user setting change or settings reload revokes the
binding immediately and emits `temporary_render_scale_revoked`; the user
must opt in again. A second simultaneous temporary requester receives
`ERR_BUSY`, rather than overwriting the active binding.

The sample `res://examples/adaptive_performance/adaptive_quality_lab.tscn`
has an explicit enable/disable control, sends simulated slow/healthy
snapshots through the existing policy and displays **saved preference**,
**recommended scale** and **effective scale** separately. Unlike the
original observation lab, enabling this one *does change real render scale*,
but never the persisted preference. The lab does not simulate device
FPS as if it were real hardware data.

The headless regression `adaptive_quality_binding_test.gd` checks
consent, single-owner exclusion, scale changes through the existing
display applier, manual override revocation, persistence isolation,
scene teardown and the actual demo wiring.

Known boundaries: One optional owner may control the temporary root
viewport scale at a time; authored settings changes take priority. Current
signals distinguish policy recommendations from applied effective values.
No GPU-bottleneck identification, CPU/physics changes, TDP controls or FPS
guarantees are implied. Screen-space / hardware benchmarking should be
validated in an actual Godot graphical build.

## Adaptive World Workload (opt-in background budgets)

`NucleusAdaptiveWorldWorkloadBinding` is a scene-owned adapter, using
`NucleusAdaptivePerformanceController.decision_observed` and its existing
hysteresis, cooldown and recovery policy. It does **not** collect frame
metrics or change procedural algorithms. Its optional
`NucleusAdaptiveWorldWorkloadProfile` (Resource) defines minimum
fractions of authored budgets for background work.

Explicit references can include **optional only**:
- `NucleusMaterializationQueue`: steps and CPU-time limit per frame.
- `NucleusWorldStreamLifecycle`: new load admissions, **not unloads**.
- `NucleusTerrainStreamer3D`: maximum new terrain chunks per update.
- `NucleusScatterRegion3D`: partition transforms and visual batches per frame.

All count budgets retain a minimum of one per cycle. This prevents the
adapter from pausing streaming or scatter indefinitely. Unlimited queue
time (`frame_budget_usec=0`) remains unlimited: no invented time cap.
Individual task steps and terrain chunk builds must still be bounded by
their original owners; changing the number of admissions does not make an
expensive single operation interruptible.

**Ownership and priority:** Never attach the binding to the queue or
stream lifecycle responsible for critical gameplay, movement or immediately
required regions. Give those tasks an independent queue/lifecycle owned by
the game. Nucleus cannot infer urgency from an arbitrary enqueued job.
This adapter reduces background workload only, and cannot guarantee target
FPS, CPU/GPU classification, or timely critical streaming.

`enable_binding()` is opt-in. It snapshots the original budgets, rejects
concurrent writers with `ERR_BUSY`, and uses the *reduced render-scale
recommendation as a proxy for sustained performance pressure*. That is
not a diagnosis of a CPU bottleneck. Bounds are relative to the game's
own authored budgets. When the existing policy recovers, they recover
gradually. Disabling, scene exit or controller deactivation restores
unchanged owned properties. External edits are detected and preserved;
the binding releases control rather than overwriting game changes.
Controller `reset_observation()` restores full background work capacity
while leaving an explicitly enabled binding active.

The demo `res://examples/adaptive_performance/adaptive_world_workload_lab.tscn`
simulates 42/60 FPS snapshots and displays live workload budgets, including
a critical queue which the binding never touches. No actual CPU load is
generated. The regression `tests/headless/adaptive_world_workload_test.gd`
covers opt-in, exclusivity, budget floors, recovery, unload protection,
external edits and teardown.

This final phase composes existing Nucleus mechanisms without introducing
a global world manager, new settings writers or a task scheduler.

## Real-work A/B measurement

The synthetic policy labs remain deterministic policy demonstrations. For real
frame windows and actual TerrainBuildJob load, use
`examples/adaptive_performance/adaptive_measured_lab.tscn`.
[Composition acceptance](../guides/composition_acceptance.md) documents the report,
throughput/recovery interpretation and hardware-evidence limits.
