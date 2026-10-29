# Pooling, Spawning, Targeting, and Sensing Contract

## Scope

```text
addons/nucleus/components/gameplay/pooling
addons/nucleus/components/gameplay/targeting
```

Both systems are scene-owned and source-aware. There is no global `PoolManager`
or global target registry.

## Object pooling

Pools are type-specific and owned by the scene/system that needs them.

The reusable lifecycle is:

```text
reserve/acquire
→ configure transform/context
→ activate
→ release/reset
```

`NucleusPoolable` defines the reusable object lifecycle. `NucleusObjectPool`
owns instances. 2D/3D spawners apply transform before activation so a pooled
object cannot briefly wake at its previous location.

Pool reset must remove source-owned gameplay state before the next activation.

## Targeting model

Targeting separates discovery from decision:

```text
sensors
→ source-owned candidate registry
→ filters
→ scorers
→ current target / lock state
```

`NucleusTargetingAgent` owns candidates, current selection, and lock state.
Sensors register candidates by source ownership so clearing one sensor does not
remove candidates still observed by another.

Filters answer validity. Scorers rank valid candidates. Higher aggregate score
wins.

## 2D/3D sensing

Area sensors use native `Area2D`/`Area3D` overlap signals and shapes. Geometry
helpers remain dimension-specific where Godot coordinate conventions differ.

Editor warnings cover:

- a sensor with neither body nor area detection enabled;
- a sensor without an enabled collision shape;
- an unassigned agent where runtime auto-resolution could be ambiguous.

Warnings do not remove runtime auto-resolution or runtime guards.

## Integrations

Targeting has explicit seams for GameplayActions, interaction, status effects,
local multiplayer contexts, and pooled projectile/action contexts.

Do not make consumers query physics again if the TargetingAgent already owns the
required selection.

## Extension rule

New acquisition behavior should normally be a sensor, filter, or scorer.
Introduce a global targeting service only if a future feature genuinely requires
cross-scene target ownership.

## Target endpoint lifetime

TargetingAgent removes an endpoint on `tree_exiting`, before it is freed. All
sensor registrations, cached ranks, selection and lock for that endpoint are
removed together. A still-valid endpoint is carried by the removal signals.
If an endpoint re-enters the tree, sensors must register it again; the agent
does not silently restore stale ownership. Detached endpoints freed without a
tree-exit signal are pruned on registry/cache reads or selection refresh.
Agent exit disconnects subscriptions; re-entry reconnects surviving candidates.
Regression coverage: `tests/headless/target_lifecycle_test.gd`.

## Sustained lightweight bullets

See [2D bullet patterns](bullet_hell_2d.md) for resource-authored radial, fan, line,
lotus and spiral geometry, bounded cadence, retained storage and MultiMesh wiring.
Scene-based pooling remains the owner for reusable actors with native bodies.
