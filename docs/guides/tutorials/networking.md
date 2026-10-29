# Tutorial: from localhost to an authoritative dedicated server

This tutorial follows one small multiplayer game through the environments a real
project normally reaches:

```text
localhost
-> LAN
-> Internet listen server
-> dedicated authoritative server
```

The goal is not to build a complete backend. It is to answer the questions that
usually block a developer when multiplayer leaves the editor.

At the end you will know:

- what Nucleus owns and what remains game-owned;
- how to prove ENet locally before adding replication;
- why a host/join game is a listen server rather than symmetric P2P;
- what NAT, port forwarding and CGNAT change;
- how to move gameplay authority to a dedicated process;
- how to start that process locally and from a server export;
- which Linux firewall/process-supervision steps matter;
- which costs appear first and which ones can wait.

## 1. Use one session scene

Start with:

```text
GameSession
├── Network : NucleusNetworkHandler
├── Players
├── MultiplayerSpawner
└── World
```

For the first transport test, `Players` and `MultiplayerSpawner` can remain
unused. Instance the network handler from:

```text
res://addons/nucleus/modules/networking/network_handler.tscn
```

Keep it scene-owned unless you deliberately need one connection to survive full
session replacement.

## 2. Build a tiny Host / Join / Leave UI

A development UI can be as small as:

```text
NetworkLab : Control
├── Address : LineEdit
├── Host : Button
├── Join : Button
├── Leave : Button
├── Status : Label
└── Network : NucleusNetworkHandler
```

Set `Address.text` to:

```text
127.0.0.1
```

Attach:

```gdscript
extends Control

const PORT := 42069

@onready var network: NucleusNetworkHandler = %Network


func _ready() -> void:
	network.state_changed.connect(_refresh_status.unbind(2))
	network.peer_connected.connect(_refresh_status.unbind(1))
	network.peer_disconnected.connect(_refresh_status.unbind(1))
	network.connected_to_server.connect(_refresh_status)
	network.connection_failed.connect(_refresh_status)
	network.server_disconnected.connect(_refresh_status)

	%Host.pressed.connect(_host)
	%Join.pressed.connect(_join)
	%Leave.pressed.connect(_leave)
	_refresh_status()


func _host() -> void:
	var error := network.start_enet_server(PORT, 8)
	if error != OK:
		push_error("Host failed: %s" % error_string(error))
	_refresh_status()


func _join() -> void:
	var address := %Address.text.strip_edges()
	var error := network.start_enet_client(address, PORT)
	if error != OK:
		push_error("Join failed: %s" % error_string(error))
	_refresh_status()


func _leave() -> void:
	network.shutdown()
	_refresh_status()


func _refresh_status() -> void:
	var state_name := NucleusNetworkTypes.State.keys()[network.state]
	%Status.text = "%s | peer=%d | peers=%s" % [
		state_name,
		network.get_unique_id(),
		str(network.get_connected_peers()),
	]
```

The important distinction is:

```text
start_enet_client() returns OK
    connection attempt started

connected_to_server signal
    connection completed
```

Do not enter connected gameplay merely because `start_enet_client()` returned
`OK`.

## 3. Prove localhost with two processes

Run one copy as Host and another as Join.

Expected path:

```text
host
OFFLINE -> STARTING -> SERVER

client
OFFLINE -> STARTING -> CONNECTING -> CLIENT
```

The server's peer ID is `1`.

Before adding a Player scene, verify all of these:

1. host starts;
2. client connects to `127.0.0.1`;
3. host receives `peer_connected`;
4. client reaches `CLIENT`;
5. client leaves;
6. host receives `peer_disconnected`;
7. both can return to `OFFLINE` and reconnect.

Also test a failed join with no host running. Recovery should end in `OFFLINE`,
not leave a stale peer installed.

## 4. Understand what you just built

The host process is both:

```text
server authority
+
local player's game client
```

That topology is a **listen server**.

It is often described informally as P2P because one player hosts the session,
but the simulation is not symmetric. One peer still owns server authority.

Advantages:

```text
no dedicated-server bill
fast iteration
simple friend-hosted co-op
```

Costs:

```text
host must stay online
host has latency advantage
host machine carries server workload
home network must be reachable
host departure needs session policy
```

