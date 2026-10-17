# AI / Navigation Quickstart

## Choose 2D or 3D

- **2D enemies:** [AI Character 2D tutorial](tutorials/ai_character_2d.md)
  connects NavigationAgent2D, NavigationFollower2D, NavigationMotionSource2D,
  CharacterMotor2D, UtilityBrain, FSM and optional 2D facing.
- **3D enemies:** use the existing guide below.

Both dimensions reuse targeting, Utility AI and GameplayActions.
For encounter instance IDs and damage/reward bridges, see
[encounter composition](../components/rpg_composition.md).

## Recommended 3D composition

A reusable ground AI character can start as:

```text
Enemy : CharacterBody3D
├── CollisionShape3D
├── CharacterMotor3D
├── NavigationAgent3D
├── NavigationFollower3D
├── NavigationMotionSource3D
├── MovementFacing3D
├── TargetingAgent
├── UtilityBrain
├── StateMachine
│   ├── Idle
│   ├── Patrol
│   ├── Chase
│   ├── Attack
│   └── Flee
├── AIStateMachineBridge
├── AICharacterSetup3D
└── VisualRoot
    ├── imported rig
    ├── AnimationTree
    └── AnimationVelocity3D
```

The important rule is:

```text
AI chooses intent
Navigation chooses a path velocity
CharacterMotor3D owns physical movement
Animation reads the resulting body velocity
```

Do not create separate AI physics or animation controllers when the player and AI
share the same movement rules.

## 1. Build native navigation first

Create/bake a Godot `NavigationRegion3D`.

Configure `NavigationAgent3D` for the actor:

```text
radius / height
path_desired_distance
target_desired_distance
navigation_layers
avoidance only when actually needed
```

Nucleus does not replace navigation mesh authoring.

## 2. Keep CharacterMotor3D as locomotion authority

Configure the same motor you would use for a player:

```text
speed
ground_acceleration
ground_deceleration
air_acceleration
gravity
jump policy when applicable
```

AI does not write `CharacterBody3D.velocity` directly.

## 3. Add NavigationFollower3D

Configure:

```text
agent = NavigationAgent3D
origin = Enemy
target_repath_distance = 0.75
minimum_repath_interval = 0.20
```

The follower owns path/repath/avoidance intent.

## 4. Add NavigationMotionSource3D

Assign:

```text
follower = NavigationFollower3D
```

Then:

```text
CharacterMotor3D.motion_source
    = NavigationMotionSource3D
```

The complete movement path becomes:

```text
NavigationFollower.output_velocity
→ NavigationMotionSource3D
→ CharacterMotor3D
→ CharacterBody3D
```

The adapter synchronizes navigation max speed to:

```gdscript
motor.get_max_planar_speed()
```

The setup helper also schedules the follower before the motor by default so each
physics tick consumes freshly computed navigation intent rather than a
tree-order-dependent previous-frame value.

by default.

This means a motor speed multiplier, slow effect or other locomotion modifier
does not leave navigation steering at an obsolete speed.

## 5. Use AICharacterSetup3D to remove wiring work

Add:

```text
NucleusAICharacterSetup3D
```

Use Inspector actions:

```text
Auto Resolve AI Character
Wire Navigation Locomotion
Sync Locomotion Speeds
Print AI Character Report
```

The helper can create missing plumbing components according to its creation
toggles.

It does not create an authored NavigationAgent automatically because agent
radius, layers and avoidance policy are game/world-specific.

## 6. Manage goals from behavior states

Static destination:

```gdscript
follower.set_target_position(destination)
```

Moving target:

```gdscript
follower.follow_node(target)
```

Stop:

```gdscript
follower.clear_target()
```

A Chase state no longer needs to assign body velocity every physics frame.

Typical state:

```gdscript
func enter(
	_previous: NucleusState,
	context: Dictionary,
) -> void:
	var target_point: Node = context.get(&"target_point")

	if target_point is Node3D:
		follower.follow_node(target_point as Node3D)


func exit(_next: NucleusState) -> void:
	follower.clear_target()
```

The shared motor keeps moving between AI decision ticks.

## 7. Reuse targeting as perception

Use the existing targeting pipeline:

```text
sensors
→ filters
→ scorers
→ TargetingAgent.current
```

`NucleusAITargetContextProvider` can expose target information to Utility AI.

## 8. Utility AI decides intention

Create `NucleusAIUtilityOption` resources such as:

```text
idle
patrol
chase
attack
flee
```

Use normalized considerations for target presence, distance, health, resources or
game-specific context.

Utility AI should not call:

```text
body.move_and_slide()
AnimationTree.travel()
```

directly.

## 9. Use the existing Utility → State bridge

Map options through:

```text
NucleusAIStateBinding
NucleusAIStateMachineBridge
```

Example:

```text
patrol → Patrol
chase  → Chase
attack → Attack
flee   → Flee
```

The FSM remains authoritative for whether a transition is valid.

## 10. Reuse GameplayActions

If player and AI attacks follow the same rules, both should call the same
`NucleusGameplayAction`.

```text
player input ─┐
              ├→ Attack GameplayAction
AI state ─────┘
```

Requirements, cooldown, cost and effects remain identical.

## 11. Facing policy

For normal movement:

```text
MovementFacing3D.mode = MOVEMENT
```

For lock-on/strafe combat:

```gdscript
facing.set_facing_target(target_point)
```

Now AI may move sideways while continuing to face its opponent.

The directional AnimationTree reads local body velocity and naturally resolves
forward/back/strafe clips.

## 12. Animation requires no AI-specific controller

Use the same:

```text
NucleusAnimationVelocityBinding3D
AnimationTree
OneShotController
AnimationQualityController3D
```

as any other character.

Animation sees the physical result:

```text
CharacterBody3D.velocity
```

not the source that produced it.

## 13. Jump and traversal

Programmatic behavior can call:

```gdscript
motor.request_jump()
```

without manufacturing an input event.

Navigation links remain game-semantic:

```text
jump
vault
door
ladder
teleport
elevator
```

Listen to `navigation_link_reached` and dispatch the appropriate state/action.
Nucleus does not guess link semantics.

## 14. Avoidance

When native avoidance is enabled, `NavigationMotionSource3D` consumes the
follower's safe `output_velocity`.

Avoidance has a runtime cost. Enable it only for agents that need local collision
avoidance and profile large crowds.

## 15. Scheduling and performance

A useful separation is:

```text
UtilityBrain
    2–5 Hz for many ordinary NPCs

target/perception refresh
    game-dependent, often staggered

path repath
    movement threshold + interval

navigation steering
    physics

CharacterMotor3D
    physics

animation
    Full / Reduced / Minimal presentation policy
```

The brain can think more slowly without making locomotion physically choppy.

For many actors, assign `NucleusUpdateScheduler` to UtilityBrain so evaluations
do not align on the same frame.

## 16. Validate the character

`Print AI Character Report` checks common wiring mistakes:

```text
motor not using navigation source
follower using wrong NavigationAgent
wrong follower origin
navigation/motor speed mismatch
facing wired to another motor
animation velocity reading another body
UtilityBrain/StateMachine without bridge
bridge without authored bindings
```

It also reports performance notes such as active RVO or an unstaggered
interval-driven UtilityBrain.

## 17. Persistence and multiplayer

Persist durable AI state, not native path internals.

After load:

```text
durable gameplay state restored
→ UtilityBrain evaluates
→ behavior state chooses goal
→ navigation path rebuilt
```

For multiplayer, authoritative AI normally runs on the server/host and clients
receive the game-specific replicated state.
