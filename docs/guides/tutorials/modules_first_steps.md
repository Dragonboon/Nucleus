# Tutorial: first steps with optional Nucleus modules

Optional modules are not Autoloaded by default.

Add one only when the game needs its capability.

The rule is:

```text
Core/components
    reusable baseline

addons/nucleus/modules/*
    opt-in systems with a real project cost/benefit decision
```

## 1. EventBus: publish a genuinely decoupled event

Use EventBus when producer and consumer should not naturally reference each
other.

Do not use it instead of a local signal.

### Add the module

Instance:

```text
res://addons/nucleus/modules/event_bus/event_bus.tscn
```

inside the scene/session that should own it.

Promote it to an Autoload only if events truly need cross-scene lifetime.

### Subscribe

```gdscript
func _ready() -> void:
    event_bus.subscribe(
        &"boss_defeated",
        _on_boss_defeated,
    )


func _exit_tree() -> void:
    event_bus.unsubscribe(
        &"boss_defeated",
        _on_boss_defeated,
    )


func _on_boss_defeated(boss_id: StringName) -> void:
    print("Boss defeated: ", boss_id)
```

### Publish

```gdscript
event_bus.publish(
    &"boss_defeated",
    &"harbor_mutant",
)
```

A tutorial system/achievement layer is a reasonable consumer because the boss
does not need to know about those systems.

## 2. Networking: host and join

Add:

```text
Network : NucleusNetworkHandler
```

from:

```text
res://addons/nucleus/modules/networking/network_handler.tscn
```

For a native ENet host:

```gdscript
var error: Error = network.start_enet_server(
    42069,
    8,
)

if error != OK:
    push_error(error_string(error))
```

For a native client:

```gdscript
var error: Error = network.start_enet_client(
    "127.0.0.1",
    42069,
)
```

Close the session with:

```gdscript
network.shutdown()
```

This module owns transport/peer lifecycle.

It does **not** decide:

```text
gameplay RPCs
authority
replication schema
authentication
lobbies
matchmaking
```

See the online replication guide before synchronizing gameplay state.

## 3. Inventory: create storage and add an item

Create:

```text
Player
└── Inventory : NucleusInventory
```

Create `NucleusItemDefinition` Resources and a `NucleusItemCatalog`.

Assign the catalog to Inventory.

Add:

```gdscript
var ammo := inventory.get_definition(&"ammo_9mm")

var accepted: int = inventory.add_item(
    ammo,
    24,
)
```

Always use the returned amount when capacity may reject part of the request.

Read the full walkthrough:

[`../inventory_equipment_quickstart.md`](../inventory_equipment_quickstart.md)

## 4. Equipment: reference inventory identity, do not clone item state

Create:

```text
Player
├── Inventory
├── Attributes
└── Equipment
```

Define slots and equipment item definitions.

Equip a runtime inventory stack:

```gdscript
var stack: NucleusItemStack = inventory.get_stacks()[0]

var error: Error = equipment.equip_inventory_stack(
    &"main_hand",
    stack.stack_id,
)
```

Equipment can own attribute modifier sources while Inventory remains the storage
authority.

## 5. Loot: produce results, then decide what the game does with them

Create:

```text
Enemy
└── LootRoller : NucleusLootRoller
```

Assign a `NucleusLootTable`.

Generate:

```gdscript
var results: Array[NucleusLootResult] = loot_roller.generate()
```

Loot does not require Inventory.

If the payload is an item definition, the game may pass the result into
Inventory.

Keep:

```text
random selection
storage
world drop presentation
overflow policy
```

as separate responsibilities.

Read:

[`../loot_quickstart.md`](../loot_quickstart.md)

## 6. Persistent World State: make scene reloads remember authored entities

Use this module for things such as:

```text
opened chest
destroyed unique object
unlocked door
collected authored pickup
changed world switch
```

The world-state service must outlive level scenes when those scenes are
replaced.

A common ownership shape is:

```text
GameSession
├── SaveSession
├── WorldStateService
└── LoadedLevel
```

Give persistent entities stable IDs and explicit state adapters.

Do not use transient NodePaths as durable identity.

Read the complete setup:

[`../persistent_world_quickstart.md`](../persistent_world_quickstart.md)

## 7. AI + Navigation: decision chooses, navigation moves

A typical enemy:

```text
Enemy
├── NavigationAgent2D/3D
├── NavigationFollower2D/3D
├── TargetingAgent
├── UtilityBrain
├── StateMachine
└── AIStateMachineBridge
```

Responsibility split:

```text
UtilityBrain
    chooses intention

StateMachine
    owns current behavioral state

NavigationAgent/Follower
    pathfinds and moves

TargetingAgent
    supplies candidate/target information

GameplayAction
    executes attack/ability transaction
```

Do not put movement, animation, and attack effects directly inside the Utility
score calculation.

Read:

[`../ai_navigation_quickstart.md`](../ai_navigation_quickstart.md)

## 8. Online replication: send intent, mutate on authority

A useful starting flow is:

```text
client input
→ intent request
→ server admission/validation
→ authoritative gameplay action/state mutation
→ replicated state or transform snapshot
→ remote presentation
```

Use Godot's:

```text
MultiplayerSpawner
MultiplayerSynchronizer
```

for native replication where they fit.

Use Nucleus intent/transform helpers only for the additional repeated behavior
they own.

Read:

[`../online_replication_quickstart.md`](../online_replication_quickstart.md)

## 9. Platform Services: keep store SDKs out of gameplay

Gameplay should depend on a provider-neutral platform boundary.

The game then selects an adapter for:

```text
standalone
Steam-like provider
Epic-like provider
console provider
```

based on the project/export.

Do not import a storefront SDK throughout unrelated gameplay scripts.

Read:

[`../platform_services_quickstart.md`](../platform_services_quickstart.md)

## 10. Module adoption checklist

Before enabling a module:

1. What real game requirement needs it?
2. Which scene/service owns its lifetime?
3. Is an Autoload actually required?
4. What native Godot API remains authoritative?
5. What data must be saved?
6. What is server-authoritative, if networked?
7. What project-specific policy should stay outside the module?
8. Can the module be removed without breaking unrelated systems?

## Related docs

- [`../optional_modules_quickstart.md`](../optional_modules_quickstart.md)
- [`../../modules/event_bus.md`](../../modules/event_bus.md)
- [`../../modules/networking.md`](../../modules/networking.md)
- [`../../modules/inventory_equipment.md`](../../modules/inventory_equipment.md)
- [`../../modules/probability_loot.md`](../../modules/probability_loot.md)
- [`../../modules/persistent_world_state.md`](../../modules/persistent_world_state.md)
- [`../../modules/ai_navigation.md`](../../modules/ai_navigation.md)
- [`../../modules/online_replication.md`](../../modules/online_replication.md)
- [`../../modules/platform_services.md`](../../modules/platform_services.md)
