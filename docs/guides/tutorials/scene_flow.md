# Tutorial: production-style Scene Flow with transitions and recovery

This tutorial upgrades a direct menu-to-world scene change into a reusable flow
that can:

- load in the background;
- keep the current scene alive until the destination is loadable and instantiable;
- cover the screen with fade, curtain, flash, or shader transitions;
- report detailed failure stages;
- recover if a switch loses the current scene;
- return to the previous file-backed scene after a game-owned initialization
  failure.

The visual style remains project policy. Scene Flow only provides reusable
sequencing.

## 1. Create two scenes

For example:

```text
res://game/menu.tscn
res://game/world.tscn
```

Use your normal game scenes. They do not need to inherit from a Nucleus base
class.

## 2. Start with a fade profile

Create a Resource in your game, for example:

```text
res://game/presentation/transitions/default_fade.tres
```

Use `NucleusSceneTransitionProfile` and configure:

```text
mode = FADE
color = black
cover_duration = 0.25
reveal_duration = 0.25
covered_hold_seconds = 0.0
presentation_timeout_seconds = 8.0
block_input = true
```

In a menu controller:

```gdscript
@export var world_scene: String = "res://game/world.tscn"
@export var transition: NucleusSceneTransitionProfile


func _on_play_pressed() -> void:
    var error := NucleusSceneFlow.change_scene(
        world_scene,
        true,
        false,
        transition,
    )

    if error != OK:
        push_error(error_string(error))
```

The return value answers whether the request was admitted and whether any
synchronous preparation failed immediately. A threaded load can still fail later
through the transition signals.

## 3. Understand the new order of operations

The important sequence is:

```text
request accepted
    ↓
start loading target
    +
start covering outgoing scene
    ↓
PackedScene loaded
    ↓
PackedScene.can_instantiate()
    ↓
PackedScene.instantiate() while old scene is still current
    ↓
wait until transition reports covered
    ↓
SceneTree.change_scene_to_node(prepared_node)
    ↓
scene_changed
    ↓
transition_completed
    ↓
reveal new scene
    ↓
transition_finished / idle
```

The preflight instance is important. `SceneTree` only receives a Node that was
already successfully created from the destination resource.

## 4. Try a curtain

You can create another `.tres` or construct a temporary profile:

```gdscript
var curtain := NucleusSceneTransitionProfile.curtain(
    Color("101522"),
    0.35,
    NucleusSceneTransitionProfile.CurtainAxis.HORIZONTAL,
)

NucleusSceneFlow.change_scene(
    "res://game/world.tscn",
    true,
    false,
    curtain,
)
```

Vertical curtains use:

```text
CurtainAxis.VERTICAL
```

The built-in curtain is intentionally simple. A game that wants branded panels,
logos, sound, or authored timing should use a custom overlay scene later in this
tutorial.

## 5. Use flash for short cuts

A white flash is useful for respawn, teleport-like presentation, or abrupt scene
cuts where a full fade feels too slow:

```gdscript
var flash := NucleusSceneTransitionProfile.flash()
NucleusSceneFlow.change_scene(
    "res://game/arena.tscn",
    true,
    false,
    flash,
)
```

This is still a normal scene change. The flash does not own teleport/gameplay
logic.

## 6. Use the built-in tile shader

Create a profile with:

```gdscript
var tiled := NucleusSceneTransitionProfile.tiled(
    Color("0b0e18"),
    0.45,
)
```

The default parameters are available through:

```text
shader_parameters
    tile_count
    softness
    seed
```

Example:

```gdscript
tiled.shader_parameters[&"tile_count"] = Vector2(24.0, 14.0)
tiled.shader_parameters[&"softness"] = 0.04
tiled.shader_parameters[&"seed"] = 8.0
```

The example shader lives at:

```text
res://addons/nucleus/core/scene_flow/scene_transition_tiles.gdshader
```

Treat it as a reference implementation. Duplicate it into game-owned presentation
assets before turning it into a project-specific visual identity.

## 7. Drive your own shader

A custom transition shader only needs a progress uniform:

```glsl
shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 transition_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
    float alpha = step(UV.x, progress);
    COLOR = vec4(transition_color.rgb, transition_color.a * alpha);
}
```

On the profile:

```text
mode = SHADER
shader = your shader
shader_progress_parameter = progress
```

Additional uniforms go in `shader_parameters`.

Nucleus does not inspect or generate the effect. It animates progress from
`0 -> 1` to cover and `1 -> 0` to reveal.

## 8. Build an authored custom overlay

For a transition that needs an `AnimationPlayer`, multiple Controls, audio, or
more complex timing, create a scene like:

```text
BrandedTransition : NucleusSceneTransitionOverlay
├── Control
├── AnimationPlayer
└── ...
```

Attach a subclass:

