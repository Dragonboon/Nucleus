# UI and Accessibility Contract

## Scope

```text
addons/nucleus/components/ui/accessibility
addons/nucleus/components/ui/data
addons/nucleus/components/ui/effects
addons/nucleus/components/ui/feedback
addons/nucleus/components/ui/focus
addons/nucleus/components/ui/gameplay
addons/nucleus/components/ui/input
addons/nucleus/components/ui/interaction
addons/nucleus/components/ui/layout
addons/nucleus/components/ui/localization
addons/nucleus/components/ui/modal
addons/nucleus/components/ui/motion
addons/nucleus/components/ui/navigation
addons/nucleus/components/ui/presentation
addons/nucleus/components/ui/text
addons/nucleus/components/ui/toast
addons/nucleus/components/ui/tooltip
addons/nucleus/components/ui/virtualization
addons/nucleus/core/accessibility
```

Nucleus UI is composition around Godot `Control` nodes. It is not a replacement
UI framework.

Godot remains authoritative for:

```text
Control / Container layout
Theme inheritance and type variations
StyleBox / fonts / icons
focus neighbors and native focus behavior
Tween / AnimationPlayer
ShaderMaterial
RichTextLabel
accessibility tree integration
```

Nucleus adds small reusable policies around those primitives.

## Presentation and navigation

Presenters/bindings project runtime state into Controls. Focus scopes and
navigation helpers improve keyboard/gamepad traversal without replacing Godot's
focus system.

Modal, toast, and tooltip hosts own transient presentation inside the scene/UI
layer.

## UI polish ownership

Reusable polish is split into layers:

```text
authored/native visual state
    Theme + layout + base Control transform

presentation transition
    NucleusUIPresenter + NucleusUITransitionProfile

local interaction/feedback
    NucleusUIInteractionFeedback + NucleusUIVisualStateProfile

specialized presentation adapters
    progress / input glyph / shader parameter / text reveal
```

When multiple systems need to animate transforms, prefer separate Controls:

```text
LayoutSlot
└── PresentationRoot
    └── FeedbackRoot
        └── Content
```

The Container owns `LayoutSlot`. `NucleusUIPresenter` owns transforms on
`PresentationRoot`. Interaction/progress pulses own `FeedbackRoot`.

This avoids two independent Tweens writing the same `scale`, `position`,
`rotation`, or `modulate` property.

Do not add a global UI transform mixer merely to avoid this composition.

## Motion

`NucleusUIMotionProfile` owns timing:

```text
duration
transition
easing
ignore_time_scale
respect_reduced_motion
reduced_motion_scale
```

`reduced_motion_scale` is the retained fraction of nonessential motion when the
shared `NucleusMotionPolicy` reports reduced motion.

The default remains `0`, preserving the historical UI behavior of completing
nonessential transitions immediately. Projects may use a small value such as
`0.25` when an orientation/selection cue should remain visible.

`NucleusUIMotion.get_effect_amplitude_scale()` exposes the same policy for
effects whose displacement should be attenuated as well as shortened.

The user setting `accessibility/ui_motion_scale` remains a duration multiplier
independent of the reduced-motion decision.

## Declarative transitions

`NucleusUITransitionProfile` describes the hidden state relative to the
Control's authored base state:

```text
hidden alpha
scale multiplier
position offset
rotation offset
pivot
motion profile
```

Convenience builders:

```gdscript
NucleusUITransitionProfile.fade_only()
NucleusUITransitionProfile.pop()
NucleusUITransitionProfile.slide(Vector2(0.0, 24.0))
```

Assign a profile to:

```text
NucleusUIPresenter.transition
```

Existing `fade`, `scale`, `hidden_scale`, and `motion` exports remain as the
legacy fallback when no transition profile is assigned.

For authored timeline animation, cinematic menus, or elaborate art-direction
sequences, keep using native `AnimationPlayer`.

## Interaction visual states

`NucleusUIVisualStateProfile` is additive transform/opacity feedback:

```text
scale multiplier
position offset
rotation offset
alpha multiplier
optional motion override
```

It intentionally does not contain fonts, icons, StyleBoxes, Theme colors, or
textures. Those remain in Godot `Theme`.

`NucleusUIFeedbackProfile` may assign visual states for:

```text
idle
hover
focus
pressed
selected
```

`NucleusUIInteractionFeedback` resolves those states from native Control events.
Toggle buttons automatically drive `selected`; other widgets may call
`set_selected()` explicitly.

The old scale/opacity fields remain as a compact fallback when visual-state
Resources are not assigned.

## Progress feedback

`NucleusUIProgressFeedback` presents one gameplay/runtime number through:

```text
primary Range
optional delayed trailing Range
optional punch target
```

It is suitable for health, shield, stamina, boss health, experience, resource
meters, or loading sub-progress. The component does not know what the number
means.

Typical composition:

```text
ProgressSlot
├── Trailing : ProgressBar
├── Primary  : ProgressBar
└── ProgressFeedback
```

For a decrease, `Primary` can move immediately while `Trailing` waits for
`decrease_trail_delay` before catching up.

When the two `Range` nodes use different numeric bounds, the trailing value is
mapped through normalized progress. `sync_trailing_bounds` can instead keep both
ranges identical.

