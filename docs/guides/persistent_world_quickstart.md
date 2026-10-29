# Persistent World State Quickstart

This guide is the recommended day-one setup for a game whose world changes must
survive scene transitions and save/load.

## 1. Keep WorldState alive

If your game uses full scene replacement through `NucleusSceneFlow` or
`SceneTree.change_scene_*()`, add:

```text
addons/nucleus/modules/world_state/world_state.tscn
```

as an **optional** Autoload named, for example:

```text
NucleusWorldState
```

This is one of the few responsibilities where cross-scene lifetime is intrinsic.

Alternatively, place `NucleusWorldStateService` under a persistent GameSession
Node that is not replaced with the level.

Do not place it inside a level that will be freed.

## 2. Bind it to the save session

When your game session creates/owns `NucleusSaveSession`:

```gdscript
NucleusWorldState.bind_save_session(
	save_session,
	&"world_state",
)
```

If WorldState lives under GameSession instead of an Autoload, call the same
method through that node reference.

This is explicit registration; `NucleusSave` still does not scan gameplay.

## 3. Give every persistent scene a region ID

Example level:

```text
Forest
├── WorldRegion : NucleusWorldRegion
├── PlayerSpawn
├── Chest
└── IronOrePickup
```

Configure:

```text
WorldRegion.region_id = forest
```

Keep that ID stable once saves exist.

For a small game, names such as:

```text
island_01
village
dungeon_mine
ship_interior
```

are perfectly valid.

## 4. Give authored objects stable IDs

Add the component as a child:

```text
Chest
├── ChestController
└── WorldEntity : NucleusWorldEntity
```

Select `WorldEntity` and press:

```text
Generate Persistent ID
```

Save the scene.

Never regenerate that ID casually after shipping.

Each placed instance needs a distinct ID.

## 5. Persist a simple door/chest property

Suppose your chest script exposes:

```gdscript
var is_open: bool = false
```

Compose:

```text
Chest
├── ChestController
└── WorldEntity
    └── Properties : NucleusPropertyStateAdapter
```

Configure:

```text
adapter_id = chest
target = Chest
properties = [is_open]
```

No special Save code is required in the chest.

When leaving the scene, `is_open` is captured.

When returning, the new chest instance receives the saved value.

## 6. Persist an Inventory or LootRoller

Existing Nucleus state owners already expose capture/restore.

Example chest:

```text
Chest
├── Inventory : NucleusInventory
├── LootRoller : NucleusLootRoller
└── WorldEntity
    ├── InventoryState : NucleusNodeStateAdapter
    └── LootState : NucleusNodeStateAdapter
```

Configure:

```text
InventoryState
  adapter_id = inventory
  target = Inventory

LootState
  adapter_id = loot
  target = LootRoller
```

Both default to:

```text
capture_state
restore_state
```

Opening the chest, generating loot, leaving the scene, and returning now keeps
both its contents and unique/RNG loot state.

## 7. Persist movement

For a movable 3D object:

```text
Crate
└── WorldEntity
    └── Transform : NucleusTransform3DStateAdapter
```

Configure:

```text
adapter_id = transform
target = Crate
use_global_transform = true
```

For 2D use `NucleusTransform2DStateAdapter`.

These adapters store numeric arrays so their state also works with the JSON save
codec.

## 8. Permanently collect/destroy something

For a one-time pickup:

```gdscript
func collect() -> void:
	grant_reward()
	world_entity.remove_persistently()
```

Do **not** do only:

```gdscript
queue_free()
```

`queue_free()` means:

```text
this Node disappears now
```

`remove_persistently()` means:

```text
this world identity must stay absent when this region is loaded again
```

That distinction is the core lifecycle rule.

## 9. Persistent runtime spawn

A scene intended to survive later region visits can contain:

```text
DroppedSword
├── WorldEntity
│   runtime_identity_only = true
│   ├── Transform
│   └── Inventory/CustomState adapter
└── visuals/physics/etc.
```

It must be saved as a real `.tscn`.

Spawn it through the region:

```gdscript
var dropped_sword := region.spawn_persistent(
	dropped_sword_scene
)
```

The region assigns a runtime UUID and records the scene resource path.

Later:

```text
leave region
→ runtime object state is captured
→ return
→ PackedScene is re-instantiated
→ same UUID/state is restored
```

Use this for genuinely persistent runtime objects, not projectiles or effects.

## 10. Saving

Normal SaveSession capture is enough once WorldState is bound:

```gdscript
save_session.save_manual()
```

Before the snapshot is built, WorldState commits all currently live regions.

You do not need to manually save every chest or door.

## 11. Loading from the title screen

Recommended sequence:

```text
create GameSession / WorldState
→ create/bind SaveSession
→ load save document
→ choose saved level
→ enter level
→ WorldRegion appears
→ persistent objects reconcile
```

`NucleusSaveSession` also supports the reverse bind order because it retains
pending participant payload.

## 12. In-game Load Game

For a robust implementation:

```text
load snapshot
→ WorldState restores database
→ reload/change to the saved world scene
```

The reload matters if the current runtime previously freed an authored object
that should exist in the loaded save.

`NucleusSceneFlow.reload_current_scene()` is suitable when the save belongs to
the current level.

## 13. New game

Clear persistent runtime data before entering the first gameplay region:

```gdscript
NucleusWorldState.clear_state()
```

Then load the initial world scene.

Do not clear it merely when moving between levels.

## 14. Identity rules worth enforcing from day one

Treat these like database primary keys:

```text
region_id
persistent_id
```

Safe changes:

```text
renaming a Node
moving it under another parent
changing its SceneTree path
renaming display text
```

Breaking save identity:

```text
regenerating persistent_id
changing region_id
duplicating a placed entity without giving the copy a new ID
```

The region reports duplicate-ID configuration warnings.

## 15. Recommended persistent object composition

A real chest may end up as:

```text
Chest
├── ChestController
├── Inventory
├── LootRoller
└── WorldEntity
    ├── DoorState      : PropertyStateAdapter
    ├── InventoryState : NodeStateAdapter
    └── LootState      : NodeStateAdapter
```

That is the intended Nucleus architecture:

```text
the object owns gameplay
WorldEntity owns stable identity
adapters explicitly describe persistent slices
WorldRegion owns scene reconciliation
WorldStateService owns cross-scene runtime records
SaveSession owns disk snapshot coordination
```

No layer needs to serialize or understand the entire object graph.
