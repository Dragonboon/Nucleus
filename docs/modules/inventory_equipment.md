# Optional Inventory and Equipment Module

`addons/nucleus/modules/inventory` is optional and scene-owned. It separates immutable item
definitions from mutable runtime stacks and keeps inventory/equipment ownership
local to the actor/container that owns it.

## Data model

```text
NucleusItemDefinition
    immutable design metadata
        ↓
NucleusItemStack
    stack_id + amount + game-owned state
        ↓
NucleusInventory
    scene-owned runtime storage
```

Definitions expose stable item identity, display metadata, stack size, unit
weight and tags. They intentionally do not impose weapon/material/rarity/crafting
enums; games may use tags or subclasses for their own taxonomy.

Stacks merge only when item identity, runtime state and stackability are
compatible. Non-stackable items naturally remain individually addressable by
stable `stack_id`.

## Inventory and equipment

`NucleusInventory` can enforce optional slot/weight capacity. Zero means
unlimited. It is not an Autoload; players, chests, vendors and vehicles may each
own normal inventory Nodes.

`NucleusEquipment` uses game-authored slot IDs and filters. Equipped inventory
items may reference exact stack IDs while remaining in the inventory. This avoids
forcing one universal "equipped items leave the bag" policy.

Equipment modifiers compose with `NucleusAttributeSet` through source-owned
modifier IDs so one producer does not erase another producer's effects.

## Actions and persistence

Reusable GameplayAction requirements/costs support fungible item quantities.
Unique/stateful instance selection remains a game-specific cost when necessary.

Inventory and equipment expose `capture_state()` / `restore_state()` and should
be registered explicitly with `NucleusSaveSession`. Restore Inventory before
Equipment when Equipment depends on restored stack IDs.

Restore preserves existing owned items even if later balance changes reduce
capacity; load should not silently delete player data. Missing item IDs are
reported for migration/diagnosis.

## Networking boundary

The module defines no RPCs. In authoritative multiplayer, the authority validates
mutations, changes the scene-owned inventory/equipment state and the game's
replication layer sends resolved state/deltas.

## Not owned by this module

```text
inventory UI / drag-drop / grid layouts
crafting / shops / economy
loot generation / world pickup spawning
durability and weapon behavior
rarity taxonomy / item-use effects
network authority and replication protocol
```
