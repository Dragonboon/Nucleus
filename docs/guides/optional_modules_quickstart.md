# Optional Modules Quickstart

This page is the module selection map.

For a first-use recipe for every optional module, see:

[`tutorials/modules_first_steps.md`](tutorials/modules_first_steps.md)

## Performance / Diagnostics

Use `addons/nucleus/modules/performance` when the project needs continuous lightweight
performance visibility, configurable target budgets, trace markers, and
human-readable routing into Godot's native profiling tools.

Fastest setup:

```text
res://addons/nucleus/modules/performance/performance_panel.tscn
```

The module reads native `Performance` monitors and can publish summary/custom
monitors back into Godot Debugger. It does not replace the Profiler, Network
Profiler, Video RAM panel, or GPU profilers.

Budgets are game-owned. Do not invent low-end hardware requirements merely
because the module can express them.

See:

```text
docs/guides/performance_quickstart.md
docs/guides/tutorials/performance_profiling.md
docs/modules/performance.md
```

## Procedural Terrain Generation

Use `addons/nucleus/modules/terrain` when the project wants fast heightfield terrain generation
from noise, heightmaps, or grayscale images without adopting manual terrain
painting as the core workflow.

Typical authored ownership:

```text
World
└── Terrain : NucleusTerrainGenerator3D
```

Reusable Resources separate:

```text
height / geometry / collision profile
world layout (single, grid, linear, islands)
procedural terrain material layers
```

For continuous traversal, `NucleusTerrainStreamer3D` keeps a linear chunk window
around a tracked Node3D.

The module uses native `ArrayMesh`, `HeightMapShape3D`, `FastNoiseLite`, and
ShaderMaterial. It is not a replacement for dedicated sculpt/paint tools such as
Terrain3D or TerraBrush.

See:

```text
docs/guides/terrain_generation_quickstart.md
docs/guides/tutorials/procedural_terrain_3d.md
docs/modules/terrain_generation.md
```

## EventBus

Use the EventBus only when you intentionally need mediator semantics.

Add `addons/nucleus/modules/event_bus/event_bus.tscn` to the scope that should own it. Promote
it to an Autoload only for genuine cross-scene events.

Prefer a normal signal for direct/local relationships.

## Networking

Add `addons/nucleus/modules/networking/network_handler.tscn` to the scope that should own peer
lifecycle, or configure it as an Autoload in a game that genuinely needs
cross-scene connection lifetime.

Choose transport explicitly:

```text
ENet
    native desktop/server use

WebSocket
    browser-compatible client path
```

The module does not implement gameplay replication, RPC design, authentication,
lobbies, or matchmaking.

## Inventory / Equipment

`addons/nucleus/modules/inventory` is data/runtime infrastructure and does not require an
Autoload.

Typical ownership:

```text
Player
├── Inventory
└── Equipment

Chest
└── Inventory
```

See:

```text
docs/guides/inventory_equipment_quickstart.md
```

## Probability / Loot

`addons/nucleus/modules/loot` uses Godot's native `RandomNumberGenerator` and adds reusable
loot-table semantics.

Typical ownership:

```text
Enemy
└── LootRoller

Chest
└── LootRoller
```

Loot does not require Inventory.

See:

```text
docs/guides/loot_quickstart.md
```

## Persistent World State

`addons/nucleus/modules/world_state` gives authored/runtime world objects stable identity and
explicit cross-scene state.

If the game replaces whole level scenes, its `NucleusWorldStateService` must live
outside those scenes.

Use either:

```text
persistent GameSession
```

or intentionally add:

```text
addons/nucleus/modules/world_state/world_state.tscn
```

as an opt-in Autoload.

This service is not added to the default Nucleus project.

See:

```text
docs/guides/persistent_world_quickstart.md
```

## AI / Navigation

`addons/nucleus/modules/ai` composes Utility AI with Godot `NavigationAgent2D/3D`.

It intentionally reuses:

```text
NucleusTargetingAgent
NucleusStateMachine
Godot NavigationServer
```

instead of introducing another perception system, another FSM, or custom
pathfinding.

Typical 3D ownership:

```text
Enemy
├── NavigationAgent3D
├── NavigationFollower3D
├── TargetingAgent
├── UtilityBrain
├── StateMachine
└── AIStateMachineBridge
```

There is no AI Autoload.

See:

```text
docs/guides/ai_navigation_quickstart.md
```

## Online Gameplay Replication

`addons/nucleus/modules/networking/replication` complements Godot's native multiplayer
replication instead of replacing it.

Use:

```text
MultiplayerSpawner
    spawn / despawn

MultiplayerSynchronizer
    discrete replicated state

NucleusNetworkIntentChannel
    client → server gameplay requests

NucleusNetworkTransformReplicator2D/3D
    optional remote transform smoothing
```

The default contract is server-authoritative.

See:

```text
docs/guides/online_replication_quickstart.md
```

## Platform Services

`addons/nucleus/modules/platform_services` provides only:

```text
provider lifecycle
local platform identity
capability discovery
standalone fallback
```

It has no dependency on GodotSteam, EOS, or console SDKs.

A game integrates those through a thin `NucleusPlatformProvider` adapter.

See:

```text
docs/guides/platform_services_quickstart.md
```

## Content Packs / DLC / community mods

`addons/nucleus/modules/content_packs` separates trusted Godot resource packs from untrusted
community data.

Use signed resource packs for:

```text
official patches
official DLC
explicitly trusted executable packs
```

Use the data-mod path for community content:

```text
JSON / CSV / text by default
strict path/size/extension policy
no load_resource_pack()
no ResourceLoader
```

Do not auto-mount arbitrary `.pck` files discovered in a mods folder.

See:

```text
docs/guides/content_packs_quickstart.md
docs/modules/content_packs.md
```

## Mobile Foundation

`addons/nucleus/modules/mobile` and `addons/nucleus/components/ui/touch` complete the missing mobile policy
without creating a second gameplay input framework.

Use:

```text
NucleusVirtualStick
NucleusTouchActionButton
NucleusTouchLookArea
NucleusHaptics
NucleusMobileOrientationPolicy
NucleusMobilePermissions
```

Touch controls feed the same semantic InputMap actions used by keyboard/gamepad.

Existing `NucleusApp`, `NucleusUISafeArea`, and `NucleusUIBreakpoints` remain the
lifecycle/layout foundation.

See:

```text
docs/guides/mobile_quickstart.md
docs/modules/mobile.md
```

## Keep optional modules optional

The default Nucleus `project.godot` intentionally does not load these modules.

A game that does not use one should pay no runtime architectural cost for it.

For concrete first-use code and scene ownership, continue with:

[`tutorials/modules_first_steps.md`](tutorials/modules_first_steps.md)
