# Probability / Loot Quickstart

## 1. Create loot entries

Create `NucleusLootEntry` Resources.

Example common item:

```text
entry_id       = scrap
weight         = 8.0
minimum_amount = 1
maximum_amount = 4
```

Example rare item:

```text
entry_id = reactor_core
weight   = 0.5
unique   = true
```

Assign any Resource to `payload`.

When Inventory is enabled, a `NucleusItemDefinition` is a natural payload.

## 2. Create a table

Create `NucleusLootTable`:

```text
roll_mode               = WEIGHTED
rolls                    = 3
allow_duplicate_entries  = false
maximum_random_results   = 0
```

Add the entry Resources.

The table is design data and should be safely shareable.

## 3. Add a scene-owned roller

Example enemy:

```text
Enemy
└── LootRoller : NucleusLootRoller
```

Assign the table.

For normal gameplay:

```text
seed_mode = RANDOMIZED
```

For deterministic validation/procedural runs:

```text
seed_mode  = FIXED
fixed_seed = 12345
```

Generate:

```gdscript
var results: Array[NucleusLootResult] = (
	loot_roller.generate()
)
```

## 4. Weighted mode

`WEIGHTED` performs one weighted pick per configured roll.

Example:

```text
scrap        weight = 10
medkit       weight = 3
reactor_core weight = 0.2
```

Nucleus delegates the actual weighted index choice to Godot's
`RandomNumberGenerator.rand_weighted()`.

Weight `0` means the entry cannot be selected randomly.

## 5. Independent chance mode

Use:

```text
roll_mode = INDEPENDENT_CHANCE
```

Then each candidate uses its `chance`.

Example:

```text
ammo    chance = 0.75
medkit  chance = 0.20
key     chance = 0.05
```

`rolls = 1` evaluates that set once.

Higher rolls repeat the independent checks.

## 6. Guaranteed rewards

Set:

```text
guaranteed = true
```

for something that must always appear when eligible.

Typical examples:

```text
boss quest key
mission token
minimum currency reward
tutorial item
```

Guaranteed entries are emitted before random results.

## 7. Unique rewards

Set:

```text
unique = true
```

and use a `NucleusLootRoller`.

The roller owns `NucleusLootState`, so once that entry is selected it remains
consumed for that owner.

A shared table therefore remains unchanged.

## 8. Conditions

Subclass `NucleusLootCondition`.

Example:

```gdscript
class_name GameDifficultyLootCondition
extends NucleusLootCondition

@export var minimum_difficulty: int = 2


func check(context: Dictionary) -> bool:
	return (
		int(context.get("difficulty", 0))
		>= minimum_difficulty
	)
```

Then:

```gdscript
loot_roller.generate({
	"difficulty": current_difficulty,
})
```

Conditions should not mutate gameplay state.

## 9. Add results to Inventory

When the payload is an item definition:

```gdscript
for result: NucleusLootResult in loot_roller.generate():
	if not result.payload is NucleusItemDefinition:
		continue

	var accepted: int = inventory.add_item(
		result.payload as NucleusItemDefinition,
		result.amount,
	)

	var overflow: int = result.amount - accepted

	if overflow > 0:
		_handle_loot_overflow(result, overflow)
```

Overflow policy belongs to the game.

## 10. Save exact runtime state

Register a roller with `NucleusSaveSession`:

```gdscript
save_session.register_participant(
	&"boss_loot",
	loot_roller.capture_state,
	loot_roller.restore_state,
)
```

This preserves:

```text
PRNG seed
PRNG state
consumed unique entry IDs
```

The next roll after loading therefore continues from the saved sequence.

## 11. Multiplayer

Roll authoritative rewards only on the authority/server.

Recommended:

```text
kill/container event
→ server LootRoller.generate()
→ server updates Inventory/world reward
→ replicate resolved result/state
```

Do not send a seed to an untrusted client and accept its claimed result as
authoritative.

## 12. Rarity

Nucleus deliberately has no rarity enum.

A game can represent rarity through:

```text
entry tags
definition metadata/subclass
different tables
weights
game-specific Resources
```

This avoids baking one RPG progression model into a general addon.
