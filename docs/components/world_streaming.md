# World Streaming Lifecycle Contract

## Scope

```text
addons/nucleus/components/world/streaming
```

`NucleusWorldStreamLifecycle` is a scene-owned admission controller for world
content lifecycle.

It does not decide where the player is, which cells are visible, or which assets
belong to a region.

The consuming game supplies an ordered desired set:

```text
game-owned spatial heuristic
        ↓
stable region IDs in desired load order
        ↓
NucleusWorldStreamLifecycle
        ↓
bounded load / unload requests
        ↓
game-owned loader / instantiator
```

This keeps spatial policy outside Nucleus while removing repeated lifecycle
bookkeeping.

## Ownership

The game remains authoritative for:

```text
region/cell/sector definitions
distance and visibility heuristics
prediction and prefetch radius
memory budgets
terrain/foliage/POI composition
actual ResourceLoader plans
scene instantiation
persistent-state identity
network interest management
fallback and retry policy
```

Nucleus owns only:

```text
desired-region bookkeeping
bounded request admission
in-flight lifecycle state
stale completion recovery
explicit failure state
```

There is no WorldManager Autoload.

## Desired set

Call:

```gdscript
lifecycle.set_desired_regions([
    &"harbour",
    &"coast",
    &"island_03",
])
```

The order is the load-admission order.

Duplicates are collapsed while preserving first occurrence. Empty IDs are
rejected.

Changing the desired set does not hard-cancel work already admitted. Most
underlying loaders cannot guarantee cancellation once work has started.

Instead, stale completions converge safely:

```text
region stops being desired while loading
→ load may still complete
→ mark_loaded()
→ next pump requests unload
```

and:

```text
region becomes desired while unloading
→ unload may still complete
→ mark_unloaded()
→ next pump requests load
```

## Admission budgets

The exported controls are:

```text
max_load_requests_per_frame
max_unload_requests_per_frame
process_automatically
```

These are admission budgets, not CPU-time or memory budgets.

One admitted request may still be expensive. The consumer should combine this
component with appropriate loading/generation techniques and profile the real
game.

Call `pump()` manually when a game needs an authored cadence instead of
per-frame automatic admission.

## Acknowledgements

A consumer responds to:

```text
load_requested(region_id, request_token)
unload_requested(region_id, request_token)
```

Every admitted operation receives a monotonically increasing request token.
Pass that token back with the completion:

```gdscript
lifecycle.mark_loaded(region_id, request_token)
lifecycle.mark_unloaded(region_id, request_token)
```

This prevents a late callback from an older failed/retried operation from
completing a newer request for the same region.

For content that already exists when the lifecycle component is attached:

```gdscript
lifecycle.register_loaded_region(region_id)
```

Resident means the game still owns materialized content. A region remains
resident while its unload request is in flight.

## Failures and retry

Failed work must be explicit:

```gdscript
lifecycle.mark_request_failed(
    region_id,
    request_token,
    NucleusWorldStreamLifecycle.Operation.LOAD,
    error,
)
```

Failed regions are not retried automatically. This avoids one bad asset or
generator entering a request loop every frame.

A game may apply its own retry/backoff/fallback policy, then call:

```gdscript
lifecycle.retry_region(region_id)
```

Retry policy remains product/game policy.

## Resource loading integration

`NucleusResourceLoadQueue` is a natural implementation behind a load request:

```text
load_requested
    ↓
game creates/selects NucleusLoadPlan
    ↓
NucleusResourceLoadQueue
    ↓
consumer instantiates retained PackedScene/resources
    ↓
mark_loaded
```

The lifecycle component does not own a load queue and does not build load plans.

This preserves the Resource Loading contract: world-streaming heuristics remain
game-owned.

## Persistent world state

`NucleusWorldStateService` and `NucleusWorldRegion` persist stable world state.

They do not own streaming.

A normal consuming composition can be:

```text
WorldSession
├── WorldStateService
└── World
    ├── WorldStreamLifecycle
    ├── ResourceLoadQueue
    └── GameStreamingCoordinator
```

Before unloading a persistent region, the game should let its normal
`NucleusWorldRegion` exit/commit lifecycle run.

Persistent identity and streaming identity may share a stable game-owned ID, but
Nucleus does not force that coupling.

## Terrain integration

`NucleusTerrainStreamer3D` remains a specialized linear terrain streamer.

Do not replace it with `NucleusWorldStreamLifecycle` merely for abstraction.

Use the lifecycle component when a game needs coordinated materialization of
multiple region-owned concerns such as:

```text
terrain
POIs
props
foliage
encounters
navigation
audio
persistent entities
```

A future terrain adapter should be extracted only after a production consumer
shows repeated integration friction.

## Teleports and rapid movement

Large desired-set changes are valid.

The lifecycle component intentionally does not block the player or show a
loading screen. A game may coordinate teleport presentation through existing
scene/UI primitives while the lifecycle converges.

The lab at:

```text
examples/world/world_streaming_lifecycle_lab.tscn
```

provides rapid route changes and delayed acknowledgements to exercise stale
completion behavior.

## Performance instrumentation

Streaming is a good place to emit authored performance traces:

```gdscript
sampler.mark_trace(
    &"world_region_loaded",
    {"region_id": region_id},
)
```

Use `NucleusPerformanceSampler` and Godot's native profiler to correlate
materialization with frame pacing, memory, physics, rendering, and shader
compilation.

Do not interpret admission count as proof that a frame budget is safe.

## Networking boundary

Streaming lifecycle is not multiplayer interest management.

The multiplayer authority decides which entities exist and replicate. A client
may stream visual regions around its viewpoint without becoming authoritative
over persistent or networked world state.

Do not derive server authority from a client's desired-region set.

## Non-goals

This component is not:

```text
a world manager
a spatial partition
an LOD system
a ResourceLoader replacement
a memory-budget solver
a persistence service
a network relevancy system
a terrain clipmap
```

It is deliberately only the lifecycle seam between game-owned desire and
game-owned materialization.
