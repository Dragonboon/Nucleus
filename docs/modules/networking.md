# Optional Networking Module

## Status

`addons/nucleus/modules/networking` is optional and is not loaded by default.

It provides two deliberately separate layers:

```text
transport / bootstrap
    NucleusNetworkHandler
    NucleusLanDiscovery
    NucleusNetworkUtils

gameplay replication helpers
    NucleusNetworkIntentChannel
    NucleusNetworkSequenceTracker
    NucleusNetworkRateLimiter
    NucleusTransformSnapshotBuffer2D / 3D
    NucleusNetworkTransformReplicator2D / 3D
```

It is not a matchmaking service, relay network, account backend, lobby service,
anti-cheat product, or general-purpose MMO stack.

## Start by choosing a topology

Before writing RPCs, decide which machine is authoritative.

### Listen server

One player's game process acts as both server and local client:

```text
host player
    game + authority
        ↑       ↑
        |       |
     client   client
```

This is the natural first Internet-capable step after localhost. It is cheap and
simple, but the host must remain online, has a latency advantage, and must be
reachable through NAT/firewall policy.

A listen server is often casually called "P2P", but it is not symmetric peer to
peer. Godot still has one server peer, whose peer ID is `1`.

### Dedicated authoritative server

A separate process owns the simulation:

```text
client ─┐
client ─┼─> dedicated server authority
client ─┘
```

This costs infrastructure money but gives predictable ownership, uptime,
connectivity, moderation, persistence, and operational control.

### Provider P2P / relay

Steam, Epic Online Services, console platforms, VPN overlays, and other providers
can supply NAT traversal or relays. Those integrations remain provider-specific.
Nucleus does not pretend that a generic UDP socket wrapper replaces them.

## NetworkHandler responsibility

`NucleusNetworkHandler` wraps Godot's high-level `MultiplayerAPI` peer lifecycle.

Supported convenience paths include:

```text
ENet server/client
WebSocket server/client
shutdown/offline restoration
peer/state signals
connected-peer queries
server-side disconnect
```

ENet is the normal native-game starting point. Godot's high-level multiplayer
uses UDP for this path. Internet-hosted ENet therefore requires the relevant UDP
port to be reachable.

Transport remains separate from gameplay replication.

## Environment ladder

Prove networking in increasing order of uncertainty:

```text
1. localhost
   127.0.0.1
   no router/NAT involved

2. LAN
   192.168.x.x / 10.x.x.x / 172.16-31.x.x
   local firewall + Wi-Fi/router policy involved

3. public listen server
   public IP or provider endpoint
   NAT / CGNAT / port forwarding / firewall involved

4. dedicated server
   public VM or bare metal
   deployment, firewall, process supervision and cost involved
```

Do not debug gameplay replication while the lower networking layer is still
unproven.

## NAT and CGNAT

A home-hosted ENet server usually needs UDP port forwarding from the router to
the host machine.

Example:

```text
Internet UDP 42069
    -> router public IPv4
    -> forward UDP 42069
    -> host LAN IP 192.168.1.50:42069
```

If the ISP places the user behind carrier-grade NAT, the user may not control a
publicly reachable IPv4 address at all. Port forwarding on the home router then
cannot solve the problem by itself.

Typical responses are:

```text
provider relay / P2P transport
VPN/overlay networking for private testing
IPv6 when both ends and product policy support it
dedicated public server
```

Nucleus does not implement generic NAT traversal or relays.

## LAN discovery

`NucleusLanDiscovery` provides optional UDP broadcast announcements for local
networks. Discovery traffic is separate from the authoritative multiplayer
transport.

Use it for "Find LAN games", not as identity or authentication.

## Optional client prediction and world readiness

For locally controlled actors, `NucleusNetworkInputBuffer` and
`NucleusNetworkReconciler2D/3D` support bounded command replay after a
server-confirmed input sequence. They are side-effect-free helpers and do
not move actors or replace `NucleusNetworkIntentChannel`.

`NucleusNetworkWorldReadiness` provides an opt-in, scene-owned gate for
replication visibility until an authenticated peer acknowledges that its
world paths are ready. It does not perform authentication or spawn actors.

See [Network prediction and readiness](network_prediction.md) for contracts,
limitations and test instructions.

## Gameplay replication

The online replication helpers add:

```text
client -> authority intent admission
monotonic sequence validation
basic per-peer rate limiting
2D / 3D transform snapshot interpolation
```

