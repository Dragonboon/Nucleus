# Tutorial: build reusable UI audio and a persistent volume control

This tutorial uses the global audio service for a UI confirmation sound and a
settings binding for volume.

## 1. Create an AudioCue

In the FileSystem dock create a new `NucleusAudioCue` Resource, for example:

```text
res://game/audio/ui_confirm.tres
```

Configure:

```text
stream        = your confirmation AudioStream
bus           = UI
volume_linear = 1.0
pitch_scale   = 1.0
```

The Resource describes reusable playback policy; it does not own a player.

## 2. Play it from a button

```gdscript
extends Control

@export var confirm_cue: NucleusAudioCue


func _ready() -> void:
    %ConfirmButton.pressed.connect(_on_confirm_pressed)


func _on_confirm_pressed() -> void:
    NucleusAudio.play_cue(confirm_cue)
```

Nucleus reuses its one-shot pool for the temporary non-positional player.

## 3. Compare with raw one-shot playback

For a sound that does not need a reusable cue:

```gdscript
@export var cancel_stream: AudioStream


func play_cancel() -> void:
    NucleusAudio.play_one_shot(
        cancel_stream,
        NucleusAudioBuses.UI,
        0.8,
        1.0,
    )
```

Use the cue when policy is design data. Use direct one-shot arguments for truly
local/simple cases.

## 4. Add a master-volume Slider

Build:

```text
AudioOptions : VBoxContainer
└── MasterVolume : HSlider
    └── Binding : NucleusRangeSettingBinding
```

Assign the existing setting Resource:

```text
res://addons/nucleus/core/settings/defaults/audio_master_volume.tres
```

The binding synchronizes:

```text
Slider
↔ NucleusSettings
→ NucleusAudio setting listener
→ AudioServer bus volume
```

Do not add another `value_changed` handler that calls `AudioServer` directly.

## 5. Add SFX/music sliders

Repeat the same composition with the corresponding default setting Resources.

This is where settings bindings pay off: every options scene uses the same
persisted value and runtime application policy without duplicating glue code.

## 6. Add variation without custom randomization code

When a cue should choose between multiple footstep/click/impact samples, use
Godot `AudioStreamRandomizer` as the cue's `stream`.

The cue can still choose the Nucleus bus/volume policy while Godot owns sample
selection and random pitch/volume behavior.

## 7. Know when not to use NucleusAudio

For a boat engine attached to a moving boat:

```text
Boat
└── EngineAudio : AudioStreamPlayer3D
```

is usually the better ownership model.

Nucleus does not need to wrap a native positional player just because audio is
involved.

## Validation

Verify:

1. the UI cue plays repeatedly without creating game-owned temporary players;
2. moving the master slider changes playback immediately;
3. the selected volume survives restart;
4. the cue routes through the expected bus;
5. positional world sounds remain spatial when using native 2D/3D players.

## Related docs

- [`../audio_quickstart.md`](../audio_quickstart.md)
- [`bindings.md`](bindings.md)
- [`../../components/audio_save_scene_localization.md`](../../components/audio_save_scene_localization.md)
