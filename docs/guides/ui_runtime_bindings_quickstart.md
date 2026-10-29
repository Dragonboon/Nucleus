# UI Runtime Bindings Quickstart

Use these adapters when a Nucleus runtime owner already exposes the state and
you only need to project it into authored UI.

Technical contract:

[`../components/ui_runtime_bindings.md`](../components/ui_runtime_bindings.md)

## ValuePool to a polished bar

Build the normal UI first:

```text
HealthSlot
├── Trailing : ProgressBar
├── Primary : ProgressBar
├── ProgressFeedback : NucleusUIProgressFeedback
└── HealthBinding : NucleusUIValuePoolProgressBinding
```

Assign:

```text
ProgressFeedback.primary_target = Primary
ProgressFeedback.trailing_target = Trailing
HealthBinding.source = player health NucleusValuePool
HealthBinding.target = ProgressFeedback
```

Now gameplay only updates the pool:

```gdscript
health.decrease(25.0)
```

The binding observes the ratio and `NucleusUIProgressFeedback` owns the visual
response.

## Bootstrap or runtime load-plan presentation

Author any loading UI:

```text
LoadingUI
├── ProgressBar
├── CountLabel
├── ItemLabel
└── ResourceLoadBinding : NucleusUIResourceLoadBinding
```

Assign the scene-owned `NucleusResourceLoadQueue` as `source`, then wire any
combination of:

```text
progress_feedback
progress_target
count_label
item_label
```

If a `NucleusUIProgressFeedback` is assigned, it takes precedence over the raw
Range so there is only one writer for that progress value.

The binding does not start the plan. Your coordinator still does:

```gdscript
queue.start(bootstrap_plan)
```

The UI updates from the queue's signals automatically.

## Direct SceneFlow progress

For an ordinary scene change, keep using `NucleusSceneFlow` rather than creating
an artificial load plan.

Add:

```text
LoadingPanel
├── ProgressBar
└── SceneLoadBinding : NucleusUISceneLoadBinding
```

Assign the progress target. The adapter listens to `NucleusSceneFlow` and emits:

```text
loading_started(scene_path)
loading_finished(scene_path, succeeded)
```

Use those local signals to drive your own `NucleusUIPresenter`, AnimationPlayer,
or static visibility policy.

Example:

```gdscript
func _ready() -> void:
    scene_binding.loading_started.connect(_on_loading_started)
    scene_binding.loading_finished.connect(_on_loading_finished)


func _on_loading_started(_scene_path: String) -> void:
    presenter.show_animated()


func _on_loading_finished(
    _scene_path: String,
    _succeeded: bool,
) -> void:
    presenter.hide_animated()
```

Nucleus intentionally does not choose the loading art, text, tips, background,
video, or destination name.

## Progress smoothing

Both loading adapters default to:

```text
animate_progress = false
```

This keeps visual progress faithful to the runtime source and avoids restarting
Tweens on frequent ResourceLoader updates.

If the game wants a deliberately softened bar, assign
`NucleusUIProgressFeedback` and enable `animate_progress` after profiling the
actual loading screen.

## Godot 4.7 first-start audio warning

The addon keeps the AudioBusLayout itself as a normal `.tres` Resource, but
`project.godot` references it by:

```text
res://addons/nucleus/core/audio/default_bus_layout.tres
```

This avoids the intermittent Godot 4.7 early UID-cache warning for the default
bus layout on a clean checkout.

## Validation

Run:

```bash
python3 scripts/ci/static_checks.py
python3 scripts/ci/documentation_audit.py
python3 scripts/ci/productization_audit.py

godot --headless --path . --import
godot --headless --path . res://tests/headless/test_runner.tscn
godot --headless --path . res://tests/smoke/resource_loading_smoke.tscn
```
