# Optional Persistent World State Module

## Status

`addons/nucleus/modules/world_state` is optional and is not loaded by default.

It solves a specific cross-scene problem:

```text
stable world identity
+
explicit object state
+
scene reconciliation
+
runtime persistent spawning
```

It does not serialize the SceneTree.

## Why this exists

A normal scene reload recreates authored objects from their `.tscn` defaults.

Without a persistent identity layer, common bugs include:

```text
collected pickups respawn
opened chests close again
destroyed objects return
moved physics props reset
doors forget lock/open state
runtime-spawned actors vanish forever
two identical objects overwrite each other's save data
```

The module separates identity, state, and scene materialization.

## Architecture

```text
NucleusWorldStateService
        ↓
NucleusWorldStateStore
        ↓
region_id
        ↓
persistent_id
        ↓
record

NucleusWorldRegion
        ↓
NucleusWorldEntity
        ↓
NucleusWorldStateAdapter(s)
```

Built-in adapters:

```text
NucleusPropertyStateAdapter
NucleusNodeStateAdapter
NucleusTransform2DStateAdapter
NucleusTransform3DStateAdapter
```

## Cross-scene lifetime

World state only survives full SceneTree scene replacement if its service also
survives.

Recommended options:

```text
persistent GameSession
└── NucleusWorldStateService
```

or intentionally add:

```text
addons/nucleus/modules/world_state/world_state.tscn
```

as an opt-in Autoload such as:

```text
NucleusWorldState
```

Nucleus does not add this Autoload by default.

Unlike EventBus, cross-scene lifetime is intrinsic to this responsibility, so an
intentional game-level Autoload is appropriate when the project uses complete
scene replacement.

## World regions

Every independently persistent world/level scene should contain one
`NucleusWorldRegion`.

Example:

```text
ForestLevel
└── WorldRegion
    region_id = forest
```

`region_id` is part of the save contract.

Do not rename it casually after shipping saves.

Human-readable IDs are valid. A Generate Region ID inspector button is also
provided when UUID-style identity is preferred.

Only one live region with the same ID may be active in one service.

## Authored entity identity

An authored persistent object receives a `NucleusWorldEntity` component.

Example:

```text
Chest
├── ChestScript
└── WorldEntity
    persistent_id = 7c7d...
```

Use the **Generate Persistent ID** inspector button once, then save the scene.

The ID belongs to the placed world object, not to an item type/class.

Two placed chests need different persistent IDs even if both instantiate the
same chest prefab.

A missing/duplicate ID is a configuration error.

## State adapters

WorldEntity does not inspect arbitrary child properties.

State is explicit.

### Property adapter

Useful for small scalar/state-machine values:

```text
is_open
is_locked
activated
health
phase
```

Only listed properties are captured.

Values must be compatible with the save codec selected by the game.

### Node-state adapter

Bridges any Node exposing:

```text
capture_state()
restore_state(state)
```

Existing Nucleus systems already fit this pattern, including:

```text
NucleusInventory
NucleusEquipment
NucleusLootRoller
NucleusAttributeSet
many timing/gameplay components
```

This avoids teaching WorldState about those types.

### Transform adapters

2D and 3D transform adapters serialize numbers/arrays rather than Vector2,
Vector3, Basis, or Transform types.

Their payloads are therefore compatible with Nucleus JSON saves as well as
Binary/Text Variant formats.

Use them for persistent movable actors/props.

## Scene transitions

When a persistent service is alive, regions are discovered as they enter the
SceneTree.

A region entering the world:

1. discovers explicit WorldEntity components inside itself;
2. captures authored defaults as a local baseline;
3. looks up each stable ID in WorldStateStore;
4. restores saved state when present;
5. suppresses records marked removed;
6. respawns missing runtime-persistent scenes.

When an entity exits because its scene is unloaded, it commits its current
state.

Therefore a normal flow becomes:

