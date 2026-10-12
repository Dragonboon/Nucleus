# Adaptive Performance Lab

Open `adaptive_performance_lab.tscn`. The lab injects **synthetic**
window FPS and p95 frame times into the production
`NucleusAdaptivePerformanceController` to demonstrate hysteresis,
cooldowns, the 80% lower bound and progressive quality recovery.

Choose 1 (42 FPS), 2 (60 FPS), or 3 (55 FPS). Press Space to submit a
window or use the twelve-window batch button. R resets observation.

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