For a small co-op game, that may be completely acceptable.

## 5. Move the same build to LAN

On the host, obtain a private IPv4 address. You can display:

```gdscript
print(NucleusNetworkUtils.get_preferred_local_ipv4())
```

Typical addresses look like:

```text
192.168.1.50
10.0.0.25
172.20.0.10
```

Run the host on one machine and join from another machine on the same LAN using
that address.

If localhost works but LAN does not, inspect these before touching gameplay
code:

```text
host OS firewall
Wi-Fi guest/client isolation
wrong network interface
VPN routing
wrong private IP
```

At this stage there is still no public Internet NAT traversal involved.

## 6. Move the listen server to the Internet

Godot's ENet high-level multiplayer path uses UDP. A home host usually needs:

```text
router port forward:
    UDP 42069
    -> host LAN IP : 42069

host firewall:
    allow UDP 42069
```

The remote client connects to the host's public address instead of the private
LAN address.

Do not forward only TCP. ENet needs the UDP port.

### What if it still does not work?

Check whether the host is behind CGNAT.

A common symptom is that the router's WAN address is not the same publicly
reachable address the Internet sees, or the ISP simply does not provide the
subscriber a controllable public IPv4.

Normal router forwarding cannot cross an upstream carrier NAT that you do not
control.

At that point choose one of:

```text
provider P2P / relay
VPN overlay for private testing
IPv6 when the whole product path supports it
public dedicated server
```

Nucleus deliberately does not contain a fake "automatic NAT traversal" layer.
That problem needs a real provider/relay or public endpoint.

## 7. Keep transport and gameplay authority separate

Once Host / Join / Leave works, add replicated gameplay.

A useful default is:

```text
client
    read input
    -> send intent

server
    validate intent
    -> simulate authoritative state
    -> replicate result

client
    present replicated state
```

Do not accept these as client truth:

```text
"my position is now X"
"I dealt 100 damage"
"I looted legendary_sword"
"my cooldown finished"
```

Instead accept requests such as:

```text
move direction
fire pressed
interact with target ID
request inventory operation
```

and validate them against server state.

## 8. Spawn players with Godot-native replication

Use `MultiplayerSpawner` for authoritative scene lifetime.

Typical structure:

```text
GameSession
├── Players
├── MultiplayerSpawner
└── World
```

A replicated player scene might contain:

```text
Player
├── MultiplayerSynchronizer
├── IntentChannel
└── TransformReplicator3D
```

Use `MultiplayerSynchronizer` for discrete replicated properties such as health,
team, selected weapon, animation state, or match phase.

Use `NucleusNetworkIntentChannel` for client-to-server gameplay requests.

Use the Nucleus transform replicator only if you need its interpolation buffer.
Do not synchronize the same transform through two systems simultaneously.

The full replication contract is documented in:

[`../online_replication_quickstart.md`](../online_replication_quickstart.md)

## 9. Turn the same game into a dedicated server

A dedicated server is not a different networking protocol. It is a separate game
process that always owns authority and normally has no local player.

Do not make every headless run start a live server. Nucleus CI and Godot tooling
also use headless mode.

Prefer an explicit rule:

```gdscript
var server_mode := (
	OS.has_feature("dedicated_server")
	or "--server" in OS.get_cmdline_user_args()
)
```

The repository includes a game-owned example:

```text
examples/networking/authoritative_server_bootstrap.gd
```

It intentionally stays under `examples/`. Nucleus should not own your match
startup rules, map selection, persistence, authentication, or player admission.

## 10. Parse server configuration from user arguments

Godot reserves arguments after the standard `--` separator for the game.

A local server run can therefore look like:

```bash
godot --headless --path . -- \
  --server \
  --port=42069 \
  --max-clients=8 \
  --bind=0.0.0.0
```

A simple game-owned parser:

```gdscript
func _user_options() -> Dictionary:
	var result := {
		"server": false,
		"port": 42069,
		"max_clients": 8,
		"bind": "*",
	}

	for argument: String in OS.get_cmdline_user_args():
		if argument == "--server":
			result.server = true
		elif argument.begins_with("--port="):
			result.port = argument.get_slice("=", 1).to_int()
		elif argument.begins_with("--max-clients="):
			result.max_clients = argument.get_slice("=", 1).to_int()
		elif argument.begins_with("--bind="):
			result.bind = argument.get_slice("=", 1)

	return result
```

