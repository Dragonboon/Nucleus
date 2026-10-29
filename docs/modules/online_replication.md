# Optional Online Gameplay Replication

## Status

Online gameplay replication extends the existing optional
`addons/nucleus/modules/networking` transport layer.

Nucleus does **not** replace Godot's high-level multiplayer stack.

Use native:

```text
MultiplayerSpawner
    authoritative scene spawn / despawn

MultiplayerSynchronizer
    replicated properties and visibility

RPC
    discrete network messages
```

Nucleus adds only recurring gameplay pieces that remain awkward when every
project reimplements them:

```text
client → authority intent admission
monotonic sequence validation
basic per-peer rate limiting
2D / 3D transform snapshot interpolation
```

## Authority model

The default contract is server-authoritative:

```text
client input / request
        ↓
intent
        ↓
server validates
        ↓
server changes gameplay state
        ↓
native replication / snapshots
        ↓
clients present result
```

Clients should not authoritatively submit:

```text
final positions
damage results
inventory contents
loot outcomes
cooldown completion
persistent world mutations
match results
```

because knowing an RPC path is not authorization.

## Native replication first

Prefer `MultiplayerSynchronizer` for ordinary replicated properties such as:

```text
health
animation state
team
weapon ID
door open/closed
match phase
```

Prefer `MultiplayerSpawner` for networked scene lifetime.

Do not wrap those nodes merely to make their APIs look like Nucleus.

The high-level multiplayer protocol also requires RPC-capable nodes to exist at
matching NodePaths with matching RPC signatures on participating peers.

## Intent channel

`NucleusNetworkIntentChannel` is intended to live on an actor/player scene that
exists at the same replicated path on client and server.

Configure:

```text
controlling_peer_id
```

to the peer allowed to submit intents for that actor.

Examples:

```text
move
look
jump
fire
interact
reload
ability_primary
```

Reliable intents use RPC channel `1`.

Unreliable ordered intents use RPC channel `2`.

The component validates:

```text
controlling peer
positive monotonic sequence
duplicate/out-of-order sequence rejection
top-level payload size
intent ID size
fixed-window request rate
```

Then it calls:

```gdscript
validate_intent(
	peer_id,
	intent_id,
	payload,
	reliable,
)
```

Override that method in a game-specific subclass for semantic validation.

Only after validation does the server emit:

```text
intent_received
```

Transport admission is not gameplay permission.

## Reliable vs unreliable intent

Use reliable delivery for infrequent actions where loss is unacceptable:

```text
interact
inventory transaction request
confirm respawn
select loadout
use ability with discrete activation
```

Use unreliable ordered delivery for high-frequency replaceable intent:

```text
movement vector
look direction
aim state
continuous steering
```

Do not send highly variable packet sizes through one unreliable-ordered stream
without understanding the head-of-line/drop behavior.

## Sequence tracker

`NucleusNetworkSequenceTracker` maintains one last accepted sequence for each:

```text
peer + stream
```

A sequence must be positive and strictly increasing.

This rejects duplicated and older packets without implementing a general
reliable transport protocol.

The intent channel uses independent reliable/unreliable streams.

## Rate limiter

`NucleusNetworkRateLimiter` is a fixed-window admission helper.

It is intentionally basic.

It prevents accidental or obvious high-frequency abuse from immediately
reaching game logic, but it is not a DDoS solution and does not replace backend
edge protection.

Game-specific actions should still enforce their own:

```text
cooldowns
resource costs
distance
line of sight
ownership
match state
permissions
server-side simulation rules
```

## Transform interpolation

`NucleusNetworkTransformReplicator2D/3D` sends authority snapshots using
unreliable-ordered RPC channel `3`.

The authority sends:

```text
sequence
position
rotation
```

Remote peers buffer snapshots by **local arrival time** and render at:

```text
current local time - interpolation_delay
```

This avoids requiring synchronized wall clocks merely to smooth presentation.

There is deliberately no extrapolation in the baseline.

No snapshot means no guessed future state.

