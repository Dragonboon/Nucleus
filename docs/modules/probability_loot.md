# Optional Probability / Loot Module

`addons/nucleus/modules/loot` provides reusable loot-table semantics on top of Godot's native
`RandomNumberGenerator`. It does not wrap or replace general PRNG functionality.

## Architecture

```text
NucleusLootCondition
        ↓
NucleusLootEntry
        ↓
NucleusLootTable
        ↓
RandomNumberGenerator

NucleusLootState
        ↑
NucleusLootRoller
        ↓
NucleusLootResult
```

No loot Autoload exists and shared table Resources remain immutable configuration.
Cross-roll unique state belongs to `NucleusLootState`, not mutation of the table
asset.

## Entry and roll semantics

Entries can define stable IDs, payload Resources, enablement, guaranteed/chance/
weight semantics, uniqueness, amount ranges, tags and conditions.

Supported random modes include weighted selection and independent chance. Chance
boundaries are explicit (`<= 0` never, `>= 1` always). Guaranteed entries are
resolved before random selection and may optionally count toward the random
result limit.

`allow_duplicate_entries` governs duplicates inside one roll call. Persistent
uniqueness uses `unique + NucleusLootState`.

## Determinism

`NucleusLootRoller` owns an RNG plus unique state and can capture/restore both RNG
seed/state and consumed unique IDs for exact continuation on the supported Godot
runtime.

Do not make network protocols depend on clients reproducing the engine's exact
PRNG sequence. In authoritative multiplayer, roll on the authority and replicate
resolved results.

## Integration

Loot payload is any Resource. The module does not depend on Inventory; when both
modules are enabled, game code decides how results enter inventory and what
happens to overflow.

Conditions are side-effect-free extension points over game-owned context such as
biome, difficulty, quest state or world phase.

## Not owned by this module

```text
rarity / luck / pity formulas
loot UI
pickup spawning
inventory overflow policy
crafting / economy
party/backend reward policy
replication protocol
```
