# Accessibility Preferences and Input Comfort Contract

## Scope

This contract covers reusable preferences and helpers that improve comfort
without moving game art direction or gameplay semantics into Nucleus.

```text
addons/nucleus/core/accessibility/ui_accessibility_policy.gd
addons/nucleus/core/input/input_accessibility_policy.gd
addons/nucleus/core/input/input_activation_state.gd
addons/nucleus/components/ui/accessibility/ui_accessibility_binding.gd
addons/nucleus/components/gameplay/control/motion_input.gd
addons/nucleus/components/gameplay/camera/look_rig_3d.gd
```

Nucleus owns preference identity, persistence integration, neutral policy, and
small reusable adapters. The consuming game continues to own its Theme, layout,
contrast palette, semantic action choices, and balance.

## Built-in preferences

The default settings catalog includes:

```text
accessibility/ui_scale
accessibility/high_contrast
input/mouse_look_sensitivity_scale
input/gamepad_look_sensitivity_scale
input/gamepad_move_deadzone
input/gamepad_look_deadzone
```

The settings catalog schema is version 3. Older settings files remain readable;
new definitions enter with their defaults and the settings service rewrites the
file using the current schema through its existing migration behavior.

### Interface scale

`accessibility/ui_scale` expresses **user intent**. It does not scale an entire
Control tree automatically.

Blindly assigning a root `Control.scale` conflicts with native Container layout,
anchors, safe areas, and project-specific responsive rules. Instead compose a
`NucleusUIAccessibilityBinding` in the UI scene and apply the emitted value to
the game's Theme/layout strategy.

```gdscript
func _on_ui_scale_changed(value: float) -> void:
    # Example policy owned by the game, not Nucleus.
    ui_theme.default_font_size = roundi(18.0 * value)
    _rebuild_spacing_for_scale(value)
```

The binding also emits the current value during `_ready()` so a scene can build
its initial presentation without polling settings manually.

### High contrast

`accessibility/high_contrast` is also intent rather than a universal palette.

A game should use the setting to choose a game-owned high-contrast Theme or
presentation variant. Essential state must not depend on color alone. Combine
color with text, icon shape, outline, pattern, position, or another redundant
cue where appropriate.

Nucleus does not ship a color-blind post-process filter as a substitute for
semantic UI design.

## Look sensitivity

`NucleusLookRig3D` keeps its authored values as the baseline:

```text
mouse_sensitivity_degrees_per_pixel
gamepad_degrees_per_second
```

The corresponding user preferences multiply those authored values. A default
scale of `1.0` therefore preserves every existing scene.

This precedence remains:

```text
authored component baseline
× persisted sensitivity scale
= effective sensitivity
```

Games should not rewrite the component's authored baseline every time the user
changes the preference. Let the shared policy supply the multiplier.

## Controller deadzones

`NucleusMotionInput` preserves explicit scene overrides.

When `move_deadzone` or `look_deadzone` is non-negative, that value remains
authoritative. When the export remains at its existing `-1` automatic value and
the active/local source is a gamepad, Nucleus resolves the matching persisted
controller deadzone.

```text
explicit scene deadzone >= 0
    → scene wins

scene deadzone == -1 + gamepad source
    → accessibility preference

scene deadzone == -1 + keyboard/touch
    → existing Godot/InputMap behavior
```

The two controller deadzones are intentionally separate because a player may
need generous movement drift filtering while retaining fine camera control, or
the inverse.

## Hold versus toggle

Hold/toggle is not a single global preference. Sprint, aim, crouch, scanning,
and other actions may each need independent behavior.

`NucleusInputActivationState` is therefore a small per-action state machine. It
receives an already semantic pressed state and never knows the physical binding.

```gdscript
var aim_activation := NucleusInputActivationState.new()

aim_activation.set_mode(NucleusInputActivationState.Mode.TOGGLE)

func _process(_delta: float) -> void:
    var pressed := motion_input.is_action_pressed(&"aim")
    var aiming := aim_activation.update_state(pressed)
    weapon_controller.set_aiming(aiming)
```

A game can persist one setting per action if it exposes that choice. Nucleus
should not invent universal sprint/aim/crouch settings because those action IDs
and semantics are project policy.

Switching between keyboard/mouse and gamepad does not reset a toggle because the
activation state follows the semantic action rather than a device. Games that
want a mode change or session transition to cancel the state should call
`reset()` explicitly.

## Local multiplayer

Sensitivity and default deadzone preferences in the baseline catalog are
application-wide. This matches the current Nucleus settings ownership model.

A game that needs different accessibility profiles for multiple simultaneous
local players should keep those per-player values in its own profile layer and
supply explicit component deadzones/sensitivity baselines. Do not overload the
global active-device state to represent multiple players.

## What remains game-owned

Nucleus does not decide:

```text
high-contrast colors or art
font families
exact widget spacing
subtitle presentation
which actions support toggle mode
per-player profile UX
assist-mode balance
color-blind semantic palettes
```

Those choices depend on content and product requirements.

## Validation

Executable coverage should verify:

```text
default catalog contains every preference
new defaults are neutral/backward-compatible
hold mode tracks press/release
 toggle mode changes only on press edges
invalid activation modes are rejected
existing explicit MotionInput deadzones remain authoritative
```

Manual validation should additionally check:

```text
keyboard/mouse ↔ gamepad hot swap
controller drift around configured deadzones
very low/high look sensitivity
UI relayout at minimum/maximum scale
high-contrast Theme readability
hold/toggle actions after pause and device hot swap
```