Validate the parsed values before starting the peer. A production bootstrap
should fail fast on an invalid port or nonsensical client count.

## 11. Start server mode without creating a local player

The dedicated path should not spawn a fake host player merely because peer ID
`1` exists.

Conceptually:

```gdscript
func _start_server(options: Dictionary) -> void:
	var error := network.start_enet_server(
		int(options.port),
		int(options.max_clients),
		str(options.bind),
	)

	if error != OK:
		push_error("Server failed: %s" % error_string(error))
		get_tree().quit(2)
		return

	_start_authoritative_world_without_local_player()
```

Player scenes should be created when admitted clients connect, not because the
server itself exists.

## 12. Test the dedicated topology locally

Before renting anything, run one local headless server process and two clients.

Server terminal:

```bash
godot --headless --path . -- --server --port=42069 --max-clients=8
```

Clients connect to:

```text
127.0.0.1:42069
```

Verify:

```text
server has no local player
both clients receive distinct peer IDs
server owns authoritative world state
clients cannot directly author critical results
client disconnect cleanup works
server continues after one client exits
```

This is the most valuable pre-deployment test because it proves the topology
without adding cloud variables.

## 13. Export a dedicated Linux build

Create a Linux export preset intended for the server.

Use Godot's **Export as dedicated server** mode where appropriate. That mode can
strip visual resources and supplies the `dedicated_server` feature tag.

The server output should be tested locally before upload.

Your startup code can then enter server mode because:

```gdscript
OS.has_feature("dedicated_server")
```

is true for that export.

## 14. Rent the smallest sensible VM first

For a first external test, one Linux VM with a public IP is enough.

Start small unless your measured workload says otherwise. A lightweight co-op
server often needs far less RAM than the graphical client; CPU/physics/network
work matters more than GPU because the dedicated build is headless.

Do not interpret a cheap VM as a promise that every game will run well on shared
CPU. Measure server frame time under representative player/NPC load.

Current pricing examples and a bandwidth calculation are in:

[`../multiplayer_deployment_quickstart.md`](../multiplayer_deployment_quickstart.md)

## 15. Secure the Linux host before exposing the game

A minimal server should use:

```text
SSH keys
unprivileged service account
system updates
only necessary inbound ports
process supervision
logs
```

Example firewall intent:

```text
22/tcp
    SSH administration
    ideally restricted by source policy where practical

42069/udp
    game ENet traffic
```

Do not open every port "to make networking work".

If you use WebSocket for browser clients, terminate TLS appropriately and expose
the specific TCP endpoint required by that design.

## 16. Run the server under systemd

The package includes:

```text
examples/networking/nucleus-server.service.example
```

A service manager gives you:

```text
start on boot
restart after crash
consistent working directory
journal logs
resource/process ownership
```

For one or a few machines, this is usually more useful than starting with a
container orchestrator.

