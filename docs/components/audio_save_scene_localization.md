# Audio, Save, Scene Flow, and Localization Contract

## Audio

`NucleusAudio` composes bus preferences, music and a pooled non-positional one-shot
surface around Godot's AudioServer/AudioStreamPlayer APIs. Godot's bus layout
remains authoritative.

`NucleusAudioCue` owns reusable one-shot data including relative `voice_priority`.
When the one-shot pool is saturated, equal priorities preserve oldest-first
recycling; a lower-priority incoming voice may be rejected rather than stealing a
more important active voice. Positional AudioStreamPlayer2D/3D ownership remains
scene/game policy.

## Save

`NucleusSave` owns the global save profile, platform-aware storage location,
versioned documents, binary/Variant-text/JSON codecs, integrity, optional
password/key encryption, manual/quick backups, autosave rotation and migrations.
`NucleusSaveSession` coordinates scene-owned participants, metadata, lifecycle
autosaves, restore and incremental main-thread capture.

The shipped save root resolves to `OS.get_user_data_dir().path_join("saves")`,
not `res://`; overrides live in `NucleusSaveProfile`. Games own stable slot IDs,
cloud synchronization and save selection UI. Lifecycle autosaves on pause/quit
remain synchronous even when incremental capture is available.

See the [Save System contract](save_system.md) for precise filenames,
defaults, limits, failure behavior and runtime configuration, and the
[Save Quickstart](../guides/save_quickstart.md) for working examples.

## Scene Flow

`NucleusSceneFlow` owns application-level scene replacement, threaded loading,
progress, PackedScene preflight, transition presentation and failure/rollback
reporting. It keeps the outgoing scene alive until the destination is loadable and
instantiable.

For a single scene replacement, use Scene Flow directly. For a larger explicit
resource bundle, compose `NucleusResourceLoadQueue`, then hand a retained
`PackedScene` to `change_scene_to_packed()`.

## Localization

`NucleusLocalization` remains a thin facade around `TranslationServer` and locale
metadata. Translation resources and actual localized content remain Godot/game
owned. Optional message Resources, locale-aware Control bindings, editor PO/MO
registration and template extraction are documented in the
[localization pipeline](localization_pipeline.md). Source catalogs contain message
identities only; no second translated database or Autoload is introduced.

## Boundaries

- settings preferences do not belong in save-game payloads;
- save failures remain explicit `NucleusSaveResult` values;
- audio cues do not choose game-specific content policy;
- scene-flow failures are not converted into a global EventBus by default;
- locale selection does not create a second translation database.
