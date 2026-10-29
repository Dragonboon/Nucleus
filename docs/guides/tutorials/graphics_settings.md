# Graphics settings: runtime viewport and scene-owned Environment

This tutorial builds a graphics menu without turning `NucleusSettings` into a
second rendering engine.

## 1. What Nucleus owns by default

The default settings catalog includes runtime settings that map cleanly to global
Godot state:

```text
display/window_mode
display/borderless
display/vsync_mode
graphics/max_fps
graphics/render_scale
graphics/scaling_3d_mode
graphics/screen_space_aa
graphics/taa_enabled
graphics/msaa_2d
graphics/msaa_3d
graphics/debanding_enabled
```

`NucleusDisplaySettingsApplier` translates those values into `DisplayServer`,
`Engine` and the root `Viewport`.

Your UI should call `NucleusSettings.set_value()` or use the existing settings
bindings. It should not write those engine properties independently.

## 2. Build a basic graphics menu

For a slider controlling 3D render scale:

```gdscript
func _on_render_scale_changed(value: float) -> void:
	NucleusSettings.set_value(
		NucleusSettingIds.GRAPHICS_RENDER_SCALE,
		value,
	)
```

For an option control, read its `NucleusIntOptionSettingDefinition` so the UI is
driven by the catalog rather than duplicating enum labels.

A project may expose only a subset of the default settings. A mobile game, for
example, may hide fullscreen and present only render scale plus a small quality
surface.

## 3. Understand the AA settings

Nucleus keeps Godot's mechanisms separate:

- screen-space AA selects Disabled, FXAA or SMAA;
- TAA is a boolean;
- MSAA 2D and MSAA 3D are independent;
- FSR2 at native scale also behaves as a temporal reconstruction solution.

The framework does not invent a universal "best" combination. Decide per game,
renderer and hardware tier.

## 4. Add scene-owned Environment settings

The following resources are shipped under:

```text
addons/nucleus/core/settings/optional/environment/
```

They cover SSAO, SSIL, glow, volumetric fog, SDFGI and tonemapping. They are not
part of the default catalog because attaching them globally would overwrite
scene-authored Environment values even in games that never requested that policy.

To opt in:

1. create a game-owned settings catalog based on the default catalog;
2. add only the optional Environment definitions the game exposes;
3. add `NucleusEnvironmentSettingsApplier` beneath the relevant
   `WorldEnvironment`, or assign its `target` property;
4. bind the menu controls to the matching setting IDs.

The component changes the existing `Environment` resource. It does not create a
new environment and does not move scene ownership into an Autoload.

## 5. Quality presets

Nucleus deliberately does not ship Low/Medium/High/Ultra values. Those names are
meaningless without the game's content and target hardware.

A game can implement a preset by applying several existing setting values in one
UI action. Keep `Custom` as presentation state derived from whether the current
values still match one of the game's known bundles.

Recommended precedence is:

```text
framework definition default
→ game-owned catalog/default override
→ optional platform recommendation chosen by the game
→ persisted user value
```

Persisted user choice wins. Platform recommendations should seed defaults, not
silently overwrite an explicit preference every launch.

## 6. Renderer/platform availability

A setting existing in the catalog does not mean every renderer implements the
feature. Before showing expensive scene effects, the game should know its chosen
renderer and supported platform matrix.

Examples:

- SDFGI/SSIL/volumetric effects are Forward+-oriented features;
- MetalFX is intentionally omitted from the default scaling choices;
- desktop window mode is ignored on platforms with managed window behavior.

Prefer hiding unsupported options over accepting a setting that cannot have an
effect.

## 7. Testing

Validate three layers:

1. catalog validation and defaults in headless CI;
2. runtime root-viewport values in a normal game window;
3. visual Environment changes in representative scenes and exports.

Window-mode validation must be done with Godot game embedding disabled or in an
exported build.

## Common mistakes

- writing `ProjectSettings` and expecting a runtime graphics change;
- making a menu write `Viewport` directly while an applier owns the setting;
- globally forcing SSAO/glow/fog on every scene;
- treating a Low/Ultra preset as framework truth;
- exposing renderer-specific options without checking the target renderer;
- reducing logical UI resolution instead of using 3D render scaling.

The authoritative ownership contract remains
`docs/components/settings_and_input.md`.
