# Performance / Diagnostics Quickstart

Performance work starts with a repeatable workload and a product target, not a
universal draw-call/FPS rule.

## 1. Add the optional sampler

Instance:

```text
res://addons/nucleus/modules/performance/performance_panel.tscn
```

under a development scene. The embedded sampler defaults to low-frequency
sampling and a 60 FPS development target.

Create a game-owned `NucleusPerformanceProfile` for each hardware/resolution/FPS
target the product actually promises.

## 2. Watch frame health, then open the specialist profiler

Useful groups include:

```text
frame pacing p50 / p95 / max
physics and navigation time
draw calls / objects / primitives
video and static memory
physics objects / collision pairs
navigation agents / obstacles
pipeline compilation counters
```

Nucleus answers "where should I look?" and "did this workload regress?". Use the
Godot Profiler, Network Profiler, Video RAM tools and platform GPU profilers for
deep investigation.

## 3. Mark authored events

```gdscript
performance_sampler.mark_trace(
	&"combat_wave_started",
	{"enemy_count": enemies.size()},
)
```

Trace scene transitions, spawn bursts, large saves, VFX first-use and other
meaningful events; do not emit markers every frame.

### Instrument synchronous sections and frame hitches (optional)

Attach `NucleusPerformanceSectionProfiler` to the same scene and point its
`sampler` at the existing `NucleusPerformanceSampler`:

```gdscript
var token: int = section_profiler.begin_section(&"network/interest_update")
update_interest_sets()
if token != 0:
	section_profiler.end_section(token)
```

Set explicit budgets through `set_section_budget()` to record and trace expensive
sections. The profiler also listens to the sampler's maximum frame interval per
sampling window and can emit bounded hitch events. It does **not** add a second
per-frame collector or replace Godot's function profiler.

Complete contract: [`../modules/performance_sections.md`](../modules/performance_sections.md).

## 4. Capture and compare

```gdscript
performance_sampler.save_report("user://baseline.json")
```

After a change, compare the same workload under equivalent context. Inspect
`comparable_context` and its warnings before treating deltas as a regression.

## 5. Choose an intervention from evidence

Typical mapping:

| Evidence | Candidate tool |
| --- | --- |
| many low-frequency jobs align on one frame | `NucleusUpdateScheduler` |
| distant/inactive subtrees still process | `NucleusActivityGate` |
| pool creation hitches | incremental pool prewarm |
| Utility AI evaluates in bursts | scheduler-backed AI staggering |
| rendering budget pressure | `NucleusRenderAudit` + native profiler |
| light/shadow budget pressure | `NucleusLightingAudit3D` + native profiler |
| physics pressure | `NucleusPhysicsAudit` + native profiler |
| first-use PackedScene hitch | `NucleusWarmupSequence` |
| first-use GPU pipeline hitch | game-authored rendered warmup after evidence |
| one-shot audio saturation | voice priorities |
| bursty UI writes | `NucleusUIRefreshCoalescer` |
| large participant capture spike | incremental save capture |

For lighting findings, continue with:

```text
docs/guides/lighting_shadows_quickstart.md
```

Continue with [`runtime_optimization_quickstart.md`](runtime_optimization_quickstart.md)
only after the measurement identifies one of these shapes.