They do not replace native:

```text
MultiplayerSpawner
MultiplayerSynchronizer
SceneReplicationConfig
RPC
```

See:

```text
docs/modules/online_replication.md
docs/guides/online_replication_quickstart.md
```

## Authority model

A strong default for gameplay-critical state is:

```text
client reads local input
    -> sends bounded intent
    -> server validates current authoritative state
    -> server simulates/mutates state
    -> state/result is replicated
    -> clients present it
```

The server should normally own:

```text
combat results
inventory mutations
loot rolls
cooldowns/resource costs
persistent world changes
AI decisions relevant to gameplay
match results
```

Client authority can still be appropriate for presentation-only state or games
whose threat model explicitly accepts it.

## Dedicated-server startup policy

Nucleus intentionally does not automatically turn every headless process into a
game server. Headless mode is also used by CI, imports, tests, and automation.

A consuming game should choose an explicit startup rule such as:

```text
OS.has_feature("dedicated_server")
OR
"--server" in OS.get_cmdline_user_args()
```

Then call `NucleusNetworkHandler.start_enet_server()` from the game-owned session
bootstrap.

A complete example is provided in:

```text
examples/networking/authoritative_server_bootstrap.gd
```

## Dedicated export

Godot 4 supports dedicated-server exports without a special server executable.
A dedicated export preset can strip visual assets and supplies the
`dedicated_server` feature tag.

Keep the same gameplay code where practical. Branch on presentation and startup,
not on a second unrelated implementation of the game simulation.

## Security boundary

Transport connectivity is not authentication and an RPC path is not
permission.

Production Internet games still need game-owned policy for:

```text
identity/authentication
session admission
build/protocol compatibility
semantic RPC validation
server-side ownership checks
rate/cooldown/resource validation
secret storage
ban/moderation policy
backend trust
persistence authorization
```

`NucleusNetworkRateLimiter` limits how often admitted requests enter game logic.
It is not DDoS protection.

Never expose arbitrary Development Tools commands, source evaluation, or raw
property mutation as a public remote administration protocol.

## Web behavior

ENet server/client startup is unavailable on Web through the current handler.
Browsers also cannot listen for incoming WebSocket connections.

A browser-facing game can use a WebSocket client to a native server, normally
through `wss://` in production, or use another browser-capable provider
transport.

## Operational baseline for a public dedicated server

A small production deployment should at minimum have:

```text
unprivileged OS user
SSH keys rather than password-only administration
only required firewall ports open
process supervision/restart policy
logs with timestamps and build/version identity
resource monitoring
backups when persistent state exists
secrets outside committed project files
staged update/rollback procedure
```

For a single server, systemd is usually enough. Containers are useful when they
solve packaging or orchestration needs; they are not required merely because a
game is networked.

## Cost model

Infrastructure cost is approximately:

```text
compute
+ outbound traffic beyond included allowance
+ public IPv4 / load balancer when charged separately
+ database/storage/backups
+ relay/matchmaking/provider usage
+ logs/metrics
+ operational time
```

The cheapest useful prototype is often one small Linux VM. Do not buy an
orchestrated fleet before measuring actual server CPU, memory, bandwidth, match
lifetime, and concurrent users.

See the deployment guide for a dated pricing snapshot and a bandwidth formula:

```text
docs/guides/multiplayer_deployment_quickstart.md
```

## Godot-native APIs

The module delegates to:

```text
MultiplayerAPI
MultiplayerPeer
SceneMultiplayer
MultiplayerSpawner
MultiplayerSynchronizer
SceneReplicationConfig
ENetMultiplayerPeer
WebSocketMultiplayerPeer
OfflineMultiplayerPeer
TLSOptions
PacketPeerUDP
IP
Crypto
```

Nucleus does not maintain a parallel networking stack.

## Ownership

The game decides whether the handler is scene-owned or promoted to an Autoload.

A normal online-session structure is:

```text
GameSession
├── Network : NucleusNetworkHandler
├── Players
├── MultiplayerSpawner
└── World
```

Promote networking to an Autoload only when the connection intentionally
survives complete session/scene replacement.

## Production learning path

Use the networking documentation in this order:

```text
networking_quickstart
    -> tutorials/networking
    -> online_replication_quickstart
    -> multiplayer_deployment_quickstart
```

The tutorial walks the same project from localhost to a public authoritative
server rather than presenting those topics as unrelated recipes.
