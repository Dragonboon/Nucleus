<p align="center">
  <img src="icon.svg" width="112" height="112" alt="Nucleus icon">
</p>

<h1 align="center">Nucleus</h1>

<p align="center">
  An installable Godot addon for existing and new projects: small core services,
  composable gameplay systems, optional production modules, and executable validation.
</p>

<p align="center">
  <a href="https://github.com/Dragonboon/Nucleus/actions/workflows/nucleus-ci.yml">
    <img alt="Nucleus CI" src="https://github.com/Dragonboon/Nucleus/actions/workflows/nucleus-ci.yml/badge.svg?branch=main">
  </a>
  <img alt="Godot 4.7.2" src="https://img.shields.io/badge/Godot-4.7.2-478CBF?logo=godot-engine&logoColor=white">
  <img alt="Godot addon" src="https://img.shields.io/badge/type-Godot%20addon-6D5DFB">
  <img alt="Pre-1.0" src="https://img.shields.io/badge/status-pre--1.0-EA9A3A">
  <a href="LICENSE"><img alt="MIT License" src="https://img.shields.io/badge/license-MIT-2EA44F"></a>
</p>

Nucleus is a reusable **Godot 4.7 addon** for new and existing games
with common infrastructure already separated into explicit ownership boundaries.
It is not an addon framework and it does not replace Godot's scene tree, physics,
rendering, animation, resources, multiplayer, navigation, or UI systems.

The intended relationship is:

```text
Godot native systems
        ↓
small Nucleus service/component contracts
        ↓
game-owned rules, content, art and product policy
```

## Download and install

**Current distribution:** the addon is prepared for store submission. No verified
public Nucleus Asset Store/Asset Library listing is linked yet; do not confuse
similarly named assets with this repository.

