# Mobile Foundation Contract

## Scope

```text
addons/nucleus/modules/mobile
addons/nucleus/components/ui/touch
addons/nucleus/core/input/haptics.gd
addons/nucleus/core/input/local
addons/nucleus/core/platform/nucleus_platform.gd
```

Mobile Foundation does not create a separate mobile gameplay framework.

Its goal is:

> the same semantic gameplay actions continue to drive the game whether the
> player uses keyboard/mouse, gamepad, or touchscreen.

## Reused baseline

Before adding mobile-specific code, reuse:

```text
NucleusApp
    pause/resume/focus/back/memory-warning lifecycle

NucleusUISafeArea
    display cutout / safe-area margins

NucleusUIBreakpoints
    compact/regular/wide + portrait classification

NucleusSettings
    accessibility and vibration preferences

NucleusMotionInput
    semantic movement/look bridge
```

## Touch as an input source

`NucleusInputTypes.Source.TOUCH` is a first-class source.

`NucleusLocalPlayerInput` can own:

```text
KEYBOARD_MOUSE
GAMEPAD
TOUCH
```

A one-player `NucleusLocalInputSession` can hot-swap the same stable player seat
between all three.

A delayed touch **release** does not change ownership after another device has
already taken the seat.

## Virtual controls

### NucleusVirtualStick

Feeds four semantic InputMap actions.

Typical movement:

```text
move_left
move_right
move_forward
move_back
```

It can target:

```text
NucleusLocalInputSession + player_index
```

or fall back to global `Input.action_press()` for simple single-player scenes.

The stick does not create a separate `mobile_move_vector`.

### NucleusTouchActionButton

Extends Godot `TouchScreenButton` so multiple gameplay buttons and a stick may be
held simultaneously.

It feeds one semantic action such as:

```text
jump
interact
primary_action
secondary_action
```

The inherited native `action` is intentionally kept empty so the action has one
Nucleus routing path.

### NucleusTouchLookArea

Feeds touch drag delta directly into an existing `NucleusMotionInput`.

Therefore a third-person camera can continue to use:

```text
NucleusMotionInput
→ NucleusLookRig3D
→ NucleusThirdPersonCameraRig3D
```

without a second mobile camera API.

## Haptics

`NucleusHaptics.pulse()` applies the existing vibration setting and selects:

```text
explicit local gamepad
active gamepad
handheld vibration
```

in that order.

Android exports still need the platform `VIBRATE` permission for handheld
vibration to have an effect.

## Orientation

`NucleusMobileOrientationPolicy` is scene-owned.

It supports:

```text
project default
landscape
portrait
reverse variants
sensor landscape
sensor portrait
full sensor
```

Do not globally force orientation when one scene/product configuration can own
the choice.

On iOS, the project handheld orientation setting must permit sensor orientation
for runtime sensor changes to take effect.

## Permissions

`NucleusMobilePermissions` centralizes Android runtime permission requests but
does not own permission-rationale UX. iOS permission prompts remain tied to the
feature/native integration that owns them; Nucleus does not pretend the Android
OS request API is portable to iOS.

Recommended flow:

```text
player taps "Enable microphone"
→ game explains why
→ request permission
→ feature reacts to result/platform state
```

Do not request every dangerous permission at startup.

Android permissions must also be declared in the export preset.

## Sensors

Use Godot's native `Input` sensor APIs directly unless a consuming game proves
that reusable policy is missing.

Examples include accelerometer, gravity, gyroscope, and magnetometer/orientation
data.

Nucleus deliberately does not wrap these getters merely to rename them.

## Responsive UI

Use:

```text
NucleusUISafeArea
NucleusUIBreakpoints
Godot Containers/anchors
```

Touch controls are still game presentation. Nucleus does not choose their
screen position, opacity, art, size, handedness, or whether they are available
on desktop.

## Platform checks

Use `NucleusPlatform` for reusable capability decisions:

```text
is_android()
is_ios()
is_native_mobile()
is_mobile_host()
supports_touchscreen()
supports_orientation()
supports_handheld_haptics()
```

Prefer feature queries to repeated operating-system string comparisons.

## What is intentionally not baseline

```text
billing / IAP
push notifications
ads
analytics
store review prompts
cloud messaging
camera/microphone feature UX
platform account SDKs
graphics-quality presets
download managers
```

Those belong behind explicit project/provider integrations.

## Testing

Desktop editor:

```text
Project Settings
→ Input Devices / Pointing
→ Emulate Touch From Mouse
```

This is useful for interaction smoke tests, but it does not replace Android/iOS
device validation.

Validate at least:

```text
multi-touch stick + action simultaneously
safe areas
pause/resume
back behavior
orientation
permission flow
handheld haptics
thermal/performance behavior
```

on real target hardware.
