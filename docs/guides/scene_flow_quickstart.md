# Scene Flow Quickstart

Use `NucleusSceneFlow` when scene replacement needs one shared contract for
loading, transitions, progress, failure handling, and recovery.

Hands-on tutorial:

[`tutorials/scene_flow.md`](tutorials/scene_flow.md)

## Basic change

```gdscript
const WORLD_SCENE := "res://game/world.tscn"


func start_game() -> void:
    if NucleusSceneFlow.is_busy():
        return

    var error := NucleusSceneFlow.change_scene(WORLD_SCENE)
    if error != OK:
        push_error(error_string(error))
```

Immediate request errors include invalid/missing paths and `ERR_BUSY`.
Background-load failures are reported through Scene Flow signals.

## Add a visual transition

A project can keep a reusable profile as a `.tres` Resource or create one in
code.

```gdscript
var fade := NucleusSceneTransitionProfile.fade(
    Color.BLACK,
    0.25,
)

NucleusSceneFlow.change_scene(
    WORLD_SCENE,
    true,
    false,
    fade,
)
```

Built-in profiles can describe:

```text
fade
curtain
flash
tiled/custom shader
```

Useful constructors:

```gdscript
NucleusSceneTransitionProfile.fade()
NucleusSceneTransitionProfile.curtain()
NucleusSceneTransitionProfile.flash()
NucleusSceneTransitionProfile.tiled()
```

For a project-wide default:

```gdscript
NucleusSceneFlow.default_transition_profile = transition_profile
```

Use `change_scene_direct()` when a particular change intentionally bypasses that
default.

## Custom shader transition

Set a profile to `SHADER`, assign a `canvas_item` `Shader`, and expose a float
uniform such as:

```glsl
uniform float progress : hint_range(0.0, 1.0) = 0.0;
```

Then set:

```text
shader_progress_parameter = progress
```

Nucleus animates only that progress value. The shader owns the visual design.
Additional uniforms can be supplied through `shader_parameters`.

A tile dissolve example ships at:

```text
res://addons/nucleus/core/scene_flow/scene_transition_tiles.gdshader
```

## Custom transition scene

When a shader is not enough, create a scene whose root derives from:

```text
NucleusSceneTransitionOverlay
```

Override:

```text
begin_cover()
begin_reveal()
```

and emit:

```text
covered
revealed
```

Assign that PackedScene to `profile.overlay_scene`.

This supports authored `AnimationPlayer` transitions without putting visual
policy in the Scene Flow service.

## Observe lifecycle

Core signals remain:

```text
transition_started
load_progress
transition_completed
transition_failed
busy_changed
```

Additional signals distinguish presentation and recovery:

```text
transition_finished
transition_failed_detailed
transition_visual_failed
rollback_started
rollback_completed
rollback_failed
```

`transition_completed` means the new scene is current.

`transition_finished` means the optional reveal has also completed and Scene Flow
is idle again.

## Why invalid scenes do not destroy the current scene

Scene Flow preflights the target before switching:

```text
ResourceLoader
    -> PackedScene type check
    -> can_instantiate()
    -> instantiate()
    -> only then SceneTree.change_scene_to_node()
```

A missing, corrupt, wrong-type, or non-instantiable target therefore fails while
the outgoing scene is still current.

## Detailed failure information

```gdscript
func _on_transition_failed(details: Dictionary) -> void:
    print(details.get("stage_name"))
    print(details.get("error_name"))
    print(details.get("scene_path"))
```

Connect that function to:

```text
transition_failed_detailed
```

You can also inspect the most recent failure with:

```gdscript
NucleusSceneFlow.get_last_failure()
```

## Fallback and rollback

For a transition that has a known safe destination:

```gdscript
NucleusSceneFlow.change_scene(
    "res://game/world.tscn",
    true,
    false,
    fade,
    "res://game/menu.tscn",
)
```

The fallback is only needed for a post-switch failure where the old scene is no
longer current. Ordinary load/preflight failures never remove the old scene.

If game-specific initialization fails after the new scene is already running:

```gdscript
NucleusSceneFlow.return_to_previous_scene(fade)
```

This reloads the previous scene resource. It cannot restore unsaved runtime-only
state from the former instance.

## Reload current scene

```gdscript
NucleusSceneFlow.reload_current_scene(fade)
```

This now uses the same load/preflight/transition path as a normal scene change.

## Common mistakes

Avoid:

- placing critical persistent state inside the transition overlay;
- treating a visual reveal error as a failed gameplay-scene load;
- expecting rollback to reconstruct runtime state that was never saved;
- using one global transition style when different flows need different UX;
- writing a second scene loader in menu/portal scripts;
- using a custom overlay that never emits `covered` or `revealed`;
- setting presentation timeouts shorter than the authored animation.

## Technical contract

[`../components/audio_save_scene_localization.md`](../components/audio_save_scene_localization.md)
