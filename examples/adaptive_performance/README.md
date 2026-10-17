# Adaptive Performance Lab

Open `adaptive_quality_lab.tscn`. The lab injects **synthetic**
window FPS and p95 frame times into the production
`NucleusAdaptivePerformanceController` to demonstrate hysteresis,
cooldowns, the 80% lower bound and progressive quality recovery.

Choose 1 (42 FPS), 2 (60 FPS), or 3 (55 FPS) to inject twelve
synthetic windows; use **Step 1 sample** to inspect an individual
observation. R resets the policy. A render-scale override is opt-in.

This example **never changes** project rendering scale, FPS cap,
`NucleusSettings`, or user preferences. For live observation instead,
assign a scene-owned `NucleusPerformanceSampler` to the controller's
`sampler` property. It will subscribe to its existing
`snapshot_sampled` signal; do not implement a second frame monitor.

## Adaptive Quality Binding Lab

Open `adaptive_quality_lab.tscn` to demonstrate an **opt-in temporary
render-scale override**. Press *Enable adaptation* first. Then press
**1** to submit twelve simulated slow frame windows (42 FPS/p95 25 ms),
or **2** to submit twelve healthy windows (60 FPS/p95 17 ms). The
saved preference, recommended scale and effective scale are shown separately.
Press **R** to reset policy, disable adaptation and restore the authored
setting. The demo's simulated sample timings do not represent actual GPU
measurements. The demo changes the root viewport scale temporarily only
after user approval. Closing the scene releases the override.

## Adaptive World Workload Lab (final phase)

Open `adaptive_world_workload_lab.tscn`. Enable the optional binding with
**E** or the UI button. Press **1** to send 12 synthetic slow windows and
watch optional background budgets reduce; press **2** to send 30 healthy
windows and observe recovery. **R** releases all budgets and resets policy.
Unload admissions and the independent critical queue are never throttled.
The example illustrates budget composition; it does not spawn heavy jobs
or claim a measured frame-rate gain.

See `docs/modules/performance.md` for ownership, constraints and profiles.
