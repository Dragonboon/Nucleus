# Tutorial: build a third-person 3D controller and camera

This tutorial builds the generic 3D gameplay shell Nucleus provides before a
game adds genre-specific movement or production character art.

The final composition uses:

```text
CharacterBody3D
NucleusMotionInput
NucleusCharacterMotor3D
NucleusThirdPersonCameraRig3D
NucleusLookRig3D
NucleusMouseCapture
```

It works with keyboard/mouse and the default gamepad movement/look actions.

## 1. Create the Player

```text
Player : CharacterBody3D
├── CollisionShape3D
├── VisualRoot : Node3D
│   └── PrototypeMesh : MeshInstance3D
├── MotionInput : NucleusMotionInput
└── Motor : NucleusCharacterMotor3D
```

Keeping prototype geometry under `VisualRoot` makes the later art upgrade a
presentation replacement rather than a gameplay rewrite.

Configure the motor:

```text
body = Player
motion_input = MotionInput
speed = 5.0
ground_acceleration = 20.0
ground_deceleration = 24.0
air_acceleration = 8.0
air_deceleration = 4.0
```

Leave `jump_action` empty for a grounded/no-jump prototype, or assign a
project-defined action when jumping is part of the game.

## 2. Instance the Nucleus camera rig

Instance:

```text
res://addons/nucleus/components/gameplay/camera/third_person_camera_rig_3d.tscn
```

into the world/session:

```text
World
├── Player
├── ThirdPersonCameraRig3D
└── MouseCapture : NucleusMouseCapture
```

The packed rig contains a SpringArm/Camera composition plus look control.

## 3. Wire target and input

Assign on the camera rig:

```text
target = Player
motion_input = Player/MotionInput
```

Assign on the motor:

```text
orientation_source = ThirdPersonCameraRig3D
```

This makes planar movement camera-relative rather than actor-relative.

## 4. Start with camera values you can feel

Example starting point:

```text
target_offset = (0, 1.5, 0)
minimum_distance = 2.0
maximum_distance = 8.0
initial_distance = 4.0
zoom_step = 0.5
zoom_response = 14.0
```

Tune these against the scale of the real world/character.

## 5. Configure look feel

On `LookRig`:

```text
mouse_sensitivity_degrees_per_pixel = 0.10
gamepad_degrees_per_second = 180
minimum_pitch = -70 degrees
maximum_pitch = 70 degrees
```

Mouse look is angular delta per pixel. Gamepad look is angular speed per second.

## 6. Capture the mouse

Add `NucleusMouseCapture` with:

```text
capture_on_ready = true
```

When opening UI:

```gdscript
mouse_capture.release()
```

When returning to gameplay:

```gdscript
mouse_capture.capture()
```

Do not assign `Input.mouse_mode` directly when Nucleus cursor policy already
owns it.

## 7. Test SpringArm collision

Place a wall behind the player and orbit into it. `SpringArm3D` should shorten
the camera distance instead of clipping through the obstacle.

## 8. Test camera-relative movement

Rotate the camera 90 degrees and press forward. The player should move toward the
camera's new planar forward direction.

## 9. Add local-player input later without changing the motor

For a session-owned local seat:

```gdscript
motion_input.bind_local_player_input(player_input)
```

The motor and camera continue consuming the same `NucleusMotionInput` API.

## 10. Replace the prototype mesh with a real rig

Do not replace `Player : CharacterBody3D`.

Replace only the contents of `VisualRoot`, then add the native Godot animation
stack and Nucleus animation adapters.

Continue with:

[`character_animation_3d.md`](character_animation_3d.md)

That tutorial covers Mixamo/KayKit/Mesh2Motion-style assets, Godot retargeting,
AnimationTree locomotion, SkeletonModifier3D/IK, attachments, and ragdoll.

## 11. What stays game-specific

Keep game policy outside the generic motor for mechanics such as:

```text
swimming
climbing
vehicles
stamina sprint
ledge vaulting
lock-on movement
root-motion locomotion
special camera composition
```

## Validation

- WASD/left stick moves the character;
- movement rotates with camera orientation;
- mouse/right stick rotates the camera;
- pitch clamps correctly;
- SpringArm avoids walls;
- mouse releases for UI and captures again for gameplay;
- gamepad works without mouse capture;
- replacing `VisualRoot` does not change movement behavior.

## Related docs

- [`character_animation_3d.md`](character_animation_3d.md)
- [`platformer_2d.md`](platformer_2d.md)
- [`local_multiplayer.md`](local_multiplayer.md)
- [`../../components/gameplay_movement_camera.md`](../../components/gameplay_movement_camera.md)
