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
native facade. `examples/platform_handheld/handheld_detection_lab.tscn`
shows a live result and clearly marked simulated samples.
