# Spatial Interest Management — Optional Networking Mechanism

Target: Godot 4.7.2-stable / GDScript. Module: `addons/nucleus/modules/networking/interest`.

> [!CAUTION]
> **Server authority is mandatory.** Nearby candidates are not a
> permission grant; the authoritative game controls replication visibility.

## What this does

Spatial interest management reduces the number of network-relevant entities
considered for each connected player. It does **not** replicate properties,
authenticate peers, or decide what gameplay data a player is *authorized* to
see. It supplies a server-owned, scene-owned **candidate relevance mechanism**.

The three small units are:

- `NucleusNetworkInterestGrid3D`: incremental XZ cell index of stable entity IDs
  and authoritative positions; bounded-radius, nearest-first queries.
- `NucleusNetworkInterestReconciler`: deduplicated desired/admitted IDs with
  per-pump enter/exit limits and immediate cleanup paths.
- `NucleusNetworkInterestController3D`: optional `Node` that manages a grid and
  separate reconciler per peer, runs round-robin across peers, and exposes
  signals for game-owned replication visibility.

There are no Autoloads, transport dependencies, RPCs, or SpacetimeDB bindings.

## Ownership and security

The server must obtain `peer_id`, viewer position and entity positions from
**authoritative session/gameplay state**, not directly from a client RPC.
`upsert_entity`, `remove_entity`, `update_peer_interest`, `refresh_peer_interest`
and `remove_peer` refuse to mutate when the controller is not inside the scene
tree on the server. No client may grant itself visibility by choosing a larger
radius or lying about its position.

A spatial hit is **not authorization**. Before applying a visibility grant, the
game must enforce team, stealth, instancing, PvP, permission and game-rule
filters as applicable. Such filters should fail closed. Visibility decisions
must be made by the authority; user-interface hiding is not data security.

## Grid geometry and stable IDs

A cell is:

```text
Vector2i(floor(world_x / cell_size), floor(world_z / cell_size))
```

Negative coordinates are floored correctly. Y is deliberately ignored: this
mechanism supports a 3D scene with horizontal relevance. A dungeon with many
vertically stacked floors may need separate game-owned layer/zone filters.
Precise query membership uses **horizontal Euclidean distance**, not just
cell overlap. Results are ordered nearest-first with stable ID as tie-break.
`get_covered_cells()` exposes the overlapping XZ cells (bounding area, sorted
nearest-cell-center-first) for games using zone/chunk subscription adapters;
`get_entities_in_cell()` provides deterministic per-cell membership.

Entity IDs are stable for one network lifetime and are **not** SceneTree
instance IDs, peer IDs or necessarily durable save UUIDs. Supply unique
`StringName` values, remove despawned IDs and refresh positions when they move.

`cell_size` can be reconfigured at runtime; the index is rebuilt, so do this
infrequently. Query radius is limited to 16 cells to bound neighborhood cell
iteration. An invalid radius yields an empty direct grid result; the controller
instead returns `ERR_INVALID_PARAMETER` and retains its existing desired state.
The query's returned entity count is capped at 1024. It still scans and sorts
all candidates in nearby occupied cells, so the cap is **not** a total CPU-time
budget in exceptionally dense scenes. Profile with real player/entity counts.

## Minimal authoritative integration

Scene:

```text
GameSession
├── Network                 : NucleusNetworkHandler (optional)
├── Interest                : NucleusNetworkInterestController3D
├── Players                 : Node3D
├── ReplicatedActors         : Node3D
└── MultiplayerSpawner       : MultiplayerSpawner
```

Configure for example:

```text
cell_size = 32
interest_radius = 96
max_relevant_entities = 128
max_enters_per_peer_per_pump = 8
max_exits_per_peer_per_pump = 16
max_peers_per_pump = 8
process_automatically = true
```

A server-side game session maintains an ID-to-`MultiplayerSynchronizer`
registry and uses **game-authoritative** positions:

```gdscript
@onready var interest: NucleusNetworkInterestController3D = $Interest

var synchronizers: Dictionary = {} # StringName -> MultiplayerSynchronizer


func _ready() -> void:
    if not multiplayer.is_server():
        return
    interest.entity_entered_interest.connect(_on_interest_entered)
    interest.entity_exited_interest.connect(_on_interest_exited)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func server_update_actor(entity_id: StringName, actor: Node3D) -> void:
    # Called on the authority, when the actor is created or changes position.
    interest.upsert_entity(entity_id, actor.global_position)


func server_update_viewer(peer_id: int, player: Node3D) -> void:
    # Obtain player from an authenticated server-controlled session registry.
    interest.update_peer_interest(peer_id, player.global_position)


func _on_interest_entered(peer_id: int, entity_id: StringName) -> void:
    var synchronizer: MultiplayerSynchronizer = synchronizers.get(entity_id)
    if synchronizer != null and _may_replicate_to(peer_id, entity_id):
        synchronizer.set_visibility_for(peer_id, true)


func _on_interest_exited(peer_id: int, entity_id: StringName) -> void:
    var synchronizer: MultiplayerSynchronizer = synchronizers.get(entity_id)
    if synchronizer != null:
        synchronizer.set_visibility_for(peer_id, false)


func _on_peer_disconnected(peer_id: int) -> void:
    interest.remove_peer(peer_id)


func _may_replicate_to(_peer_id: int, _entity_id: StringName) -> bool:
    # REPLACE with actual authoritative game permission checks.
    return false
```

