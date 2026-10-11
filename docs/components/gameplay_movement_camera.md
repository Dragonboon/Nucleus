# Movement, Control, and Camera Contract

## Scope

```text
components/gameplay/control
components/gameplay/movement
components/gameplay/camera
```

Game-facing movement and camera behavior is scene-owned and split into small
adapters around Godot-native character/camera nodes.

## One motor, several intent producers

`NucleusCharacterMotor3D` remains the physical movement owner for a normal
`CharacterBody3D`.

It can receive planar intent from either:

```text
NucleusMotionInput
    player / local-seat semantic input

NucleusPlanarMotionSource3D
    AI / autopilot / replay / cutscene / proxy intent
```

When an enabled `motion_source` is assigned it has priority for planar movement.
If that source is disabled, the motor falls back to `motion_input` when present.

This lets different controllers reuse the same:

```text
acceleration / deceleration
gravity
jump implementation
CharacterBody3D velocity
move_and_slide()
ground transitions
animation velocity source
```

Do not create a separate AI motor when only the producer of movement intent
changes.

## Motion-source contract

A `NucleusPlanarMotionSource3D` returns desired **world-space planar velocity**.

Velocity is used instead of direction alone so a source can request:

```text
stop
slow approach
40% gait
full-speed chase
avoidance-corrected velocity
```

`CharacterMotor3D` clamps the request to:

```text
speed * speed_multiplier
```

and exposes that limit through:

```gdscript
motor.get_max_planar_speed()
```

Vertical movement remains owned by the motor/gameplay unless a distinct movement
model is intentionally introduced.

## Navigation integration

The AI module provides:

```text
NucleusNavigationMotionSource3D
```

which adapts `NucleusNavigationFollower3D.output_velocity` into the common motor.

The flow is:

```text
NavigationAgent3D
        ↓
NavigationFollower3D
    path / avoidance intent
        ↓
NavigationMotionSource3D
        ↓
CharacterMotor3D
        ↓
CharacterBody3D
```

The adapter can synchronize follower/native-agent maximum speed to the motor's
effective maximum so status effects or speed multipliers do not leave path
steering and physical locomotion using different limits.

## Input versus movement

`NucleusMotionInput` translates semantic Nucleus/Godot input into player movement
intent.

Keep input collection separate from physical motion so AI, replay, local
multiplayer, scripted movement, or networking can provide intent without
rewriting locomotion.

Programmatic systems can still call:

```gdscript
motor.request_jump()
```

rather than manufacturing fake input events.

Jump press/release callbacks queue intent; the motor consumes it in its physics
tick. A press and release between two ticks still produces a short jump. A
release queued during jump buffering is retained until consumption or expiry.
Disabling the motor discards pending jump input, and disabled motors ignore
release events. Re-enabling does not replay a stale jump.

Planar input preserves analog magnitude and clamps diagonals. At a vertical
camera angle, the camera's projected right axis preserves heading instead of
falling back immediately to world Z. Use a stable camera/heading pivot as
`orientation_source`; rotating the gameplay root to face its own relative
movement can otherwise create feedback.

## Godot-native motion

`CharacterBody2D`, `CharacterBody3D`, their `velocity`, and `move_and_slide()`
remain the physical source of truth.

Nucleus does not maintain a second motion simulation.

## Facing

`NucleusMovementFacing3D` rotates a dedicated visual pivot and supports:

```text
MOVEMENT
    face CharacterMotor3D desired movement

TARGET
    keep looking at a moving Node3D target

DIRECTION
    face an explicit world-space direction
```

`MOVEMENT` preserves the original behavior and costs no extra polling beyond the
motor movement signal.

`TARGET` and `DIRECTION` update during physics processing because facing may need
to change while the actor is stationary.

This supports both player lock-on and AI combat strafing without adding a
separate AI-facing implementation.

## Cameras

Camera helpers compose follow/look/FOV behavior around native camera nodes and
scene pivots.

Game-feel feedback is a presentation layer on top of the camera, not part of
movement physics. Stackable source-owned feedback supports impulses,
recoil/kick/shake, head bob, landing feedback, and temporary FOV offsets.

See `camera_game_feel.md` for the feedback contract.

## Animation integration

Velocity adapters project **actual `CharacterBody` motion** into `AnimationTree`
parameters.

This is intentionally controller-agnostic:

```text
player input ─┐
AI navigation ├→ same motor → same body velocity → same AnimationTree
autopilot  ───┘
```

Movement components do not select clips directly.

A production 3D model remains a presentation child of the stable
`CharacterBody3D` gameplay root. See `animation_integration.md`.

For a physical regression scene, run:

```bash
godot --headless --path . res://tests/smoke/locomotion_3d_smoke.tscn
```

This checks contact transitions, short/held jumps, release timing, acceleration
and braking over real physics frames. It does not validate animation quality,
stairs, water transitions, moving boats or network latency.

## Multiplayer

Local-player ownership belongs to the input layer.

For authoritative AI, run decision/navigation/movement on the authority and
replicate the gameplay state/results required by the game. Do not make visual
animation the network authority.

On a remote snapshot-driven actor, disable the motor and local motion input:
the replicator and motor must not both write the actor transform. A motion
source is an intent adapter, not client prediction or reconciliation. A future
dedicated server must be able to run collision/movement without a camera,
AnimationTree or IK rig. See `../modules/online_replication.md`.

## Extension rule

Add a movement model only when its physics policy differs materially.

Add a motion-source/controller adapter when only the source of desired movement
changes.
