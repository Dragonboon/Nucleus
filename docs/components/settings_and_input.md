# Settings and Input Contract

## Scope

```text
addons/nucleus/core/settings
addons/nucleus/core/input
```

Settings and Input integrate closely but retain separate responsibilities:
Settings owns configurable values and persistence; Input owns device state,
InputMap-facing rebinding, labels/prompts, and local-player ownership.

## Settings ownership

`NucleusSettings` is the default settings Autoload.

The subsystem is structured around:

```text
definitions
catalog
defaults
persistence
appliers
bindings
```

Definitions describe settings. The catalog is the authoritative registry.
Persistence stores user choices. Appliers translate values into engine state.
Bindings connect UI or other consumers without duplicating settings logic.

Do not make UI widgets write `ProjectSettings`, `DisplayServer`, root-viewport
properties, or audio buses independently when a Nucleus setting/applier already
owns that runtime preference.

## Runtime application

Changing a setting through `NucleusSettings.set_value()` updates the runtime
value, emits `setting_changed`, and lets the matching applier update Godot state.

For built-in display and root-viewport settings,
`NucleusDisplaySettingsApplier` owns:

```text
display/window_mode
display/borderless
display/vsync_mode
graphics/max_fps
graphics/render_scale
graphics/scaling_3d_mode
graphics/screen_space_aa
graphics/taa_enabled
graphics/msaa_2d
graphics/msaa_3d
graphics/debanding_enabled
```

These map to `DisplayServer`, `Engine.max_fps`, and the root `Viewport`. Do not
make runtime preferences effective by writing the corresponding
`ProjectSettings` key. Many project settings are read only during startup.

The ownership boundary is intentionally the **root viewport preference**, not
every `Viewport` in the scene tree. A game may configure scene-owned
`SubViewport` nodes directly when they are rendering cameras, minimaps, portals,
UI previews, or other local content.

### Scene-owned Environment settings

SSAO, SSIL, glow, volumetric fog, SDFGI and tonemapping are properties of an
`Environment` resource, not application-global rendering state.

Nucleus ships optional definitions under:

```text
addons/nucleus/core/settings/optional/environment/
```

and a scene component:

```text
NucleusEnvironmentSettingsApplier
```

Those definitions are intentionally absent from the default catalog. A consuming
game opts in by adding only the definitions it wants to its game-owned catalog
and attaching the applier to the relevant `WorldEnvironment` (or assigning its
`target`).

The component mutates the existing scene `Environment`; it does not create one
and does not move ownership into an Autoload. Before opting in, copy or adjust
the optional definition defaults so they match the visual baseline the game
actually intends to expose.

A different scene may therefore have a different `Environment` or no environment
applier at all. That is expected.

### Defaults and precedence

Use this precedence model when a consuming game customizes Nucleus:

```text
framework definition default
→ game-owned catalog/default override
→ game-selected platform recommendation
→ persisted user preference
```

Persisted user choice wins. Platform recommendations should seed an appropriate
first-run default, not silently replace an explicit choice on every launch.

Nucleus does not ship universal Low/Medium/High/Ultra bundles. Those labels
depend on the game's content, renderer, performance budget, and target hardware.
A game can build presets by assigning several ordinary setting values; `Custom`
is presentation state derived from whether the active values still match a known
game-owned bundle.

### Godot editor game embedding

Godot 4.7 enables game embedding by default. Embedded runs do not support window
mode or window-flag changes such as fullscreen.

Nucleus keeps the preference persisted but does not treat an embedded editor run
as proof that fullscreen is broken. The display applier emits a diagnostic when
an unsupported embedded window change is requested.

To validate window mode:

1. open the editor's **Game** workspace;
2. disable **Embed Game on Next Play**;
3. run again or validate an exported build;
4. compare with `DisplayServer.window_get_mode()` when debugging.

Web and native-mobile targets also use managed window behavior and intentionally
ignore desktop-only window-mode requests.

## Input ownership

`NucleusInput` is the default input Autoload.

It builds on Godot's `Input` and `InputMap` rather than replacing them.

The public surface includes:

- semantic default action identifiers;
- active input-source/device tracking;
- keyboard/mouse, gamepad, and touch as first-class sources;
- gamepad family metadata and vibration;
- runtime rebinding serialization;
- human-readable binding labels and prompt bindings;
- cursor helpers;
- local multiplayer input sessions/readers.

## Three separate input concepts

Nucleus treats these as different layers:

```text
physical event
    A key, mouse button, touch event, gamepad B/Circle, stick axis

InputMap action
    ui_cancel, interact, dodge, pause, move_left

consumer context
    active menu, modal, gameplay character, vehicle, pause screen
```

One physical event may map to more than one InputMap action. That is valid when
the active consumer makes the intended context unambiguous.

### UI navigation actions

Godot's `ui_*` actions are navigation semantics for active `Control` trees,
dialogs, and menu layers.

`NucleusInputActions.UI_ACCEPT` and `UI_CANCEL` exist so reusable code can refer
to those native action names without string literals.

They are **not** gameplay commands.

