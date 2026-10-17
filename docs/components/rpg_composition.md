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

## Turn-based composition

Turn ownership stays in the general-purpose [turn scheduler](turn_sessions.md).
Attach `NucleusTurnRequirement` to actions that need an active seat; attach
`NucleusFinishTurnEffect` after their other effects when executing that action
ends the seat's opportunity. `NucleusTurnStatusBinding` advances statuses with
`duration_unit = TURNS` on the chosen discrete clock. These bridges are
optional: real-time combat still works with no turn session.

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

## Encounters and battle outcomes

`NucleusEncounterDirector` owns the wave lifecycle without spawning scenes.
`register_instance(instance_id, participant_id)` associates a concrete
enemy with a wave slot. `mark_instance_defeated(instance_id)` consumes that
slot once and rejects duplicated death notifications. Legacy
`mark_defeated(participant_id, count)` remains available for authoritative
aggregate reports. Use only one reporting method per instance.

`NucleusEncounterCombatant` listens to a health ValuePool's `depleted`
signal and emits stable instance/participant IDs. Connect this signal to
the director; pooled actors must call `reset_defeat()` on reacquisition.
For 2D and 3D actor spawning, consume `wave_requested` with the existing
`NucleusSpawner` and call `register_instance` for each spawned actor.
Keep a per-instance map to safely release pooled instances when defeated.

`finish_encounter("victory" | "defeat" | "retreat")` and
`cancel_encounter()` terminate an active encounter. A natural last-wave
completion emits `encounter_completed` and
`encounter_ended(id, "victory")`; defeat and retreat emit only
`encounter_ended`. Ending clears pending wave instances. The game decides
when a player party has been defeated or has escaped.

`NucleusEncounterReward` grants experience from a ProgressionTrack and
optionally rolls loot on victory, not on defeat/retreat/cancel. Save the
reward claim and the director state together to prevent replaying loot
after loading. The game owns item delivery, inventory capacity and
authoritative reward grants; the LootRoller emits generated results.

`capture_state` / `restore_state` save stable wave counts and instance
IDs, not live nodes. Restoring an active wave requires recreating or
reattaching its actors explicitly. Restoration is refused while a
session is already running; invalid data is rejected without modifying
the director.

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

## End-to-end acceptance

Open `tests/smoke/rpg_battle_smoke.tscn` in the editor and press F6, or use
`godot --headless --path . res://tests/smoke/rpg_battle_smoke.tscn`.
It composes the real action, rank gate, mana cost, damage resolver, shields,
interrupt channel, XP track and two encounter waves into one in-process
fixture with explicit PASS/FAIL diagnostics. It does not simulate enemy AI,
networked authority, status turn counters or an RPG UI.

## Checks
`tests/headless/advanced_combat_contracts_test.gd` and
`tests/headless/rpg_contracts_test.gd` exercise narrow behavior contracts.
These tests need an actual Godot headless execution to claim a pass.
