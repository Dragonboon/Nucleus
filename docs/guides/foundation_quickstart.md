# Foundation Quickstart

This is the shortest orientation for a project with the Nucleus addon enabled.

## 1. Know what the addon owns

The baseline Autoloads are:

```text
NucleusApp
NucleusSettings
NucleusInput
NucleusAudio
NucleusSave
NucleusSceneFlow
```

They exist because their lifetime genuinely crosses scene changes. Do not create
scene-local duplicates of these services.

Optional systems such as networking, AI, inventory, terrain, development tools
and performance diagnostics remain opt-in.

## 2. Keep Godot authoritative

Continue using native:

```text
SceneTree / Node
CharacterBody2D/3D / RigidBody2D/3D
Camera2D/3D
Area2D/3D
AnimationPlayer / AnimationTree
NavigationAgent2D/3D
Control / Container / Theme
Input / InputMap
ResourceLoader
TranslationServer
```

Nucleus supplies small reusable boundaries around repeated production wiring. It
does not recreate those engine systems.

## 3. Compose gameplay locally

A player might contain:

```text
Player
├── MotionInput
├── movement/camera
├── Health : NucleusValuePool
├── DamageReceiver
├── StateMachine
├── ActionSet
└── Interaction / Targeting when needed
```

Add only the components the scene requires. Prefer direct references and local
signals over global event plumbing when ownership is already clear.

## 4. Keep game policy in the game

Examples of game-owned policy:

```text
combat formulas and balance
survival rules
world/island distribution
missions and progression
art direction and palettes
provider/store decisions
multiplayer authority model
quality presets
```

A reusable Nucleus primitive may support these systems without owning their
product decisions.

## 5. Validate before building on top

Run the baseline sequence in [`validation_ci_quickstart.md`](validation_ci_quickstart.md).
A known-green starting point makes later regressions attributable.

## Read next

- Settings/input/options: [`settings_input_quickstart.md`](settings_input_quickstart.md)
- UI/accessibility: [`ui_quickstart.md`](ui_quickstart.md)
- Runtime efficiency: [`runtime_optimization_quickstart.md`](runtime_optimization_quickstart.md)
- Hands-on path: [`tutorials/README.md`](tutorials/README.md)
