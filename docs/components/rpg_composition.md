# RPG-neutral composition contracts

This family is **mechanism only**, not a battle manager or a ruleset.

## Action / combat / progression adapters

`NucleusApplyDamageEffect` is a synchronous GameplayAction effect. It can use
an explicitly assigned `NucleusDamageResolver` or resolve a single resolver
under the node supplied as `context["target"]`. Ambiguous targets are refused.
Immunity remains a valid paid attack result, surfaced through `hit_processed`;
a malformed damage rule still fails the committed action (no rollback).

`NucleusDamageInterruptBinding` listens for resolved health damage (optionally
shield absorption) and interrupts an attached ActionChannel at a configured
minimum amount/priority. It never bypasses that channel's priority rules.

`NucleusUnlockRequirement` gates standalone actions on a learned rank and
notifies availability listeners on a graph change. Slots in AbilityLoadout
perform their own checks as an additional defense.

## Damage and reactions
See [gameplay foundation](gameplay_foundation.md) and [actions](gameplay_actions_attributes_status.md).
Damage and shields are handled by DamageResolver, while ActionChannel/ReactionCoordinator
add cancellable windups and explicitly triggered reactions. Event timing and player
authority are the consuming game's responsibility.

## Progression
`NucleusProgressionDefinition` defines cumulative XP thresholds for levels 2..N.
`NucleusProgressionTrack` stores XP and level, not rewards. `grant_experience`
rejects negative grants and integer overflow. Invalid or nonincreasing thresholds
are rejected. Store one track per independent progression axis.

`NucleusUnlockGraph` consumes `NucleusUnlockDefinition` nodes: ranks, prerequisites,
minimum level, exclusive groups and fixed cost per rank. It rejects invalid
references and cycles; `unlock` consumes points only after validation. Rank IDs
are stable; UI positions, skill effect scaling and point/reward policy belong in
the game. `capture_state` / `restore_state` provide data-only snapshots. Reset
with `reset_unlocks`; refunds are based on the currently authored cost.

`NucleusAbilityLoadout` assigns known `NucleusGameplayAction` IDs to named
slots. It can require an unlock rank with the same ID, and rechecks on execution.
Saved slot IDs must be restored after the ActionSet registry and graph are ready.
Changing learned ranks does not automatically delete a slot assignment.

## Encounters
`NucleusEncounterDefinition` holds ordered `NucleusEncounterWave` resources,
each with participant IDs and counts. `NucleusEncounterDirector` emits
`wave_requested(index, participants)`, then waits for authoritative calls to
`mark_defeated(id, count)`. It emits `encounter_completed` after the last
wave. The director does *not* spawn scenes, determine whether an actor is dead,
perform RNG selection, assign teams, or roll rewards. The game connects these
signals to the existing Spawner, AI, targeting, Loot and save adapters.
Duplicate IDs within a wave are accumulated. Do not treat `mark_defeated` as a
network-trusted input.

## Persistence and limits
Persist only stable IDs, integer amounts, assigned slots, and serializable
snapshots. Save the whole RPG actor atomically through the game's save owner;
the contracts do not coordinate cross-component atomic restoration. There
is no built-in turn scheduler, status duration measured in rounds, or
cross-actor reaction stack. Those should be added only when needed as separate
clock/arbiter contracts.

## Checks
`tests/headless/advanced_combat_contracts_test.gd` and
`tests/headless/rpg_contracts_test.gd` exercise narrow behavior contracts.
These tests need an actual Godot headless execution to claim a pass.
