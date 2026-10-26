# Optional AI / Navigation Module

`modules/ai` is optional and scene-owned. It separates **decision**, **behavior**,
**navigation intent**, **physical locomotion**, and **presentation**.

## Ownership

```text
TargetingAgent
    perception / selected target
        ↓
UtilityBrain
    choose intention
        ↓
AIStateMachineBridge
        ↓
StateMachine / game behavior
        ↓
NavigationFollower
    path / avoidance velocity
        ↓
NavigationMotionSource3D
        ↓
CharacterMotor3D
    acceleration / gravity / collision
        ↓
CharacterBody3D.velocity
        ↓
animation / facing presentation
```

The module does not provide an Enemy base class, global AI manager, duplicate
physics motor, Behavior Tree/GOAP framework, or replacement NavigationServer.

## 2D and 3D AI character parity

Use `NucleusAICharacterSetup2D` for a CharacterBody2D and
`NucleusAICharacterSetup3D` for CharacterBody3D. Both reuse the
dimension-neutral UtilityBrain, AIStateMachineBridge, TargetingAgent
and GameplayAction rather than creating an enemy-specific controller.

The 2D helper resolves or creates CharacterMotor2D, NavigationFollower2D
and NavigationMotionSource2D, can wire the state bridge, and checks
physics-process priority and effective movement speed. Optional
`NucleusMovementFacing2D` rotates only the visual pivot.
See the [complete 2D walkthrough](../guides/tutorials/ai_character_2d.md).

Top-down movement generally uses FLOATING; platformers use GROUNDED
and need game-authored jump/link semantics. Both rely on native
NavigationServer2D and collision geometry.

## Shared locomotion

`NucleusNavigationMotionSource3D` is the standard adapter for ground AI using
`NucleusCharacterMotor3D`.

It consumes the follower's resolved `output_velocity`, including native
avoidance output when avoidance is enabled.

`CharacterMotor3D` stays responsible for:

```text
acceleration / deceleration
speed multipliers
gravity
jump
move_and_slide()
ground transitions
```

This means player and AI actors can share identical locomotion tuning.

By default the navigation source synchronizes:

```text
NavigationFollower3D.movement_speed
NavigationAgent3D.max_speed
```

The 3D setup assistant also places `NavigationFollower3D` one physics priority
before `CharacterMotor3D` by default, preventing a tree-order-dependent frame of
intent latency. Disable that policy only when the project owns process order
explicitly.

Both 2D and 3D motion adapters synchronize intent to their motor's
current effective maximum speed.

Disable that synchronization only when the project intentionally needs navigation
intent capped differently from physical locomotion.

## Utility AI

`NucleusAIUtilityBrain` evaluates `NucleusAIUtilityOption` resources. Scores are
base score multiplied by normalized considerations. Explicit priority breaks
equal scores, then authored array order is deterministic.

`current_option_bonus` provides small hysteresis around close decisions.

Context providers contribute side-effect-free ephemeral values and may notify the
brain when an event warrants reevaluation.

The brain chooses intent. It does not move, attack, animate, or transition states
directly.

## Utility → gameplay state

Existing:

```text
NucleusAIStateBinding
NucleusAIStateMachineBridge
```

map a winning utility option to an existing `NucleusStateMachine` state.

Do not duplicate this with an AI-specific animation controller.

A state such as Chase normally owns only goal policy:

```text
enter
    follower.follow_node(target)

exit
    follower.clear_target()
```

The shared locomotion chain moves the actor continuously.

## Actions

AI and players should reuse the same `NucleusGameplayAction` where their gameplay
rules are the same.

For example:

```text
player input ───────┐
                    ├→ Attack GameplayAction
AI Attack state ────┘
```

The action can own requirements, costs, cooldown and effects. Animation remains a
presentation effect/OneShot rather than the authority deciding whether the
attack is valid.

## Navigation followers

`NucleusNavigationFollower2D/3D` own target/repath throttling,
`get_next_path_position()`, desired velocity and optional native RVO velocity
handoff.

They do not call `move_and_slide()`.

Moving targets require both displacement and minimum-time thresholds before a new
path target is requested.

Avoidance is opt-in because it has meaningful runtime cost with many agents.

## Facing and strafing

Use the shared `NucleusMovementFacing3D`:

```text
MOVEMENT
    patrol / normal chase

TARGET
    combat strafe while keeping attention on target

DIRECTION
    scripted or tactical facing
```

Directional `AnimationTree` locomotion then reads actual local body velocity, so
left/right/backward strafe clips work without the AI selecting clips.

## Animation

AI does not need a separate animation controller.

```text
Navigation
→ shared CharacterMotor3D
→ CharacterBody3D.velocity
→ NucleusAnimationVelocityBinding3D
→ same AnimationTree used by a player
```

High-level gameplay state may still feed `NucleusAnimationTreeStateBinding`, and
GameplayActions may trigger OneShots.

## AI character setup assistant

`NucleusAICharacterSetup3D` is an editor-oriented wiring/diagnostic helper.

It can resolve and wire:

```text
CharacterBody3D
CharacterMotor3D
NavigationAgent3D
NavigationFollower3D
NavigationMotionSource3D
UtilityBrain
StateMachine
AIStateMachineBridge
TargetingAgent
MovementFacing3D
AnimationVelocityBinding3D
```

It may create plumbing components such as motor/follower/motion source/bridge
when explicitly requested.

It does **not** invent:

```text
utility options
state semantics
attack behavior
targeting rules
navigation mesh
state bindings
animation clips
```

Those remain game-owned.

## Scheduled evaluation

Automatic Utility AI may bind to `NucleusUpdateScheduler`.

A useful large-crowd cadence is conceptually:

```text
utility decisions       low frequency / staggered
target/perception       project-dependent cadence
path repath              displacement + interval throttled
navigation steering      physics
CharacterMotor3D         physics
animation pose           quality-dependent presentation cadence
```

Do not reduce the physical motor to a low-frequency AI tick.

## Persistence / networking

Persist durable actor state and reconstruct native path internals after load.

For authoritative multiplayer, run decision/navigation/gameplay movement on the
authority and replicate resolved gameplay state. This module defines no RPC
protocol.

## Scheduled path requests and bounded separation

Both navigation followers accept a scene-owned `update_scheduler` assigned before
tree entry. This schedules permission for target path requests while native path
following and the character motor remain fixed-step. `CrowdMotionSource2D` exposes
opt-in `maximum_candidates` (0 preserves exact legacy selection). See
[the workload contract](../components/runtime_optimization.md#physics-workload-integration-037)
for defaults, latency, lifecycle and approximation limits.