A world/session script must not interpret `ui_cancel` as a universal
"return to menu", "leave session", or gameplay cancel action. The physical
B/Circle input commonly used by `ui_cancel` may also be assigned to dodge,
melee, interaction, or another project-specific gameplay action.

For gameplay pause/back behavior use a gameplay action such as
`NucleusInputActions.PAUSE`, then let the opened UI consume `ui_cancel`.

### Why Nucleus does not add mapping contexts yet

Systems such as G.U.I.D.E demonstrate the value of explicit mapping contexts for
complex input stacks. Nucleus currently avoids introducing a second input
framework while ordinary Godot consumers already provide sufficient context.

The default rule is:

```text
world gameplay consumes gameplay actions
active UI consumes ui_* navigation actions
```

A future context system should be added only after a consuming game demonstrates
a concrete case that cannot be represented cleanly with this model.

## Cursor ownership

`NucleusCursor` is the public cursor-mode boundary.

Use:

```gdscript
NucleusCursor.show()
NucleusCursor.hide()
NucleusCursor.capture()
NucleusCursor.confine()
NucleusCursor.confine_hidden()
NucleusCursor.set_mode(custom_mode)
```

Game-facing code should not assign `Input.mouse_mode` directly. Keeping the raw
Godot assignment inside `NucleusCursor` gives agents and humans one searchable
owner for cursor policy without hiding the engine's actual modes.

## Runtime rebinding

`NucleusInputBindingCodec` serializes supported `InputEvent` bindings so they can
be persisted through Settings or another project-owned store.

Rebinding changes Godot's `InputMap`; gameplay continues to query actions, not
physical keys/buttons.

Gamepad events are normalized to InputMap's all-devices id. A player rebinding a
button therefore creates a controller-family-agnostic binding rather than a
binding tied to one transient device id.

Actions beginning with `ui_` are protected from rebinding by default. Projects
that deliberately expose UI-navigation rebinding may set:

```gdscript
NucleusInput.allow_ui_action_rebinding = true
```

Such projects are responsible for preserving a usable accept/cancel fallback.

## Single-player device hot-swap

`NucleusLocalInputSession` owns explicit local-player assignments.

When:

```text
max_players == 1
single_player_hot_swap == true
```

meaningful keyboard/mouse, gamepad, or touch activity may move the stable player
seat to that source.

The `NucleusLocalPlayerInput` object remains the same. Consumers that already
hold it, such as `NucleusMotionInput`, do not need to rebind when the player
touches another device.

This is the normal "plug in a controller and keep playing" path.

## Local multiplayer

When `max_players > 1`, explicit seat ownership remains authoritative. Do not
globally swap every player to the last active device.

Do not solve couch multiplayer by forking InputMap per player unless a real game
requirement cannot be represented by the existing session/reader model.

## Mobile/touch rule

Virtual controls feed the same semantic InputMap actions used by keyboard and
gamepad. Do not create a parallel gameplay surface such as
`mobile_move_vector`. `NucleusVirtualStick`, touch actions and touch look are
input adapters, not a second control model.

Safe areas, breakpoints, orientation, permissions, haptics, lifecycle events and
capabilities remain composed helpers rather than a monolithic MobileManager.

## Device presentation

Core input emits device state. UI presentation remains scene-owned.

`NucleusInputDeviceToastBinding` bridges gamepad connection/disconnection signals
into `NucleusUIToastHost`. This keeps `addons/nucleus/core/input` independent from UI while
allowing a game to opt into standard controller feedback with one composed layer.

## Signals and data flow

Typical flow:

```text
device InputEvent
→ NucleusInput source/device tracking
→ optional local-player routing
→ gameplay/UI consumer

rebind request
→ InputMap mutation
→ serialized binding
→ settings persistence
→ prompt/label refresh

settings binding
→ NucleusSettings.set_value()
→ setting_changed
→ global applier or scene-owned Environment applier
→ native Godot runtime API

gamepad connection
→ NucleusInput signal
→ optional toast binding
→ scene-owned NucleusUIToastHost
```

## Agent and CI guardrail

The root `AGENTS.md` tells coding agents to search Nucleus before duplicating a
lower-level Godot call and explicitly separates UI navigation from gameplay
actions.

`scripts/ci/static_checks.py` protects a deliberately small set of high-value
ownership boundaries. It intentionally does not ban ordinary scene-owned
`SubViewport` or `Environment` configuration merely because the root graphics
preferences expose related Godot properties.

## Persistence boundary

Settings persistence is configuration data. Save-game state belongs to
`addons/nucleus/core/save`. Do not mix them merely because both write under `user://`.

## Extension rule

New settings enter through definitions/catalog/appliers.

Add an application-wide applier only when the native Godot owner is genuinely
global. Prefer a scene-owned component when the native owner is a node/resource
in the scene.

New input presentation consumes semantic actions and existing label/prompt
helpers rather than encoding device-specific strings in gameplay code.

New input infrastructure should solve demonstrated production friction without
replacing Godot InputMap unless the native model becomes a proven limitation.
