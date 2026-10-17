# Gameplay Actions, Attributes, and Status Effects Contract

## Scope

```text
components/gameplay/actions
components/gameplay/attributes
components/gameplay/status
```

These systems form Nucleus's reusable gameplay transaction/modifier layer.

## GameplayAction pipeline

The committed action pipeline is:

```text
requirements
→ costs
→ effect prevalidation
→ pay
→ cooldown
→ commit
→ effects
```

This ordering matters. Requirements and effect prevalidation happen before
payment. Once the action reaches commit, effects execute against the committed
context.

Actions support source-owned blockers and context providers. This allows
equipment, targeting, status effects, AI, or a game-specific producer to add
context without turning GameplayAction into a dependency hub.

Representative extension contracts include:

```text
NucleusActionRequirement
NucleusActionCost
NucleusActionEffect
NucleusActionContextProvider
```

Prefer a new small requirement/cost/effect Resource or Node over subclassing the
entire action execution pipeline.

## Optional channel and reaction contracts

`NucleusActionChannel` adds a windup and recovery around one synchronous
`NucleusGameplayAction`. Windup interruption prevents the action from paying
costs or committing effects. Recovery interruption cannot undo a committed
action; it only ends the remaining recovery period. `interrupt_action(priority,
reason)` enforces the channel's minimum interruption priority, and `advance()`
allows deterministic manual clocking alongside normal `_process`.

`NucleusReactionCoordinator` maps explicit event IDs and optional timed/manual
windows to registered actions via `NucleusReactionDefinition`. Higher-priority
reactions are tried first, retaining authored order for ties. A reaction validates
the candidate action before requesting an interruption and executing the
reaction; callers own the event timing, permissions, and networking authority.
A lower-priority reaction cannot interrupt an active channel. These contracts
do not add a global battle manager or a rollback engine.

The existing `GameplayAction` cost refund applies to a failed cost payment.
After a successful commit, a failed effect does **not** roll back earlier effects,
costs, or cooldown. Keep committed effects predictably successful, or introduce
an explicit game-owned compensation policy.

For RPG-neutral unlocks, ability slot assignment and XP tracks, see
[`rpg_composition.md`](rpg_composition.md).

Use `NucleusApplyDamageEffect` for target-scoped damage through the existing
DamageResolver; it does not bypass mitigation/shield rules. See
[RPG composition](rpg_composition.md).

## Discrete turns and status lifetimes

Turn requirements and end-of-turn action effects live in
[generic turn sessions](turn_sessions.md). A status definition can now opt into
`DurationUnit.TURNS` while the default remains seconds. Its container advances
turn-based effects only via `advance_turns()` or an explicit
`NucleusTurnStatusBinding`; real-time `_process` skips those effects.
Turn-based tick intervals must be whole numbers. For action ordering, place a
turn-finishing effect after damage and status effects; effects already committed
are not rolled back on failure.

## Attributes

Attributes represent runtime numeric values derived from a base plus modifiers.

Modifier ownership is source-based. A producer can add modifiers and later
remove exactly the modifiers it owns.

This is important for clean composition:

```text
StatusEffect source
Equipment source
temporary buff source
game-specific source
→ Attribute
```

Bindings project attribute values onto engine/gameplay properties without
making the attribute system own those consumers.

`NucleusValuePoolAttributeBinding` uses `ValuePool.set_limits()` so pool clamping
and signals remain authoritative.

## Status effects

Status effects are one producer of modifiers and periodic behavior.

The container owns active effect instances, duration/stacking state, and removal.
Definitions describe reusable effect policy.

Periodic pool changes are performed through the existing ValuePool API rather
than writing pool internals.

## Ownership and cleanup

Blockers, context, and modifiers must be removed by the source that added them.
This prevents orphaned state after equipment removal, effect expiry, pooling, or
scene teardown.

## Persistence

Persist durable gameplay state at the game layer using stable IDs and plain data.
Do not serialize live Node references, Callables, timers, or modifier-source
objects directly.

## Extension rule

If a new mechanic can be expressed as a requirement, cost, effect, context
provider, modifier source, or status definition, extend that seam instead of
adding another central gameplay manager.