## Why this exists alongside MultiplayerSynchronizer

`MultiplayerSynchronizer` is the correct native choice for replicated
properties.

Directly synchronizing a transform may still produce visible stepping at a
network send rate lower than the render/physics rate.

The Nucleus transform replicator exists only for projects that want a small
interpolation buffer without implementing one again.

Do **not** synchronize the same position/rotation with both systems.

## Teleports

Each transform replicator has:

```text
teleport_distance
```

If an arriving position is farther from the current remote transform than that
threshold, the interpolation buffer is cleared and the state is applied
immediately.

Admission happens **before** clearing history or writing the transform. A stale
sequence or invalid transform cannot bypass validation merely by being far away.

Use this for:

```text
respawn
portals
fast travel
authoritative correction
scene relocation
```

Set the threshold to `0` to disable distance-based teleport detection.

## Transform buffer

The pure helpers:

```text
NucleusTransformSnapshotBuffer2D
NucleusTransformSnapshotBuffer3D
```

reject stale sequences and interpolate between ordered snapshots.

Arrival times must be finite, nonnegative and nondecreasing; equal times are
valid. Positions and angles must be finite; 3D rotations must be unit quaternions.
Rejected pushes leave the latest sequence and history unchanged, so a corrected
snapshot can retry the same sequence. Invalid sample times return an empty map.
`clear()` deliberately resets sequence admission as well as history: reserve it
for a new stream/session, not for admitting old packets.

They are networking-policy agnostic and regression-testable without opening a
socket.

Run the composition test with the pinned engine:

```bash
godot --headless --path . res://tests/smoke/network_replication_smoke.tscn
```

It creates two independent MultiplayerAPI roots, connects them through
`NucleusNetworkHandler` over localhost ENet (UDP port 48472), and exercises the
actual 2D/3D replicator RPCs. It checks ordinary snapshots, rejection of stale or
invalid teleports, and a valid retry. Headless buffer tests cover numeric and
timestamp boundaries. These checks do not simulate WAN latency, loss, a
four-player game or client prediction.

## Player prediction

This baseline does not implement:

```text
client-side movement prediction
input history replay
server reconciliation
rollback
lag compensation
rewind hit validation
```

Those systems are genre- and movement-model-sensitive.

A competitive FPS, fighting game, physics co-op game, and slow survival game
need materially different solutions.

Add prediction only when the real project proves which model is required.

## Spawning

For authoritative replicated actors, use native `MultiplayerSpawner`.

Typical structure:

```text
Game
├── Players
├── MultiplayerSpawner
└── ...
```

Player/enemy scenes may then contain:

```text
MultiplayerSynchronizer
NucleusNetworkIntentChannel
NucleusNetworkTransformReplicator3D
```

according to their role.

## Persistent World State

Persistent identity and network identity are separate contracts.

For a persistent multiplayer world:

```text
NucleusWorldEntity.persistent_id
    durable save identity

multiplayer authority / replicated scene
    current network lifetime
```

The server should normally own both the authoritative world-state mutation and
network spawn/despawn decision.

Do not use transient peer IDs as persistent save IDs.

## Inventory / Loot / AI

Recommended authority:

```text
Inventory mutations
Loot rolls
Persistent World mutations
AI decisions
combat result validation
```

run on the server.

Replication communicates resolved state/results.

This keeps the optional modules compatible with both single-player and
authoritative multiplayer.

## Authentication and public Internet games

`NucleusNetworkHandler` bootstraps peers; it is not authentication.

Before exposing a public game, design:

```text
player authentication
session admission
RPC validation
rate limiting
backend trust
ban/moderation requirements
secret handling
```

Godot's `SceneMultiplayer` also exposes authentication hooks that a production
game may use.

## Not included

```text
matchmaking
relay service
NAT traversal service
Steam/EOS networking adapter
rollback framework
prediction/reconciliation
lag compensation
voice
anti-cheat
backend persistence
MMO interest management
```

These remain game/provider-specific until real project evidence justifies a
reusable Nucleus layer.
