# Tutorial: one 2D locomotion stack for players and AI

This is the 2D companion to [AI character 3D](ai_character_3d.md).
Use it for top-down, tactical or side-view characters while retaining native
Godot physics and game-owned behavior.

## Build the character

```text
Enemy (CharacterBody2D)
├── CollisionShape2D
├── CharacterMotor2D
├── NavigationAgent2D
├── NavigationFollower2D
├── NavigationMotionSource2D
├── TargetingAgent
├── UtilityBrain
├── StateMachine
├── AIStateMachineBridge
├── AICharacterSetup2D
└── VisualPivot (Node2D)
    └── AnimatedSprite2D / Sprite2D / AnimationTree visuals
```

Give the actor valid Godot 2D navigation data and set the
`NavigationAgent2D` layers/radius according to the game. Add the
`NucleusAICharacterSetup2D` to the actor; assign the agent and use the
Inspector commands **Auto Resolve 2D AI Character** followed by
**Wire 2D Navigation Locomotion**. The latter may create motor, follower,
motion source and optional state bridge, but does not create authored
navigation polygons, AI decisions or attacks.

For a top-down actor set `CharacterBody2D.motion_mode = FLOATING`.
For platformers, use the native GROUNDED mode. Its motor projects navigation
intent to the floor tangent: a conventional 2D navmesh does not provide
jump/link traversal logic. Author platform transitions as game states or
actions using appropriate native navigation links.

## Shared movement path

```text
Target sensors 2D → TargetingAgent → AITargetContextProvider
                                        ↓
UtilityBrain → AIStateMachineBridge → StateMachine
                                        ↓
                            NavigationFollower2D
                                        ↓
                           NavigationMotionSource2D
                                        ↓
                              CharacterMotor2D
                                        ↓
                              CharacterBody2D
                                        ↓
                           visuals and animation
```

An AI Chase state should call `follower.follow_node(target_point)`; when
exiting, call `follower.clear_target()`. Do not directly write velocity
from UtilityBrain or the state machine.

The motion adapter synchronizes the follower and native agent to
`motor.get_max_speed()`. The setup helper also ensures the follower
evaluates before the motor by default; speed multipliers remain effective.

For visual facing, add `NucleusMovementFacing2D`, assign a Node2D pivot,
and choose movement, target or explicit direction. The pivot assumes +X
as its front; use `front_angle_offset` for sprites facing up/down.
It does not change the body's collision rotation. You may instead control
flip_h and directional SpriteFrames entirely in game code.

The optional `NucleusAnimationVelocityBinding2D` reads physical velocity
for AnimationTree blending, regardless of human or AI input.

## Combat and encounters

An enemy action may use `NucleusApplyDamageEffect`, status effects,
cooldowns or `NucleusTurnRequirement`. The target comes from the existing
TargetingAgent/context provider; the game owns target selection and when to
commit the action. In an encounter, assign a unique instance ID via
`NucleusEncounterDirector.register_instance()` and connect
`NucleusEncounterCombatant.defeated` to authoritative encounter accounting.
Do not count defeat twice with both aggregate and instance APIs.

For pooled enemies, reset the encounter combatant after reacquisition,
refresh targeting candidates, and clear the follower goal on release.

## Diagnostics and validation

Use **Print 2D AI Character Report** to inspect missing links, speed
mismatches, scheduling, state bridge mappings and optional performance notes.
The helper does not require combat modules or add Autoloads.

Run `tests/headless/ai_character_2d_test.gd` through the registered
`tests/headless/test_runner.tscn`. The test verifies setup, speed parity,
processing order and visual facing. Validate real navigation meshes,
collisions, enemy behavior and rendering inside the consuming game.