After installing the service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now nucleus-server
sudo systemctl status nucleus-server
journalctl -u nucleus-server -f
```

Adapt usernames and paths to the deployment.

## 17. Verify the public server from outside its network

Do not validate a public endpoint only from the same machine.

From a different Internet connection:

1. connect using the public server address;
2. confirm `connected_to_server`;
3. join gameplay;
4. disconnect/reconnect;
5. restart the server process;
6. verify clients handle `server_disconnected` cleanly.

Then test latency and packet loss deliberately. A localhost-perfect game can
still feel poor at 60-120 ms RTT with jitter.

## 18. Add authentication after transport works, before public launch

A public endpoint should not equate "can reach UDP port" with "may join game".

Design:

```text
player identity
session/admission token
protocol/build compatibility
server-side validation of token/session
only then player spawn
```

Godot's `SceneMultiplayer` exposes authentication hooks that a project can use.
Provider-specific identity verification remains provider-owned.

Do not put long-lived private secrets in exported project Resources or source.
Use deployment secrets/environment/backend facilities appropriate to the
provider.

## 19. Measure before adding prediction or infrastructure complexity

Track at least:

```text
server physics/frame time
process CPU
resident memory
connected peers
packets/bytes in and out
intent rejection/rate-limit counts
disconnect/reconnect rate
```

Then profile a representative match.

Only add these when evidence requires them:

```text
client prediction/reconciliation
lag compensation
rollback
relay fleet
matchmaking service
autoscaling
container orchestration
database cluster
regional fleet
```

A working single authoritative server is a better foundation than an unfinished
"scalable architecture".

## 20. Know where the first money goes

The first recurring bill is usually the VM.

The next costs tend to appear in this order:

```text
more CPU/RAM or more game-server processes
outbound bandwidth beyond included transfer
persistent database/storage/backups
logs/metrics retention
relay/provider traffic
multiple regions
matchmaking/session backend
operations and support time
```

For a prototype with friends, a listen server can cost zero infrastructure.
For public testing, a small VM can remain in the low tens of USD per month.
At real concurrency, architecture and bandwidth matter more than the sticker
price of the first VM.

## 21. Decide when to move from listen server to dedicated

Stay with a listen server when most of these are true:

```text
small friend groups
sessions exist only while host plays
host advantage is acceptable
provider relay/direct connectivity is solved
no authoritative persistent world
low moderation/uptime requirements
```

Move toward dedicated authority when several are true:

```text
public matchmaking
persistent/shared world
competitive integrity
host migration is painful
host connectivity is unreliable
24/7 availability
server-side persistence/economy
moderation/ban enforcement
central anti-abuse policy
```

## 22. Release checklist

Before calling multiplayer production-ready, prove:

```text
[ ] localhost connect/disconnect/reconnect
[ ] LAN connection
[ ] real WAN connection
[ ] NAT/CGNAT product strategy
[ ] server-authoritative critical gameplay
[ ] invalid/malicious intents rejected
[ ] dedicated server has no accidental local player
[ ] dedicated export starts with production arguments
[ ] firewall exposes only required endpoints
[ ] process restarts after failure
[ ] logs identify build/version/session failures
[ ] client handles server restart/disconnect
[ ] authentication/admission exists for public play
[ ] representative latency/jitter test completed
[ ] measured CPU/RAM/network budget exists
[ ] monthly cost estimate includes traffic and storage
[ ] backup/restore tested if persistent state exists
```

## Frequently asked questions

### Do I need a dedicated server on day one?

No. Prove your gameplay with localhost/listen-server authority first. Rent a
server when public reachability, uptime, fairness or persistence requires it.

### Do I need port forwarding for localhost?

No. `127.0.0.1` never leaves the machine.

### Do I need port forwarding on LAN?

Usually not on the router, but the host OS firewall must allow the traffic and
the LAN must allow devices to talk to one another.

### Why can friends not connect even though I forwarded the port?

Check UDP vs TCP, firewall rules, the destination LAN IP, and whether the ISP
uses CGNAT.

### Does ENet encrypt/authenticate my players automatically?

Do not treat transport creation as identity or gameplay authorization. Add a
real admission/authentication design for a public game.

### Should clients own their transforms?

Only if your game intentionally accepts that trust model. For gameplay-critical
movement, server authority is the safer default, then add prediction if latency
evidence requires it.

### Should the server be an Autoload?

Only if its lifetime genuinely spans scene/session replacement. Scene ownership
is a good default.

### Docker or systemd?

For one VM, systemd is often simpler. Use containers when reproducible packaging,
isolation or orchestration actually helps your deployment.

### Kubernetes?

Not for the first server. Add orchestration after you have measured a need for a
fleet and understand how one server process maps to matches/worlds/ports.

## Source references

Godot documentation used by this tutorial:

- High-level multiplayer:
  https://docs.godotengine.org/en/4.7/tutorials/networking/high_level_multiplayer.html
- Dedicated-server exports:
  https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_dedicated_servers.html
- User command-line arguments:
  https://docs.godotengine.org/en/4.7/classes/class_os.html

For the Nucleus contracts, continue with:

- [`../../modules/networking.md`](../../modules/networking.md)
- [`../../modules/online_replication.md`](../../modules/online_replication.md)
- [`../online_replication_quickstart.md`](../online_replication_quickstart.md)
- [`../multiplayer_deployment_quickstart.md`](../multiplayer_deployment_quickstart.md)
