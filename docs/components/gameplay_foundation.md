# Gameplay Foundation Contract

## Scope

```text
components/gameplay/resources
components/gameplay/combat
components/gameplay/interaction
components/gameplay/timing
components/gameplay/lifecycle
components/gameplay/state
```

All systems in this document are scene-owned composition pieces. None requires a
global gameplay manager.

## ValuePool and regeneration

`NucleusValuePool` is a bounded numeric pool for health, stamina, mana, shield,
fuel, or another game-defined quantity. It intentionally has no combat
semantics.

Important behavior:

- values clamp to minimum/maximum by default;
- optional overflow has an explicit limit;
- `decrease()` preserves remaining overflow instead of discarding it;
- `set_limits()` can preserve normal-range ratio;
- capture/restore state is local and serialization-format agnostic;
- threshold signals report depletion, fill, and overflow transitions.

`NucleusRegenerator` consumes the ValuePool API and owns regeneration timing.
This is composition rather than a specialized Health class.

## Combat

`NucleusHitPayload` carries hit data. `NucleusDamageReceiver` converts accepted
payload damage into a ValuePool decrease and owns invulnerability/immunity
policy.

An optional `NucleusDamageResolver` applies ordered, side-effect-free
`NucleusDamageRule` transformations, then consumes distinct shield ValuePools
in configured order, forwarding any remainder through `NucleusDamageReceiver`.
Use `resolve_hit(payload)` instead of calling the receiver directly for the
same impact. It returns requested/modified/absorbed/health_damage/overkill and
rejects hits before draining shields if the receiver is immune or invulnerable.
Rules must return finite, non-negative amounts; damage mathematics (armor,
criticals, resistances) remains game-owned. Multiple shield layers are allowed;
this pipeline does not roll chance-based block/parry.

2D/3D hitboxes and hurtboxes use Godot collision/area facilities. Keep hit
detection separate from damage storage.

## Interaction

Interaction components discover/represent interactable targets and invoke their
contract. Use local signals and direct references when producer and consumer
already share scene ownership.

Do not route ordinary nearby interaction through the global EventBus.

## Cooldown and lifetime

Cooldown and lifetime are generic timing components. They remain mechanic-
agnostic and reusable by actions, spawned objects, UI, or game-specific logic.

## State machine

`NucleusStateMachine` owns one scene-local FSM. States encapsulate behavior and
transition hooks. Other systems integrate by observing state changes or using
explicit action requirements/effects.

Animation consumes state through AnimationTree adapters; the FSM does not own
animation playback.

### Optional buffered transitions

The default `change_state(id, context)` retains immediate-only semantics:
a denied exit returns `ERR_UNAVAILABLE`, and a reentrant transition returns
`ERR_BUSY`. This is important for transactional action effects and AI.

To defer requests, assign a `NucleusStateTransitionPolicy` Resource to
`transition_policy` and call `request_state(id, context)` instead.
Accepted requests return `OK` even while queued: this is **acceptance, not
completion**. The optional policy controls queue capacity (1-16), rejection
or replacement of the newest item when full, and optional expiration.
`transition_queued` and `transition_request_discarded` report outcomes;
`state_changed` reports the actual committed transition.

At most one pending request is attempted per physics tick. Use
`process_pending_request()` for explicit processing after unlocking a
state. The head of the queue blocks later requests until it can exit;
requests for invalid destinations or expired requests are discarded.
Disabling the machine, leaving the scene, manually transitioning, or
restoring state clears queued requests. Contexts are copied defensively.

`restart_state(context)` deliberately performs exit/enter of the active
state without pushing a duplicate history entry. Ordinary same-state
`change_state()` remains a no-op.

An optional `actor` reference defaults to the machine's parent and is
accessible to state scripts through `get_actor()`. Actor logic and
movement remain game-owned. No new autoloads are required.

`restore_state()` now commits saved history only after a successful
transition, preventing partially applied saves when state guards reject a
restore. Pending requests are deliberately transient and are not persisted.


## Editor validation

`NucleusRegenerator` exposes editor configuration warnings so missing ValuePool
wiring is visible before Play while runtime auto-resolution remains available.

## Persistence

Only state a game needs to persist should be captured into its save document.
Timers and transient collision-overlap state should normally be reconstructed
after scene load.
