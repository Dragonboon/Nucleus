# Optional PC handheld detection (Godot 4.7.2)

`NucleusPlatform.get_handheld_info()` calls the stateless
`NucleusHandheldDetector.detect()`. The detector uses Godot's
`OS.get_model_name()`, `OS.get_processor_name()`,
`RenderingServer.get_video_adapter_name()`, and (Linux only) read-only DMI
fields under `/sys/class/dmi/id/`. No shell, registry, SDK or Autoload.

The pure `NucleusHandheldDetector.classify(evidence: Dictionary)` allows
deterministic testing or project-supplied OEM evidence. Results contain:

- `family`: `steam_deck`, `rog_ally`, `legion_go`, `msi_claw`,
  `ayaneo`, `gpd_win`, `onexplayer` or `unknown`.
- `model`: human-readable recognized family/model.
- `confidence`: `confirmed`, `probable` or `unknown`.
- `source`: `model_name`, `linux_dmi`, or `hardware_signature`.
- `is_handheld`: whether a handheld family is suspected or confirmed.
- `os_name`: Godot's host OS, *not* an inferred storefront.

The legacy barebone Steam Deck heuristics (Van Gogh GPU and AMD Custom APU
0405) are preserved as **probable** evidence rather than definitive proof.
SteamOS alone and generic integrated GPUs are **not proof** of Steam Deck.
ASUS ROG Ally/Ally X use recognized product names and ASUS model codes.
Other recognized handheld families use model names. This is intentionally a
small extensible recognition set, not an exhaustive model database.

`NucleusPlatform.is_pc_handheld()` is a convenience boolean including
probable results. For automatic tuning, **inspect confidence first** and
ask the user before applying performance settings. A confirmed handheld does
not imply a particular TDP, dock state, gamepad mode, battery state or screen
resolution. Existing `NucleusPerformanceProfile`, `NucleusSettings` and
input owners remain responsible for those policies.

### Validation

`tests/headless/handheld_detection_test.gd` tests injected Windows/Linux,
Steam Deck LCD/OLED, Ally/Ally X, other families, weak evidence and the
native facade. `examples/platform_handheld/handheld_tuning_lab.tscn`
shows a live result and clearly marked simulated samples.

## Optional settings proposals

`NucleusHandheldTuningProfile` is an authored Resource containing only
`graphics/max_fps` and `graphics/render_scale`. The supplied optional
profiles are **Autonomy** (30 FPS/0.80 scale), **Balanced** (60/0.90) and
**Image quality** (60/1.00). These are illustrative starting points,
not device-specific benchmarks, guaranteed framerates or battery savings.

`NucleusHandheldSettingsAdvisor.suggested_profile_id(hardware)` returns
`balanced` only for a confirmed known handheld. Unknown and probable
identifications return an empty recommendation. No suggestions are applied
automatically.

The advisor has a read-only `preview(profile, settings)` and explicit
`apply_profile(profile, settings, approved, expected)`; the latter validates
both values against the active Settings catalog and rejects stale snapshots
with `ERR_BUSY`. For a one-session undo, use `revert_if_unchanged(settings,
previous_values, applied_values, approved)`. Undo is rejected if another
writer changed any applied setting. The active `NucleusSettingsService`
continues to own validation, live appliers and persistent configuration.
No extra Autoload or concurrent writer is added.

The optional `res://examples/platform_handheld/handheld_tuning_lab.tscn`
displays the actual before/after changes and requires an explicit button
press for applying or undoing. Its preview depends on the existing
`/root/NucleusSettings` service. It is not a hardware power manager.
