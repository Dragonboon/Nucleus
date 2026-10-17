# Nucleus Documentation

Nucleus documentation is organized by **task first** and **technical ownership
second**. Start with a quickstart; use a tutorial when you want a complete example;
open the component/module contract when you need API guarantees, limits or extension
rules.

## Choose a starting point

> [!IMPORTANT]
> **Start from the result you want**, not from a class name. The use-case catalog
> maps game features to the right contracts; the source scripts remain the final
> reference for actual API signatures.

### Build a feature

| Your starting point | Read first |
| --- | --- |
| A gameplay feature or player behavior | **[Use-case catalog](guides/use_case_catalog.md)** |
| A combination of several systems | **[Composition recipes](guides/composition_recipes.md)** |
| Coding with an AI agent | **[Agent prompt playbook](guides/agent_prompt_playbook.md)** |
| See step-by-step prompts for 2D, turn-based and 3D games | [Worked agent prompt sequences](guides/agent_prompt_examples.md) |
| Understand agent ownership and proof rules | [AI/human workflow](guides/ai_composition_workflow.md) |
| Debug or validate gameplay with an agent | [Debug/testing prompt library](guides/agent_debug_testing_prompts.md) |
| Build scenes and reuse assets/addons | [Scene/asset/addon prompt library](guides/agent_scenes_assets_addons_prompts.md) |
| Choosing the correct code owner | [Architecture decision guide](architecture/component_selection.md) |

### Setup, learning, and diagnostics

| Goal | Read |
| --- | --- |
| Create a game from Nucleus | [`guides/installation.md`](guides/installation.md) |
| Understand the baseline architecture | [`guides/foundation_quickstart.md`](guides/foundation_quickstart.md) |
| Choose a consolidated interactive lab | [`guides/lab_guide.md`](guides/lab_guide.md) |
| Learn by building | [`guides/tutorials/README.md`](guides/tutorials/README.md) |
| Match a game problem to a subsystem | [`guides/real_game_patterns.md`](guides/real_game_patterns.md) |
| Configure project/rendering defaults | [`guides/project_configuration.md`](guides/project_configuration.md) |
| Validate locally and in CI | [`guides/validation_ci_quickstart.md`](guides/validation_ci_quickstart.md) |
| Diagnose integration problems | [`guides/troubleshooting.md`](guides/troubleshooting.md) |

> [!NOTE]
> **Two reading modes:** Use the catalog to answer *which tool should I use?*
> Open a technical contract to answer *how exactly does this API behave?*

The registry [`use_case_registry.json`](use_case_registry.json) exposes the same
discovery routes for machine-assisted tools. It does not execute code.

## Project-wide UI Theme

> [!TIP]
> Nucleus starts with a native, neutral [Theme baseline](components/ui_theme_baseline.md)
> selected in `project.godot`. Use the [Theme Quickstart](guides/ui_theme_quickstart.md)
> to preview focus, text contrast, states and the optional high-contrast variant.
> The game's own look and accessibility layout decisions remain configurable.

## Core and player-facing systems

| Goal | Read |
| --- | --- |
| Settings, input, rebinding and device hot-swap | [`guides/settings_input_quickstart.md`](guides/settings_input_quickstart.md) |
| UI, focus, accessibility and presentation | [`guides/ui_quickstart.md`](guides/ui_quickstart.md) |
| Audio, save and localization | [`guides/runtime_services_quickstart.md`](guides/runtime_services_quickstart.md) |
| Save directories, formats, security, backups and migrations | [`components/save_system.md`](components/save_system.md) |
| Continue/resume newest save | [`components/save_resume.md`](components/save_resume.md) |
| Scene transitions and recovery | [`guides/scene_flow_quickstart.md`](guides/scene_flow_quickstart.md) |
| Resource batches / loading presentation | [`guides/resource_loading_quickstart.md`](guides/resource_loading_quickstart.md) |
| Build a turn-based game: first steps | [`guides/turns_composition_quickstart.md`](guides/turns_composition_quickstart.md) |
| Build 2D AI enemies | [`guides/tutorials/ai_character_2d.md`](guides/tutorials/ai_character_2d.md) |
| Generic turn sessions (Turnity migration) | [`components/turn_sessions.md`](components/turn_sessions.md) |
| RPG-neutral encounter, abilities and progression | [`components/rpg_composition.md`](components/rpg_composition.md) |
| Gameplay foundation | [`guides/gameplay_foundation_quickstart.md`](guides/gameplay_foundation_quickstart.md) |
| Safe spawn / teleport / exit placement | [`components/safe_placement_queries.md`](components/safe_placement_queries.md) |
| Reusable grounded or floating 2D movement | [2D foundation](components/2d_foundation.md) |
| In-game 3D placement and editing | [Runtime placement](components/runtime_placement_3d.md) |
| Actions, attributes and status effects | [`guides/actions_attributes_status_quickstart.md`](guides/actions_attributes_status_quickstart.md) |
| Pooling and targeting | [`guides/pooling_targeting_quickstart.md`](guides/pooling_targeting_quickstart.md) |
| Humanoid ragdoll authoring | [`guides/ragdoll_authoring_quickstart.md`](guides/ragdoll_authoring_quickstart.md) |

## Performance and runtime efficiency

Use these in order:

