# Nucleus acceptance labs: choose the right scene

Nucleus deliberately ships **a small selection of purposeful visual labs**
plus independent headless and smoke regressions. A lab must demonstrate a
distinct reusable contract with observable actions and limits, not merely
provide a second UI for the same component. The consuming game owns its
actual levels, art, player flow and performance targets.

## Start with a goal

| Goal | Scene to run (F6) | What to verify |
| --- | --- | --- |
| Theme, focus, UI motion and overlays | `examples/ui/ui_polish_lab.tscn` | Normal/high-contrast Theme, keyboard/gamepad focus, reduced motion, responsive layout |
| Handheld identification and opt-in tuning | `examples/platform_handheld/handheld_tuning_lab.tscn` | Live versus simulated detection, preview, explicit apply, safe undo |
| Adaptive controller and visual quality | `examples/adaptive_performance/adaptive_quality_lab.tscn` | Simulated policy, opt-in effective scale change, restore |
| Actual adaptive work | `examples/adaptive_performance/adaptive_measured_lab.tscn` | Real workload measurements, not synthetic FPS claims |
| Opt-in world background budgets | `examples/adaptive_performance/adaptive_world_workload_lab.tscn` | Critical queue untouched while optional work scales |
| UI anchors projected in 3D | `examples/ui/world_anchor_lab.tscn` | Occlusion, bounds and viewport projection |
| World/biomes and persistent objects | `examples/world_composition/world_composition_lab.tscn` | Unload/reload, persistent IDs, authored layout |
| Terrain authoring and inspection | `examples/terrain/terrain_debug_lab.tscn` | Real terrain material, navigation/debug data |
| 2D/3D grids and placement | `examples/square_grid/`, `examples/hex_grid_2d/`, `examples/placement/` | Grid/placement ownership and collision |

Other specialist labs remain scoped to distinct native/runtime contracts.
For executable, assertion-driven verification, prefer the
[composed acceptance scenes](composition_acceptance.md) and
`tests/headless/test_runner.tscn` rather than creating another interactive lab.

## Recent lab consolidations

- The former standalone theme demonstration now lives in the
  **Theme & Controls** page of `ui_polish_lab.tscn`. It previews both
  variants locally, with no mutation of project-wide Resources.
- Handheld device classification and settings proposal now share
  `handheld_tuning_lab.tscn`. Simulated detection does not authorize
  graphics setting changes.
- Synthetic adaptation observation now shares
  `adaptive_quality_lab.tscn`, where applying render-scale changes
  still requires explicit opt-in. Live measured work stays separate.

Obsolete scripts, scenes and matching script UIDs are removed together.
Preserve any copies used by a **derived game** until it updates its scene
references; these deletions affect example routes only, not game APIs.

## Review checklist

1. Confirm the current project Theme is active and the requested scene opens.
2. Test mouse, keyboard/controller focus and readable text in both themes.
3. Resize a narrow viewport: tabs, panels and controls should remain reachable.
4. Change opt-in settings once, undo, and verify persistent preferences.
5. Distinguish synthetic samples from real device/performance measurements.
6. Check scene exit restores temporary overrides and disconnects callbacks.
7. Run corresponding headless or smoke suites; record actual passes separately.

**Not proven by headless checks:** gameplay feel, UI appearance on all devices,
graphics performance, contrast of every custom game widget and export quality.
