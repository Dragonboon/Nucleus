# Networking Quickstart

This guide is the shortest path from "I need multiplayer" to a correct first
architecture decision.

For the complete practical exercise from localhost through a public dedicated
server, use:

[`tutorials/networking.md`](tutorials/networking.md)

## 1. Pick the topology before writing RPCs

For most small online games, choose one of these first:

```text
Listen server
    one player hosts and also plays
    cheapest prototype
    host must be reachable and stay online

Dedicated authoritative server
    separate server process owns simulation
    predictable public endpoint and authority
    recurring infrastructure cost
```

Do not call the listen-server model fully symmetric P2P. Godot still has one
server peer with peer ID `1`.

## 2. Add the handler

Instance:

```text
res://addons/nucleus/modules/networking/network_handler.tscn
```

A normal scene-owned setup is:

```text
GameSession
├── Network : NucleusNetworkHandler
└── World
```

## 3. Prove localhost first

Host:

```gdscript
var error: Error = network.start_enet_server(
	42069,
	8,
)
```

Client:

```gdscript
var error: Error = network.start_enet_client(
	"127.0.0.1",
	42069,
)
```

A successful client constructor only means the attempt started. Wait for:

```text
connected_to_server
```

before entering connected gameplay.

## 4. Observe lifecycle signals

Useful signals:

```text
state_changed
peer_connected
peer_disconnected
connected_to_server
connection_failed
server_disconnected
start_failed
```

UI should derive connection state from those transitions rather than inventing a
second state machine.

## 5. Move to LAN

Replace `127.0.0.1` with the host's private LAN IPv4 address.

`NucleusNetworkUtils.get_preferred_local_ipv4()` can help present a likely local
address.

At this stage, common failures are local firewall rules and guest Wi-Fi/client
isolation.

## 6. Move to the public Internet

For direct ENet hosting from a home connection:

```text
forward UDP 42069 on the router
allow UDP 42069 in the host firewall
connect clients to the host's public address
```

If the host is behind CGNAT, normal home-router forwarding may be impossible.
Use a provider relay/P2P transport or a public dedicated server instead.

## 7. Add authority before gameplay replication

A safe starting model is:

```text
client input
-> client intent
-> server validates
-> server mutates authoritative state
-> native replication / Nucleus snapshots
-> clients present result
```

Continue with:

[`online_replication_quickstart.md`](online_replication_quickstart.md)

## 8. Add a dedicated server only after the game loop works locally

Use an explicit server startup condition:

```gdscript
var server_mode := (
	OS.has_feature("dedicated_server")
	or "--server" in OS.get_cmdline_user_args()
)
```

Do not automatically treat every `--headless` process as a live game server;
CI and test runners also use headless mode.

Example bootstrap:

```text
examples/networking/authoritative_server_bootstrap.gd
```

## 9. Export for a server

Create a Linux export preset for the server and use Godot's dedicated-server
export mode so visual resources can be stripped and the `dedicated_server`
feature tag is available.

Then deploy the output to a Linux VM and expose the configured UDP port.

## 10. Estimate cost before choosing infrastructure

A small prototype server is usually a low-cost Linux VM, not Kubernetes.

As a rough current reference, entry-level cloud VMs commonly start around
single-digit USD per month and 2-4 GB machines around low tens of USD per month.
Bandwidth, database, relay and operational costs may matter more later.

Use the dated table and bandwidth formula in:

[`multiplayer_deployment_quickstart.md`](multiplayer_deployment_quickstart.md)

## Common mistakes

Avoid:

- treating `start_enet_client() == OK` as a completed connection;
- debugging synchronization before host/join/disconnect is reliable;
- trusting client-reported damage, inventory, loot, or final transforms;
- assuming UDP port forwarding works through CGNAT;
- using `--headless` alone as the production-server identity;
- adding Kubernetes, Redis, a database and matchmaking before one match works;
- shipping Development Tools or secrets as a remote admin surface.

## Related documentation

- [`tutorials/networking.md`](tutorials/networking.md)
- [`online_replication_quickstart.md`](online_replication_quickstart.md)
- [`multiplayer_deployment_quickstart.md`](multiplayer_deployment_quickstart.md)
- [`../modules/networking.md`](../modules/networking.md)
- [`../modules/online_replication.md`](../modules/online_replication.md)
