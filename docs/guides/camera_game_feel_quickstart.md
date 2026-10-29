# Camera / Game Feel — Godot Editor Quickstart

Technical reference:

```text
docs/components/camera_game_feel.md
```

## 1. Third-person 3D setup

Recommended hierarchy:

```text
ThirdPersonCameraRig3D
└── FeedbackPivot : Node3D
    ├── CameraFeedback3D
    └── SpringArm3D
        └── Camera3D
            └── CameraFov3D
```

Assign:

```text
ThirdPersonCameraRig3D.spring_arm = SpringArm3D
ThirdPersonCameraRig3D.camera = Camera3D

CameraFeedback3D.target = FeedbackPivot
CameraFeedback3D.fov_controller = CameraFov3D
```

The Camera3D remains a direct SpringArm child.

## 2. First-person 3D setup

A typical structure:

```text
ViewYaw
└── ViewPitch
    └── FeedbackPivot
        ├── CameraFeedback3D
        └── Camera3D
            └── CameraFov3D
```

Look code owns yaw/pitch.

Feedback owns only FeedbackPivot local offsets.

## 3. 2D with NucleusCameraFollow2D

Keep the existing Camera2D:

```text
Camera2D
├── CameraFollow2D
└── CameraFeedback2D
```

Set:

```text
CameraFeedback2D.target = Camera2D
use_camera_offset = true
apply_rotation = false
```

Feedback then uses `Camera2D.offset`, leaving Follow position untouched.

## 4. Create a recoil profile

Create a:

```text
NucleusCameraImpulseProfile3D
```

Example:

```text
duration = 0.14

position_kick
    z = 0.035

rotation_kick_degrees
    x = -1.8

position_amplitude
    0.005, 0.005, 0.003

rotation_degrees
    0.2, 0.15, 0.15

fov_kick_degrees = 0.4

frequency = 30
decay_power = 2.5
```

Tune values for the camera scale and game style.

## 5. Trigger recoil from an Action

Action tree:

```text
Fire : NucleusGameplayAction
├── AmmoCost
├── Cooldown
├── FireAnimation
├── SpawnProjectile
└── CameraImpulse
```

Attach:

```text
addons/nucleus/components/gameplay/feedback/camera_impulse_effect_3d.gd
```

Assign:

```text
feedback
profile
```

The same GameplayAction now coordinates:

```text
cost
cooldown
animation
pooled projectile
camera feedback
```

without a weapon controller duplicating those systems.

## 6. Landing kick

Add:

```text
LandingFeedback3D
```

to the actor/camera composition.

Assign:

```text
CharacterBody3D
CameraFeedback3D
landing profile
```

Example thresholds:

```text
minimum_impact_speed = 4
full_strength_speed = 14
```

A small step causes no impulse.

A hard fall scales toward full profile strength.

## 7. Head bob

Add:

```text
CameraBob3D
```

Assign the CharacterBody and feedback mixer.

Tune:

```text
reference_speed
frequency
position_amplitude
rotation_degrees
response
```

The bob is a continuous source. It stacks with landing/recoil/shake rather than
replacing them.

## 8. Reduced motion

The camera feedback system automatically checks the same reduced-motion policy
used by Nucleus UI.

Each profile/source has:

```text
respect_reduced_motion
reduced_motion_scale
```

Recommended starting point for camera motion:

```text
0.10–0.25
```

For an effect that should disappear entirely:

```text
reduced_motion_scale = 0
```

Always test the game with Reduced Motion enabled.

## 9. Explosion or damage shake

You do not need a dedicated explosion camera class.

Connect the relevant local gameplay signal and call:

```gdscript
camera_feedback.play_impulse(
    explosion_profile,
    strength,
)
```

If the event is already a GameplayAction, use the provided Action effect.

## 10. Avoid transform contention

Do not attach multiple scripts that all assign the same camera/pivot transform.

Prefer:

```text
movement/orbit
    owns rig transform

CameraFeedback
    owns dedicated feedback pivot

CameraFov3D
    owns Camera3D.fov
```

This ownership boundary is the key to predictable composition.