```gdscript
class_name GameBrandedTransition
extends NucleusSceneTransitionOverlay

@onready var animation_player: AnimationPlayer = %AnimationPlayer


func begin_cover() -> Error:
    animation_player.play(&"cover")
    animation_player.animation_finished.connect(
        _on_cover_finished,
        CONNECT_ONE_SHOT,
    )
    return OK


func begin_reveal() -> Error:
    animation_player.play(&"reveal")
    animation_player.animation_finished.connect(
        _on_reveal_finished,
        CONNECT_ONE_SHOT,
    )
    return OK


func _on_cover_finished(_animation: StringName) -> void:
    covered.emit()


func _on_reveal_finished(_animation: StringName) -> void:
    revealed.emit()
```

Assign the PackedScene to:

```text
profile.overlay_scene
```

The scene root must derive from `NucleusSceneTransitionOverlay`.

The transition scene is temporarily parented under the root viewport, so it
survives the replacement of the outgoing current scene.

## 9. Observe transition completion correctly

There are two useful completion moments.

When the destination becomes the current scene:

```text
transition_completed
```

When reveal presentation has also finished and Scene Flow is idle:

```text
transition_finished
```

Use `transition_completed` for logic that needs the new scene reference.

Use `transition_finished` for UI/input that should wait until the whole visual
transition is over.

## 10. Test missing files

Try:

```gdscript
var error := NucleusSceneFlow.change_scene(
    "res://game/does_not_exist.tscn"
)
```

Expected result:

```text
ERR_FILE_NOT_FOUND
current scene remains active
no switch occurs
```

This is an admission failure, so there is no need to roll back.

## 11. Test a wrong resource type

Point the request at an existing non-scene Resource.

The request is rejected by the PackedScene existence/type check or fails during
load/preflight. The current scene remains active.

## 12. Test a broken scene

Temporarily break a copy of a `.tscn` so Godot cannot load it, or give it a
missing dependency that aborts resource loading.

For a background request, connect:

```gdscript
NucleusSceneFlow.transition_failed_detailed.connect(
    _on_scene_flow_failed
)


func _on_scene_flow_failed(details: Dictionary) -> void:
    push_error(
        "%s: %s" % [
            details.get("stage_name", "unknown"),
            details.get("error_name", "unknown"),
        ]
    )
```

The outgoing scene should remain current and any active cover transition should
reveal it again.

## 13. Configure a safe fallback

A switch-level failure is rarer because the target was pre-instantiated, but a
public game should still have a safe route.

```gdscript
NucleusSceneFlow.change_scene(
    "res://game/world.tscn",
    true,
    false,
    transition,
    "res://game/menu.tscn",
)
```

If the current scene is lost during switching and the switch does not complete,
Scene Flow attempts to recreate the fallback.

When `fallback_scene_path` is omitted, it uses the previous file-backed scene.

Observe:

```text
rollback_started
rollback_completed
rollback_failed
```

A rollback reloads a resource. It does not serialize the outgoing runtime object
graph before switching.

## 14. Handle a game-owned initialization failure

Suppose `world.tscn` loads correctly, but after `_ready()` the game discovers
that a required save slot, backend session, level manifest, or game-specific
asset is invalid.

That is not a `PackedScene` load failure. The destination scene itself must own
that decision.

Example:

```gdscript
func _ready() -> void:
    var error := _initialize_session()
    if error == OK:
        return

    push_error("World initialization failed: %s" % error_string(error))
    NucleusSceneFlow.return_to_previous_scene()
```

For a product with a known safe menu/error scene, routing there explicitly may be
better than returning to the previous scene.

## 15. Know what rollback cannot promise

Scene Flow can recover file-backed navigation. It cannot generically restore:

```text
unsaved inventory changes
runtime-spawned nodes
network session state
open transactions
random generator state
game-specific temporary state
```

Persist or checkpoint those through the systems that own them before requesting
a transition when the game requires that guarantee.

## 16. Set a project default without losing control

A persistent application bootstrap may assign:

```gdscript
NucleusSceneFlow.default_transition_profile = default_transition
```

Normal calls then use that profile automatically.

For a cut that must remain direct:

```gdscript
NucleusSceneFlow.change_scene_direct(
    "res://game/bootstrap.tscn"
)
```

The game still chooses where transitions are appropriate.

## Validation checklist

Verify all of these before relying on Scene Flow in production:

- direct transition with no profile;
- fade, curtain, flash, and tile shader;
- custom transition scene;
- repeated request returns `ERR_BUSY`;
- missing target leaves current scene alive;
- malformed target emits detailed failure and reveals the old scene;
- long threaded load keeps progress signals working;
- transition overlay blocks input only when configured;
- `transition_completed` occurs before reveal completion;
- `transition_finished` occurs after reveal completion;
- reload current scene uses the same path;
- game-owned initialization can explicitly return to the previous scene;
- fallback/rollback signals are handled by fatal-error UX where appropriate.

## Related docs

- [`../scene_flow_quickstart.md`](../scene_flow_quickstart.md)
- [`core_services.md`](core_services.md)
- [`../../components/audio_save_scene_localization.md`](../../components/audio_save_scene_localization.md)
