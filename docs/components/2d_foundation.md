# 2D gameplay integration: reusable ownership contract

Reference engine: Godot **4.7.2-stable**.

Nucleus is a project foundation, not a platformer/top-down engine. The same
`NucleusCharacterMotor2D` handles movement for a `CharacterBody2D`; genre choices
are native Godot configuration and game-authored mechanics.

## One physical owner

```text
CharacterBody2D
├── CollisionShape2D            Godot collision and motion_mode
├── MotionInput                 optional input producer
├── CharacterMotor2D            owns velocity integration + move_and_slide()
├── Visuals                     Sprite2D / AnimatedSprite2D / AnimationTree
├── AnimationVelocityBinding2D  optional: observes physical motion
└── Nucleus game components     actions, health, interactions, targeting...
```

The motor has no sprite, animation names, gameplay state, AI mode, or terrain
dependency. It reads desired world-space velocity from an optional
`NucleusMotionSource2D`, or semantic `NucleusMotionInput` as fallback.

The consuming game configures the native body:

- `MOTION_MODE_GROUNDED`: tangent-axis intent, preserved up-axis velocity,
  gravity while airborne. Use for floor/ceiling gameplay with authored jumps.
- `MOTION_MODE_FLOATING`: full XY intent, without implicit gravity. Use when
  directional movement and wall collision matter more than floor detection.

These are **Godot physics choices**, not separate Nucleus character classes.
Grounded source velocity is projected onto the tangent before clamping to
`get_max_speed()`. For example, a request `(400, 400)` with up `(0, -1)` and
maximum speed `120` becomes `(120, 0)`, while an analog request `(30, 400)`
becomes `(30, 0)`. Vertical intent neither moves the actor nor reduces its
tangent speed; use `request_velocity_impulse()` for a game-authorized jump.
Floating mode still clamps the complete XY vector.

The game owns jumping, dashes, acceleration curves beyond the motor baseline,
combat animation policy, knockback validation, sprite flip and art.

## AI / replay / network / cutscenes

`NucleusMotionSource2D` is the single optional world-velocity contract.
`NucleusNavigationMotionSource2D` converts the existing navigation follower's
output into that contract. No separate AI motor or AI scene generator is needed.

```text
AI / input / replay → NucleusMotionSource2D or NucleusMotionInput
                               ↓
                       CharacterMotor2D
                               ↓
                         CharacterBody2D
                               ↓
                    AnimationVelocityBinding2D
```

Godot `NavigationAgent2D` and `NucleusNavigationFollower2D` own path/avoidance
intent, not the physical body. Order follower processing before motor processing
when using continuously updated navigation output.

## Native animation ownership

Use Godot `AnimatedSprite2D`, `SpriteFrames`, `AnimationPlayer`, `AnimationTree`
and the existing Nucleus animation state/velocity bindings. Nucleus does not
invent a genre-specific sprite animation state machine, imported frame database,
or animation authoring workflow. The game maps semantic gameplay state to clips.

## Compatibility with earlier motors

`NucleusPlatformerMotor2D` and `NucleusTopDownMotor2D` existed in the Nucleus
baseline before this feature. They remain available for previously authored
scenes; **new integrations should prefer `NucleusCharacterMotor2D`**. This
change does not silently remove public scripts or change their serialized scene
properties. The experimental sprite/setup and genre-specific demo files from
the previous 2D Foundation overlay are no longer part of the recommended API.

## Tutorials

- [`../guides/tutorials/2d_foundation.md`](../guides/tutorials/2d_foundation.md)
- [`../guides/tutorials/platformer_2d.md`](../guides/tutorials/platformer_2d.md)
- [`../guides/tutorials/top_down_2d.md`](../guides/tutorials/top_down_2d.md)

## Verification

`tests/headless/gameplay_2d_foundation_test.gd` checks the two native physics
modes, source lifecycle, impulse validation, and navigation adapter. Gameplay
projects must still validate collisions, animation transitions and gameplay
states with their own representative level scenes.
