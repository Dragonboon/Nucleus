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
