# Floating text and directional sprites in 2D

These optional scene-owned adapters use native Godot Labels, Tweens,
AnimatedSprite2D and SpriteFrames. They require no Autoload, game assets, combat
classes or 3D changes. Introduced in `0.34.0-dev.1`; existing APIs remain intact.

## Ownership and reuse

| Need | Native owner | Nucleus adapter | Consumer policy |
| --- | --- | --- | --- |
| Floating damage, healing, XP or notices | Label and Tween | FloatingTextPresenter2D and profile | Confirmed event, text, precision, styling |
| Four/eight direction sprites | AnimatedSprite2D and SpriteFrames | DirectionalSpriteAnimator2D and profile | Movement source, aim, action requests, terminal states |
| Target lifetime | SceneTree and signals | Existing TargetingAgent | Sensor registration and targeting policy |

The same text presenter supports combat numbers and non-combat collection
notices. The sprite adapter supports autonomous actors and player/NPC visuals;
neither depends on which controller supplies motion. These are adapters, not a
combat system, state machine, import pipeline or gameplay animation authority.

## Floating text

Add `NucleusFloatingTextPresenter2D` to the same world canvas as the positions
being presented. Assign a `NucleusFloatingTextProfile2D`. Use one presenter for
one independently bounded stream; it owns its Labels and native Tweens.

```gdscript
feedback.show_number(applied_damage, actor.global_position) # Zero decimals.
feedback.show_number(2.75, actor.global_position, 2)
feedback.show_text("+XP", pickup.global_position, experience_style)
```

- `show_number(value, world_position, decimals = 0, style = null) -> Label` uses
  Godot's `String.num`, accepts finite numbers and 0–6 decimal places. It does not
  change the supplied gameplay value. Trailing zeroes need not be displayed.
- `show_text(text, world_position, style = null) -> Label` accepts nonempty text.
  Pass already localized/formatted strings when needed. An optional style
  overrides the presenter's profile for this request.
- Rejected requests return null without evicting existing labels. Missing or
  invalid profiles, nonfinite positions and detached presenters reject.
- `maximum_visible` bounds this presenter alone (default 96). At capacity, the
  oldest label is hidden immediately and queued for deletion, with its Tween
  stopped. `get_visible_count()` reports active owned labels.
- `clear()` and tree exit stop Tweens and retire labels. External label deletion
  releases its entry too. A label can outlive its source actor because the
  presenter does not retain that actor.
- Font, size, colors, outline, duration, fade start, offset and travel belong to
  the Resource. No project font or global group is hardcoded. Runtime creation
  copies these values into the Label/Tween; shared profiles are not mutated.
- `reduced_motion` suppresses travel for new labels, preserving the fade. Wire
  it to the consuming game's accessibility settings. Presenter process mode and
  native scene pause determine timing; no independent wall clock is introduced.

Positions use world coordinates in the presenter's canvas. Labels are top-level
CanvasItems, so movement/scale of the presenter does not drag existing text.
Use a separate screen-space UI composition for HUD notifications or 3D projection.
Returned labels are short-lived: always check validity before retaining them.

For damage, connect `DamageReceiver.hit_received` and show the *applied* amount
only when positive. Immunity, critical/resisted styling and zero-value policy
belong to the consumer; the presenter intentionally accepts zero and negatives
for other uses. It never subscribes globally or applies damage.

## Directional sprites

Assign one `AnimatedSprite2D` and one `NucleusDirectionalSpriteProfile2D` to
`NucleusDirectionalSpriteAnimator2D`. Ready binds them automatically. For runtime
replacement, call `configure(sprite, profile) -> Error`. Invalid configuration
leaves the previous binding intact. Successful replacement resets presentation
silently to idle/right and snapshots the profile; call configure again after
editing a profile. Frames remain authored native resources; reconfigure after
replacing them. Do not mutate bound clips or assign another animation writer.

Profile clip names are explicit and need not follow any naming convention:

- `idle_clips` and `move_clips` contain matching arrays of four or eight names.
- Order is clockwise from right, in positive-Y-down canvas coordinates:
  right/down/left/up, or right/down-right/down/down-left/left/up-left/up/up-right.
- `action_clips` maps semantic StringName IDs to arrays of the same length.
- Locomotion clips must loop; actions must not loop. Every clip requires frames,
  non-null textures and finite positive FPS. There is no cell-size, pivot, art,
  frame-count or mandatory game-action contract.
- `start_speed > stop_speed >= 0` supplies locomotion hysteresis.
  `direction_hysteresis` adds a radian margin at sector boundaries.
- `get_validation_errors(frames)` reports configuration problems without mutation.

```gdscript
animator.update_motion(actual_velocity, aim_direction)
animator.play_action(&"interact")
# An explicit terminal pose, for any game-owned reason:
animator.play_action(&"collapse", true, true)
```

`update_motion(velocity, aim = Vector2.ZERO) -> Error` accepts finite vectors;
nonzero aim controls facing, otherwise velocity does. Zero motion preserves
facing. Supply vectors in the same canvas axes as the authored clips.

`play_action(action, interrupt = false, hold_last_frame = false) -> Error`:

- Unknown IDs reject; an active different action rejects with ERR_BUSY unless
  interruption is explicit. Repeating the same active action returns OK without
  rewinding it or changing its hold policy.
- Actions keep their starting direction to avoid cross-direction frame jumps.
  Motion/aim continues updating the direction used after completion.
- Native `animation_finished` resumes locomotion and emits `action_finished(id)`.
  A held terminal pose completes once but stays on its final frame until explicit
  interruption, `cancel_action()` or reconfiguration.
- `cancel_action()` resumes locomotion and emits `action_canceled(id)` for a
  still-running action. Explicit interruption also emits cancellation, not finish.
- `get_current_action()` is empty after completion, including a held pose.
- Tree exit disconnects signals; re-entry rebinds and resets presentation.
  A freed sprite causes update/play calls to return ERR_UNCONFIGURED.

Only this adapter selects clips on its bound sprite. Godot owns playback;
physics, attack resolution, health and cooldowns must not depend on its visual
completion signal. No CharacterBody transforms, sprite offsets or collision
shapes are changed.

## Validation

`target_lifecycle_test`, `floating_text_test` and `directional_sprite_test` cover
lifetime, invalid data, budgets, direction mapping and interruption boundaries.
`tests/smoke/presentation_2d_smoke.tscn` composes a real ValuePool/DamageReceiver,
targeting, synthetic native clips and floating text. It waits for actual Tween
and animation completion and checks rejection, overkill, held poses and cleanup.
The fixture uses generated tiny textures, not game content.

Run the standard CI plus that scene with the pinned Godot build. Headless
success does not establish typography, visual quality, camera legibility or
performance on a target device; review the consuming game's actual art and UI.
