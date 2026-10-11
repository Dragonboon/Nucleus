# Optional prediction and world readiness

These helpers are opt-in, scene/session owned and have **no Autoloads**. They do not create ENet peers, move actors, authenticate users, replicate transforms, or replace native Godot multiplayer.

## Ownership

- `NucleusNetworkHandler`: transport lifecycle.
- `NucleusNetworkIntentChannel`: client intents, server admission, rate and sequence checks.
- `NucleusNetworkInputBuffer`: bounded local unacknowledged commands and predicted states.
- `NucleusNetworkReconciler2D / 3D`: pure replay of commands after authoritative acknowledgment.
- `NucleusNetworkWorldReadiness`: explicit per-peer world-loaded barrier.
- Game: authorization, deterministic movement function, actor snapshots, spawning, visibility, session epochs.

## Reconciliation contract

Create one reconciler per locally controlled actor. Record each local command with a **strictly increasing** sequence number and the state predicted after applying it. Give the server the command via your existing `NucleusNetworkIntentChannel`; the game server validates and executes it. The authoritative state must report the **last processed input sequence**, not a transform snapshot sequence.

```gdscript
var prediction := NucleusNetworkReconciler2D.new()

# For each locally simulated step (game code):
prediction.record(input_sequence, {"direction": direction}, {
    "position": predicted_position,
})

# When the server confirms processing input sequence 12:
var result := prediction.reconcile(12, {
    "position": server_position,
}, _simulate_pure)

if not result.is_empty():
    # Only the owning game applies the correction to its actor.
    actor.position = result["state"]["position"]

func _simulate_pure(state: Dictionary, command: Dictionary, dt: float) -> Dictionary:
    var direction: Vector2 = command["direction"]
    return {"position": state["position"] + direction * 200.0 * dt}
```

`simulate(state, command, fixed_delta) -> Dictionary` must be pure, use the same deterministic rules as the server and return a finite `position` (Vector2 for 2D, Vector3 for 3D). The generic replay helper **does not reproduce CharacterBody collisions** on its own. A project using collision-based movement must provide a compatible simulation strategy and validate it under actual physics/network conditions before trusting corrections. Do not run physics side effects from replay callbacks.

A missing/duplicate acknowledgment or invalid replay leaves the input history unchanged. The bounded input buffer refuses new entries when full; the game must handle backpressure. Call `reset()` after a new session, respawn or authority transfer. This API does not promise transport resend/recovery: integrate that with your game and its existing intent channel.

For remote players, continue using `NucleusNetworkTransformReplicator2D/3D`. Do not let it write the locally predicted actor's transform simultaneously with the game reconciler.

## Per-peer world readiness

Add a `NucleusNetworkWorldReadiness` node at a **matching NodePath** on server and clients, alongside the native `MultiplayerSpawner` / `MultiplayerSynchronizer`. It is a gate, not a spawner or authenticator.

1. Server calls `begin_session(epoch)` with a fresh **positive**, monotonically increasing session epoch; after authenticating and accepting a peer, call `expect_peer(peer_id)`.
2. Game sends the trusted epoch to the admitted client through its own RPC protocol. Client calls `prepare_session(epoch)` before loading the corresponding world.
3. After the world and matching replication NodePaths exist, client calls `confirm_loaded()`.
4. Server receives `peer_ready(peer_id, epoch)` and only then enables the corresponding synchronizer visibility / spawn for that client.
5. On disconnect, removal, or world change, readiness resets. Re-register the peer before accepting another acknowledgment.

An epoch is a stale-session guard, **not a credential**. A client ACK proves that it sent a claim, not that it has honestly loaded the world. Admission/authentication and visibility remain explicit game-owned policies. The server must ensure each epoch changes across a restarted session, or a replayed old ACK might be applicable again.

## Validation

New pure regression suites:

- `tests/headless/network_prediction_test.gd`: bounded history, immutability, replay, stale confirmations and invalid coordinates.
- `tests/headless/network_world_readiness_test.gd`: per-peer admission, epoch change and duplicate/stale acknowledgments.

Both are registered in `tests/headless/test_manifest.gd`.

Run the pinned engine with `godot --headless --path . --import` followed by `godot --headless --path . res://tests/headless/test_runner.tscn`.

These tests do **not** establish a live multi-process dedicated server or prove collision determinism. Before release, also exercise ENet sockets, lost packets, reconnection, mixed 2D/3D actors and scene-lifetime teardown in an actual consuming game.

## Optional localhost packet impairment

The standard-library-only tool `tools/networking/udp_impairment_proxy.py` delays,
jitters and drops real UDP datagrams in both directions for one local client.
Run a game server on `127.0.0.1:42069`, then:

```bash
python3 tools/networking/udp_impairment_proxy.py --listen 42070 --target 42069 --delay 100 --jitter 25 --loss 5
```

Connect one client to `127.0.0.1:42070`. Each additional test client needs a
separate proxy listener. This tool is for development testing on loopback;
it is not an Internet relay, NAT traversal mechanism, or rate-limit defense.
Its design was informed by the MIT-licensed
[CodingQuests godot-multiplayer-starter](https://github.com/CodingQuests/godot-multiplayer-starter).