1. [`guides/performance_quickstart.md`](guides/performance_quickstart.md) — measure and establish budgets.
2. [`guides/tutorials/performance_profiling.md`](guides/tutorials/performance_profiling.md) — reproduce and diagnose a real workload.
3. [`guides/runtime_optimization_quickstart.md`](guides/runtime_optimization_quickstart.md) — choose a bounded runtime intervention.
4. [`guides/tutorials/runtime_optimization.md`](guides/tutorials/runtime_optimization.md) — compose scheduler, gates, prewarm, audits and warmup.
5. [`components/runtime_optimization.md`](components/runtime_optimization.md) — canonical public contract.

Terrain/world streaming have their own performance rules; the runtime optimization
contract above covers general systems outside those domains.

## Accessibility

Accessibility is split deliberately:

- [`components/ui_and_accessibility.md`](components/ui_and_accessibility.md) — UI behavior, focus, motion and presentation boundaries.
- [`components/accessibility_preferences.md`](components/accessibility_preferences.md) — persisted UI scale/contrast intent, sensitivity, deadzones and hold/toggle behavior.
- [`guides/settings_input_quickstart.md`](guides/settings_input_quickstart.md) — source-aware input and controller hot-swap.

## Optional modules

| Module | Contract |
| --- | --- |
| Performance | [`modules/performance.md`](modules/performance.md) |
| Development tools | [`modules/development_tools.md`](modules/development_tools.md) |
| EventBus | [`modules/event_bus.md`](modules/event_bus.md) |
| Networking | [`modules/networking.md`](modules/networking.md) |
| Online replication | [`modules/online_replication.md`](modules/online_replication.md) |
| Inventory / equipment | [`modules/inventory_equipment.md`](modules/inventory_equipment.md) |
| Probability / loot | [`modules/probability_loot.md`](modules/probability_loot.md) |
| Persistent world state | [`modules/persistent_world_state.md`](modules/persistent_world_state.md) |
| AI / navigation | [`modules/ai_navigation.md`](modules/ai_navigation.md) |
| Platform services | [`modules/platform_services.md`](modules/platform_services.md) |
| Content packs | [`modules/content_packs.md`](modules/content_packs.md) |
| Mobile | [`modules/mobile.md`](modules/mobile.md) |
| Terrain | [`modules/terrain_generation.md`](modules/terrain_generation.md) |

## World and presentation contracts

| What you need | Existing contract |
| --- | --- |
| A clock, daylight or environment cycle | [World time](components/world_time_environment.md), [celestial quickstart](guides/celestial_environment_quickstart.md) |
| Rendering and lighting budgets | [Rendering quickstart](guides/rendering_quality_quickstart.md), [lighting quickstart](guides/lighting_shadows_quickstart.md) |
| Sample terrain/water or attach buoyancy | [Surfaces](components/world_surfaces.md), [buoyancy](components/world_buoyancy.md) |
| Hex coordinates, neighbors or a board | [Shared topology and 2D](components/hex_grid_2d.md), [3D layers](components/hex_grid_3d.md) |
| Decals, spatial fields or world feedback | [Decals](components/world_decals.md), [fields](components/world_fields.md), [feedback](components/world_feedback.md) |
| Schedule or batch visual work | [Scheduling and batched effects](components/world_scheduling_and_batched_fx.md) |
| Connect movement, camera and animation | [Movement/camera](components/gameplay_movement_camera.md), [animation](components/animation_integration.md), [camera feedback](components/camera_game_feel.md) |
| Configure a physical skeleton | [Ragdoll quickstart](guides/ragdoll_authoring_quickstart.md) |
| Bind HUD values or project labels from 3D | [UI bindings](components/ui_runtime_bindings.md), [world anchors](components/ui_world_anchors.md) |
| Validate edits, spatial overlap or scene instantiation | [Action history](components/validated_action_history.md), [rectangle index](components/spatial_rect_index_2d.md), [scene preflight](modules/packed_scene_preflight.md) |

Hex boards own axial occupancy; placement sessions validate free-form 3D
transforms. Neither owns inventory costs, network permission or save slots.
Choose the contract that matches the required space rather than using both as
competing owners of the same object.

## Documentation layers

```text
guides/use_case_catalog.md
    find reusable tools by player/developer intent

guides/ai_composition_workflow.md and composition_recipes.md
    compose native Godot, Nucleus and game-owned mechanics

guides/*_quickstart.md
    minimum setup + ownership

guides/tutorials/
    concrete build-along examples

components/ and modules/
    public behavior, limits, persistence/network/performance boundaries

architecture/
    dependency direction and design rationale

policies/
    compatibility, stability, versioning and deprecation
```

Technical contracts describe the current product. Migration history and iteration
journals belong in Git history, releases and pull requests rather than current-use
documentation.

## Machine-checkable coverage

`documentation_coverage.json` maps every top-level subsystem directory to one or
more technical documents. `use_case_registry.json` maps common developer needs
to existing contracts; `scripts/ci/use_case_audit.py` validates these references.
Edit the JSON registry and run `scripts/ci/build_use_case_catalog.py` to regenerate
the human-readable catalog; CI rejects out-of-sync copies.

Run:

```bash
python3 scripts/ci/documentation_audit.py
python3 scripts/ci/use_case_audit.py
python3 scripts/ci/build_use_case_catalog.py --check
python3 scripts/ci/productization_audit.py
```

## Stabilization and adoption

- [Maturity and evidence](architecture/maturity.md)
- [Composed acceptance scenes](guides/composition_acceptance.md)
- [Dependencies and selective upgrades](guides/upgrading_and_dependencies.md)