Download a versioned ZIP and its checksum from
[GitHub Releases](https://github.com/Dragonboon/Nucleus/releases), when published.
Until a release is published, use the **Nucleus Release Package** workflow's
versioned artifact, or copy `addons/nucleus/` from a pinned source checkout.
Extract the addon ZIP into your existing project and enable **Nucleus** under
**Project > Project Settings > Plugins**. Keep your existing `project.godot`.

Once the official listing is approved, search **Nucleus** in the editor's
**Asset Store / AssetLib** tab, verify the repository is **Dragonboon/Nucleus**,
then download/install `addons/nucleus/` and enable the plugin. This is an addon
for the open project, not a Project Manager template.

The **Nucleus** dock integrates **Manage** and **Localization**. Manage previews
physical **Full / 2D / 3D** profiles, protects host references, keeps rollback
copies and stages verified updates from successful `main` CI commits.
See [installation](docs/guides/installation.md),
[addon management](docs/guides/addon_management.md) and
[store publication](docs/guides/asset_store_publication.md).

## Integration readiness

See the [maturity map](docs/architecture/maturity.md) for evidence and limits,
[composed acceptance scenes](docs/guides/composition_acceptance.md) for runnable
end-to-end checks, and [dependencies/upgrades](docs/guides/upgrading_and_dependencies.md)
when adopting changes into an existing game.

## Current baseline

| Contract | Current state |
| --- | --- |
| Addon version | [`VERSION`](VERSION) |
| Reference engine | Godot `4.7.2-stable` |
| API stability | Pre-1.0; intentional public changes may still occur |
| Core validation | static audits + headless tests + smoke scenes |
| Export validation | Linux, Windows and Web smoke exports |
| License | [MIT](LICENSE) |

The addon does not replace the game main scene. The consuming project
owns its entry point and opts into only the systems it needs.

## Start here: choose your route

> [!TIP]
> **Building a mechanic?** Start with the [Game Development Use Cases](docs/guides/use_case_catalog.md)
> to find the existing owner before creating new classes.
> **Using an AI agent?** Start with the [copy-ready agent prompt playbook](docs/guides/agent_prompt_playbook.md)
> and [worked 2D, turn-based and 3D prompts](docs/guides/agent_prompt_examples.md).
> Follow the [AI and human composition workflow](docs/guides/ai_composition_workflow.md).

| Goal | Best entry point |
| --- | --- |
| Find tools by a player-facing feature | **[Use-case catalog](docs/guides/use_case_catalog.md)** |
| Combine gameplay, UI, or world systems | **[Composition recipes](docs/guides/composition_recipes.md)** |
| Decide Godot vs. Nucleus vs. game code | [Ownership guide](docs/architecture/component_selection.md) |
| Read exact APIs and limitations | [Documentation index](docs/README.md) |

### First five minutes

The single **Nucleus** dock integrates localization, physical 2D/3D profiles and
verified updates from stable main. See [addon management](docs/guides/addon_management.md).

1. Read [Installation](docs/guides/installation.md).
2. Open [Foundation Quickstart](docs/guides/foundation_quickstart.md).
3. Create your game's main scene under a game-owned directory.
4. Keep the six baseline Autoloads unless you intentionally redesign their contracts.
5. Run the validation sequence before substantial game-specific changes.

The complete documentation map is [`docs/README.md`](docs/README.md).
Hands-on build-along guides are indexed at
[`docs/guides/tutorials/README.md`](docs/guides/tutorials/README.md).

## Build by game mechanic: humans and coding agents

If you know **what a game should do**, but not which reusable system owns it,
start with the **live [use-case catalog](docs/guides/use_case_catalog.md)**.
It routes player/designer problems to canonical components, modules and the
specific work that still belongs in the game.

- [AI and human composition workflow](docs/guides/ai_composition_workflow.md):
  how to turn a behavior request into owned nodes, tests and observable results.
- [Debugging/testing prompts](docs/guides/agent_debug_testing_prompts.md):
  reproducible diagnosis, regression suites and composed game verification.
- [Scene/asset/addon prompts](docs/guides/agent_scenes_assets_addons_prompts.md):
  reusable levels, imported art and approved plugin integration.
- [Composition recipes](docs/guides/composition_recipes.md): persistent doors,
  stamina/dodges, AI, inventory, terrain, boats, UI labels, multiplayer and tools.
- [Ownership decision tree](docs/architecture/component_selection.md):
  when to use native Godot, an existing Nucleus contract, or game-owned code.
- [`docs/use_case_registry.json`](docs/use_case_registry.json): same problem-first
  routing data in machine-readable form for agents and maintenance tooling.

Nucleus does **not** automatically generate full mechanics. A human or agent
writes the game's rules and connects the existing mechanisms. The goal is faster,
safer composition with less duplicate code, not a new engine or global framework.

## Accessible native UI by default

> [!TIP]
> Every new Nucleus project loads a neutral, editable Godot `Theme` automatically.
> Buttons, fields, panels and selection/focus states have a readable baseline
> without installing third-party fonts or adding an Autoload.
> See the **[UI Theme Quickstart](docs/guides/ui_theme_quickstart.md)** and
> run `res://examples/ui/ui_polish_lab.tscn` to inspect it. The project can replace
> the resource or override a specific UI subtree at any time.

## Core runtime

Nucleus keeps the global surface deliberately small:

```text
NucleusApp
NucleusSettings
NucleusInput
NucleusAudio
NucleusSave
NucleusSceneFlow
```

These services own cross-scene concerns only. Gameplay, UI composition, world
simulation and optional production tooling remain scene-owned by default.

| Need | Start here |
| --- | --- |
| Lifecycle, paths, logging, platform helpers | [Core runtime](docs/components/core_runtime.md) |
| Settings, input, rebinding, hot-swap | [Settings and input](docs/guides/settings_input_quickstart.md) |
| Audio, localization, scene flow | [Runtime services](docs/guides/runtime_services_quickstart.md) |
| Save paths, formats, backups and migrations | [Save system](docs/components/save_system.md) |
| Resource batches and loading UI | [Resource loading](docs/guides/resource_loading_quickstart.md) |
| UI, focus and accessibility | [UI and accessibility](docs/guides/ui_quickstart.md) |

## Gameplay composition

Nucleus favors small Nodes and Resources over inheritance-heavy base classes.
Typical gameplay is assembled from independent owners:

```text
Player
├── MotionInput
├── movement/camera components
├── ValuePool / attributes
├── DamageReceiver
├── GameplayAction set
├── StateMachine
└── interaction / targeting as needed
```

| Need | Start here |
| --- | --- |
| Health/resources, damage, interaction, timing, state | [Gameplay foundation](docs/guides/gameplay_foundation_quickstart.md) |
| Actions, attributes, modifiers, status effects | [Actions / attributes / status](docs/guides/actions_attributes_status_quickstart.md) |
| Movement and camera | [Movement / camera](docs/components/gameplay_movement_camera.md) |
| Pooling, spawning and targeting | [Pooling / targeting](docs/guides/pooling_targeting_quickstart.md) |
| Camera feedback and game feel | [Camera / game feel](docs/guides/camera_game_feel_quickstart.md) |
| AnimationTree integration | [Animation integration](docs/guides/animation_integration_quickstart.md) |

## Accessibility and input comfort

The baseline includes controller hot-swap, source-aware prompts/glyphs, rebinding,
reduced motion, screen-flash intensity, UI-scale intent, high-contrast intent,
look sensitivity, separate gamepad movement/look deadzones, and a reusable
hold/toggle activation helper.

Nucleus stores neutral preferences and exposes adapters. The game remains the owner
of Theme, subtitle styling, contrast palette, action semantics and assist balance.

Start with:

- [Settings and Input Quickstart](docs/guides/settings_input_quickstart.md)
- [UI and Accessibility Quickstart](docs/guides/ui_quickstart.md)
- [Accessibility Preferences contract](docs/components/accessibility_preferences.md)

## Runtime efficiency

Nucleus includes opt-in tools for reducing frame spikes without introducing a
global optimization manager:

```text
performance sampling and regression reports
staggered low-frequency scheduling
activity gating
incremental pool prewarming
Utility AI staggering
render / physics audits
first-use PackedScene warmup
audio one-shot voice budgeting
UI refresh coalescing
incremental save capture
```

These tools do not automatically change renderer, physics, AI or content policy.
Measure a representative workload, apply one bounded intervention, then compare.

Start with:

- [Performance Quickstart](docs/guides/performance_quickstart.md)
- [Runtime Optimization Quickstart](docs/guides/runtime_optimization_quickstart.md)
- [Runtime Optimization tutorial](docs/guides/tutorials/runtime_optimization.md)

## Optional production modules

Optional modules are included in the addon but are not promoted to baseline
Autoloads simply for convenience.

| Capability | Documentation |
| --- | --- |
| Performance diagnostics | [Performance](docs/guides/performance_quickstart.md) |
| Development command palette | [Development tools](docs/guides/development_tools_quickstart.md) |
| Networking bootstrap / LAN | [Networking](docs/guides/networking_quickstart.md) |
| Authoritative replication | [Online replication](docs/guides/online_replication_quickstart.md) |
| Inventory and equipment | [Inventory / equipment](docs/guides/inventory_equipment_quickstart.md) |
| Deterministic loot | [Loot](docs/guides/loot_quickstart.md) |
| Persistent world state | [Persistent world](docs/guides/persistent_world_quickstart.md) |
| Utility AI and navigation | [AI / navigation](docs/guides/ai_navigation_quickstart.md) |
| Platform/store boundary | [Platform services](docs/guides/platform_services_quickstart.md) |
| Signed DLC and data-only mods | [Content packs](docs/guides/content_packs_quickstart.md) |
| Touch/mobile integration | [Mobile](docs/guides/mobile_quickstart.md) |
| Procedural heightfield terrain | [Terrain](docs/guides/terrain_generation_quickstart.md) |

The terrain module owns reusable heightfield generation primitives and layouts.
Biome policy, island/world distribution for a specific game, objectives, content
placement, art direction and progression remain game-owned.

## Documentation model

Use the shortest layer that answers the question:

```text
README / docs index
    orientation
        ↓
use-case catalog
    choose a mechanism by gameplay intent
        ↓
*_quickstart.md
    ownership + minimum setup
        ↓
guides/tutorials/ and composition recipes
    build one concrete integration
        ↓
addons/nucleus/components/ or addons/nucleus/modules/
    public contract, limits and extension rules
```

For game-shaped examples, use [Real-game patterns](docs/guides/real_game_patterns.md).

## Validation

Fast repository checks:

```bash
python3 scripts/ci/static_checks.py
python3 scripts/ci/documentation_audit.py
python3 scripts/ci/use_case_audit.py
python3 scripts/ci/build_use_case_catalog.py --check
python3 scripts/ci/productization_audit.py
```

Authoritative Godot validation:

```bash
godot --headless --path . --import
godot --headless --path . res://tests/headless/test_runner.tscn
godot --headless --path . res://tests/smoke/smoke_main.tscn
```

Run the resource-loading smoke scene when `addons/nucleus/core/loading` changes. See
[Validation and CI](docs/guides/validation_ci_quickstart.md) for the complete gate.

## Compatibility and API policy

- [Godot compatibility](docs/policies/godot_compatibility.md)
- [API stability](docs/policies/api_stability.md)
- [Versioning](docs/policies/versioning.md)
- [Deprecation](docs/policies/deprecation.md)

Pin the Nucleus release, tag or source commit used by a consuming game. Vendoring
and selective upgrades are intentional.

## Contributing

Read [`AGENTS.md`](AGENTS.md) before modifying reusable contracts. The recurring
rules are: Godot-native first, explicit ownership, scene ownership by default,
composition over inheritance, no hidden dependencies between optional modules,
and executable evidence for reusable behavior.

## License

Nucleus is available under the [MIT License](LICENSE). A game built from the
addon may use its own license while retaining the required notice for reused
Nucleus code.