The `_may_replicate_to` example intentionally **fails closed**. Do not leave
its body unchanged if you expect replication. Install this code in a
*server-owned* game script; it is an integration sketch, not a drop-in scene.

**Critical native configuration:** set `public_visibility = false` on each
`MultiplayerSynchronizer` **before replication begins**, so newly joined peers
cannot see entities by default. If the `root_path` is a node spawned via
`MultiplayerSpawner`, native Godot can use synchronizer visibility to control
that actor's spawn/despawn for each peer. Do not also replicate these entities
through a second, conflicting manual spawn/despawn pipeline.

Nucleus's transform snapshot helpers send RPCs separately and do **not**
automatically inherit synchronizer visibility. The game must explicitly gate
those RPCs or choose native synchronization for interest-managed transforms.
Do not assume hiding a synchronizer filters unrelated RPC traffic.

## Update cadence, budgets, and lifecycle

- Call `upsert_entity()` whenever an authoritative entity changes position
  sufficiently to matter for relevance. Call `remove_entity()` on despawn.
- Call `update_peer_interest()` from a game-owned cadence using the player's
  **server-controlled** position, e.g. 5–10 Hz; `refresh_peer_interest()` can
  recompute the last supplied position after world changes.
- `pump()` admits a bounded number of enter/exit decisions for up to
  `max_peers_per_pump` peers, round-robin. It is automatic by default, but can
  be driven manually after `set_automatic_processing(false)`.
- A new desired set is nearest-first. **Enters are processed before exits** to
  reduce temporary gaps; during a transition, admitted membership may
  momentarily exceed `max_relevant_entities`. This is a candidate limit, not
  a hard cap on concurrent native synchronized actors.
- `remove_entity()` forgets all peer memberships immediately and emits exit
  signals. `remove_peer()` releases the peer's memberships immediately, even
  if configured per-pump budgets are zero.
- Desired state is updated **only** when you call the update/refresh API.
  The component does not poll player positions itself or auto-recompute when
  actors move. If the game stops updating a viewer, stale relevance remains
  until explicitly recomputed or removed.
- Rapid movement near the query radius can cause enter/exit churn. Smooth
  positions, throttle updates and add game-owned hysteresis/zone policy when
  measurement demonstrates a need. P4 does not silently invent that policy.

Signals indicate *admitted relevance*, not acknowledgement of actual network
spawn, subscription completion or reliable message delivery. The baseline is
synchronous. For asynchronous services, add a separate tokenized adapter with
an acknowledgement contract; do not treat these signals as completed DB work.

## Testing and performance boundaries

The registered headless suite `tests/headless/network_interest_test.gd` covers
negative coordinates, nearest-first/tie ordering, limit behavior, cell moves,
reindexing, deduplication, bounded reconciliation and immediate cleanup.

Run in the Nucleus root:

```bash
python3 scripts/ci/static_checks.py
godot --headless --path . --import
godot --headless --path . res://tests/headless/test_runner.tscn
```

For gameplay validation, run at least two peers with `public_visibility=false`
and verify distant objects are absent from the network scene, then approach,
leave, teleport, disconnect and reconnect. Capture entity counts, replication
bandwidth and frame times at representative concurrency. This module makes no
claim about bandwidth improvement until measured in a real game.

See `docs/modules/networking.md`, `docs/modules/online_replication.md` and
`docs/guides/online_replication_quickstart.md` for native authority and
replication contracts.

## Use cases

| Scenario | Relevant use | Authority caveat |
| --- | --- | --- |
| Co-op world with creatures near each player | Select nearby candidate entity IDs | Server authorizes visibility/spawning |
| Open-world MMO-style shard | Query cells with per-peer admission budgets | Authentication, persistence and backend stay game/provider-owned |
| A player teleports across the map | Reconcile old/new relevance without trusting the client | Clear stale visibility and replicated identities |

Interest is a **server-side optimization and filtering input**, never proof that
a remote player is permitted to see or control an object. Validate actual
network effect with at least two clients and an authoritative server.