## Input glyph presentation

Core Input owns actions, current bindings, active input source, and gamepad
family detection.

UI owns visual glyphs:

```text
NucleusInput
    current InputEvent + active family
        ↓
NucleusInputGlyphProfile
    game-owned Texture2D mapping
        ↓
NucleusInputGlyphBinding
    TextureRect + optional Label fallback
```

Nucleus ships no keyboard/controller icon artwork.

`NucleusInputGlyphProfile.event_key()` converts supported InputEvents into stable
mapping keys. Gamepad lookup first checks the active family and then the generic
gamepad table.

`NucleusInputGlyphBinding` observes the same Input signals as text prompts, so a
rebind or input-source hot swap refreshes presentation automatically.

If no glyph exists, the binding can show
`NucleusInput.get_binding_text()` through a normal Label.

## Shader parameter effects

`NucleusUIShaderEffect` is a small adapter over a game-owned `ShaderMaterial`.

It supports:

```text
set one shader parameter
Tween one interpolatable parameter
stop one parameter animation
stop all local parameter animations
```

Supported Tween value categories are numeric values, vectors, and colors.

The default `DUPLICATED_MATERIAL` mode prevents one widget effect from
mutating every Control that shares the original Resource.

For shaders authored with `instance uniform`, use `INSTANCE_UNIFORM` mode to keep
the material shared and write through CanvasItem per-instance parameters. A
`SHARED_MATERIAL` mode exists only when deliberately animating every user of one
material.

The shader itself remains game-owned. Nucleus does not prescribe glow, dissolve,
glitch, outline, vignette, selection, damage, or rarity styles.

Use native `AnimationPlayer` when several shader/transform tracks need an authored
timeline.

## Text reveal

`NucleusUITypewriter` controls only `RichTextLabel.visible_characters`.

It does not own:

```text
dialogue graphs
speaker state
localization data
voice playback
choices
quest state
BBCode authoring
```

The game sets the RichTextLabel content, then calls:

```gdscript
typewriter.restart()
typewriter.skip()
typewriter.reveal_immediately()
```

Reveal cadence is authored through:

```text
characters_per_second
minor_punctuation_delay
major_punctuation_delay
minor_punctuation_characters
major_punctuation_characters
pause_on_line_break
```

The default punctuation sets cover common Latin, Arabic, CJK and Japanese
punctuation. Projects can replace either string without changing reveal logic.

Cadence is resolved from `RichTextLabel.get_parsed_text()`, so BBCode is never
parsed or owned by Nucleus. A long frame consumes the same character and pause
budget instead of skipping punctuation waits.

The component can use real elapsed time while gameplay is paused or time-scaled.
Under reduced motion, complete text is revealed immediately by default.

This preserves accessibility and keeps `RichTextLabel` authoritative for shaping
and BBCode.

## Theme boundary

Nucleus does not implement a parallel design-token or skinning framework.

Use Godot Theme/type variations for visual identity. Dynamically generated
Nucleus controls should expose stable type variations where practical, as
`NucleusUIToastHost` already does.

A consuming game should be able to replace Theme, fonts, icons and StyleBoxes
without changing UI behavior code.

## Layout and virtualization

Safe-area/breakpoint helpers adapt layouts around viewport constraints.
Virtualization is for large/repeated data views and should not be used when a
normal Godot container is sufficient.

Do not animate layout-owned position on a Control that a Container rewrites every
frame. Insert a presentation/feedback child Control and animate that layer.

## Data and gameplay bindings

UI data components observe stable gameplay/runtime APIs such as ValuePool,
settings, localization, or action state.

UI should not mutate private dictionaries or reach into another subsystem's
implementation details.

## Screen effects

Screen effects are visual presentation. They should not become the authority for
gameplay state such as damage, pause, or status effects.

`NucleusUIScreenEffects` owns common fade/flash presentation.
`NucleusUIShaderEffect` covers local game-owned material parameters without
turning screen effects into a gameplay-state manager.

## Localization

Localized controls observe `TranslationServer`/Nucleus locale changes. Store
translation keys and source data, not permanently translated output.

Typewriter presentation should be restarted after the consuming game changes
the target text. Projects should also review punctuation character sets for
languages that use different sentence or clause marks.

## Accessibility

Accessibility helpers improve default usability while preserving native Godot
semantics.

Reduced motion is shared through `NucleusMotionPolicy`; UI-specific duration and
flash preferences remain in `NucleusUIMotionPolicy`.

Input glyphs should retain a readable text fallback. Do not make controller
artwork the only way to understand a required action.

## Validation lab

Run:

```text
examples/ui/ui_polish_lab.tscn
```

to inspect:

```text
panel transitions
hover/focus/press/selected states
delayed progress feedback
input glyph/text fallback
shader parameter animation
RichTextLabel reveal/skip/punctuation cadence
reduced-motion response
```

Use mouse, keyboard and controller while validating focus, hot swap and motion.

## Extension rule

First ask whether a native Control, Theme, Container, focus, Tween,
AnimationPlayer, ShaderMaterial, or RichTextLabel behavior already solves the
problem.

Add a Nucleus component only when it removes repeated production wiring across
projects without taking ownership away from the engine or the game's art
direction.
