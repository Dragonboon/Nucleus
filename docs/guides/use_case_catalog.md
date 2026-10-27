# Game Development Use Cases

**78 game-development scenarios · five capability areas · one source of truth**

> [!TIP]
> **Start with the feature you want.** Find its row, follow the existing
> Nucleus contract, and implement only the game-specific rules that remain.

**Browse:** [Core](#core) · [Gameplay](#gameplay) · [UI](#ui) ·
[World](#world) · [Optional modules](#optional-modules)

## How to use this catalog

1. Find the closest player or developer problem below.
2. Open the linked technical contract and verify its current script API.
3. Read a quickstart or tutorial to wire a minimal scene.
4. Keep gameplay logic and content in the consuming game.
5. Run the relevant tests and verify the behavior in a real scene.

> [!IMPORTANT]
> **Ownership boundary:** Godot owns engine primitives; Nucleus provides
> reusable contracts; the game owns rules, content, balance, and visuals.

**More help:** [AI/human workflow](ai_composition_workflow.md) ·
[Composition recipes](composition_recipes.md) ·
[Ownership decisions](../architecture/component_selection.md) ·
[Machine-readable registry](../use_case_registry.json)

## 🟦 Core

| What you want to build | Reuse this contract | The game still decides |
| --- | --- | --- |
| Start a game, handle app pause/quit | [Use lifecycle hooks without making a global GameManager](../components/core_runtime.md) | Game boot scene and state transitions |
| Player changes resolution or fullscreen | [Persist user intent and apply via settings owners](../components/settings_and_input.md) | Graphics presets and art-quality tradeoffs |
| Rebind keyboard, mouse, gamepad controls | [Use semantic input and device ownership](../guides/settings_input_quickstart.md) | Names and meaning of game actions |
| Local co-op with multiple gamepads | [Assign devices to seats, avoid global last-device assumptions](../guides/local_multiplayer_quickstart.md) | Players, splitscreen and game modes |
| Play an impact sound or music | [Use audio routing and one-shot policies](../guides/audio_quickstart.md) | Sound assets, mixing and when to play |
| Switch menus, levels or restart | [Use SceneFlow transitions instead of manual global switching](../guides/scene_flow_quickstart.md) | Target scenes and player progress |
| Save and resume an adventure | [Use Save contracts, codecs, sessions and latest-slot loading](../components/save_system.md) | Serializable schema and migrations |
| Keep persistent object IDs stable | [Separate persistent identity from instance and peer IDs](../modules/persistent_world_state.md) | What must survive between sessions |
| Show a loading overlay or preload scenes | [Use resource batch loading and progress presentation](../guides/resource_loading_quickstart.md) | Assets to load and UX thresholds |
| Translate UI and gameplay text | [Use localization adapters and keys](../guides/localization_quickstart.md) | Translation content and typography |
| Respect reduced motion and accessibility options | [Read neutral preferences and connect visuals to adapters](../components/accessibility_preferences.md) | Accessibility presentation and gameplay assistance |
| Diagnose errors and log important operations | [Use diagnostic scopes, reports and logging](../components/diagnostics.md) | Relevant failure messages and privacy |
| Format large numbers or bound integer arithmetic | [Use NumberFormatter and BoundedIntMath without game-specific counters](../components/numeric_utilities.md) | Displayed units, numeric limits and economy policy |
| Import gettext translations and extract source templates from scenes and message Resources | [Compose native PO/MO loading and extraction with optional editor tools and live text bindings](../guides/localization_workflow.md) | Translation content, source scope, fonts, language review and runtime arguments |

## 🟩 Gameplay

| What you want to build | Reuse this contract | The game still decides |
| --- | --- | --- |
| Health, stamina, shield or mana | [Compose ValuePool and optional regeneration](../components/gameplay_foundation.md) | Resource rules and balancing |
| Hits, damage, invulnerability | [Compose hit payloads, damage receivers and collision nodes](../components/gameplay_foundation.md) | Hitbox shape, damage formulas and teams |
| Attack, dodge, cast or use an ability | [Compose actions, requirements and effects](../components/gameplay_actions_attributes_status.md) | Timing, damage and animation choreography |
| Buffs, debuffs, poison and temporary modifiers | [Use status and attribute contracts](../components/gameplay_actions_attributes_status.md) | Status effects and combat balance |
| Finite player or enemy states | [Use scene-owned FSM with guarded transitions](../components/gameplay_foundation.md) | Concrete state rules and animations |
| Third-person character movement | [Connect semantic input, native body motor and camera rig](../components/gameplay_movement_camera.md) | Locomotion feel, speeds and traversal specifics |
| 2D platformer or top-down controls | [Use 2D movement and input foundation](../components/2d_foundation.md) | Platforming rules and camera feel |
| Interaction prompt and usable objects | [Compose interactable discovery and explicit actions](../components/gameplay_foundation.md) | Interaction ranges, costs and effects |
| Enemies detecting and selecting targets | [Use sensors and composable filters/scorers](../components/gameplay_pooling_targeting.md) | Aggro rules and combat behavior |
| Repeated projectiles, enemies or pickups | [Use spawner and object-pool contracts where warranted](../components/gameplay_pooling_targeting.md) | Spawn composition and capacity |
| Respawn or vehicle exit without clipping | [Use real-shape placement queries in 2D or 3D](../components/safe_placement_queries.md) | Ordered candidate transforms and failure handling |
| Undo a game action after validation | [Use data-only validated history only when native UndoRedo is insufficient](../components/validated_action_history.md) | State schema, atomic restore and side effects |
| Retarget a camera and add shake | [Use camera and gameplay feedback components](../components/camera_game_feel.md) | Intensity, accessibility and art direction |
| AnimationTree character state integration | [Compose animation adapters rather than replacing AnimationTree](../components/animation_integration.md) | Animation assets and transition semantics |
| Ragdoll on death or impact | [Use humanoid ragdoll authoring helpers with native physics](../components/ragdoll_authoring_3d.md) | Rig, reactions and cinematic choices |
| Compose a grounded or floating 2D character | [Use CharacterMotor2D with native motion_mode and shared intent sources](../components/2d_foundation.md) | Jump rules, sprites, combat and level design |
| Animate four/eight-direction 2D sprites with temporary actions | [Select native AnimatedSprite2D clips with explicit profile and lifecycle](../components/presentation_2d.md) | Art, motion and aim sources, action semantics and terminal states |
| Emit sustained circular, shotgun, line, lotus and spiral bullet patterns | [Compose bounded emission, retained packed storage and native MultiMesh rendering](../components/bullet_hell_2d.md) | Damage, teams, collision policy, cadence and target-device budgets |

## 🟪 UI

| What you want to build | Reuse this contract | The game still decides |
| --- | --- | --- |
| Build image-driven point-and-click screens with resolution-independent hotspots | [Compose image-screen interaction with native Control input](../components/image_screen_interaction.md) | Artwork, room graph, puzzle rules, accessible focus UI and save flags |
| Menus and keyboard/gamepad focus | [Use focus, navigation and modal ownership](../components/ui_and_accessibility.md) | Menu hierarchy and visual theme |
| Responsive HUD and safe area | [Compose UI layout and scale policies](../components/ui_and_accessibility.md) | Breakpoints, art and hierarchy |
| Inventory slots, health bars and data-bound widgets | [Bind presentation to game-owned state](../components/ui_runtime_bindings.md) | Inventory or combat semantics |
| World-space NPC nameplates and health bars | [Use world anchor projection and layout separation](../components/ui_world_anchors.md) | Label design, visibility authorization |
| Toasts, prompts and tooltips | [Use scene-owned feedback and tooltip components](../components/ui_and_accessibility.md) | Wording, timing and priority |
| Screen flashes, fades and reduced-motion variants | [Use UI motion and effects adapters](../components/ui_and_accessibility.md) | Effects art and intensity |
| Large scrolling equipment or item lists | [Use UI virtualization and refresh coalescing](../components/runtime_optimization.md) | List content and item selection rules |
| Touch screen controls | [Use mobile touch input and semantic actions](../guides/mobile_quickstart.md) | Touch layout, gestures and ergonomics |
| Select thousands of objects in a 2D editor | [Use SpatialRectIndex2D as broad phase before exact hit testing](../components/spatial_rect_index_2d.md) | Object IDs, draw order and precision selection |
| Show active input glyphs and prompts | [Use input-source-aware UI adapters](../guides/settings_input_quickstart.md) | Localized action labels and glyph art |
| Show floating damage, healing or collection numbers in a 2D world | [Bound scene-owned Labels and Tweens with configurable presentation](../components/presentation_2d.md) | Confirmed events, text, numeric precision and styles |

## 🟨 World

| What you want to build | Reuse this contract | The game still decides |
| --- | --- | --- |
| Procedural hills, islands and heightmaps | [Use terrain profiles, generation and heightfield preprocessing](../modules/terrain_generation.md) | Biome, geography and terrain art direction |
| Remove heightmap needle peaks | [Apply explicit heightfield slope constraints after shaping](../modules/terrain_heightfield_constraints.md) | Physical slope budget and authored source |
| Mask vegetation, danger or building zones | [Read WorldMask3D scalar textures in world coordinates](../components/world_fields.md) | Meaning of each mask channel |
| Scatter rocks, grass and props deterministically | [Compose region, profile, variants and scatter batches](../modules/scatter_generation.md) | Biome frequency and visual assets |
| Stream regions in and out near the player | [Use lifecycle requests and asynchronous materialization](../components/world_streaming.md) | Interest distances, retention and world topology |
| Stagger scene construction to avoid spikes | [Use materialization jobs and frame budgets](../components/materialization_queue.md) | What work can be incremental |
| Weather, time of day and world clock | [Use world time, schedules and celestial drivers](../components/world_time_environment.md) | Weather states, seasons and climate |
| Dynamic light and shadow quality | [Use lighting/rendering profiles and audits](../components/lighting_shadows_3d.md) | Art direction and platform budgets |
| Footsteps, wet surfaces or impact responses | [Resolve semantic surfaces and dispatch game effects](../components/world_surfaces.md) | Surface library, audio and effects |
| Boat flotation or floating objects | [Use analytical surface sampling plus buoyancy contracts](../components/world_buoyancy.md) | Wave math, boat steering and tuning |
| Footprints, wakes, rain impacts or temporary marks | [Use bounded world stamp buffers and viewport rendering](../components/world_feedback.md) | Stamp textures, shape and response policy |
| Repeated lightweight surface FX | [Use transient surface batches instead of thousands of Nodes](../components/world_scheduling_and_batched_fx.md) | Effect spawning and artistic timing |
| Decals that adapt to uneven ground | [Use smart decals and ground sampling](../components/world_decals.md) | Materials, duration and placement context |
| Choosing a visual/collision LOD | [Use rendering quality and explicit scene-owned policies](../components/rendering_quality.md) | LOD thresholds and hardware targets |
| Place, move or rotate 3D objects during play | [Use PlacementSession3D and existing shape/surface validation](../components/runtime_placement_3d.md) | Assets, costs, permissions and persistent placement records |
| Build a 2D hex board or query hex neighbors | [Use shared axial topology with optional CanvasItem board presentation](../components/hex_grid_2d.md) | Tile assets, turn rules, passability and path costs |
| Build a layered 3D hex board | [Use the XZ adapter and scene-owned board over shared axial topology](../components/hex_grid_3d.md) | Meshes, collision, layer rules and persistence |

## 🟧 Optional modules

| What you want to build | Reuse this contract | The game still decides |
| --- | --- | --- |
| Enemy decision utility and path following | [Compose utility AI with native navigation and scheduled evaluations](../modules/ai_navigation.md) | Behaviors, context scores and factions |
| Carry, stack and equip items | [Use inventory and equipment contracts](../modules/inventory_equipment.md) | Items, slots, restrictions and UX |
| Roll reproducible rewards or procedural drops | [Use loot/probability helpers with server-side authority when online](../modules/probability_loot.md) | Reward tables, rarity and economy |
| Join LAN or host a multiplayer session | [Use network transport/bootstrap helpers](../modules/networking.md) | Authentication, routing and session policy |
| Reconnect after losing a multiplayer connection | [Use network recovery policy and restoration callbacks](../modules/network_recovery.md) | Reauthentication and reconciling game state |
| Estimate server simulation time | [Use network clock sync over an authenticated transport](../modules/network_clock_sync.md) | Trusted timestamps and authority |
| Replicate transform, intent and resolved state | [Use native replication plus intent and snapshot helpers](../modules/online_replication.md) | Validation, prediction and combat outcomes |
| Send only spatially relevant entities per peer | [Use server-owned interest grid and admission controller](../modules/network_interest_management.md) | Authorization and spawn visibility |
| Support achievements and platform features | [Use platform-service provider boundary](../modules/platform_services.md) | Account, store and SDK dependencies |
| Load DLC or data-only community content | [Use content-pack trust boundaries](../modules/content_packs.md) | Content policies and moderation |
| Measure framerate, stutter, memory and work | [Use performance sampler, monitors and reports](../modules/performance.md) | Budget, representative workload and decisions |
| Find expensive code sections and frame hitches | [Use optional section profiling beside native profiler](../modules/performance_sections.md) | Instrumented sections and performance targets |
| Reduce update spikes and node churn | [Use schedulers, reusable physics queries, pool prewarm and the live workload lab](../components/runtime_optimization.md) | Permissible latency and gameplay rules |
| Build safe editor commands | [Use explicit development command registry, never eval](../modules/development_tools.md) | Permitted operations and trust |
| Validate a PackedScene before editor placement | [Inspect stored SceneState without instantiation](../modules/packed_scene_preflight.md) | Shape compatibility and authored metadata |
| Communicate across distant independent systems | [Use optional EventBus only when local signals are insufficient](../modules/event_bus.md) | Event semantics and ownership |
| Capture stable world flags and state | [Use persistent world state with stable IDs](../modules/persistent_world_state.md) | What the world must remember |

## Limits and guardrails

> [!WARNING]
> **Use the listed owner; do not assume a finished game mechanic.**
> Add your own rules, test real gameplay, and keep trust decisions server-side.

- A component is not a finished RPG/MMO/survival/puzzle mechanic; the game wires inputs, state and feedback.
- A valid API call is not a trust decision; authoritative worlds validate requests and visibility.
- A smoke/headless test is not proof of feel, visuals, latency or frame budget on real hardware.
- Generic tools should not replace Godot physics, animation, navigation or UndoRedo.
- Do not add a global manager merely to make a generated mechanic easier to access.