```text
enter Forest
→ mutate Chest A
→ change to Village
→ Chest A commits to runtime store
→ return to Forest
→ fresh Forest scene loads
→ Chest A restores
```

No disk save is required for state to survive that scene round trip.

## Persistent removal

Never infer permanent destruction from `queue_free()`.

Scene unloading also frees Nodes.

For a pickup, destroyed prop, consumed resource, or one-time enemy use:

```gdscript
world_entity.remove_persistently()
```

This:

```text
marks the stable ID as removed
→ records that status in WorldStateStore
→ frees the target Node
```

When the scene is loaded again, the fresh authored instance is immediately
suppressed.

Plain `queue_free()` does not mean persistent removal.

This distinction prevents scene unloads from accidentally marking an entire
level as destroyed.

## Runtime-spawned persistent objects

A runtime-persistent PackedScene must:

```text
have a resource_path
contain NucleusWorldEntity
usually set runtime_identity_only = true
contain whichever state adapters it needs
```

Spawn through the active region:

```gdscript
var actor := region.spawn_persistent(enemy_scene)
```

WorldRegion generates a UUID and stores:

```text
persistent ID
PackedScene resource path
current adapter state
removed flag
```

When the region is left and later re-entered, that PackedScene is instantiated
again and its stored adapter state is applied.

This is appropriate for long-lived runtime objects such as:

```text
dropped equipment
placed buildables
persistent enemies
vehicles
movable world props
player-created objects
```

Temporary bullets/VFX should not use this system.

## Save integration

WorldStateService exposes:

```text
capture_state()
restore_state()
```

and can register explicitly with `NucleusSaveSession`:

```gdscript
world_state.bind_save_session(
	save_session,
	&"world_state",
)
```

Before capture, active regions commit their live entities.

The store then becomes one normal SaveSession participant.

Because SaveSession retains pending payload for participants that register late,
WorldStateService may bind after a save document has already been applied and
still receive its state.

## Loading while already inside a world scene

The safest production flow is:

```text
load save
→ restore WorldStateStore
→ load/reload the saved world scene
```

This matters because a previously removed authored Node may already have been
freed in the currently running scene.

Reconciliation can update live objects and remove objects immediately, but only
a fresh scene instantiation can recreate authored Nodes that no longer exist.

For title-screen load flows this is naturally satisfied.

For in-game "Load Game", reload/change to the saved scene after successful load.

## Save schema

WorldStateStore uses:

```text
schema_version
regions
  <region_id>
    <persistent_id>
      removed
      dynamic
      scene_path
      state
```

Node references are never stored.

Scene/node paths are never used as authored identity.

The only scene path persisted is the source PackedScene for runtime-spawned
objects that need rematerialization.

## Save migrations

Persistent IDs and region IDs become data-contract keys once a game ships.

If an object is renamed or reparented, no migration is required.

If its persistent ID changes, old saves no longer refer to the same entity.

Treat ID changes like save-schema changes and migrate them deliberately.

## JSON compatibility

Built-in Transform adapters produce arrays/numbers.

Property/Node adapters may capture arbitrary values.

When using Nucleus JSON saves, custom state must remain JSON-compatible because
the JSON codec intentionally rejects Godot-specific Variants instead of silently
changing them.

Binary is the default Nucleus save format and can preserve broader Variant data.

## Multiplayer boundary

WorldState is persistence, not replication.

Authoritative multiplayer should normally maintain this store on the authority.

A replicated object's network identity and its persistent world identity may be
related by game code, but they are not the same contract.

Do not make clients authoritative over persistent removal or runtime spawn
records merely because they know an entity UUID.

## What this module does not own

```text
world streaming/chunk loading
network replication
procedural generation seeds
quest logic
spawn balancing
AI state machines
scene selection after loading a save
backend/cloud persistence
automatic arbitrary-node serialization
```

Those concerns can use stable world IDs without being embedded into this module.
